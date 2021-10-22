#!/bin/bash

set -ex
sudo -v

# note: this will result in an erroneous value in submodules.
top_level=$(git rev-parse --show-toplevel)
node_version=16
base_container=buster
dockerfile_dir=$top_level/docker-node/$node_version/$base_container
sif_location=$top_level/image.sif
env_activate=$top_level/.env/bin/activate

if [ ! -f "$env_activate" ]; then
    python3 -m venv .env
    source $env_activate
    pip3 install -r $top_level/requirements.txt
else
    source $top_level/.env/bin/activate
fi

cd $dockerfile_dir

# Singularity doesn't play well with inline comments in recipes.
sed -e '/^[ \t]*#/d' $dockerfile_dir/Dockerfile \
    | spython recipe --parser docker /dev/stdin \
    | sudo singularity build $sif_location /dev/stdin

cd -
