#!/bin/bash

echo "
###                        ###
# ? OpenVPN config generator #
# ?  https://ahmetozer.org   #
###                        ###
"
###                   ###
#  * Preset variables    #
###                   ###

port_regex="^((6553[0-5])|(655[0-2][0-9])|(65[0-4][0-9]{2})|(6[0-4][0-9]{3})|([1-5][0-9]{4})|([1-9][0-9]{3})|([1-9][0-9]{2})|([1-9][0-9])|([1-9]))$"
ip_regex="^(((25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)(\.|$)){3})(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)(\/([0-9]$|[1-2][0-9]$|3[0-2])|$)"
ip6_regex="^(([0-9a-fA-F]{1,4}:){7,7}[0-9a-fA-F]{1,4}|([0-9a-fA-F]{1,4}:){1,7}:|([0-9a-fA-F]{1,4}:){1,6}:[0-9a-fA-F]{1,4}|([0-9a-fA-F]{1,4}:){1,5}(:[0-9a-fA-F]{1,4}){1,2}|([0-9a-fA-F]{1,4}:){1,4}(:[0-9a-fA-F]{1,4}){1,3}|([0-9a-fA-F]{1,4}:){1,3}(:[0-9a-fA-F]{1,4}){1,4}|([0-9a-fA-F]{1,4}:){1,2}(:[0-9a-fA-F]{1,4}){1,5}|[0-9a-fA-F]{1,4}:((:[0-9a-fA-F]{1,4}){1,6})|:((:[0-9a-fA-F]{1,4}){1,7}|:)|fe80:(:[0-9a-fA-F]{0,4}){0,4}%[0-9a-zA-Z]{1,}|::(ffff(:0{1,4}){0,1}:){0,1}((25[0-5]|(2[0-4]|1{0,1}[0-9]){0,1}[0-9])\.){3,3}(25[0-5]|(2[0-4]|1{0,1}[0-9]){0,1}[0-9])|([0-9a-fA-F]{1,4}:){1,4}:((25[0-5]|(2[0-4]|1{0,1}[0-9]){0,1}[0-9])\.){3,3}(25[0-5]|(2[0-4]|1{0,1}[0-9]){0,1}[0-9]))(/[1-9][0-9])?$"
server_config_dir=${server_config_dir-/server}

cidr_netmask_array=("0.0.0.0" "128.0.0.0" "192.0.0.0" "224.0.0.0" "240.0.0.0" "248.0.0.0" "252.0.0.0" "254.0.0.0" "255.0.0.0"
    "255.128.0.0" "255.192.0.0" "255.224.0.0" "255.240.0.0" "255.248.0.0" "255.252.0.0" "255.254.0.0" "255.255.0.0"
    "255.255.128.0" "255.255.192.0" "255.255.224.0" "255.255.240.0" "255.255.248.0" "255.255.252.0" "255.255.254.0"
    "255.255.255.0" "255.255.255.128" "255.255.255.192" "255.255.255.224" "255.255.255.240" "255.255.255.248" "255.255.255.252"
    "255.255.255.254" "255.255.255.255"
)
ip_block_cidr=${ip_block-10.0.1.0}

echo "Config dir $server_config_dir"
mkdir -pv $server_config_dir/oneconfig
if [ -f $server_config_dir/env ]; then
    echo "Server is already configured and installed"
    exit 0
fi

ip6_block=${ip6_block-"fdac:900d:c0ff:ee::/64"}
echo "Detecting Ip adresses"
printf "Ip ..."
server_ip4=${server_ip-$(wget -T 3 -t 2 -q4O- cloudflare.com/cdn-cgi/tracert | grep "ip=" | cut -d"=" -f2)}
echo " ... $server_ip4"
printf "Ipv6 ..."
server_ip6=${server_ip6-$(wget -T 3 -t 2 -q6O- cloudflare.com/cdn-cgi/tracert | grep "ip=" | cut -d"=" -f2)}
echo " ... $server_ip6"

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

until [[ $has_a_ip ]]; do
    echo "Define your server IP address"
    if [ "$fast_install" == 'true' ]; then
        if [ -z "$server_ip" ]; then
            server_ip="$server_ip6 $server_ip4"
        fi
    else
        if [ -z "$server_ip" ]; then
            read -p "Given Ip address > " -e -i "$server_ip" server_ip
        else
            read -p "Auto detected Ip address > " -e -i "$server_ip6 $server_ip4" server_ip
        fi
    fi
    server_ip_array=($server_ip)
    for i in "${server_ip_array[@]}"; do
        if [[ "$i" =~ $ip_regex ]] || [[ "$i" =~ $ip6_regex ]]; then
            echo "Server Ip = '$i'"
            has_a_ip=true
        else
            echo "Wrong Ip adress '$i'"
            exit 1
        fi
    done
done

until [[ "$protocol" =~ "^tcp$|^udp$" ]]; do
    echo "UDP can have a faster and lower latency connection, but some companies block UDP."
    if [ "$fast_install" == 'true' ] && [ -z "$protocol" ]; then
        protocol='tcp'
    elif [ "$fast_install" == 'true' ]; then
        echo "Protocol is setted by hand = $protocol"
    else
        protocol=${protocol-"tcp"}
        read -p "What protocol do you want to use for VPN? (TCP/UDP) > " -e -i "$protocol" protocol
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
    *) if [ "$fast_install" == 'true' ]; then
        echo "ERR: Protocol '$protocol' is not valid protocol."
        exit 1
    else
        echo "Please type 'tcp' or 'udp'."
    fi ;;
    esac
done

echo "Protocol $protocol"

until [[ "$port" =~ $port_regex ]]; do

    if [ "$fast_install" == 'true' ] && [ -z "$port" ]; then
        port='443'
    elif [ "$fast_install" == 'true' ]; then
        echo "Port is setted by hand = $port"
    else
        port=${port-"443"}
        read -p "What port number do you want to use for VPN ? (suggested 443) > " -e -i "$port" port
    fi

    if ! [[ "$port" =~ ^[0-9]+$ ]]; then
        echo "Only Number accepted."
        if [ "$fast_install" == 'true' ]; then
            exit 1
        fi
    else
        if [ "$port" -ge 1 -a "$port" -le 65535 ]; then
            if [ "$porttype" == "tcp" ]; then
                if (lsof -i :$port | grep TCP); then
                    echo "Port already usage. Please select another port."
                    if [ "$fast_install" == 'true' ]; then
                        exit 1
                    fi
                else
                    echo "Selected port $port/tcp"
                    break
                fi
            fi

            if [ "$porttype" == "udp" ]; then
                if (lsof -i :$port | grep UDP); then
                    echo "Port already usage. Please select another port."
                    if [ "$fast_install" == 'true' ]; then
                        exit 1
                    fi
                else
                    echo "Selected port $port/udp"
                    break
                fi
            fi
        else
            echo "Please select a number between 1 and 65535 for the port."
            if [ "$fast_install" == 'true' ]; then
                exit 1
            fi
        fi
    fi
done
echo "Port $port"

until [[ "$dev_type" =~ "^tun$|^tap$" ]]; do
    if [ "$fast_install" == 'true' ] && [ -z "$dev_type" ]; then
        dev_type='tun'
    elif [ "$fast_install" == 'true' ]; then
        echo "Device type is setted by hand = $dev_type"
    else
        dev_type=${dev_type-"tun"}
        read -p "What device type is do you want to use for VPN ? (tun/tap) > " -e -i "$dev_type" dev_type
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
    *) if [ "$fast_install" == 'true' ]; then
        echo "ERR: Device type '$dev_type' is not valid type."
        exit 1
    else
        echo "Please type 'tun' or 'tap'."
    fi ;;

    esac
done
echo "Device type $dev_type"

loop_detect=0
until [[ "$dns1" =~ $ip_regex ]] || [[ "$dns1" =~ $ip6_regex ]]; do
    if [ $loop_detect -gt 0 ]; then
        echo "ERR dns1 = '$dns1' is not valid IPv4 or IPv6 address"
        exit 1
    fi
    dns1=${dns1-"1.1.1.1"}
    if [ "$fast_install" != 'true' ]; then
        read -p "Write a primary dns server > " -e -i "$dns1" dns1
    else
        loop_detect=$((loop_detect + 1))
    fi
done
echo "DNS 1 $dns1"

loop_detect=0
until [[ "$dns2" =~ $ip_regex ]] || [[ "$dns2" =~ $ip6_regex ]]; do
    if [ $loop_detect -gt 0 ]; then
        echo "ERR dns2 = '$dns2' is not valid IPv4 or IPv6 address"
        exit 1
    fi
    dns2=${dns2-"8.8.4.4"}
    if [ "$fast_install" != 'true' ]; then
        read -p "Write a secondary dns server > " -e -i "$dns2" dns2
    else
        loop_detect=$((loop_detect + 1))
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
echo "server_ip=\"$server_ip\"" >>$server_config_dir/env
echo "server_ip6=$server_ip6" >>$server_config_dir/env

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
#EASYRSA="/easy-rsa/"
#cd $server_config_dir/pki/
echo EASYRSA="/easy-rsa/" EASYRSA_PKI="$server_config_dir/pki" /easy-rsa/easyrsa

echo "EASYRSA_CERT_EXPIRE ${EASYRSA_CERT_EXPIRE-3650}"
echo "EASYRSA_CRL_DAYS ${EASYRSA_CRL_DAYS-3650}"

EASYRSA="/easy-rsa/" EASYRSA_PKI="$server_config_dir/pki" /easy-rsa/easyrsa init-pki
EASYRSA="/easy-rsa/" EASYRSA_PKI="$server_config_dir/pki" /easy-rsa/easyrsa --batch build-ca nopass
EASYRSA="/easy-rsa/" EASYRSA_PKI="$server_config_dir/pki" /easy-rsa/easyrsa build-server-full server nopass
EASYRSA="/easy-rsa/" EASYRSA_PKI="$server_config_dir/pki" /easy-rsa/easyrsa gen-crl
cp $server_config_dir/pki/ca.crt $server_config_dir/pki/private/ca.key $server_config_dir/pki/issued/server.crt $server_config_dir/pki/private/server.key $server_config_dir/pki/crl.pem $server_config_dir
chmod o+x $server_config_dir/
$openvpn_bin --genkey --secret $server_config_dir/tc.key
# ? trap - ERR #! Reset the trap
##ls -lah $server_config_dir/

verb=${verb-0}
cipher=${cipher-"AES-256-CBC"}
auth=${auth-"SHA512"}
echo "
        Envoriment variables are saving...
"
echo "protocol=$protocol" >>$server_config_dir/env
echo "port=$port" >>$server_config_dir/env
echo "dns1=$dns1" >>$server_config_dir/env
echo "dns2=$dns2" >>$server_config_dir/env
echo "dev_type=$dev_type" >>$server_config_dir/env
echo "verb=$verb" >>$server_config_dir/env
echo "cipher=$cipher" >>$server_config_dir/env
echo "auth=$auth" >>$server_config_dir/env

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

#data-ciphers $cipher   # Version =>2.5
cipher $cipher         # Version < 2.4
auth $auth

user nobody
group nobody
persist-key
persist-tun
#status ${openvpn_status_log_loc-/dev/null} #? Log location. Default openvpn-status.log
verb ${verb}

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
#client-to-client
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
tls-crypt tc.key
" >>$server_config_dir/server.conf

printf "
        Checking generated files ... "
required_conf_files=("ca.crt" "server.crt" "server.key" "dh.pem" "crl.pem" "tc.key" "server.conf" "env")

for file in ${required_conf_files[*]}; do
    if [ ! -f $server_config_dir/$file ]; then
        echo "File $server_config_dir/$file not found"
        err_on_exit=yes
    fi
done
unset required_conf_files

if [ "$err_on_exit" == "yes" ]; then
    exit
else
    echo "ok"
fi

echo "
        Classic configuration is done
        Creating oneconfig/server.sh
"

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

echo "
        ###     ###     ###     ###     ###     ###     ###

        Server Certificate and Config generations are done ...

        ###     ###     ###     ###     ###     ###     ###
"
