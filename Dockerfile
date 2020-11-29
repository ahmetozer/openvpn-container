FROM alpine:latest
WORKDIR /openvpn
COPY . /openvpn
RUN apk add bash wget openssl openvpn iptables ip6tables iproute2 &&\
mkdir -vp /etc/openvpn/server/easy-rsa/ && \
wget -qO- "https://github.com/OpenVPN/easy-rsa/releases/download/v3.0.8/EasyRSA-3.0.8.tgz" | tar xz -C /etc/openvpn/server/easy-rsa/ --strip-components 1 &&\
chown -R root:root /etc/openvpn/server/easy-rsa/ && \
chmod +x *.sh

CMD /openvpn/entrypoint.sh