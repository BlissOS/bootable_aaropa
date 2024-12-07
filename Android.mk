# Copyright 2009-2014, The Android-x86 Open Source Project
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
BUILD_TOP := $(shell pwd)

ifneq ($(filter x86%,$(TARGET_ARCH)),)
LOCAL_PATH := $(call my-dir)

RELEASE_OS_TITLE := BlissOS-$(VERSION)

include $(CLEAR_VARS)
LOCAL_MODULE := iso_from_target_files
LOCAL_SRC_FILES := bin/iso_from_target_files
LOCAL_MODULE_CLASS := EXECUTABLES
LOCAL_MODULE_PATH := $(HOST_OUT)/bin

include $(BUILD_PREBUILT)

.PHONY: iso_scripts
iso_scripts: iso_from_target_files

VER ?= $$(date "+%Y-%m-%d")

# use squashfs or erofs for iso, unless explictly disabled
ifneq ($(USE_SQUASHFS),0)
MKSQUASHFS := $(HOST_OUT_EXECUTABLES)/mksquashfs$(HOST_EXECUTABLE_SUFFIX)

define build-squashfs-target
	$(hide) $(MKSQUASHFS) $(1) $(2) -noappend -comp zstd
endef
endif

ifneq ($(USE_EROFS),0)
MKEROFS := $(HOST_OUT_EXECUTABLES)/make_erofs$(HOST_EXECUTABLE_SUFFIX)

define build-erofs-target
	$(hide) $(MKEROFS) -zlz4hc -C65536 $(2) $(systemimage_intermediates)
endef
endif

initrd_dir := $(LOCAL_PATH)/initrd
initrd_bin := \
	$(initrd_dir)/init \
	$(wildcard $(initrd_dir)/*/*)

ifneq ($(USE_SQUASHFS),0)
systemimg  := $(PRODUCT_OUT)/system.$(if $(MKSQUASHFS),sfs,img)
else ifneq ($(USE_EROFS),0)
systemimg  := $(PRODUCT_OUT)/system.$(if $(MKEROFS),efs,img)
else
systemimg  := $(PRODUCT_OUT)/system.img
endif

TARGET_INITRD_OUT := $(PRODUCT_OUT)/initrd
INITRD_RAMDISK := $(TARGET_INITRD_OUT).img
$(INITRD_RAMDISK): $(initrd_bin) $(systemimg) $(TARGET_INITRD_SCRIPTS) | $(ACP) $(MKBOOTFS)
	$(hide) rm -rf $(TARGET_INITRD_OUT)
	mkdir -p $(addprefix $(TARGET_INITRD_OUT)/,android apex efi hd iso lib mnt proc scripts sfs sys tmp)
	$(if $(TARGET_INITRD_SCRIPTS),$(ACP) -p $(TARGET_INITRD_SCRIPTS) $(TARGET_INITRD_OUT)/scripts)
	ln -s /bin/ld-linux.so.2 $(TARGET_INITRD_OUT)/lib
	echo "VER=$(VER)" > $(TARGET_INITRD_OUT)/scripts/00-ver
	$(if $(RELEASE_OS_TITLE),echo "OS_TITLE=$(RELEASE_OS_TITLE)" >> $(TARGET_INITRD_OUT)/scripts/00-ver)
	$(if $(INSTALL_PREFIX),echo "INSTALL_PREFIX=$(INSTALL_PREFIX)" >> $(TARGET_INITRD_OUT)/scripts/00-ver)
	$(MKBOOTFS) $(<D) $(TARGET_INITRD_OUT) | gzip -9 > $@

.PHONY: initrdimage
initrdimage: $(INITRD_RAMDISK)

INSTALLED_RADIOIMAGE_TARGET += $(INITRD_RAMDISK)
INSTALLED_RADIOIMAGE_TARGET += $(PRODUCT_OUT)/ramdisk-recovery.img

INSTALL_RAMDISK := $(PRODUCT_OUT)/install.img
$(INSTALL_RAMDISK): $(wildcard $(LOCAL_PATH)/install/*/* $(LOCAL_PATH)/install/*/*/*/*) | $(MKBOOTFS)
	$(if $(TARGET_INSTALL_SCRIPTS),mkdir -p $(TARGET_INSTALLER_OUT)/scripts; $(ACP) -p $(TARGET_INSTALL_SCRIPTS) $(TARGET_INSTALLER_OUT)/scripts)
	$(MKBOOTFS) $(dir $(dir $(<D))) $(TARGET_INSTALLER_OUT) | gzip -9 > $@

.PHONY: installimage
installimage: $(INSTALL_RAMDISK)

boot_dir := $(PRODUCT_OUT)/boot
$(boot_dir): $(shell find $(LOCAL_PATH)/boot -type f | sort -r) $(systemimg) $(INSTALL_RAMDISK) $(GENERIC_X86_CONFIG_MK) | $(ACP)
	$(hide) rm -rf $@
	$(ACP) -pr $(dir $(<D)) $@
	$(ACP) -pr $(dir $(<D))../install/grub2/efi $@
	PATH="/sbin:/usr/sbin:/bin:/usr/bin"; \
	img=$@/boot/grub/efi.img; dd if=/dev/zero of=$$img bs=3M count=5; \
	mkdosfs -n EFI $$img; mmd -i $$img ::boot; \
	mcopy -si $$img $@/efi ::; mdel -i $$img ::efi/boot/*.cfg

BUILT_IMG := $(addprefix $(PRODUCT_OUT)/,initrd.img install.img ramdisk-recovery.img) $(systemimg)
BUILT_IMG += $(if $(TARGET_PREBUILT_KERNEL),$(TARGET_PREBUILT_KERNEL),$(PRODUCT_OUT)/kernel)

BUILD_NAME_VARIANT := $(ROM_VENDOR_VERSION)

ISO_IMAGE := $(PRODUCT_OUT)/$(BLISS_BUILD_ZIP).iso
$(ISO_IMAGE): $(boot_dir) $(BUILT_IMG)
	# Generate Changelog
	@echo ----- Making iso image ------
	$(hide) sed -i "s|VER|$(VER)|; s|CMDLINE|$(BOARD_KERNEL_CMDLINE)|" $</efi/boot/android.cfg
	PATH="/sbin:/usr/sbin:/bin:/usr/bin"; \
	which xorriso > /dev/null 2>&1 && GENISOIMG="xorriso -as mkisofs" || GENISOIMG=genisoimage; \
	$$GENISOIMG -vJURT -b isolinux/isolinux.bin -c isolinux/boot.cat \
		-no-emul-boot -boot-load-size 4 -boot-info-table -eltorito-alt-boot -e boot/grub/efi.img -no-emul-boot \
		-input-charset utf-8 -V "$(if $(RELEASE_OS_TITLE),$(RELEASE_OS_TITLE),Android-x86) ($(TARGET_ARCH))" -o $@ $^
	$(hide) PATH="/sbin:/usr/sbin:/bin:/usr/bin" isohybrid --uefi $@
	$(hide) $(SHA256) $(ISO_IMAGE) | sed "s|$(PRODUCT_OUT)/||" > $(ISO_IMAGE).sha256
	@echo -e ${CL_CYN}""${CL_CYN}
	@echo -e ${CL_CYN}"      ___           ___                   ___           ___      "${CL_CYN}
	@echo -e ${CL_CYN}"     /\  \         /\__\      ___        /\  \         /\  \     "${CL_CYN}
	@echo -e ${CL_CYN}"    /::\  \       /:/  /     /\  \      /::\  \       /::\  \    "${CL_CYN}
	@echo -e ${CL_CYN}"   /:/\:\  \     /:/  /      \:\  \    /:/\ \  \     /:/\ \  \   "${CL_CYN}
	@echo -e ${CL_CYN}"  /::\~\:\__\   /:/  /       /::\__\  _\:\~\ \  \   _\:\~\ \  \  "${CL_CYN}
	@echo -e ${CL_CYN}" /:/\:\ \:\__\ /:/__/     __/:/\/__/ /\ \:\ \ \__\ /\ \:\ \ \__\ "${CL_CYN}
	@echo -e ${CL_CYN}" \:\~\:\/:/  / \:\  \    /\/:/  /    \:\ \:\ \/__/ \:\ \:\ \/__/ "${CL_CYN}
	@echo -e ${CL_CYN}"  \:\ \::/  /   \:\  \   \::/__/      \:\ \:\__\    \:\ \:\__\   "${CL_CYN}
	@echo -e ${CL_CYN}"   \:\/:/  /     \:\  \   \:\__\       \:\/:/  /     \:\/:/  /   "${CL_CYN}
	@echo -e ${CL_CYN}"    \::/__/       \:\__\   \/__/        \::/  /       \::/  /    "${CL_CYN}
	@echo -e ${CL_CYN}"     ~~            \/__/                 \/__/         \/__/     "${CL_CYN}
	@echo -e ${CL_CYN}""${CL_CYN}
	@echo -e ${CL_CYN}"===========-Bliss Package Complete-==========="${CL_RST}
	@echo -e ${CL_CYN}"Zip: "${CL_MAG} $(ISO_IMAGE)${CL_RST}
	@echo -e ${CL_CYN}"SHA256: "${CL_MAG}" `cat $(ISO_IMAGE).sha256 | cut -d ' ' -f 1`"${CL_RST}
	@echo -e ${CL_CYN}"Size:"${CL_MAG}" `ls -lah $(ISO_IMAGE) | cut -d ' ' -f 5`"${CL_RST}
	@echo -e ${CL_CYN}"==============================================="${CL_RST}
	@echo -e ${CL_CYN}"Have A Truly Blissful Experience"${CL_RST}
	@echo -e ${CL_CYN}"==============================================="${CL_RST}
	@echo -e ""

.PHONY: iso_img
iso_img: $(ISO_IMAGE)

endif
