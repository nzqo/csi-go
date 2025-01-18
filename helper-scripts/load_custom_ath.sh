#!/bin/bash
# ==============================================================
# To collect CSI, we modify drivers already present in the linux
# kernel. This script unloads the respective default modules and
# loads the modified ones.
#
# NOTE: These modifications are not persistent. After rebooting,
# the original modules will be loaded. To persist them you would
# need to install the modified modules with `make install`.
# ==============================================================
original_modules=(
    ath9k
    ath9k_common
    ath9k_hw
    ath
)


###################################################################
# Script logic start.
# - Skip if driver already loaded
# - Otherwise unload dependent modules and reload custom built ones
###################################################################
# Exit if modules are already loaded
if lsmod | grep -wq "ar9003_csi"; then
  echo "Looks like modified CSI modules are already loaded! -- Exiting."
  exit 0
fi


# Propagate errors
set -e

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
echo "Assuming you are running this from the project root directory!"

# TODO!
echo "TODO: Be smarter about path where to load modules from"
basepath="$HOME/Development/csi-modules"

sudo modprobe mac80211
load_module_from_file "$basepath/driver/build/module_src/ath/ath.ko"
load_module_from_file "$basepath/driver/build/module_src/ath/ath9k/ar9003_csi.ko"
load_module_from_file "$basepath/driver/build/module_src/ath/ath9k/ath9k_hw.ko"
load_module_from_file "$basepath/driver/build/module_src/ath/ath9k/ath9k_common.ko"
load_module_from_file "$basepath/driver/build/module_src/ath/ath9k/ath9k.ko"

sleep 1
