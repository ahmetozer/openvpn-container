#!/bin/bash

###                   ###
#   Preset variables    #
###                   ###

port_regex="^((6553[0-5])|(655[0-2][0-9])|(65[0-4][0-9]{2})|(6[0-4][0-9]{3})|([1-5][0-9]{4})|([1-9][0-9]{3})|([1-9][0-9]{2})|([1-9][0-9])|([1-9]))$"
ip_regex="^(((25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)(\.|$)){4})"
ip6_regex="^(([0-9a-fA-F]{1,4}:){7,7}[0-9a-fA-F]{1,4}|([0-9a-fA-F]{1,4}:){1,7}:|([0-9a-fA-F]{1,4}:){1,6}:[0-9a-fA-F]{1,4}|([0-9a-fA-F]{1,4}:){1,5}(:[0-9a-fA-F]{1,4}){1,2}|([0-9a-fA-F]{1,4}:){1,4}(:[0-9a-fA-F]{1,4}){1,3}|([0-9a-fA-F]{1,4}:){1,3}(:[0-9a-fA-F]{1,4}){1,4}|([0-9a-fA-F]{1,4}:){1,2}(:[0-9a-fA-F]{1,4}){1,5}|[0-9a-fA-F]{1,4}:((:[0-9a-fA-F]{1,4}){1,6})|:((:[0-9a-fA-F]{1,4}){1,7}|:)|fe80:(:[0-9a-fA-F]{0,4}){0,4}%[0-9a-zA-Z]{1,}|::(ffff(:0{1,4}){0,1}:){0,1}((25[0-5]|(2[0-4]|1{0,1}[0-9]){0,1}[0-9])\.){3,3}(25[0-5]|(2[0-4]|1{0,1}[0-9]){0,1}[0-9])|([0-9a-fA-F]{1,4}:){1,4}:((25[0-5]|(2[0-4]|1{0,1}[0-9]){0,1}[0-9])\.){3,3}(25[0-5]|(2[0-4]|1{0,1}[0-9]){0,1}[0-9]))$"

mkdir -p /etc/openvpn/server/
if [ -f /etc/openvpn/server/env ]; then
    echo "Server is already configured and installed"
    exit 0
else
    touch /etc/openvpn/server/env
fi

until [[ "$protocol" =~ "^tcp$|^udp$" ]]; do
    echo "UDP can have a faster and lower latency connection, but some companies block UDP."
    if [ "$fast_install" == 'true' ] && [ -z "$protocol" ]; then
        protocol='tcp'
    else
        read -p "What protocol do you want to use for VPN? (TCP/UDP) > " -e -i "tcp" protocol
    fi
    case $protocol in
    [TCPtcp]*)
        protocol='tcp'
        break
        ;;
    [UDPudp]*)
        protocol='udp'
        break
        ;;
    *) echo "Please type 'tcp' or 'udp'." ;;
    esac
done
echo "Protocol $protocol"

until [[ "$port" =~ $port_regex ]]; do

    if [ "$fast_install" == 'true' ] && [ -z "$port" ]; then
        port=443
    else
        read -p "What port number do you want to use for VPN ? (suggested 443) > " -e -i "443" port
    fi

    if ! [[ "$port" =~ ^[0-9]+$ ]]; then
        echo "Only Number accepted."
    else
        if [ "$port" -ge 1 -a "$port" -le 65535 ]; then
            if [ "$porttype" == "tcp" ]; then
                if (lsof -i :$port | grep TCP); then
                    echo "Port already usage. Please select another port."
                else
                    echo "Selected port $port/tcp"
                    break
                fi
            fi

            if [ "$porttype" == "udp" ]; then
                if (lsof -i :$port | grep UDP); then
                    echo "Port already usage. Please select another port."
                else
                    echo "Selected port $port/udp"
                    break
                fi
            fi
        else
            echo "Please select a number between 1 and 65535 for the port."
        fi
    fi
done
echo "Port $port"

until [[ "$dev_type" =~ "^tun$|^tap$" ]]; do
    if [ "$fast_install" == 'true' ] && [ -z "$dev_type" ]; then
        protocol='tun'
    else
        read -p "What device type is do you want to use for VPN ? (tun/tap) > " -e -i "tun" dev_type
    fi
    case $dev_type in
    [TUNtun]*)
        dev_type='tun'
        break
        ;;
    [TAPtap]*)
        dev_type='tap'
        break
        ;;
    *) echo "Please type 'tun' or 'tap'." ;;
    esac
done
echo "Device type $dev_type"

until [[ "$dns1" =~ $ip_regex ]] || [[ "$dns1" =~ $ip6_regex ]]; do

    if [ "$fast_install" == 'true' ] && [ -z "$dns1" ]; then
        dns1="1.1.1.1"
    else
        read -p "Write a dns server one > " -e -i "1.1.1.1" dns1
    fi
done
echo "DNS 1 $dns1"

until [[ "$dns2" =~ $ip_regex ]] || [[ "$dns2" =~ $ip6_regex ]]; do

    if [ "$fast_install" == 'true' ] && [ -z "$dns2" ]; then
        dns2="8.8.4.4"
    else
        read -p "Write a dns server two > " -e -i "8.8.4.4" dns2
    fi
done
echo "DNS 2 $dns2"

# Write dh.pem

# https://ssl-config.mozilla.org/ffdhe2048.txt
echo "-----BEGIN DH PARAMETERS-----
MIIBCAKCAQEA//////////+t+FRYortKmq/cViAnPTzx2LnFg84tNpWp4TZBFGQz
+8yTnc4kmz75fS/jY2MMddj2gbICrsRhetPfHtXV/WVhJDP1H18GbtCFY2VVPe0a
87VXE15/V8k1mE8McODmi3fipona8+/och3xWKE2rec1MKzKT0g6eXq8CrGCsyT7
YdEIqUuyyOP7uWrat2DX9GgdT0Kj3jlN9K5W7edjcrsZCwenyO4KbXCeAvzhzffi
7MA0BM0oNC9hkXL+nOmFg/+OTxIy7vKBg8P+OxtMb61zO7X8vC7CIAXFjvGDfRaD
ssbzSibBsu/6iGtCOGEoXJf//////////wIBAg==
-----END DH PARAMETERS-----"  >/etc/openvpn/server/dh.pem

current_dir=$PWD
echo "Creating Server Certifaces"
# ? trap 'capture err' ERR
cd /etc/openvpn/server/easy-rsa/

echo "EASYRSA_CERT_EXPIRE ${EASYRSA_CERT_EXPIRE-3650}"
echo "EASYRSA_CRL_DAYS ${EASYRSA_CRL_DAYS-3650}"

./easyrsa init-pki
./easyrsa --batch build-ca nopass
./easyrsa build-server-full server nopass
./easyrsa gen-crl
cp pki/ca.crt pki/private/ca.key pki/issued/server.crt pki/private/server.key pki/crl.pem /etc/openvpn/server
chmod o+x /etc/openvpn/server/
openvpn --genkey --secret /etc/openvpn/server/tc.key
# ? trap - ERR #! Reset the trap
ls -lah /etc/openvpn/server/

echo "protocol=$protocol" >/etc/openvpn/server/env
echo "port=$port" >>/etc/openvpn/server/env
echo "dns1=$dns1" >>/etc/openvpn/server/env
echo "dns2=$dns2" >>/etc/openvpn/server/env


echo "EASYRSA_CERT_EXPIRE=${EASYRSA_CERT_EXPIRE-3650}" >>/etc/openvpn/server/env
echo "EASYRSA_CRL_DAYS=${EASYRSA_CRL_DAYS-3650}" >>/etc/openvpn/server/env

echo "port $port
proto $protocol
#dev vpn1
#dev-type $dev_type
dev $dev_type
ca ca.crt
cert server.crt
key server.key
dh dh.pem
crl-verify crl.pem
auth SHA512
tls-crypt tc.key

topology subnet

cipher AES-256-CBC
user nobody
group nobody
persist-key
persist-tun
status ${openvpn_status_log_loc-/dev/null} #? Log location. Default openvpn-status.log
verb ${verb-0}


server 10.8.0.0 255.255.255.0
keepalive 10 120

push \"redirect-gateway def1 bypass-dhcp\"
ifconfig-pool-persist ipp.txt
push \"dhcp-option DNS $dns1\"
push \"dhcp-option DNS $dns2\"
" >>/etc/openvpn/server/server.conf

if [[ "$protocol" = "udp" ]]; then
    echo "explicit-exit-notify" >>/etc/openvpn/server/server.conf
fi
