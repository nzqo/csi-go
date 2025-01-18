# CSI:GO

**CSI extraction patches for modern Linux kernels**

CSI:GO uses diff-based patching to extract and apply the necessary kernel module
changes from the Intel 5300 CSI Tool and Atheros CSI Tool. This lets you run both
on modern kernels without full kernel rebuilds.

The Atheros patches differ, addressing potential race conditions while the Intel
modifications are adapted only as needed. The Atheros module is also modified to
report the MAC Sequence Number, and I removed the frame payload reporting to lighten
the load, catering exclusively to CSI reporting.

---

## Features

- **Diff-based patching:** Build only the required modules.
- **Modular approach:** Avoid full kernel builds. Fast and allows using both modules in one system.
- **Modern kernel support:** No legacy restrictions.
- **Easy installation:** Load modules directly into a running system.

---

## Driver (in the `driver` subdirectory)

This directory contains scripts to build modified CSI extraction kernel modules for `ath9k` and `iwl5300`.
The patches are curated for newer kernel versions and may not be backwards compatible. However, the diff-based
approach makes adapting them straightforward.

**Current patch target kernel version:**  
> 6.8.0-51

### Build & Installation

1. **Fetch & Patch:**  
    Run `./pull_and_apply.sh` to download the current kernel sources and apply the patch files.
    Patched sources will be placed in `module_src`. Check the output to see if any hunks failed
    and potentially fix issues manually in the source directory. See [below](#updating-patches)
    for how to commit updates.

2. **Build:**  
    Use `make` to build the all target, otherwise use the `ath` or `iwl` targets to build only
    the respective module. This performs an out-of-tree build so that only the affected modules
    are built.

3. **Install:**  
    Install the modules with:
  
    ```bash
    sudo make install
    ```
  
    (This target proxies both `install_ath` and `install_iwl`, which may be used to perform targeted install).
    Afterwards reboot. This will install the modules into the updates directory `/lib/modules/<ver>/updates`.
    Note that DKMS updates may take precedence. To check which module is used, use `sudo modinfo ath9k | grep filename`.


Directories such as `kernel_source`, `module_src`, and `build` are created during the process
but are not committed. If you want to commit a change to the module, see next [section](#updating-patches).

## Usage

With the kernel modules running, CSI is now being extracted. To actually receive it:

1. **Build Extractor**

    For the Intel tool, use the original [connector](https://github.com/dhalperi/linux-80211n-csitool-supplementary)
    to receive CSI from the kernel module.

    The Atheros tool still exposes a character device file, but since we changed the format,
    you need to use the modified extractor. It's a simple CMake project, so in the `extractor`
    directory, run:

    ```cbash
    cmake -S . -B build && cmake --build build
    ```

1. **Use extractor**

    For the qca extractor, as in the original tool, run:

    ```bash
    ./build/csi-extractor <file>
    ```

    This will log data to the specified file. Specifically, it will write the bytes of `struct csi_user_info`
    (see `driver/patch/current/ath/module_src_ath_ath9k_ath9k_csi.h.patch` ) the CSI matrix packed to the file.
    Aside from the struct, the CSI data is the same as in the original tool. To use it, you can write your own
    scripts or slightly adapt the [original tool](https://github.com/xieyaxiongfly/Atheros-CSI-Tool-UserSpace-APP).


---

## Updating Patches

If patch conflicts occur:

- Manually fix the conflicts in `module_src/ath` or `module_src/iwlwifi`.
- Regenerate the patch with:
  
    ```bash
    ./create_diff.sh module_src/ath_original module_src/ath patch/current/ath
    ```

- Submit a pull request with your update.

*Note:* New patches may not work with older kernel versions.


---

## Supported Hardware

- **Intel 5300 Wi-Fi (iwl5300)**
- **Atheros Wi-Fi (ath9k series)**

---

## License

CSI:GO is licensed under **GPLv2**, following the original projects.

---

## Contributing

Pull requests are welcome. Open an issue or contact me directly if you have any suggestions or issues.

---

## Acknowledgments

- [**Intel 5300 CSI Tool**](https://dhalperi.github.io/linux-80211n-csitool/)
- [**Atheros CSI Tool**](https://wands.sg/research/wifi/AtherosCSI/)
- The Linux kernel community
