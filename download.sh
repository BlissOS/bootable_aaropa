#!/bin/bash

# URLs for the GitHub release page and API
RELEASE_URL="https://github.com/Ananda-Aropa/aaropa_rootfs_installer_blissos/releases/latest"
API_URL="https://api.github.com/repos/Ananda-Aropa/aaropa_rootfs_installer_blissos/releases/latest"
VERSION_FILE="version.txt"

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

# Function to get the latest tag from GitHub API
get_latest_version() {
  if command -v curl &> /dev/null; then
    curl -s "$API_URL" | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/'
  elif command -v wget &> /dev/null; then
    wget -qO- "$API_URL" | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/'
  fi
}

# Function to check version and optionally exit
check_version() {
  echo "Checking for the latest version..."
  LATEST_VERSION=$(get_latest_version)
  
  if [[ -z "$LATEST_VERSION" ]]; then
    echo "Warning: Could not determine the latest version from GitHub. Proceeding with download..."
    return 0
  fi

  if [[ -f "$VERSION_FILE" ]]; then
    LOCAL_VERSION=$(cat "$VERSION_FILE")
    if [[ "$LATEST_VERSION" == "$LOCAL_VERSION" ]]; then
      echo "You already have the latest version ($LATEST_VERSION). Skipping download."
      exit 0
    fi
  fi
  
  echo "New version found: $LATEST_VERSION (Current: ${LOCAL_VERSION:-None})"
}

# Function to update the version file
update_version() {
  if [[ -n "$LATEST_VERSION" ]]; then
    echo "$LATEST_VERSION" > "$VERSION_FILE"
    echo "Updated $VERSION_FILE to $LATEST_VERSION."
  fi
}

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
Copyright (C) 2026 BlissLabs

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
    # Check the version first
    check_version

    # Remove existing files before starting the download
    remove_existing_files

    # Download only initrd_lib.tar.gz
    if command -v aria2c &> /dev/null; then
      download_with_aria2 "initrd_lib.tar.gz"
    else
      download_with_wget "initrd_lib.tar.gz"
    fi

    extract_initrd_lib
    
    # Save the new version
    update_version
    echo "Script execution complete!"
    ;;
  
  *)
    # Check the version first
    check_version

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

    # Save the new version
    update_version
    echo "Script execution complete!"
    ;;
esac
exit 0
