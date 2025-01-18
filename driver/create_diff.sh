#!/bin/bash
# ===================================================================
# Script to create suitable diffs containing changes made between two
# directories, exluding irrelevant stuff.
#
# Usage:
# create_diff.sh <original_dir> <modified_dir> <output_diff_directory>
#
# NOTE:
# We don't diff the full kernel source, but only the respective changed
# driver. For example, if you pull a full kernel source tree into <src>,
# the actual directory to diff would be:
#     <src>/drivers/net/wireless/ath
# ===================================================================

# ------------------------------------------------------------------
# Functions
# ------------------------------------------------------------------
ensure_package_installed() {
	package=$1
	if ! dpkg-query -W -f='${Status}' "${package}"  | grep "ok installed"; then
		sudo apt install --no-install-recommends "${package}"
	fi
}


# ------------------------------------------------------------------
# Script logic
# ------------------------------------------------------------------
original_dir=$1
modified_dir=$2
output_dir=$3

# Ensure patchutils (for splitdiff) is installed
ensure_package_installed patchutils

# Create the diff in a temporary file
# NOTE: The sed command removes creations timestamps so that regenerating
# the patch without changes doesnt result in a commit.
temp_file=$(mktemp -q)
diff --unified \
	--recursive \
	--no-dereference \
	--text \
	--unidirectional-new-file \
	--ignore-trailing-space \
	--ignore-space-change \
	--exclude=".git" \
	--exclude="README*" \
	--exclude="*.pdf" \
	--exclude="*.svg" \
	--exclude="*.vim" \
	"${original_dir}" \
	"${modified_dir}" \
	| sed '/^---[[:space:]]/s/\t[0-9]\{4\}-[0-9]\{2\}-[0-9]\{2\}.*//; /^+++[[:space:]]/s/\t[0-9]\{4\}-[0-9]\{2\}-[0-9]\{2\}.*//' \
	> "${temp_file}"

# Split diff in one patch file per changed kernel module file.
splitdiff -a -d -D "${output_dir}" "${temp_file}"
rm "${temp_file}"
