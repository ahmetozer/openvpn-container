#!/bin/bash

echo "
###                       ###
# ? OpenVPN server starter  #
# ?                         #
###                       ###
"

server_config_dir=${server_config_dir-/etc/openvpn/server}

first_pwd=$PWD

echo "Looking OneConfig File"
if [ -f "$server_config_dir/oneconfig/server.conf" ]; then
    echo "OneConfig found"
    echo "Extracting environment variables"
    cat "$server_config_dir/oneconfig/server.conf" | grep "##env#-#" | sed -e 's!##env#-#!!' >/etc/openvpn/server/env
    echo "Loading environment variables"
    source /etc/openvpn/server/env
    openvpn_config_file="$server_config_dir/oneconfig/server.conf"
else
    echo "OneConfig is not found. Script will be continue with regular config."
    required_conf_files=("ca.crt" "server.crt" "server.key" "dh.pem" "crl.pem" "tc.key" "server.conf" "env")

    for file in ${required_conf_files[*]}; do
        if [ ! -f $server_config_dir/$file ]; then
            echo "File $server_config_dir/$file not found"
            err_on_exit=yes
        fi
    done
    openvpn_config_file="$server_config_dir/server.conf"
    if [ "$err_on_exit" == "yes" ]; then
        exit
    fi
    source /etc/openvpn/server/env
    cd $server_config_dir
fi

openvpn_bin=$(command -v openvpn)
if [ ! $? -eq 0 ]; then
    echo "ERR: OpenVPN is not found" >&2
    exit 1
fi

echo "Configuring Firewall"
IPTABLES_BIN=$(command -v iptables)
if [ ! $? -eq 0 ]; then
    echo "ERR: iptables is not found" >&2
    exit 1
fi
IP6TABLES_BIN=$(command -v ip6tables)
if [ ! $? -eq 0 ]; then
    echo "ERR: ip6tables is not found" >&2
    exit 1
fi

current_ip_forward=$(cat /proc/sys/net/ipv4/ip_forward)
current_ip6_forward=$(cat /proc/sys/net/ipv6/conf/all/forwarding)

function restore_iptables() {
    echo "Restoring"
    # Restore IPTables
    ###
    # IPv6
    ###

    $IP6TABLES_BIN -D INPUT -p $protocol --dport $port -j ACCEPT
    if [ "$ip6_nat" == "yes" ]; then
        $IP6TABLES_BIN -t nat -D POSTROUTING --src $ip6_block -j MASQUERADE
    fi
    $IP6TABLES_BIN -D FORWARD -s $ip6_block -j ACCEPT
    $IP6TABLES_BIN -D FORWARD -m state --state RELATED,ESTABLISHED -j ACCEPT

    ###
    #   IPv4
    ###
    $IPTABLES_BIN -D INPUT -p $protocol --dport $port -j ACCEPT
    if [ "$ip_nat" == "yes" ]; then
        $IPTABLES_BIN -t nat -D POSTROUTING --src $ip_block/$cidr -j MASQUERADE
    fi
    $IPTABLES_BIN -D FORWARD -s $ip_block/$cidr -j ACCEPT
    $IPTABLES_BIN -D FORWARD -m state --state RELATED,ESTABLISHED -j ACCEPT

    echo $current_ip_forward >/proc/sys/net/ipv4/ip_forward
    echo $current_ip6_forward >/proc/sys/net/ipv6/conf/all/forwarding

    echo "$0 is closed"

}

echo 1 >/proc/sys/net/ipv4/ip_forward
$IPTABLES_BIN -I INPUT -p $protocol --dport $port -j ACCEPT # Allow openvpn server port

if [ "$ip_nat" == "yes" ]; then
    $IPTABLES_BIN -t nat -A POSTROUTING --src $ip_block/$cidr -j MASQUERADE
fi
$IPTABLES_BIN -I FORWARD -s $ip_block/$cidr -j ACCEPT
$IPTABLES_BIN -I FORWARD -m state --state RELATED,ESTABLISHED -j ACCEPT

echo 1 >/proc/sys/net/ipv6/conf/all/forwarding
echo 0 >/proc/sys/net/ipv6/conf/all/disable_ipv6

if [ "$ip6_nat" == "yes" ]; then
    $IP6TABLES_BIN -t nat -A POSTROUTING --src $ip6_block -j MASQUERADE
fi

$IP6TABLES_BIN -I INPUT -p $protocol --dport $port -j ACCEPT # Allow openvpn server port
$IP6TABLES_BIN -I FORWARD -s $ip6_block -j ACCEPT
$IP6TABLES_BIN -I FORWARD -m state --state RELATED,ESTABLISHED -j ACCEPT

echo "Starting OpenVPN"
trap restore_iptables EXIT
$openvpn_bin $openvpn_config_file
cd $first_pwd