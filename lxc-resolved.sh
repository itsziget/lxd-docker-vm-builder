#!/usr/bin/env bash

# http://linuxcontainers.org/lxd/docs/master/networks/#integration-with-systemd-resolved

network=lxcdocker

ip_and_mask="$(lxc network get "$network" ipv4.address)"
ip="$(echo "$ip_and_mask" | cut -d / -f 1)"
domain="$( (lxc network get "$network" dns.domain && echo lxd) | head -n1)"

systemd-resolve --interface "$network" --set-domain "~$domain" --set-dns "$ip" 

# TODO: should I support resolvectl?