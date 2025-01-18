#!/bin/bash

#------------------------------------------------------------------------------
# Script to permanently disable network manager. This may not be needed on newer
# Ubuntu versions. We keep this for legacy reasons, where NetworkManager would
# regularly interfere with managing the network cards.
#
# Simply call this script without arguments.
#------------------------------------------------------------------------------

services_to_stop=(
	wpa_supplicant
	wpa_supplicant.service
	NetworkManager
	NetworkManager.service
	network-manager.service
	NetworkManager-dispatcher.service
	NetworkManager-wait-online.service
)

for service in "${services_to_stop[@]}"; do
	# I dont know why, but only disabling these services did
	# not prevent wpa_supplicant from getting started. Masks
	# might be sufficient, but better be overly thorough.
	sudo systemctl stop "${service}"
	sudo systemctl disable "${service}"
	sudo systemctl mask "${service}"
	echo "Stopped and masked ${service}"
done
