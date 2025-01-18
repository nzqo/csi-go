#!/bin/bash
# ==================================================================
# Script to pull current linux sources and try to apply the patches
# Will perform the following steps, in detail:
# - Pull kernel source tree for currently running kernel version
# - Extract ath kernel module sources from there into `src` dir
# - Try to apply the patches to those sources
# ==================================================================
set -e

# ------------------------------------------------------------------
# Functions
# ------------------------------------------------------------------
# Function to ensure that apt package is installed
ensure_package_installed() {
    package=$1
    if ! dpkg-query -W -f='${Status}' "${package}"  | grep "ok installed"; then
            sudo apt install --no-install-recommends "${package}"
    fi
}

# Function to check argument array for whether it contains flag
function has_param {
    local term="$1"
    shift
    for arg; do
        if [[ $arg == "$term" ]]; then
            return 0
        fi
    done
    return 1
}

function extract_module {
    # Extract driver sources
    # NOTE: We keep two directories for allowing diffs on changes:
    # - one with the original sources we do not want to change
    # - one to which the patches are to be applied.
    module_name=$1
    module_src_path=$2
    module_target_path=$3
    module_orig_path="${module_target_path}_orig"

    echo "Copying kernel module source from original kernel source tree ..."
    echo " -- Module name : ${module_name}"
    echo " -- From path   : ${module_src_path}"
    echo " -- To path     : ${module_target_path}"

    cp -r "$module_src_path" "$module_target_path"
    cp -r "$module_target_path" "$module_orig_path"

    echo "Copy finished"
    echo " -- Original kernel module src      : '${src_dir}/ath_original'"
    echo " -- To be patched kernel module src : '${src_dir}/ath'"
}

function apply_patch {
    patchfile_dir=$1
    for f in "${patchfile_dir}"/*; do
        echo "-----------------------------------------------------------"
        echo "Applying patch file: ${f}"
        patch --strip=0 --unified --forward --input "${f}"
        echo "Finished patch file application"
        echo ""
    done
}


# ------------------------------------------------------------------
# Script logic: Source Setup
# ------------------------------------------------------------------
# Check whether non-interactive mode (default yes) is specified
if has_param "--y" "$@"; then
    REPLY="y"
    non_interactive=1
fi

if has_param "-h" "$@"; then
    echo "Helper script to pull kernel sources and apply patches."
    echo "Usage: ./pull_and_apply.sh [--y] [-h]"
    echo "   --y : non-interactive mode, answer queries with 'yes'"
    echo "    -h : Display this help message"
    exit 0
fi

# dpkg-dev is required to pull sources from apt package (here, the kernel)
ensure_package_installed dpkg-dev

# Ensure that source ppas are enabled so the sources can be fetched
echo "Ensuring ubuntu apt source repositories are enabled.
INFO: This will change your '/etc/apt/sources.list'"
sudo sed -i~orig -e '/ubuntu/ s/# deb-src/deb-src/' /etc/apt/sources.list
sudo apt update

# Define output directories
kernel_src_dir="kernel_source"
src_dir="module_src"

# Pull kernel source if not done yet
mkdir -p "${kernel_src_dir}"
if [ -z "$(ls -A ${kernel_src_dir})" ]; then
    pushd "${kernel_src_dir}" || exit
    echo "Downloading kernel sources into: ${kernel_src_dir}"
    apt-get source "linux-image-unsigned-$(uname -r)"
    rm ./*.gz ./*.dsc
    popd || exit
else
    echo "Directory with kernel sources ${kernel_src_dir} already exists. Skipping download."
fi

# BTF generation can fail if vmlinux is not present in the correct directory
# See: https://askubuntu.com/questions/1348250/skipping-btf-generation-xxx-due-to-unavailability-of-vmlinux-on-ubuntu-21-04
if [ -z "$non_interactive" ]; then
    read -p "BTF generation is a bit buggy. Do you want to apply a potential fix? [y|n]" -n 1 -r && echo
fi
if [[ $REPLY =~ ^[Yy]$ ]]; then
    ensure_package_installed dwarves
    sudo ln -sf "/sys/kernel/btf/vmlinux" "/usr/lib/modules/$(uname -r)/build/"
fi

# Possibly empty source directory. Reapplying patches sometimes bugs out, so this is favored.
mkdir -p "${src_dir}"
if [ "$(ls -A ${src_dir})" ]; then
    if [ -z "$non_interactive" ]; then
        read -p "src directory not empty. Reapplying patches is buggy, clear src dir? [y|n]" -n 1 -r && echo
    fi

    if [[ $REPLY =~ ^[Yy]$ ]]; then
        rm -rf "${src_dir:?}"/*
    fi
fi

# ------------------------------------------------------------------
# Script logic 
# ------------------------------------------------------------------
set +e
# First we extract the module sources into separate directories
extract_module "ath"     "${kernel_src_dir}"/*/drivers/net/wireless/ath           "${src_dir}"/ath
extract_module "iwlwifi" "${kernel_src_dir}"/*/drivers/net/wireless/intel/iwlwifi "$src_dir"/iwlwifi

# Then we patch the sources in these directories to prepare them for being built
apply_patch "patch/current/ath"
apply_patch "patch/current/iwlwifi"

echo "All sources downloaded and patched."
