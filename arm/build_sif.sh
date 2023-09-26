#!/bin/bash

set -xeo pipefail

NODE_VERSION=${1:-20}
BASE_OS=${2:-bookworm-slim}

SSH_PORT=${SSH_PORT:-2222}

apt-get update
apt-get -qqy install python3 python3-venv build-essential wget sudo git squashfs-tools

cd /root/repo && ./make.sh "$NODE_VERSION" "$BASE_OS"
