# Copyright 2009-2014, The Android-x86 Open Source Project
# Copyright 2024, BlissLabs
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
initrd_lib_dir := $(LOCAL_PATH)/initrd_lib

ifneq ($(shell test -d $(initrd_lib_dir) && echo exists), exists)
    $(error initrd_lib does not exist, have you run the download script yet ?)
endif

ifneq ($(USE_SQUASHFS),0)
systemimg  := $(PRODUCT_OUT)/system.$(if $(MKSQUASHFS),sfs,img)
else ifneq ($(USE_EROFS),0)
systemimg  := $(PRODUCT_OUT)/system.$(if $(MKEROFS),efs,img)
else
systemimg  := $(PRODUCT_OUT)/system.img
endif

TARGET_INITRD_OUT := $(PRODUCT_OUT)/initrd
INITRD_RAMDISK := $(TARGET_INITRD_OUT).img
$(INITRD_RAMDISK): $(initrd_bin) $(systemimg) $(TARGET_INITRD_SCRIPTS) | $(ACP) $(HOST_OUT_EXECUTABLES)/toybox
	$(hide) rm -rf $(TARGET_INITRD_OUT)
	mkdir -p $(addprefix $(TARGET_INITRD_OUT)/,android apex mnt proc scripts sys tmp)
	$(if $(TARGET_INITRD_SCRIPTS),$(ACP) -p $(TARGET_INITRD_SCRIPTS) $(TARGET_INITRD_OUT)/scripts)
	echo "VER=$(VER)" > $(TARGET_INITRD_OUT)/scripts/00-ver
	$(if $(RELEASE_OS_TITLE),echo "OS_TITLE=$(RELEASE_OS_TITLE)" >> $(TARGET_INITRD_OUT)/scripts/00-ver)
	$(if $(INSTALL_PREFIX),echo "INSTALL_PREFIX=$(INSTALL_PREFIX)" >> $(TARGET_INITRD_OUT)/scripts/00-ver)
	$(ACP) -dpr $(initrd_dir)/* $(initrd_lib_dir)/* $(TARGET_INITRD_OUT)
	cd $(TARGET_INITRD_OUT); find . | $(HOST_OUT_EXECUTABLES)/toybox cpio -o | gzip -9 > $@; cd -

.PHONY: initrdimage
initrdimage: $(INITRD_RAMDISK)

INSTALLED_RADIOIMAGE_TARGET += $(INITRD_RAMDISK)
INSTALLED_RADIOIMAGE_TARGET += $(PRODUCT_OUT)/ramdisk-recovery.img

BUILT_IMG := $(addprefix $(PRODUCT_OUT)/,initrd.img ramdisk-recovery.img) $(systemimg)
BUILT_IMG += $(if $(TARGET_PREBUILT_KERNEL),$(TARGET_PREBUILT_KERNEL),$(PRODUCT_OUT)/kernel)

ifneq ($(shell test -d $(LOCAL_PATH)/iso && echo exists), exists)
    $(error iso does not exist, have you run the download script yet ?)
endif

MOD_DATE := $(shell date +"%Y%m%d%H%M%S"00)
DISK_LABEL := $(if $(RELEASE_OS_TITLE),$(RELEASE_OS_TITLE),Android-x86)_$(shell date "+%Y%m%d")
BOOT_HYBRID := $(LOCAL_PATH)/boot_hybrid.img
iso_dir := $(PRODUCT_OUT)/iso
$(iso_dir): $(shell find $(LOCAL_PATH)/iso -type f | sort -r) | $(ACP)
	$(hide) rm -rf $@
	$(ACP) -pr $(dir $<) $@
	$(hide) sed -i "s|OS_TITLE|$(if $(RELEASE_OS_TITLE),$(RELEASE_OS_TITLE),Android-x86)|" $@/boot/grub/grub.cfg
	$(hide) sed -i "s|BlissOSLive|$(DISK_LABEL)|" $@/boot/grub/grub.cfg
	$(hide) sed -i "s|CMDLINE|$(BOARD_KERNEL_CMDLINE)|" $@/boot/grub/grub.cfg
	$(hide) sed -i "s|VER|$(VER)|" $@/boot/grub/grub.cfg
	$(hide) echo "$(BOARD_KERNEL_CMDLINE)" > $@/cmdline.txt

ISO_IMAGE := $(PRODUCT_OUT)/$(BLISS_BUILD_ZIP).iso
$(ISO_IMAGE): $(iso_dir) $(BUILT_IMG)
	@echo ----- Making iso image ------
	PATH="/sbin:/usr/sbin:/bin:/usr/bin"; \
	xorriso -as mkisofs -graft-points --modification-date=$(MOD_DATE) -b /boot/grub/i386-pc/eltorito.img \
		-no-emul-boot -boot-load-size 4 -boot-info-table --grub2-boot-info --grub2-mbr $(BOOT_HYBRID) \
		-hfsplus -apm-block-size 2048 -hfsplus-file-creator-type chrp tbxj /System/Library/CoreServices/.disk_label \
		-hfs-bless-by i /System/Library/CoreServices/boot.efi --efi-boot efi.img -efi-boot-part --efi-boot-image \
		--protective-msdos-label -o $@ $^ --sort-weight 0 / --sort-weight 1 /boot \
		-V "$(DISK_LABEL)"
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
