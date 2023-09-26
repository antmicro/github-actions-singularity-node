#!/bin/bash

set -eo pipefail

ROOT_DIR=$(pwd)
WORK_DIR=${ROOT_DIR}/work
mkdir -p "$WORK_DIR"

DEBIAN_URL=https://cloud.debian.org/images/cloud/bullseye/20230912-1501/debian-11-nocloud-arm64-20230912-1501.qcow2
VM_IMAGE=${WORK_DIR}/debian.qcow2

APPTAINER_SHA=62e16f5071854226dfb0cedece557d56a81d254f
APPTAINER_URL=https://github.com/antmicro/apptainer/archive/${APPTAINER_SHA}.zip
APPTAINER_ZIP=${WORK_DIR}/apptainer.zip
APPTAINER_DIR=${WORK_DIR}/apptainer-${APPTAINER_SHA}

sudo dpkg --add-architecture arm64
sudo apt-get -qqy update
sudo apt-get install -qqy build-essential make gcc-aarch64-linux-gnu binutils-aarch64-linux-gnu gcc git libc6:arm64

check_go_version() {
    GO_MINOR=19
    GO_VERSION=$(go version | cut -d' ' -f3)
    CURRENT_MINOR=$(echo "$GO_VERSION" | cut -d. -f2)

    [ "$CURRENT_MINOR" -ge "$GO_MINOR" ] && echo 1
}

ensure_go() {
    GO_URL=https://go.dev/dl/go1.21.1.linux-amd64.tar.gz
    GO_TAR=${WORK_DIR}/go.tar.gz

    if [ ! "$(which go)" ] || [ ! "$(check_go_version)" ]; then
        if [ ! -d "$WORK_DIR/go" ]; then
            test -f "$GO_TAR" || wget -qO "$GO_TAR" "$GO_URL"
            tar -C "${WORK_DIR}" -xzf "$GO_TAR"
        fi
        export GO="$WORK_DIR/go/bin/go"
    fi
}

if [ ! -f "$VM_IMAGE" ]; then
    wget -q "$DEBIAN_URL" -O "$VM_IMAGE"
    qemu-img resize "$VM_IMAGE" 16G
fi


teardown_nbd() {
    if [ "$TMP_NBD_MNTPOINT" ]; then
        sudo umount "$TMP_NBD_MNTPOINT"
        sudo rm -rf "$TMP_NBD_MNTPOINT"
    fi; sudo qemu-nbd --disconnect /dev/nbd0
}

setup_nbd() {
    TMP_NBD_MNTPOINT=$(mktemp -d)
    export TMP_NBD_MNTPOINT

    # Patch up the image to generate host SSH keys and enable passwordless root login.
    sudo modprobe nbd max_part=1
    sudo qemu-nbd --connect=/dev/nbd0 "$VM_IMAGE"
    # sleep to make sure nbd partitions load on time
    sleep 1

    sudo mount /dev/nbd0p1 "$TMP_NBD_MNTPOINT"
    trap teardown_nbd EXIT
}

setup_nbd

sudo cp "${ROOT_DIR}/ssh.service" "$TMP_NBD_MNTPOINT/lib/systemd/system/ssh.service"
sudo cp "${ROOT_DIR}/allow_passwordless_root.conf" "$TMP_NBD_MNTPOINT/etc/ssh/sshd_config.d"
sudo rm -rf "$TMP_NBD_MNTPOINT/etc/udev/rules.d/*"  # Remove 75-cloud-ifupdown.rules
sudo mkdir -p "$TMP_NBD_MNTPOINT/root/repo"
find "${ROOT_DIR}/.." -mindepth 1 -maxdepth 1 -not \( -path '*/.venv' -o -path '*/arm' \) -exec sudo cp -r '{}' "$TMP_NBD_MNTPOINT/root/repo" \;

if [ ! -d "${APPTAINER_DIR}" ]; then
    [ ! -f "${APPTAINER_ZIP}" ] && wget -qO "${APPTAINER_ZIP}" "${APPTAINER_URL}"
    unzip "${APPTAINER_ZIP}" -d "${WORK_DIR}"
    echo "$APPTAINER_SHA" > "${APPTAINER_DIR}/VERSION"
fi

ensure_go
pushd "${APPTAINER_DIR}"
./mconfig \
    --without-suid \
    --prefix="${TMP_NBD_MNTPOINT}/usr" \
    -C aarch64-linux-gnu-gcc \
    -X aarch64-linux-gnu-gcc \
    -P release-stripped \
    -G "${GO:-$(which go)}" \
    --target-goarch arm64
cp "${ROOT_DIR}/apptainer.conf" builddir
pushd builddir
make -j"$(nproc)"
sudo make install
popd
popd
