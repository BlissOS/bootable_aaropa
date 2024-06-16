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
LOCAL_IS_HOST_MODULE := true
LOCAL_SRC_FILES := rpm/qemu-android
LOCAL_MODULE := $(notdir $(LOCAL_SRC_FILES))
LOCAL_MODULE_CLASS := EXECUTABLES
LOCAL_POST_INSTALL_CMD := $(hide) sed -i "s|CMDLINE|$(BOARD_KERNEL_CMDLINE)|" $(HOST_OUT_EXECUTABLES)/$(LOCAL_MODULE)
include $(BUILD_PREBUILT)

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

BUILT_IMG := $(addprefix $(PRODUCT_OUT)/,initrd.img install.img) $(systemimg)
BUILT_IMG += $(if $(TARGET_PREBUILT_KERNEL),$(TARGET_PREBUILT_KERNEL),$(PRODUCT_OUT)/kernel)

# Grab branch names
KRNL := $(shell cd $(BUILD_TOP)/kernel ; make kernelversion)
MSA := $(shell cd $(BUILD_TOP)/external/mesa ; git name-rev --name-only HEAD | cut -d '/' -f3)
HWC := $(shell cd $(BUILD_TOP)/external/drm_hwcomposer ; git name-rev --name-only HEAD | cut -d '/' -f3)

# Grab enabled extras
ifeq ($(USE_GMS),true)
	GMS := "_gms"
else ifeq ($(USE_EMU_GAPPS),true)
	GMS := "_emugapps"
else ifeq ($(USE_FOSS_APPS),true)
	GMS := "_foss"
else
	GMS := ""
endif

ifeq ($(USE_LIBNDK_TRANSLATION_NB),true)
	HOU := "_libndk"
else ifeq ($(USE_CROS_HOUDINI_NB),true)
	HOU := "_cros-hd"
else
	HOU := ""
endif

ifeq ($(USE_WIDEVINE),true)
WDV := "_cros-wv"
else
WDV := ""
endif

ifneq ("$(wildcard $(PRODUCT_OUT)/gearlock)","")
GLK := "_gearlock"
else
GLK := ""
endif

ifeq ($(TARGET_ARCH),x86_64)
IS_ANDROID_X86_64 := true
else ifeq ($(TARGET_ARCH),x86)
IS_ANDROID_X86_64 := false
endif

# Use vendor defined version names
ifeq ($(TARGET_PRODUCT),virtualbox)
KRNL := $(shell cd $(BUILD_TOP)/kernel ; make kernelversion)
ROM_VENDOR_VERSION := $(RELEASE_OS_TITLE)-vbox-$(shell date +%Y%m%d%H%M)
else ifeq ($(TARGET_PRODUCT),legacy_pc)
KRNL := $(shell cd $(BUILD_TOP)/kernel ; make kernelversion)
ROM_VENDOR_VERSION := $(RELEASE_OS_TITLE)-legacy_pc-$(shell date +%Y%m%d%H%M)
else
ROM_VENDOR_VERSION := $(RELEASE_OS_TITLE)-$(TARGET_ARCH)-$(shell date +%Y%m%d%H%M)
endif

BUILD_NAME_VARIANT := $(ROM_VENDOR_VERSION)

ISO_IMAGE := $(PRODUCT_OUT)/$(BLISS_VERSION).iso
$(ISO_IMAGE): $(boot_dir) $(BUILT_IMG)
	# Generate Changelog
	bash bootable/newinstaller/tools/changelog
	$(hide) mv Changelog.txt $(PRODUCT_OUT)/Changelog-$(BLISS_VERSION).txt
	@echo ----- Making iso image ------
	$(hide) sed -i "s|\(Installation CD\)\(.*\)|\1 $(VER)|; s|CMDLINE|$(BOARD_KERNEL_CMDLINE)|" $</isolinux/isolinux.cfg
	$(hide) sed -i "s|VER|$(VER)|; s|CMDLINE|$(BOARD_KERNEL_CMDLINE)|" $</efi/boot/android.cfg
	sed -i "s|OS_TITLE|$(if $(RELEASE_OS_TITLE),$(RELEASE_OS_TITLE),Android-x86)|" $</isolinux/isolinux.cfg $</efi/boot/android.cfg
	PATH="/sbin:/usr/sbin:/bin:/usr/bin"; \
	which xorriso > /dev/null 2>&1 && GENISOIMG="xorriso -as mkisofs" || GENISOIMG=genisoimage; \
	$$GENISOIMG -vJURT -b isolinux/isolinux.bin -c isolinux/boot.cat \
		-no-emul-boot -boot-load-size 4 -boot-info-table -eltorito-alt-boot -e boot/grub/efi.img -no-emul-boot \
		-input-charset utf-8 -V "$(if $(RELEASE_OS_TITLE),$(RELEASE_OS_TITLE),Android-x86) ($(TARGET_ARCH))" -o $@ $^
	$(hide) PATH="/sbin:/usr/sbin:/bin:/usr/bin" isohybrid --uefi $@
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
	@echo -e ""
	@echo -e ${CL_CYN}"==============================================="${CL_RST}
	@echo -e ${CL_CYN}"Have A Truly Blissful Experience"${CL_RST}
	@echo -e ${CL_CYN}"==============================================="${CL_RST}
	@echo -e ""
	sha1sum $(PRODUCT_OUT)/*.iso > $(PRODUCT_OUT)/$(BLISS_VERSION).sha

rpm: $(wildcard $(LOCAL_PATH)/rpm/*) $(BUILT_IMG)
	@echo ----- Making an rpm ------
	OUT=$(abspath $(PRODUCT_OUT)); mkdir -p $$OUT/rpm/BUILD; rm -rf $$OUT/rpm/RPMS/*; $(ACP) $< $$OUT; \
	echo $(VER) | grep -vq rc; EPOCH=$$((-$$? + `echo $(VER) | cut -d. -f1`)); \
	PATH="/sbin:/usr/sbin:/bin:/usr/bin"; \
	rpmbuild -bb --target=$(if $(filter x86,$(TARGET_ARCH)),i686,x86_64) -D"cmdline $(BOARD_KERNEL_CMDLINE)" \
		-D"_topdir $$OUT/rpm" -D"_sourcedir $$OUT" -D"systemimg $(notdir $(systemimg))" -D"ver $(VER)" -D"epoch $$EPOCH" \
		$(if $(BUILD_NAME_VARIANT),-D"name $(BUILD_NAME_VARIANT)") \
		-D"install_prefix $(if $(INSTALL_PREFIX),$(INSTALL_PREFIX),android-$(VER))" $(filter %.spec,$^); \
	mv $$OUT/rpm/RPMS/*/*.rpm $$OUT

.PHONY: iso_img usb_img efi_img rpm
iso_img: $(ISO_IMAGE)
usb_img: $(ISO_IMAGE)
efi_img: $(ISO_IMAGE)

endif
