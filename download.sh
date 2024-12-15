#!/bin/bash

# URL for the GitHub release page
RELEASE_URL="https://github.com/BlissOS/aaropa_rootfs/releases/latest"

# Get the script's directory and change to it
SCRIPT_DIR=$(dirname "$0")
cd "$SCRIPT_DIR" || exit

# Files to download
FILES=(
  "install.sfs"
  "initrd_lib.tar.gz"
  "grub-rescue.iso"
  "boot_hybrid.img"
)

# Function to remove existing files from the FILES list and directories
remove_existing_files() {
  # Remove files listed in the FILES array
  for FILE in "${FILES[@]}"; do
    if [[ -f "$FILE" ]]; then
      echo "Removing existing file: $FILE"
      rm -f "$FILE"*
    fi
  done

  # Remove initrd_lib and iso directories
  if [[ -d "initrd_lib" ]]; then
    echo "Removing existing directory: initrd_lib"
    rm -rf initrd_lib
  fi

  if [[ -d "iso" ]]; then
    echo "Removing existing directory: iso"
    rm -rf iso
  fi
}

# Function to download files using aria2c
download_with_aria2() {
  local file="$1"
  echo "Downloading $file using aria2c..."
  aria2c -x 16 -s 16 "$RELEASE_URL/download/$file"
}

# Function to download files using wget
download_with_wget() {
  local file="$1"
  echo "Downloading $file using wget..."
  wget "$RELEASE_URL/download/$file"
}

# Function to extract grub-rescue.iso to the iso directory and delete the iso file
extract_grub_rescue_iso() {
  echo "Extracting grub-rescue.iso to iso directory..."
  mkdir -p iso
  # Extract the contents of the ISO into the "iso" folder
  7z x grub-rescue.iso -oiso
  # Delete the ISO after extracting
  rm grub-rescue.iso
}

# Function to move install.sfs to the iso directory
move_install_sfs() {
  echo "Moving install.sfs to iso directory..."
  mv install.sfs iso/
}

# Function to extract initrd_lib.tar.gz and move the content to the initrd folder
extract_initrd_lib() {
  echo "Extracting initrd_lib.tar.gz..."
  tar -xzf initrd_lib.tar.gz
  echo "Setting permissions for initrd_lib..."
  chmod -R 755 initrd_lib/*
  # Remove the extracted tar.gz file
  rm -f initrd_lib.tar.gz
}

# Function to display the help message
show_help() {
  cat << EOF
Copyright (C) 2024 BlissLabs

Usage: ./download.sh [OPTION]

Options:
  --initrd-only    Download and extract only the initrd_lib.tar.gz file.
  --help           Show this help message and exit.
EOF
}

# Handle the command line argument using a case statement
case "$1" in
  --help)
    show_help
    ;;
  
  --initrd-only)
    # Remove existing files before starting the download
    remove_existing_files

    # Download only initrd_lib.tar.gz
    if command -v aria2c &> /dev/null; then
      download_with_aria2 "initrd_lib.tar.gz"
    else
      download_with_wget "initrd_lib.tar.gz"
    fi

    extract_initrd_lib
    echo "Script execution complete!"
    ;;
  
  *)
    # Remove existing files before starting the download
    remove_existing_files

    # Check if aria2c is installed
    if command -v aria2c &> /dev/null; then
      echo "aria2c found, using aria2c for download."
      for FILE in "${FILES[@]}"; do
        download_with_aria2 "$FILE"
      done
    else
      echo "aria2c not found, falling back to wget."
      for FILE in "${FILES[@]}"; do
        download_with_wget "$FILE"
      done
    fi

    # Process the downloaded files
    extract_grub_rescue_iso
    move_install_sfs
    extract_initrd_lib

    echo "Script execution complete!"
    ;;
esac
exit 0
