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
      rm -f "$FILE"
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
  for FILE in "${FILES[@]}"; do
    echo "Downloading $FILE using aria2c..."
    aria2c -x 16 -s 16 "$RELEASE_URL/download/$FILE"
  done
}

# Function to download files using wget
download_with_wget() {
  for FILE in "${FILES[@]}"; do
    echo "Downloading $FILE using wget..."
    wget "$RELEASE_URL/download/$FILE"
  done
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
  # Remove the extracted tar.gz file
  rm -f initrd_lib.tar.gz
}

# Remove existing files before starting the download
remove_existing_files

# Check if aria2c is installed
if command -v aria2c &> /dev/null; then
  echo "aria2c found, using aria2c for download."
  download_with_aria2
else
  echo "aria2c not found, falling back to wget."
  download_with_wget
fi

# Process the downloaded files
extract_grub_rescue_iso
move_install_sfs
extract_initrd_lib

echo "Script execution complete!"
