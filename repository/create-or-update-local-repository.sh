#!/bin/bash

set -eux

# Set the local repository path
REPO_DIR="${1:-$(dirname "$0")/debian}"
DISTRIBUTION="${2:-ubuntu}"
SUITE="${3:-jammy}"
GPG_KEY_ID="${4:-473F57D3A9534D53F0128E9DFF0244C9D7E28146}"

# Create a temporary directory to store the new .deb files
TEMP_DIR=$(mktemp -d)

YA_INSTALLER_CORE="${YA_INSTALLER_CORE:-pre-rel-v0.13.0-rc14}"
YA_INSTALLER_WASI=${YA_INSTALLER_WASI:-v0.2.2}
YA_INSTALLER_VM=${YA_INSTALLER_VM:-v0.3.0}

# Function to download .deb files using curl
download_deb_files() {
    for url in "$@"; do
        curl -L -o "$TEMP_DIR/$(basename "$url")" "$url"
    done
}

# Function to add .deb files to the local repository
create_local_repository() {
    mkdir -p "$REPO_DIR/conf"

    cat << EOF > "${REPO_DIR}/conf/distributions"
Origin: GOLEM $DISTRIBUTION
Label: GOLEM $DISTRIBUTION
Codename: $SUITE
Architectures: amd64
Components: main
Description: APT repository with GOLEM components
Tracking: all
EOF

    # Add new .deb files to the local repository
    reprepro -S misc -b "$REPO_DIR" includedeb "$SUITE" "$TEMP_DIR"/*.deb

    # Sign the repository metadata
    gpg --detach-sign --armor --local-user "$GPG_KEY_ID" --batch --no-tty --output "$REPO_DIR/dists/$SUITE/Release.gpg" "$REPO_DIR/dists/jammy/Release"
    gpg --clearsign --armor --local-user "$GPG_KEY_ID" --batch --no-tty --output "$REPO_DIR/dists/$SUITE/InRelease" "$REPO_DIR/dists/jammy/Release"
}

#
# Main script execution
#

# Download and add new .deb files to the local repository
download_deb_files \
  "https://github.com/golemfactory/yagna/releases/download/${YA_INSTALLER_CORE}/golem-provider_${YA_INSTALLER_CORE}_amd64.deb" \
  "https://github.com/golemfactory/ya-runtime-wasi/releases/download/${YA_INSTALLER_WASI}/ya-runtime-wasi-cli_0.2.1_amd64.deb" \
  "https://github.com/golemfactory/ya-runtime-vm/releases/download/${YA_INSTALLER_VM}/ya-runtime-vm_${YA_INSTALLER_VM}_amd64.deb"

# Add the new .deb files to the local repository and sign the repository metadata
create_local_repository

# Clean up the temporary directory
rm -rf "$TEMP_DIR"