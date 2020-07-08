#!/bin/sh

## configuration variables:
VLAN=5
declare -a IPV4_IP_ARRAY=("10.10.5.3" "10.10.5.4")
IPV4_GW="10.10.5.1/24"

# container names; e.g. nextdns, pihole, adguardhome, etc.
declare -a CONTAINER_ARRAY=("pihole" "cloudflared")

## network configuration and startup:
CNI_PATH=/mnt/data/podman/cni
if [ ! -f "$CNI_PATH"/macvlan ]
then
    mkdir -p $CNI_PATH
    curl -L https://github.com/containernetworking/plugins/releases/download/v0.8.6/cni-plugins-linux-arm64-v0.8.6.tgz | tar -xz -C $CNI_PATH
fi

mkdir -p /opt/cni
ln -s $CNI_PATH /opt/cni/bin

for file in "$CNI_PATH"/*.conflist
do
    if [ -f "$file" ]; then
        ln -s "$file" "/etc/cni/net.d/$(basename "$file")"
    fi
done

# set VLAN bridge promiscuous
ip link set br${VLAN} promisc on

# create macvlan bridge and add IPv4 IP
ip link add br${VLAN}.mac link br${VLAN} type macvlan mode bridge
ip addr add ${IPV4_GW} dev br${VLAN}.mac noprefixroute

# set macvlan bridge promiscuous and bring it up
ip link set br${VLAN}.mac promisc on
ip link set br${VLAN}.mac up

# add IPv4 route to DNS container
for ip in ${IPV4_IP_ARRAY[@]}; 
do
    ip route add ${ip}/32 dev br${VLAN}.mac
done

for container in ${CONTAINER_ARRAY[@]}; 
do
    if podman container exists ${container}; then
    podman start ${container}
    else
    logger -s -t podman-dns -p ERROR Container $container not found, make sure you set the proper name, if you have you can ignore this error
    fi
done
