#!/bin/bash

set -xeo pipefail

NODE_VERSION=${1:-20}
BASE_OS=${2:-bookworm-slim}

SSH_PORT=${SSH_PORT:-2222}

APPTAINER_VERSION=1.2.3
APPTAINER_URL=https://github.com/apptainer/apptainer/releases/download/v${APPTAINER_VERSION}/apptainer-${APPTAINER_VERSION}.tar.gz
APPTAINER_SRC_TAR=apptainer.tar.gz
APPTAINER_SRC_DIR=apptainer-${APPTAINER_VERSION}

GO_URL=https://go.dev/dl/go1.21.1.linux-arm64.tar.gz
GO_TAR=go.tar.gz

apt-get update
apt-get -qqy install python3 python3-venv build-essential wget sudo git squashfs-tools

wget -qO "$GO_TAR" https://go.dev/dl/go1.21.1.linux-arm64.tar.gz
rm -rf /usr/local/go && tar -C /usr/local -xzf "$GO_TAR"
export PATH=$PATH:/usr/local/go/bin

test -f "$APPTAINER_SRC_TAR" || wget -q "$APPTAINER_URL" -O "$APPTAINER_SRC_TAR"
test -d "$APPTAINER_SRC_DIR" || tar -xf "$APPTAINER_SRC_TAR"

pushd "$APPTAINER_SRC_DIR"
test -d "$APPTAINER_SRC_DIR/builddir" || ./mconfig --without-network --without-suid
make -C builddir
make -C builddir install
popd

cd /root/repo && ./make.sh "$NODE_VERSION" "$BASE_OS"
