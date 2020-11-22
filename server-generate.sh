#!/bin/bash

###                        ###
# ? OpenVPN config generator #
# ?  https://ahmetozer.org   #
###                        ###

###                   ###
#  * Preset variables    #
###                   ###

port_regex="^((6553[0-5])|(655[0-2][0-9])|(65[0-4][0-9]{2})|(6[0-4][0-9]{3})|([1-5][0-9]{4})|([1-9][0-9]{3})|([1-9][0-9]{2})|([1-9][0-9])|([1-9]))$"
ip_regex="^(((25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)(\.|$)){3})(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)(\/([0-9]$|[1-2][0-9]$|3[0-2])|$)"
ip6_regex="^(([0-9a-fA-F]{1,4}:){7,7}[0-9a-fA-F]{1,4}|([0-9a-fA-F]{1,4}:){1,7}:|([0-9a-fA-F]{1,4}:){1,6}:[0-9a-fA-F]{1,4}|([0-9a-fA-F]{1,4}:){1,5}(:[0-9a-fA-F]{1,4}){1,2}|([0-9a-fA-F]{1,4}:){1,4}(:[0-9a-fA-F]{1,4}){1,3}|([0-9a-fA-F]{1,4}:){1,3}(:[0-9a-fA-F]{1,4}){1,4}|([0-9a-fA-F]{1,4}:){1,2}(:[0-9a-fA-F]{1,4}){1,5}|[0-9a-fA-F]{1,4}:((:[0-9a-fA-F]{1,4}){1,6})|:((:[0-9a-fA-F]{1,4}){1,7}|:)|fe80:(:[0-9a-fA-F]{0,4}){0,4}%[0-9a-zA-Z]{1,}|::(ffff(:0{1,4}){0,1}:){0,1}((25[0-5]|(2[0-4]|1{0,1}[0-9]){0,1}[0-9])\.){3,3}(25[0-5]|(2[0-4]|1{0,1}[0-9]){0,1}[0-9])|([0-9a-fA-F]{1,4}:){1,4}:((25[0-5]|(2[0-4]|1{0,1}[0-9]){0,1}[0-9])\.){3,3}(25[0-5]|(2[0-4]|1{0,1}[0-9]){0,1}[0-9]))(/[1-9][0-9])?$"
server_config_dir=${server_config_dir-/etc/openvpn/server}

cidr_netmask_array=("0.0.0.0" "128.0.0.0" "192.0.0.0" "224.0.0.0" "240.0.0.0" "248.0.0.0" "252.0.0.0" "254.0.0.0" "255.0.0.0"
    "255.128.0.0" "255.192.0.0" "255.224.0.0" "255.240.0.0" "255.248.0.0" "255.252.0.0" "255.254.0.0" "255.255.0.0"
    "255.255.128.0" "255.255.192.0" "255.255.224.0" "255.255.240.0" "255.255.248.0" "255.255.252.0" "255.255.254.0"
    "255.255.255.0" "255.255.255.128" "255.255.255.192" "255.255.255.224" "255.255.255.240" "255.255.255.248" "255.255.255.252"
    "255.255.255.254" "255.255.255.255"
)
ip_block_cidr=${ip_block_cidr-10.0.1.0}

ip6_block=${ip6_block-"fdac:900d:c0ff:ee::/64"}

echo "Config dir $server_config_dir"
mkdir -pv $server_config_dir/oneconfig
if [ -f $server_config_dir/env ]; then
    echo "Server is already configured and installed"
    exit 0
fi

openvpn_bin=$(command -v openvpn)
if [ ! $? -eq 0 ]; then
    echo "ERR: OpenVPN is not found" >&2
    exit 1
fi

DATE=$(date)

if [[ ! "$ip_block_cidr" =~ $ip_regex ]]; then
    echo "Your ip block is not right $ip_block_cidr."
    exit 1
fi
ip_block=$(echo $ip_block_cidr | cut -d'/' -f1)

if [[ ! "$ip_block" =~ $ip_regex ]]; then
    echo "Your ip block is not right $ip_block"
    exit 1
fi
cidr=$(echo $ip_block_cidr | cut -d'/' -f2)

#if ! (( cidr >= 0 && cidr <= 32)); then
if [[ ! "$cidr" =~ "([0-9]$|[1-2][0-9]$|3[0-2])" ]]; then
    cidr="24"
fi

netmask=${cidr_netmask_array[$cidr]}
if [[ ! "$netmask" =~ $ip_regex ]]; then
    echo "Your netmask is not right $netmask"
    exit 1
fi

if [[ ! "$ip6_block" =~ $ip6_regex ]]; then
    echo "Your IPv6 block or range is not right $ip6_block"
    exit 1
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
        dev_type='tun'
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

ip_nat=${ip_nat-yes}
ip6_nat=${ip6_nat-yes}

touch $server_config_dir/env
echo "DATE=\"$DATE\"" >$server_config_dir/env

echo "ip_block=$ip_block" >>$server_config_dir/env
echo "cidr=$cidr" >>$server_config_dir/env
echo "netmask=$netmask" >>$server_config_dir/env
echo "ip6_block=$ip6_block" >>$server_config_dir/env

echo "ip_nat=$ip_nat" >>$server_config_dir/env
echo "ip6_nat=$ip6_nat" >>$server_config_dir/env

# Write dh.pem
# ? https://ssl-config.mozilla.org/ffdhe2048.txt
echo "-----BEGIN DH PARAMETERS-----
MIIBCAKCAQEA//////////+t+FRYortKmq/cViAnPTzx2LnFg84tNpWp4TZBFGQz
+8yTnc4kmz75fS/jY2MMddj2gbICrsRhetPfHtXV/WVhJDP1H18GbtCFY2VVPe0a
87VXE15/V8k1mE8McODmi3fipona8+/och3xWKE2rec1MKzKT0g6eXq8CrGCsyT7
YdEIqUuyyOP7uWrat2DX9GgdT0Kj3jlN9K5W7edjcrsZCwenyO4KbXCeAvzhzffi
7MA0BM0oNC9hkXL+nOmFg/+OTxIy7vKBg8P+OxtMb61zO7X8vC7CIAXFjvGDfRaD
ssbzSibBsu/6iGtCOGEoXJf//////////wIBAg==
-----END DH PARAMETERS-----" >$server_config_dir/dh.pem

current_dir=$PWD
echo "Creating Server Certifaces"
# ? trap 'capture err' ERR
cd $server_config_dir/easy-rsa/

echo "EASYRSA_CERT_EXPIRE ${EASYRSA_CERT_EXPIRE-3650}"
echo "EASYRSA_CRL_DAYS ${EASYRSA_CRL_DAYS-3650}"

./easyrsa init-pki
./easyrsa --batch build-ca nopass
./easyrsa build-server-full server nopass
./easyrsa gen-crl
cp pki/ca.crt pki/private/ca.key pki/issued/server.crt pki/private/server.key pki/crl.pem $server_config_dir
chmod o+x $server_config_dir/
$openvpn_bin --genkey --secret $server_config_dir/tc.key
# ? trap - ERR #! Reset the trap
ls -lah $server_config_dir/

echo "protocol=$protocol" >>$server_config_dir/env
echo "port=$port" >>$server_config_dir/env
echo "dns1=$dns1" >>$server_config_dir/env
echo "dns2=$dns2" >>$server_config_dir/env
echo "dev_type=$dev_type" >>$server_config_dir/env
echo "verb=$verb" >>$server_config_dir/env

echo "EASYRSA_CERT_EXPIRE=${EASYRSA_CERT_EXPIRE-3650}" >>$server_config_dir/env
echo "EASYRSA_CRL_DAYS=${EASYRSA_CRL_DAYS-3650}" >>$server_config_dir/env

echo "###   ###
# Hostname $HOSTNAME
# Date $DATE
# Source https://github.com/ahmetozer/openvpn-config-generator-container

local ::
port $port
proto $protocol
#dev vpn1
#dev-type $dev_type
dev $dev_type

topology subnet

cipher AES-256-CBC
user nobody
group nobody
persist-key
persist-tun
status ${openvpn_status_log_loc-/dev/null} #? Log location. Default openvpn-status.log
verb ${verb-0}


keepalive 10 120
server ${ip_block} ${netmask}
server-ipv6 ${ip6_block}
#push \"redirect-gateway def1 bypass-dhcp\"
push \"redirect-gateway def1 ipv6 bypass-dhcp\"

ifconfig-pool-persist ipp.txt
push \"dhcp-option DNS $dns1\"
push \"dhcp-option DNS $dns2\"
" >>$server_config_dir/server.conf
if [[ "$protocol" = "udp" ]]; then
    echo "sndbuf 300000
rcvbuf 300000
#fast-io
explicit-exit-notify" >>$server_config_dir/server.conf
fi

###
#  ! Set certiface configure to config
###
cp $server_config_dir/server.conf $server_config_dir/oneconfig/server.conf
echo "
ca ca.crt
cert server.crt
key server.key
dh dh.pem
crl-verify crl.pem
auth SHA512
tls-crypt tc.key
" >>$server_config_dir/server.conf

# * Embed certifaces to server.conf to more easy transfer configuration

echo "<ca>" >>$server_config_dir/oneconfig/server.conf
cat $server_config_dir/ca.crt >>$server_config_dir/oneconfig/server.conf
echo "</ca>" >>$server_config_dir/oneconfig/server.conf

echo "<cert>" >>$server_config_dir/oneconfig/server.conf
cat $server_config_dir/server.crt >>$server_config_dir/oneconfig/server.conf
echo "</cert>" >>$server_config_dir/oneconfig/server.conf

echo "<key>" >>$server_config_dir/oneconfig/server.conf
cat $server_config_dir/server.key >>$server_config_dir/oneconfig/server.conf
echo "</key>" >>$server_config_dir/oneconfig/server.conf

echo "<dh>" >>$server_config_dir/oneconfig/server.conf
cat $server_config_dir/dh.pem >>$server_config_dir/oneconfig/server.conf
echo "</dh>" >>$server_config_dir/oneconfig/server.conf

echo "<crl-verify>" >>$server_config_dir/oneconfig/server.conf
cat $server_config_dir/crl.pem >>$server_config_dir/oneconfig/server.conf
echo "</crl-verify>" >>$server_config_dir/oneconfig/server.conf

echo "<tls-crypt>" >>$server_config_dir/oneconfig/server.conf
cat $server_config_dir/tc.key >>$server_config_dir/oneconfig/server.conf
echo "</tls-crypt>" >>$server_config_dir/oneconfig/server.conf

echo "###       ###
#   Environment Variables
#   These variables useful for startup scripts
###     ###" >>$server_config_dir/oneconfig/server.conf
# Turn into comment
cat $server_config_dir/env | sed -e 's/^/##env#-#/' >>$server_config_dir/oneconfig/server.conf