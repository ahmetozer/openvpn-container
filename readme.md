# OpenVPN for Container

Run OpenVPN service on docker container. You can deploy own VPN service under 60 seconds.
Just single container with create certificates and run server and client modes.

## Available Modes

- **server-generate**: Create OpenVPN server configuration files.  
Generated configuration files are stored under `/etc/openvpn/server/` directory.  
Also server generate single config file on `/etc/openvpn/server/oneconfig/server.conf` .  
You can generate `oneserverconfig` file to move server configuration to other server or easily deploy with less store.
- **server**: Run OpenVPN server.  
System will be prepeare firewall and other settings for you.
- **client-generate**: Create configuration and certificates for clients on server.  
**Note**: Client certiface generation requires all files under `/etc/openvpn/server/`.
- **client**: Client mode. Connect to your OpenVPN server.

## Environment Variables

All environment variables has a default define. Some variables (like IPv4 and IPv6 address) is cannot be pre defined in script. Script has a function to determine your IPv4 only, IPv6 only or DualStack (IPv4 and IPv6) connection address.
If you want to change default environment variables, you can just define in your system.

```bash
docker run -it -e ip_block="192.168.3.0/24" ahmetozer/openvpn
```

Environment variables with predefined default values which is used in this system.

```bash
## !  entrypoint ; Used for more than one functions
mode=""             # Function try to determine your mode. Looks client certificate and server conf.
fast_install=""     # No user input, everything is read from environment variable

## ! Client
client_config="/etc/openvpn/client/client1.ovpn" # Client configuration file location.
# If you just give a file name like client_config="example.ovpn" system looks /etc/openvpn/client/example.ovpn
# If you give only directory name client_config="/myvpns/" system looks ovpn and conf files and select only first result.

## !   Used for server-generate - server and client
ip_block=10.0.1.0/24                            #   Address block for IPv4 to clients
ip6_block=fdac:900d:c0ff:ee::/64                #   Address block for IPv6 to clients
ip_nat=yes                                      #   Nat on client`s IPv4 addresses
ip6_nat=yes                                     #   Nat on client`s IPv6 addresses
server_ip="2001:db8:900d:c0de::2 203.0.113.2"   #   Clients are use for remote addr Detected by auto
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
Files are stored under `/etc/openvpn` by default.

If you run in terminal mode, the program ask about configurations then generate server configuration files.

### Server Configuration Generate

```bash
docker run -it --rm -v/data/vpn:/etc/openvpn -e mode="server-generate" -p 443 --privileged ahmetozer/openvpn
```

Also you can define environment variables in docker run and bypass questions with enabling fast mode.
Non defined variables are use default configurations which are shown in begin of this document.
If you run in not terminal mode, program set `fast_install=true` by default.

```bash
docker run -it --rm -v/data/vpn:/etc/openvpn -e mode="server-generate" -e port=53 -e protocol=udp -p 53/udp -e fast_install=true --privileged ahmetozer/openvpn
#or
docker run -i --rm -v/data/vpn:/etc/openvpn -e mode="server-generate" -e port=53 -e protocol=udp --privileged ahmetozer/openvpn
```

You can run container without defining mode, system firstly create server configuration files then create first client configuration and finally start the openvpn server.

```bash
docker run -it --rm -v/data/vpn:/etc/openvpn -e port=70 -e protocol=tcp -p 70:70 --privileged ahmetozer/openvpn
```

### Client Certificate Generation

You have to require all files in /etc/openvpn/server which is created while generating server configuration files.
The output in your server will be on /data/vpn/servers/clients/$client.ovpn

```bash
docker run -it --rm -v/data/vpn:/etc/openvpn -e mode="client-generate" ahmetozer/openvpn
```

You can also set client name without reading from terminal

```bash
docker run -i --rm -v/data/vpn:/etc/openvpn -e mode="client-generate" -e client=john  ahmetozer/openvpn
```

### Server mode

**NOTE**: "--privileged" argument is required for managing VPN interface and firewall rules.

```bash
docker run -i --rm --privileged -v/data/vpn:/etc/openvpn -e mode="server" ahmetozer/openvpn
#or
docker run -i --rm --privileged -v/data/vpn:/etc/openvpn -e ahmetozer/openvpn server
```

### Client

**NOTE**: "--privileged" argument is required for managing VPN interface and firewall rules.

```bash
docker run -i --rm --privileged -v/data/vpn:/etc/openvpn -e mode="client" ahmetozer/openvpn
#or
docker run -i --rm --privileged -v/data/vpn:/etc/openvpn -e ahmetozer/openvpn client
```

## Example Deployments

- For beginners, Create server, generate first client config and run openvpn server.  
Your client configuration file is under /data/vpn/server/clients/client1.ovpn

```bash
docker run -it --rm --privileged -v/data/vpn:/etc/openvpn ahmetozer/openvpn
```

- Create server, generate first client config and run openvpn server without asking any user input.

```bash
docker run -i  --rm --privileged -v/data/vpn:/etc/openvpn ahmetozer/openvpn
```

- Generate new client configuration file, system automatically recommend a new client name and you can also write own name.

```bash
docker run -it --rm --privileged -v/data/vpn:/etc/openvpn ahmetozer/openvpn client-generate
```

- Fastly create client configuration without asking any input.

```bash
docker run -i --rm --privileged -v /data/vpn:/etc/openvpn ahmetozer/openvpn client-generate
#or
docker run -i --rm --privileged -e client="john" -e mode="client-generate" -v/data/vpn:/etc/openvpn ahmetozer/openvpn
```

- Run OpenVPN server

```bash
docker run -i --rm --privileged -v/data/vpn:/etc/openvpn ahmetozer/openvpn server
```

- Give native IPv6 access to Clients Without NAT66
If your server has a IPv6 connectivity you can run OpenVPN in host network with nddpd

```bash
#If your IPv6 block is not routed, server as neighbor discovery, you have to reply neighbor discovery questions generated from router. Mostly required on all VPS providers
docker run -it --restart always --cap-add NET_ADMIN --cap-add NET_RAW --network host ahmetozer/ndppd
# Generate OpenVPN server configuration with dedicated IPV6 addr. Replace 2001:900d:c0ff:ee:1 with your range
docker run -i --rm --privileged -v/data/vpn:/etc/openvpn --network host -e ip6_block="2001:900d:c0ff:ee:1::/80" -e ip6_nat=no ahmetozer/openvpn server-generate
docker run -i --rm --privileged -v/data/vpn:/etc/openvpn --network host ahmetozer/openvpn server
```

- If you have single IPv6 and you don't want to enable IPv6 support in docker, just run in host network and system make a NAT66

```bash
docker run -i --rm --privileged -v/data/vpn:/etc/openvpn --network host ahmetozer/openvpn server-generate
docker run -i --rm --privileged -v/data/vpn:/etc/openvpn --network host ahmetozer/openvpn server
```
