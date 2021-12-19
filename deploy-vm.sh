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

function lxc_provision() {
  lxc exec --env DEBIAN_FRONTEND=noninteractive "$@"
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

while ! lxc exec "$name" -- hostname &>/dev/null; do
  echo -n "$(date): "
  echo Waiting for lxd agent to start
  sleep 5
done

lxc_provision "$name" -- apt-get update
lxc_provision "$name" -- apt-get install -y openssh-server ca-certificates curl gnupg lsb-release 
lxc_provision "$name" -- bash -c "curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg"
lxc_provision "$name" -- bash -c 'echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null'
lxc_provision "$name" -- apt-get update
lxc_provision "$name" -- apt-get install -y "docker-ce=5:20.10.12~3-0~ubuntu-focal" "docker-ce-cli=5:20.10.12~3-0~ubuntu-focal" containerd.io
lxc_provision "$name" -- apt-mark hold docker-ce docker-ce-cli containerd.io