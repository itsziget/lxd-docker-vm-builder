#!/bin/bash

set -eu -o pipefail

network_type=bridge
network_host=lxcdocker
network_parent=
network_guest=eth0
name=docker
profile=docker
image=images:ubuntu/20.04/cloud
ip=10.79.77.10
mac=00:16:3e:d6:a3:68

if [[ -e "config.sh" ]]; then
  source config.sh
fi

# end config

function deploy() {
  lxc init --vm --profile "$profile" "$image" "$name"

  if [[ "$network_type" == "bridge" ]]; then
    lxc config device override "$name" "$network_guest" ipv4.address="${ip}"
  elif [[ "$network_type" == "macvlan" ]]; then
    lxc config set  "$name" "volatile.eth0.hwaddr=$mac"
  else
    >&2 echo "Invalid network type '$network_type'"
    exit 1
  fi

  lxc start "$name"
}

function lxc_provision() {
  lxc exec --env DEBIAN_FRONTEND=noninteractive "$@"
}

if ! lxc network show "$network_host" &>/dev/null; then
  network_params=(--type "$network_type")
  if [[ "$network_type" == "macvlan" ]]; then
    network_params+=(parent="$network_parent")
  fi
  lxc network create "$network_host" "${network_params[@]}"
  if [[ "$network_type" == "bridge" ]]; then
    lxc network edit "$network_host" < network.yml
  fi
fi

if ! lxc profile show "$profile" &>/dev/null; then
  lxc profile create "$profile"
  lxc profile edit "$profile" < profile.yml
fi

deploy

while ! lxc exec "$name" -- hostname &>/dev/null; do
  echo -n "$(date): "
  echo Waiting for lxd agent to start
  sleep 5
done

while ! lxc exec "$name" -- id docker &>/dev/null; do
  echo -n "$(date): "
  echo Waiting for docker user to be created
  sleep 5
done

exit 0
lxc_provision "$name" -- apt-get update
lxc_provision "$name" -- apt-get install -y openssh-server ca-certificates curl gnupg lsb-release 
lxc_provision "$name" -- bash -c "curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg"
lxc_provision "$name" -- bash -c 'echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null'
lxc_provision "$name" -- apt-get update
lxc_provision "$name" -- apt-get install -y "docker-ce=5:20.10.12~3-0~ubuntu-focal" "docker-ce-cli=5:20.10.12~3-0~ubuntu-focal" containerd.io
lxc_provision "$name" -- apt-mark hold docker-ce docker-ce-cli containerd.io