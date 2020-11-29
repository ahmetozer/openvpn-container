#!/bin/bash
###                      ###
#   http://ahmetozer.org   #
###                      ###

if [ -t 0 ]; then
    echo 'TTY is enabled'
else
    echo 'TTY is not enabled,
No input is presentable so fast_install mode is enabled'
    fast_install=true
fi

Avaible_Modes=("server" "server-generate" "client-generate" "client")
if [ -z "$mode" ]; then
    echo 'Mode is not presented.
System try to figure out mode.
'
else
    for modes in ${Avaible_Modes[*]}; do
        if [ "$mode" == "$modes" ]; then
            system_mode="$mode"
        fi
    done
    if [ -z "$system_mode" ]; then
        echo "You are selected mode is not in this system.
Please select one of them '${Avaible_Modes[*]}'"
    else
        echo "Mode is '$mode'"
        "./$mode.sh"
        exit_code=$?
        if [ ! $exit_code -eq 0 ]; then
            echo "ERR: Mode '$mode' is exited with err $exit_code" >&2
            exit 1
        fi
    fi
fi


find_client_config() {
    client_config_extension=("ovpn" "conf")
    for ext in ${client_config_extension[*]}; do
        for file in /etc/openvpn/client/*."$ext"; do
            if [ -f "$file" ]; then
                echo "I found client config file and selecting '$file'" # If it does what you want, remove the echo
                export client_config=$file
                break 2
            fi
        done
    done
}

if [ -z "$client_config" ]; then
    find_client_config
    if [ ! -z "$client_config" ]; then
        mode="client"
    fi
fi
if [ ! -z "$client_config" ] && [ -z "$mode" ]; then
    echo "Client config location is presented"
    mode="client"
else
    if [ -f /etc/openvpn/client/client1.ovpn ]; then
        echo "Default client config found. Mode is client"
        mode="client"
    fi
    server_config_dir=${server_config_dir-/etc/openvpn/server}

    if [ -f "$server_config_dir/oneconfig/server.conf" ] && [ -z "$mode" ]; then
        echo "Oneconfig is found. Mode is server"
        mode="server"
    fi

    if [ -f "$server_config_dir/env" ] && [ -z "$mode" ]; then
        echo "Env file found. Mode is server"
        mode="server"
    fi

    if [ -z "$mode" ]; then
        mode="server-generate"
        echo "Nothing found related to server or client
I am creating server config file, client1.ovpn file and run created openvpn server"
    fi
fi
case $mode in
server-generate)
    ./server-generate.sh
    exit_code=$?
    if [ ! $exit_code -eq 0 ]; then
        echo "ERR: Mode '$mode' is exited with err $exit_code" >&2
        exit 1
    fi
    ;&
client-generate)
    ./client-generate.sh
    exit_code=$?
    if [ ! $exit_code -eq 0 ]; then
        echo "ERR: Mode '$mode' is exited with err $exit_code" >&2
        exit 1
    fi
    ;&
server)
    ./server.sh
    exit_code=$?
    if [ ! $exit_code -eq 0 ]; then
        echo "ERR: Mode '$mode' is exited with err $exit_code" >&2
        exit 1
    fi
    ;;

client)
    ./client.sh
    exit_code=$?
    if [ ! $exit_code -eq 0 ]; then
        echo "ERR: Mode '$mode' is exited with err $exit_code" >&2
        exit 1
    fi
    ;;

esac
