# Kernel Module Build and Install Makefile

PWD      := $(CURDIR)
BUILDDIR := build
SRCDIR   := module_src
ATHSRC   := $(SRCDIR)/ath
IWLSRC   := $(SRCDIR)/iwlwifi

# Extract running kernel version and module build path
KERNEL_VERSION := $(shell uname -r)
KERNEL_PATH    := /lib/modules/$(KERNEL_VERSION)/build

.PHONY: all ath iwl install_ath install_iwl clean
.PHONY: install install_ath install_iwl

all: ath iwl
install: install_ath install_iwl


# =========== Build targets
# kbuild does not support build directories for out-of-tree build.
# We create an artificial build directory by copying all relevant
# build files into BUILDDIR and start the make process there.
ath: | $(SRCDIR)
	rsync --archive --relative Makefile $(ATHSRC) $(BUILDDIR) --exclude=".git"
	make -j$(nproc) -C $(KERNEL_PATH) M=$(PWD)/$(BUILDDIR)/$(ATHSRC) modules 

iwl: | $(SRCDIR)
	rsync --archive --relative Makefile $(IWLSRC) $(BUILDDIR) --exclude=".git"
	make -j$(nproc) -C $(KERNEL_PATH) M=$(PWD)/$(BUILDDIR)/$(IWLSRC) modules 

$(SRCDIR):
	$(error Source not yet present. Invoke the fetch_and_apply.sh script. See README.)


# =========== Installation targets
install_ath:
	make -C $(KERNEL_PATH) M=$(PWD)/$(BUILDDIR)/$(ATHSRC) INSTALL_MOD_DIR=updates modules_install
	depmod -A

install_iwl:
	make -C $(KERNEL_PATH) M=$(PWD)/$(BUILDDIR)/$(IWLSRC) INSTALL_MOD_DIR=updates modules_install
	depmod -A


# =========== Experimental load-once targets
load_ath:
	modprobe -r ath9k || true
	modprobe ath9k

load_iwl:
	modprobe -r iwlwifi iwldvm mac80211 || true
	modprobe iwlwifi connector_log=0x1


# =========== Clean target
clean: 
	make -C $(KERNEL_PATH) M=$(PWD) clean
	rm -rf $(BUILDDIR)
