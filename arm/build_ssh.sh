#!/bin/bash

SSH_PORT=${SSH_PORT:-2222}
NODE_VERSION=${1:-24}
BASE_OS=${2:-trixie-slim}

ssh -p "$SSH_PORT" \
    -oUserKnownHostsFile=/dev/null \
    -oStrictHostKeyChecking=no \
    root@localhost "/bin/bash -s" < build_sif.sh "$NODE_VERSION" "$BASE_OS"

scp -P "$SSH_PORT" \
    -oUserKnownHostsFile=/dev/null \
    -oStrictHostKeyChecking=no \
    root@localhost:"/root/repo/node-$NODE_VERSION-$BASE_OS.sif" .
