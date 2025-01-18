#!/bin/bash
# ==================================================================
# Helper script to quickly regenerate a new patch after modification
# of source files
# ==================================================================

# ------------------------------------------------------------------
# Functions
# ------------------------------------------------------------------
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


# ------------------------------------------------------------------
# Script logic: Source Setup
# ------------------------------------------------------------------
if has_param "-h" "$@"; then
    echo "Regenerate new patches for the driver modifications."
    echo "Mappings  Original kernel source dir   -->  Modified current sources"
    echo "          module_src/ath_orig          -->  module_src/ath"
    echo "          module_src/iwlwifi_orig      -->  module_src/iwlwifi"
    echo ""
    echo "NOTE: Must be called from within 'driver' subdirectory."
    echo ""
    echo "Usage: ./update_patch.sh"
    exit 0
fi

# Delegate to create_diff with appropriate directories
./patch/create_diff.sh module_src/ath_orig     module_src/ath     patch/current/ath
./patch/create_diff.sh module_src/iwlwifi_orig module_src/iwlwifi patch/current/iwlwifi
