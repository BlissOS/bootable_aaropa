# Ānanda Āropa - The new initrd & installer combo for BlissOS

## Introduction

Ānanda Āropa (/ɑːˈnʌndə/ /ɑː.ɾɐw.pɐ/) or `aaropa` is BlissLabs' latest attempt in improving the installer & initrd for BlissOS. With some of additional features & improvement comparing to the old one based on Android-x86 including:

- Refactored Android-x86 init scripts.
- All prebuilts are now being downloaded instead of stored in the repo.
- A new script on initrd to generate fstab that is compatible with [Android's fstab](https://source.android.com/docs/core/architecture/kernel/mounting-partitions-early#fstab-entries).
- A whole new installation environment based on [Devuan ceres](https://www.devuan.org/) with a minimal desktop and an installer that uses [Calamares](https://calamares.io/).

The new installation environment also include programs such as:

- [JWM](https://github.com/joewing/jwm) for the desktop
- [PCManFM-Qt](https://github.com/lxqt/pcmanfm-qt) for file manager
- [QTerminal](https://github.com/lxqt/qterminal) for terminal
- [GParted](https://gparted.org/) for disks & partitions management
- [L3afpad](https://github.com/stevenhoneyman/l3afpad) for text editor
- [GPicView](https://lxde.sourceforge.net/gpicview/) for photo viewer
- [GSmartControl](https://gsmartcontrol.shaduri.dev/) for drive health monitor
- [Htop](https://github.com/htop-dev/htop) for process monitor

With these programs, your installation media is not only for Live booting or install BlissOS, but also to diagnose or debug issues related to the operating system & your PC.

## Compatibility

As of right now, `aaropa` only support `x86_64`.

## Status

Beside this main repo, `aaropa` is also made of several other repos including:

- [![](https://github.com/BlissOS/aaropa_calamares/actions/workflows/build-devuan-ceres.yml/badge.svg)](https://github.com/BlissOS/aaropa_calamares) <p>
This repo contains patches & modules for Calamares which will be built into .deb file

- ![https://github.com/BlissOS/grub2-themes](https://github.com/BlissOS/grub2-themes/actions/workflows/build-devuan-ceres.yml/badge.svg) <p>
This rpeo contains the Grub2 theme that we're using which will be built into .deb file

- [![](https://github.com/BlissOS/aaropa_busybox/actions/workflows/build-linux.yml/badge.svg)](https://github.com/BlissOS/aaropa_busybox) <p>
This repo contains `busybox` program that is on initrd, it will also be built into .deb file

- [![](https://github.com/BlissOS/aaropa_devuan_repo/actions/workflows/deplay-pages.yml/badge.svg)](https://github.com/BlissOS/aaropa_devuan_repo) <p>
This repo is a Debian (or Devuan) repository that contains the above programs.

- [![](https://github.com/BlissOS/aaropa_rootfs/actions/workflows/extract-rootfs.yml/badge.svg)](https://github.com/BlissOS/aaropa_rootfs) <p>
This repo is used to generate the `rootfs` image for the installer. It get the above repository to install the programs above and all the program listed in [Introduction](#introduction). After that, it will provide an image contains the installation environemnt, a `grub-rescue.iso` file as the skeleton of BlissOS iso image, and `initrd_lib.tar.gz` contains required programs & libraries for the initrd.

## Usage

If your BlissOS source has `bootable/newinstaller`, remove it. After that, clone this repo to `bootable/aaropa`

```
git clone https://github.com/BlissOS/bootable_aaropa.git
```

Once done, run the `download.sh` script on the repo to get all the required files

```
bash bootable/aaropa/download.sh
```

You can also apply [this commit](https://github.com/BlissOS/device_generic_x86_64/commit/866b096a447099b29a9703ae8867aceb3727ef55) to create a `vendorsetup.sh` script which will automatically run whenever you start a build.

After that, just lunch and `make iso_img` like you usually do to build BlissOS.

## Meaning behind the name

Ānanda & Āropa are two Sanskrit words used in Hinduism. <need more>

## Credit

- [Android-x86](https://android-x86.org/) for the original initrd & installer in `newinstaller`.
- [Devuan](https://www.devuan.org/) for a linux distro that doesn't use systemd.
- All the programs that are listed above. Without these programs, we couldn't be able to achieve something like this.

And [Shadichy](https://github.com/shadichy), the one who started it all !
