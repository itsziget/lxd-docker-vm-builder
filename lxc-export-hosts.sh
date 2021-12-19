#!/usr/bin/env bash

set -eu -o pipefail

hostmap="$( \
  lxc list --format json \
    | jq --raw-output '.[] | .devices.eth0["ipv4.address"] + " " + .name + ".lxc"' \
)"

inputfile=/etc/hosts
outputfile=/etc/hosts

output="$(cat "$inputfile")"

while IFS="" read -r line || [ -n "$line" ]; do
  ip="$(echo "$line" | cut -d " " -f1)"

  host="$(echo "$line" | cut -d " " -f2-)"

  ip_regex="${ip//./\\.}"
  host_regex="${host//.\\.}"

  output="$(echo "$output" | sed "/^\($ip_regex\) .*/d")"
  output="$(echo "$output" | sed "s/^\([0-9]\+\.[0-9]\+\.[0-9]\+\.[0-9]\+\( .\+\)\?\)\( $host_regex\)\( \|$\|#\)\(.*\)/\1\3.removed\4\5/g")"
  
  if [[ -n "$ip" ]]; then
    output="$(echo "$output" | sed "$ a$ip $host # lxc automatic hostmap")"
  fi
  ssh-keygen -f ~/.ssh/known_hosts -R "$host" &>/dev/null || true
done < <(echo "$hostmap")

echo "$output" | sudo tee "$outputfile" > /dev/null