FROM alpine:latest
ENV PATH="/openvpn:${PATH}"
WORKDIR /openvpn
COPY . /openvpn
RUN apk add bash wget openssl openvpn iptables ip6tables iproute2 &&\
mkdir -vp /easy-rsa/ && \
wget -qO- "https://github.com/OpenVPN/easy-rsa/releases/download/v3.0.8/EasyRSA-3.0.8.tgz" | tar xz -C /easy-rsa/ --strip-components 1 &&\
chown -R root:root /easy-rsa/ && \
chmod +x *.sh

ENTRYPOINT ["/openvpn/entrypoint.sh"]