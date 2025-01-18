#!/bin/bash

#------------------------------------------------------------------------------
# Script to set network interface into monitor mode on a specific channel.
#
# Usage:
#   ./script.sh <interface> [center_freq_mhz] [bandwidth_mhz] [control_freq_mhz]
#
# Params:
#   interface        : The interface (e.g., `lshw -class network -short`)
#   center_freq_mhz  : Center frequency of channel (default: 2412)
#   bandwidth_mhz    : Channel bandwidth in MHz (default: 20)
#   control_freq_mhz : Control frequency for wide channels (>20 MHz) (optional)
#------------------------------------------------------------------------------

# Display help
show_help() {
    echo "Usage: $0 <interface> [center_freq_mhz] [bandwidth_mhz] [control_freq_mhz]"
    echo
    echo "Params:"
    echo "  interface        : Network interface (e.g., 'wlan0')"
    echo "  center_freq_mhz  : Center frequency of channel (default: 2412)"
    echo "  bandwidth_mhz    : Channel bandwidth in MHz (default: 20)"
    echo "  control_freq_mhz : Control frequency for wide channels (>20 MHz) (optional)"
    exit 1
}

# Argument check
[[ $# -lt 1 || $# -gt 4 ]] && show_help
if [[ "$1" == "--help" || "$1" == "-h" ]]; then
    show_help
fi

interface=$1
center_freq_mhz=${2:-2412}
bandwidth_mhz=${3:-20}
control_freq_mhz=${4:-""}

# Validate bandwidth and control frequency requirements
if [[ $bandwidth_mhz -ne 20 && -z $control_freq_mhz ]]; then
    echo "Error: Bandwidths larger than 20 MHz require a control frequency to be set." 1>&2
    exit 1
fi

# Set up the interface
sudo ip link set dev "${interface}" down
sudo ifconfig "${interface}" down
sudo iwconfig "${interface}" mode monitor
sudo ifconfig "${interface}" up
sudo iw reg set US

# Configure frequency
if [[ $bandwidth_mhz -ne 20 ]]; then
    freq_args=("${control_freq_mhz}" "${bandwidth_mhz}" "${center_freq_mhz}")
else
    freq_args=("${center_freq_mhz}" "${bandwidth_mhz}")
fi

sudo iw "${interface}" set freq "${freq_args[@]}"
