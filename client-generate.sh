#/bin/sh

echo -e "\n\n\tOpenVPN Client Generator\n\n"

server_config_dir=${server_config_dir-/etc/openvpn/server}

source $server_config_dir/env
DATE=$(date)
mkdir -vp "$server_config_dir/clients/"

required_conf_files=("easy-rsa/pki/ca.crt" "dh.pem" "tc.key" "env")

for file in ${required_conf_files[*]}; do
	if [ ! -f $server_config_dir/$file ]; then
		echo "File $server_config_dir/$file not found"
		err_on_exit=yes
	fi
done

if [ "$err_on_exit" == "yes" ]; then
	exit
fi

cd $server_config_dir/easy-rsa

client_regex="^[a-zA-Z0-9]{1,15}$"

until [[ "$client" =~ $client_regex ]]; do

	if [ "$fast_install" == 'true' ]; then
		client="client1"
	else
		read -p "Please enter Client name > " -e -i "client1" client
	fi

	if [[ "$client" =~ $client_regex ]]; then
		if [ -f "$server_config_dir/easy-rsa/pki/reqs/$client.req" ] || [ -f "$server_config_dir/clients/$client.ovpn" ]; then
			echo "\"$client\" is already used."
			client_tmp="$client"
			client=""
			if [ "$fast_install" == 'true' ]; then
				exit
			fi
		fi
		if [ -f "$server_config_dir/clients/$client_tmp.ovpn" ]; then
			echo "You can found configuration file at \"$server_config_dir/clients/$client_tmp.ovpn\""
			client=""
		fi

	else
		echo "You can use only letter or numbers. Ex. \"Client1\""

	fi
done

REMOTE_ADDR() {
	server_ip_array=($server_ip)
	for i in "${server_ip_array[@]}"; do
		if [[ "$i" =~ $ip_regex ]] || [[ "$i" =~ $ip6_regex ]]; then
			echo "remote $i $port"
			has_a_ip=true
		else
			echo "ERR. Unexpected IP type. Wrong Ip adress is '$i'"
			err_on_exit=yes
		fi
	done
	if [ "$err_on_exit" == "yes" ]; then
		exit
	fi
}

./easyrsa build-client-full "$client" nopass

if [ ! $? -eq 0 ]; then
	echo "ERR: Easyrsa client generate error." >&2
	exit 1
fi

###					 ###
#	Write OVPN file	   #
###					 ###

CLIENT_COMMON() {
	echo "###		###
# Hostname $HOSTNAME
# Date $DATE
# Source https://github.com/ahmetozer/openvpn-container
# Client Name = $client
client
dev $dev_type
proto $protocol
$(REMOTE_ADDR)
resolv-retry infinite
nobind
persist-key
persist-tun
remote-cert-tls server
auth SHA512
cipher AES-256-CBC
ignore-unknown-option block-outside-dns
block-outside-dns
verb $verb

### Certs ###
"
}

OVPN_GENERATE() {
	required_conf_files=("easy-rsa/pki/ca.crt" "easy-rsa/pki/issued/$client.crt" "tc.key" "easy-rsa/pki/private/$client.key")

	for file in ${required_conf_files[*]}; do
		if [ ! -f $server_config_dir/$file ]; then
			echo "File $server_config_dir/$file not found"
			err_on_exit=yes
		fi
	done

	if [ "$err_on_exit" == "yes" ]; then
		exit 1
	fi

	CLIENT_COMMON
	echo "<ca>"
	cat $server_config_dir/easy-rsa/pki/ca.crt
	echo "</ca>"

	echo "<cert>"
	sed -ne '/BEGIN CERTIFICATE/,$ p' "$server_config_dir/easy-rsa/pki/issued/$client.crt"
	echo "</cert>"

	echo "<key>"
	cat "$server_config_dir/easy-rsa/pki/private/$client.key"
	echo "</key>"

	echo "<tls-crypt>"
	sed -ne '/BEGIN OpenVPN Static key/,$ p' "$server_config_dir/tc.key"
	echo "</tls-crypt>"
}

OVPN_GENERATE >"$server_config_dir/clients/$client.ovpn"
echo "Configuration file is created at \"$server_config_dir/clients/$client.ovpn\""

if [ "$fast_install" == 'true' ]; then
	cat $server_config_dir/clients/$client.ovpn
else
	read -p "Do you want to print client configuration ? > " -e -i "yes" question
	if [ "$question" == "yes" ]; then
		cat $server_config_dir/clients/$client.ovpn
		unset question
	fi
fi
