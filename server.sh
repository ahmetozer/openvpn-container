#!/bin/bash

###                     ###
# OpenVPN server starter  #
#   https://ahmetozer.org #
###                     ###

server_config_dir=${server_config_dir-/etc/openvpn/server}

first_pwd=$PWD

echo "Looking OneConfig File"
if [ -f "$server_config_dir/oneconfig/server.conf" ]; then
    echo "OneConfig found"
    echo "Extracting environment variables"
    cat "$server_config_dir/oneconfig/server.conf" | grep "##env#-#" | sed -e 's!##env#-#!!' > /etc/openvpn/server/env
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
    cd $server_config_dir
fi

if [ "$err_on_exit" == "yes" ]; then
    exit
fi

openvpn_bin=`command -v openvpn`
if [ ! $? -eq 0 ]
then
  echo "ERR: OpenVPN is not found" >&2
  exit 1
fi

echo "Starting OpenVPN"
$openvpn_bin $openvpn_config_file
cd $first_pwd