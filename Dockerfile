FROM debian:11
LABEL maintainer="John Doe <johndoe@example.com>"
EXPOSE 80/udp
RUN apt-get update && \
    apt-get install curl -y && \
    curl https://raw.githubusercontent.com/complexorganizations/shadowsocks-manager/main/shadowsocks-manager.sh --create-dirs -o /usr/local/bin/shadowsocks-manager.sh && \
    chmod +x /usr/local/bin/shadowsocks-manager.sh && \
    /usr/local/bin/shadowsocks-manager.sh --install
