#!/bin/bash

set -ex
sudo -v

# note: this will result in an erroneous value in submodules.
top_level=$(git rev-parse --show-toplevel)
node_version=${1:-20}
base_container=${2:-alpine3.18}
dockerfile_dir=$top_level/docker-node/$node_version/$base_container
sif_location=$top_level/node-$node_version-$base_container.sif
env_activate=$top_level/.venv/bin/activate
additional_post=$top_level/additional-$node_version-$base_container.sh
awk_include_post='$1~/[%].+/ && d==1 { system(cat_cmd); d=0; }; $0 {print}; $1=="%post" {d=1};'

if [ ! -f "$env_activate" ]; then
    python3 -m venv .venv
    source $env_activate
    pip3 install wheel
    pip3 install -r $top_level/requirements.txt
else
    source $top_level/.venv/bin/activate
fi

if [ ! -f "$additional_post" ]; then
    additional_post=/dev/null
fi

cd $dockerfile_dir

# Singularity doesn't play well with inline comments in recipes.
sed -e '/^[ \t]*#/d' $dockerfile_dir/Dockerfile \
    | spython recipe --parser docker /dev/stdin \
    | awk -v cat_cmd="cat $additional_post" "$awk_include_post" \
    | sudo singularity build $sif_location /dev/stdin

cd -
