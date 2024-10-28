#!/bin/bash

OWNER=${1:-$USER}
WORKING_DIR=${2:-$HOME}

echo "# ==============================="
echo "# Installing Obscreen Offline Launcher"
echo "# Using User: $OWNER"
echo "# Using Python: $(which python3)"
echo "# Working Directory: $WORKING_DIR"
echo "# ==============================="

# ============================================================
# Installation
# ============================================================

echo ""
echo "# Waiting 3 seconds before installation..."
sleep 3

# Install system dependencies
apt-get update
apt-get install -y git build-essential gcc python3-dev python3-pip python3-venv

# Get files
cd $WORKING_DIR
mkdir -p obscreen-offline-launcher
cd obscreen-offline-launcher

REPO="obscreen/obscreen-offline-launcher"
VERSION=$(curl -s "https://api.github.com/repos/$REPO/releases/latest" | grep -oP '"tag_name": "\K(.*)(?=")')

# Check if VERSION was fetched successfully
if [ -z "$VERSION" ]; then
    echo "Failed to retrieve the latest version. Check your internet connection or repository URL."
    exit 1
fi

echo "Latest version found: $VERSION"

# Define the base URL for the binaries
BASE_URL="https://github.com/$REPO/releases/download/${VERSION}"

# Detect architecture
ARCH=$(uname -m)
case "$ARCH" in
    "x86_64")
        ARCH="x86_64"
        ;;
    "aarch64")
        ARCH="aarch64"
        ;;
    "armv7l")
        ARCH="armv7"
        ;;
    *)
        echo "Unsupported architecture: $ARCH"
        exit 1
        ;;
esac

# Detect Python version
PYTHON_VERSION=$(python3 --version 2>&1 | awk '{print $2}')
PYTHON_MINOR_VERSION=$(echo "$PYTHON_VERSION" | cut -d. -f2)

# Build filename based on architecture and Python version
BINARY_NAME="obscreen-offline-launcher-linux.${ARCH}-py3.${PYTHON_MINOR_VERSION}.tar"
DOWNLOAD_URL="${BASE_URL}/${BINARY_NAME}"

# Attempt to download the binary
echo "Attempting to download ${BINARY_NAME} from ${DOWNLOAD_URL}..."
wget --spider "$DOWNLOAD_URL" &> /dev/null

# Check if the download link is valid
if [[ $? -eq 0 ]]; then
    # Link is valid; download the file
    wget "$DOWNLOAD_URL" -O "$BINARY_NAME"
    echo "Download completed: ${BINARY_NAME}"
else
    # Link is invalid; Python version not supported
    echo "The Python version ${PYTHON_VERSION} is not supported for this architecture."
    exit 1
fi

tar -vxf $BINARY_NAME 
mv $BINARY_NAME/* .
rm -rf $BINARY_NAME

# Install application dependencies
python3 -m venv venv
source ./venv/bin/activate
if [ -f requirements.txt ]; then
    pip install -r requirements.txt
else
    echo "requirements.txt not found, skipping pip install."
fi

# Fix permissions
chown -R $OWNER:$OWNER ./

# ============================================================
# Systemd service installation
# ============================================================

curl https://raw.githubusercontent.com/obscreen/obscreen-offline-launcher/refs/heads/main/obscreen-offline-launcher.service | sed "s#/home/pi#$WORKING_DIR#g" | sed "s#=pi#=$OWNER#g" | tee /etc/systemd/system/obscreen-offline-launcher.service
systemctl daemon-reload
systemctl enable obscreen-offline-launcher.service

# ============================================================
# Start
# ============================================================

systemctl restart obscreen-offline-launcher.service
