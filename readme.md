# OpenVPN for Container

Run OpenVPN service on docker container. You can deploy own VPN service under 60 seconds.
Just single container use to creating certificates, run server and client modes.
System is fully IPv6 supported.

## Available Modes

- **server-generate**: Create OpenVPN server configuration files.  
Generated configuration files are stored under `/server/` directory.  

- **server**: Run OpenVPN server.  
System will be prepare firewall and other settings for you.

- **client-generate**: Create configuration and certificates for clients on server.  
**Note**: Client certificate generation requires all files under `/server/` in container.

- **client**: Client mode. Connect to your OpenVPN server.

## Environment Variables

All environment variables has a default define. Some variables (like IPv4 and IPv6 address) is cannot be pre defined in script. Script has a function to determine your IPv4 only, IPv6 only or DualStack (IPv4 and IPv6) connection address.  
If you want to change default environment variables, you can just define in your system.

```bash
docker run -it -e ip_block="192.168.3.0/24" ghcr.io/ahmetozer/openvpn-container
```

Environment variables with predefined default values which is used in this system.

```bash

mode=""             # Server running mode. If it not given system try to determine
fast_install=""     # No user input, everything is read from environment variable

## ! Client
# You can determine full path of client or just name of file which is available in /client/
client_config="/client/client1.ovpn"
#   OR
client_config="myown.ovpn"                      # system looks /client/myown.ovpn
# If you give only directory name client_config="/myvpns/" system looks ovpn and conf files and select only first result.
client_config="/myvpns/"

## !   Used for server-generate - server and client
ip_block=10.0.1.0/24                            #   Address block for IPv4 to clients
ip6_block=fdac:900d:c0ff:ee::/64                #   Address block for IPv6 to clients
ip_nat=yes                                      #   Nat on client`s IPv4 addresses
ip6_nat=yes                                     #   Nat on client`s IPv6 addresses
server_ip="2001:db8:900d:c0de::2 203.0.113.2"   #   Clients are use for remote addr.It is also Detected by script or you can define.
protocol=tcp                                    #   Server listen protocol
port=443                                        #   Server listen port
dns1=1.1.1.1                                    #   Primary DNS address for Clients
dns2=8.8.4.4                                    #   Secondary DNS address for Clients
dev_type=tun                                    #   Device type. For bridge and L2 transit use tap but tap is not support on phones.
verb=0                                          #   Verbose detail. 0 is no verbose
cipher=AES-256-CBC                              #   Used cipher
auth=SHA512                                     #   Used auth mechanism
EASYRSA_CERT_EXPIRE=3650                        #
EASYRSA_CRL_DAYS=3650                           #
```

## Deployment

VPN service require privilege to create VPN and manage vpn files.
Server configuration files are stored under `/server` by default, client configuration files which is created by server are stored under `/server/clients` and client mode system looks `/client` for connecting client configuration file .

For storing configuration files you have to mount configuration directory in to container.

You can use `--rm` flag to create one time container. If you want use as a service, replace --rm flag with `--restart always` on **client** mode or **server** mode

### Server Configuration Generate

In example case configuration files are stored on `/data/vpn`. You can change this with your own directory. Server generate mode only generate server configuration files which are required for openvpn server and generate first client configuration file.

```bash
docker run -it --rm -v /data/vpn:/server -e mode="server-generate" ghcr.io/ahmetozer/openvpn-container
```

Also you can define environment variables in docker run and bypass questions with enabling fast mode.
Non defined variables are use [default configurations](https://github.com/ahmetozer/openvpn-container#environment-variables) which are shown in begin of this document.

> **NOTE:** If you run with non terminal mode, program set `fast_install=true` by default due to no way to giving input and prevent stuck in cloud systems.

```bash
docker run -it --rm -v /data/vpn:/server -e mode="server-generate" -e port=53 -e protocol=udp -e fast_install=true  ghcr.io/ahmetozer/openvpn-container
#or
docker run -i --rm -v /data/vpn:/server -e mode="server-generate" -e port=53 -e protocol=udp ghcr.io/ahmetozer/openvpn-container
```

You can run container without defining mode, system firstly create server configuration files then create first client configuration and finally start the openvpn server.

```bash
docker run -it --rm -v /data/vpn:/server -e port=70 -e protocol=tcp -p 70:70 --privileged ghcr.io/ahmetozer/openvpn-container
```

### Client Certificate Generation

You have to require all files in /server which is created while client configuration generate step.
The output in your server will be on /data/vpn/clients/$client_name.ovpn

If client name are note defined, system use "client" word with client count "client1"

```bash
docker run -it --rm -v /data/vpn:/server -e mode="client-generate" ghcr.io/ahmetozer/openvpn-container
```

You can also set client name without reading from terminal

```bash
docker run -i --rm -v /data/vpn:/server -e mode="client-generate" -e client=john  ghcr.io/ahmetozer/openvpn-container
```

### Server mode

In this example server configuration files are stored under '/data/vpn' you can replace with your own directory.

```bash
docker run -i --rm --privileged -v /data/vpn:/server -e mode="server" ghcr.io/ahmetozer/openvpn-container
```

If you want to use `oneconfig` server.conf, you have to bind server.conf into into `/server/oneconfig` directory.

```bash
docker run -i --rm --privileged -v /data/vpn:/server/oneconfig/ -e mode="server" ghcr.io/ahmetozer/openvpn-container
```

> **NOTE**: `--privileged` argument is required for managing VPN interface and firewall rules. If you don't want to run server mode with privilege, replace `--privileged` flag with  `--cap-add=NET_ADMIN --sysctl net.ipv4.ip_forward=1 --sysctl net.ipv6.conf.all.forwarding=1 --sysctl net.ipv6.conf.all.disable_ipv6=0`

### Client

System looks `/client` directory in container to find client configuration file by default.  
If you not define client_name in enviroment variable script firstly looks `/client/client1.ovpn` file, if this is also not avaible, system try to find any `ovpn|conf` file to picking up.

```bash
docker run -i --rm --privileged -v /data/vpn/clients:/client -e mode="client" ghcr.io/ahmetozer/openvpn-container
```

> **NOTE**: "--privileged" argument is required for managing VPN interface and sysctl rules. If you don't want to run client mode with privilege, replace `--privileged` flag with  `--cap-add=NET_ADMIN --sysctl net.ipv6.conf.all.disable_ipv6=0`

## Example Deployments

- 3 Mode in one command: Create server, generate first client config and run openvpn server.  
Your client configuration file is under /data/vpn/clients/client1.ovpn

```bash
docker run -it --rm --privileged -v /data/vpn:/server ghcr.io/ahmetozer/openvpn-container
```

- Create server, generate first client config and run openvpn server without asking any user input.

```bash
docker run --rm --privileged -e fast_install=true -v /data/vpn:/server ghcr.io/ahmetozer/openvpn-container
```

- Create server with custom port.

```bash
docker run -i  --rm --privileged -e port=22 -v /data/vpn:/server ghcr.io/ahmetozer/openvpn-container
```

- For tap mode, define dev_type as tap

```bash
docker run -it -e dev_type=tap --rm --privileged -v /data/vpn:/server ghcr.io/ahmetozer/openvpn-container
```

- Generate new client configuration file, system automatically recommend a new client name and you can also write own name.

```bash
docker run -it --rm --privileged -v/data/vpn:/server ghcr.io/ahmetozer/openvpn-container client-generate
```

- Fastly create client configuration without asking any input.

```bash
docker run -it -e fast_install=true --rm --privileged -e client="john" -e mode="client-generate" -v/data/vpn:/server ghcr.io/ahmetozer/openvpn-container
```

- Run OpenVPN server

```bash
docker run -i --rm --privileged -v/data/vpn:/server ghcr.io/ahmetozer/openvpn-container server
```

- Give native IPv6 access to Clients Without NAT66
If your server has a IPv6 connectivity you can run OpenVPN in host network with nddpd

```bash
#If your IPv6 block is not routed, server as neighbor discovery, you have to reply neighbor discovery questions generated from router. Mostly required on all VPS providers
docker run -it --restart always --cap-add NET_ADMIN --cap-add NET_RAW --network host ahmetozer/ndppd
# Generate OpenVPN server configuration with dedicated IPV6 addr. Replace 2001:900d:c0ff:ee:1 with your range
docker run -i --rm --privileged -v/data/vpn:/server --network host -e ip6_block="2001:900d:c0ff:ee:1::/80" -e ip6_nat=no ghcr.io/ahmetozer/openvpn-container server-generate
docker run -i --rm --privileged -v/data/vpn:/server --network host ghcr.io/ahmetozer/openvpn-container server
```

- If you have single IPv6 and you don't want to enable IPv6 support in docker, just run in host network and system make a NAT66

```bash
docker run -i --rm --privileged -v/data/vpn:/server --network host ghcr.io/ahmetozer/openvpn-container server-generate
docker run -i --rm --privileged -v/data/vpn:/server --network host ghcr.io/ahmetozer/openvpn-container server
```
