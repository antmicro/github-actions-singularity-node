#!/bin/bash

set -e

SSH_PORT=${SSH_PORT:-2222}

qemu-system-aarch64 \
    -M virt \
    -cpu cortex-a53 \
    -smp $(nproc) \
    -m 4G \
    -drive file=work/debian.qcow2 \
    -bios /usr/share/qemu-efi-aarch64/QEMU_EFI.fd \
    -netdev user,id=lan,hostfwd=tcp::"$SSH_PORT"-:22 \
    -device virtio-net-pci,netdev=lan \
    -vga none \
    -display none \
    -daemonize

for _ in {0..120}; do
    ssh -p "$SSH_PORT" \
        -oUserKnownHostsFile=/dev/null \
        -oStrictHostKeyChecking=no \
        root@localhost "uname -m" && break || true
    sleep 2
done
