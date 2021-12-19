#!/bin/bash

set -eu

network_host=lxcdocker
network_guest=eth0
name=docker
profile=docker
image=images:ubuntu/20.04/cloud
ip_ending=10

# end config

function deploy() {
  local name=$1
  local ip_ending=$2

  lxc init --vm --profile "$profile" "$image" "$name"

  ip_base="$(lxc query /1.0/networks/$network_host | jq -r '.config["ipv4.address"] | split ("/")[0] | split(".")[0:3] | join(".")')"

  lxc config device override "$name" "$network_guest" ipv4.address="${ip_base}.${ip_ending}"

  lxc start "$name"
}

if ! lxc network show "$network_host" &>/dev/null; then
  lxc network create "$network_host"
  lxc network edit "$network_host" < network.yml
fi

if ! lxc profile show "$profile" &>/dev/null; then
  lxc profile create "$profile"
  lxc profile edit "$profile" < profile.yml
fi

deploy "$name" "$ip_ending"

while ! lxc exec "$name" -- bash -c 'while ! docker version &>/dev/null; do echo -n "$(date): "; echo Waiting for docker to be installed; sleep 5; done' 2>/dev/null; do
  echo -n "$(date): "
  echo Waiting for lxd agent to start
  sleep 5
done