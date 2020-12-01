#!/bin/bash

echo -e "\n\n\tOpenVPN Client Generator\n\n"

server_config_dir=${server_config_dir-/etc/openvpn/server}

if [ -f "$server_config_dir/env" ]; then
	source $server_config_dir/env
else
	echo >&2 "ERR: Env file is not found"
	exit 1
fi

DATE=$(date)
mkdir -vp "$server_config_dir/clients/"

required_conf_files=("pki/ca.crt" "dh.pem" "tc.key" "env")

for file in ${required_conf_files[*]}; do
	if [ ! -f $server_config_dir/$file ]; then
		echo >&2 "File $server_config_dir/$file not found"
		err_on_exit=yes
	fi
done

if [ "$err_on_exit" == "yes" ]; then
	exit
fi

client_regex="^[a-zA-Z0-9]{1,15}$"

new_client_name() {
	current_client_count=$(ls $server_config_dir/clients/ 2>/dev/null | wc -l)
	echo "client$((current_client_count + 1))"
}

until [[ "$client_tmp" =~ $client_regex ]]; do
	client_tmp=${client-$(new_client_name)}
	if [ "$fast_install" != 'true' ]; then
		read -p "Please enter Client name > " -e -i "$client_tmp" client_tmp
	fi

	if [[ "$client_tmp" =~ $client_regex ]]; then
		if [ -f "$server_config_dir/pki/reqs/$client_tmp.req" ] || [ -f "$server_config_dir/clients/$client_tmp.ovpn" ]; then
			echo "\"$client_tmp\" is already used."
			client_tmp="$client_tmp"
			client=""
			if [ "$fast_install" == 'true' ]; then
				exit 1
			fi
		fi
		if [ -f "$server_config_dir/clients/$client_tmp.ovpn" ]; then
			echo "You can found configuration file at \"$server_config_dir/clients/$client_tmp.ovpn\""
			client=""
		fi

	else
		echo "You can use only letter or numbers. Current client name '$client_tmp' Ex. \"Client1\""
		if [ "$fast_install" == 'true' ]; then
			exit 1
		fi
	fi
done

REMOTE_ADDR() {
	server_ip_array=($server_ip)
	for i in "${server_ip_array[@]}"; do
		if [[ "$i" =~ $ip_regex ]] || [[ "$i" =~ $ip6_regex ]]; then
			echo "
<connection>
remote $i $port
connect-retry 1
connect-timeout 5
</connection>
"
			has_a_ip=true
		else
			echo >&2 "ERR. Unexpected IP type. Wrong Ip adress is '$i'"
			err_on_exit=yes
		fi
	done
	if [ "$err_on_exit" == "yes" ]; then
		exit
	fi
}

EASYRSA="/easy-rsa/" EASYRSA_PKI="$server_config_dir/pki" /easy-rsa/easyrsa build-client-full "$client_tmp" nopass

if [ ! $? -eq 0 ]; then
	echo >&2 "ERR: Easyrsa client generate error."
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
# Client Name = $client_tmp
client
dev $dev_type
proto $protocol
$(REMOTE_ADDR)
resolv-retry infinite
connect-retry-max infinite
nobind
persist-key
persist-tun
remote-cert-tls server
auth $auth		
cipher $cipher				# Version <= 2.4
#cipher-data-fallback $cipher	# Version => 2.5
ignore-unknown-option block-outside-dns
block-outside-dns
verb $verb
auth-nocache
### Certs ###
"
}

OVPN_GENERATE() {
	required_conf_files=("pki/ca.crt" "pki/issued/$client_tmp.crt" "tc.key" "pki/private/$client_tmp.key")

	for file in ${required_conf_files[*]}; do
		if [ ! -f $server_config_dir/$file ]; then
			echo >&2 "File $server_config_dir/$file not found"
			err_on_exit=yes
		fi
	done

	if [ "$err_on_exit" == "yes" ]; then
		exit 1
	fi

	CLIENT_COMMON
	echo "<ca>"
	cat $server_config_dir/pki/ca.crt
	echo "</ca>"

	echo "<cert>"
	sed -ne '/BEGIN CERTIFICATE/,$ p' "$server_config_dir/pki/issued/$client_tmp.crt"
	echo "</cert>"

	echo "<key>"
	cat "$server_config_dir/pki/private/$client_tmp.key"
	echo "</key>"

	echo "<tls-crypt>"
	sed -ne '/BEGIN OpenVPN Static key/,$ p' "$server_config_dir/tc.key"
	echo "</tls-crypt>"
}

OVPN_GENERATE >"$server_config_dir/clients/$client_tmp.ovpn"
echo "Configuration file is created at \"$server_config_dir/clients/$client_tmp.ovpn\""

if [ "$fast_install" == 'true' ]; then
	echo -e "\n\n"
	cat $server_config_dir/clients/$client_tmp.ovpn
	echo -e "\n\n"
else
	read -p "Do you want to print client configuration ? > " -e -i "yes" question
	if [ "$question" == "yes" ]; then
		echo -e "\n\n"
		cat $server_config_dir/clients/$client_tmp.ovpn
		echo -e "\n\n"
		unset question
	fi
fi
