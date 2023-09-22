#!/bin/bash

set -eo pipefail

SRC_DIR=${SRC_DIR}
debian_url=https://cloud.debian.org/images/cloud/bullseye/20230912-1501/debian-11-nocloud-arm64-20230912-1501.qcow2
vm_image=debian.qcow2

test -f "$vm_image" || wget -q "$debian_url" -O "$vm_image"

# Patch up the image to generate host SSH keys and enable passwordless root login.
sudo modprobe nbd max_part=1
sudo qemu-nbd --connect=/dev/nbd0 $vm_image

tmp_nbd_mntpoint=$(mktemp -d)
# sleep to make sure nbd partitions load on time
sleep 1
sudo mount /dev/nbd0p1 $tmp_nbd_mntpoint
sudo cp ssh.service "$tmp_nbd_mntpoint/lib/systemd/system/ssh.service"
sudo cp allow_passwordless_root.conf "$tmp_nbd_mntpoint/etc/ssh/sshd_config.d"
sudo rm -rf "$tmp_nbd_mntpoint/etc/udev/rules.d/*"  # Remove 75-cloud-ifupdown.rules
sudo mkdir -p "$tmp_nbd_mntpoint/root/repo"
find .. -mindepth 1 -maxdepth 1 -not \( -path '*/.venv' -o -path '*/arm' \) -exec sudo cp -r '{}' "$tmp_nbd_mntpoint/root/repo" \;

# NBD clean-up
sudo umount "$tmp_nbd_mntpoint"
sudo rm -rf "$tmp_nbd_mntpoint"
sudo qemu-nbd --disconnect /dev/nbd0

qemu-img resize "$vm_image" +10G

