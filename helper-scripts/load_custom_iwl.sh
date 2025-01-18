#!/bin/bash
# ==============================================================
# To collect CSI, we modify drivers already present in the linux
# kernel. This script unloads the respective default modules and
# loads the modified ones.
#
# NOTE: These modifications are not persistent. After rebooting,
# the original modules will be loaded. To persist them you would
# need to install the modified modules with `make install`.
#
# NOTE2: This script offers to blacklist the original modules to
# avoid having them be loaded automatically. However, this won't
# make the custom modules load automatically either.
# ==============================================================

# Propagate errors
set -e

modprobe_config_file="/etc/modprobe.d/5300-csi.conf"
original_modules=(
	iwlmvm
	iwldvm
	iwlwifi
)

# Blacklist modules to avoid them from being loaded
function blacklist_original_modules {
	for module in "${original_modules[@]}"; do
		echo "blacklist ${module}" | sudo tee -a "${modprobe_config_file}"
	done
}

# Offer user to blacklist modules
if [ ! -f "${modprobe_config_file}" ]; then
    echo "Default intel iwlwifi drivers not blacklisted."
    echo "After reinstall, they will be reloaded automatically."
    read -p "Do you want to disable them? [y|n]" -n 1 -r && echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
    	blacklist_original_modules
    fi
fi

# Unload the modules.
# NOTE: Since we currently don't install the manually built modules
# loading and unloading them cant be done with modprobe.
echo "======================================"
echo "Unloading currently active modules ..."
for module in "${original_modules[@]}"; do
    if lsmod | grep -wq "${module}"; then
        sudo rmmod "${module}"
        echo "--> Unloaded module: ${module}"
    fi
done

# Finally load the modified modules.
# Make sure that they were built and are found, then load them.
function load_module_from_file {
    modobj="$1"
    modargs="$2"
    [ ! -f "${modobj}" ] && echo "Module ${modobj} not found; Did you build it?" && exit 1
    sudo insmod "${modobj}" "${modargs}"
    echo "--> Loaded modified module: ${modobj}"
}

echo "Loading modified modules (assuming they were built)..."
sudo modprobe mac80211
load_module_from_file "build/module_src/iwlwifi/iwlwifi.ko" connector_log=0x1
load_module_from_file "build/module_src/iwlwifi/dvm/iwldvm.ko"
load_module_from_file "build/module_src/iwlwifi/mvm/iwlmvm.ko"
