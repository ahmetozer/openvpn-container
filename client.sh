echo "
###                       ###
# ? OpenVPN client starter  #
# ?                         #
###                       ###
"
first_pwd=$PWD

client_config=${client_config_dir-client1.ovpn}

client_config_basename=$(basename $client_config)
client_config_dirname=$(dirname $client_config)

if [ "$client_config_basename" == "$client_config" ]; then
    echo "Selecting Default Directory '/etc/openvpn/client/' "
    client_config_dirname="/etc/openvpn/client"
fi

if [ "$client_config_basename" == "" ]; then
    echo "Selecting Default Directory 'client1.ovpn' "
    client_config_basename="client1.ovpn"
fi

cd "$client_config_dirname"
if [ ! $? -eq 0 ]; then
    echo "ERR: Client config directory not found" >&2
    exit 1
fi

client_config="$client_config_dirname/$client_config_basename"

if [ -f "$client_config" ]; then
    openvpn_bin=$(command -v openvpn)
    if [ ! $? -eq 0 ]; then
        echo "ERR: OpenVPN is not found" >&2
        exit 1
    fi
    openvpn_bin $client_config
else

    client_config_basename=$(basename $client_config)
    if [ "$client_config_basename" == "$client_config" ]; then
        echo "$PWD/$client_config"
    fi
    echo "Err: Client config file \"$client_config\" is not found"
    exit 1
fi
