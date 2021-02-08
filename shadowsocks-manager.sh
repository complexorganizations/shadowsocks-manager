#!/bin/bash
# https://github.com/complexorganizations/shadowsocks-manager

# Require script to be run as root
function super-user-check() {
  if [ "$EUID" -ne 0 ]; then
    echo "You need to run this script as super user."
    exit
  fi
}

# Check for root
super-user-check

# Detect Operating System
function dist-check() {
  if [ -e /etc/os-release ]; then
    # shellcheck disable=SC1091
    source /etc/os-release
    DISTRO=$ID
  fi
}

# Check Operating System
dist-check

# Pre-Checks system requirements
function installing-system-requirements() {
  if { [ "$DISTRO" == "ubuntu" ] || [ "$DISTRO" == "debian" ] || [ "$DISTRO" == "raspbian" ] || [ "$DISTRO" == "pop" ] || [ "$DISTRO" == "kali" ] || [ "$DISTRO" == "linuxmint" ] || [ "$DISTRO" == "fedora" ] || [ "$DISTRO" == "centos" ] || [ "$DISTRO" == "rhel" ] || [ "$DISTRO" == "arch" ] || [ "$DISTRO" == "manjaro" ] || [ "$DISTRO" == "alpine" ] || [ "$DISTRO" == "freebsd" ]; }; then
    if { [ ! -x "$(command -v curl)" ] || [ ! -x "$(command -v iptables)" ] || [ ! -x "$(command -v bc)" ] || [ ! -x "$(command -v jq)" ] || [ ! -x "$(command -v sed)" ] || [ ! -x "$(command -v zip)" ] || [ ! -x "$(command -v unzip)" ] || [ ! -x "$(command -v grep)" ] || [ ! -x "$(command -v awk)" ] || [ ! -x "$(command -v ip)" ]; }; then
      if { [ "$DISTRO" == "ubuntu" ] || [ "$DISTRO" == "debian" ] || [ "$DISTRO" == "raspbian" ] || [ "$DISTRO" == "pop" ] || [ "$DISTRO" == "kali" ] || [ "$DISTRO" == "linuxmint" ]; }; then
        apt-get update && apt-get install iptables curl coreutils bc jq sed e2fsprogs zip unzip grep gawk iproute2 hostname systemd -y
      elif { [ "$DISTRO" == "fedora" ] || [ "$DISTRO" == "centos" ] || [ "$DISTRO" == "rhel" ]; }; then
        yum update -y && yum install epel-release iptables curl coreutils bc jq sed e2fsprogs zip unzip grep gawk iproute2 hostname systemd -y
      elif { [ "$DISTRO" == "arch" ] || [ "$DISTRO" == "manjaro" ]; }; then
        pacman -Syu --noconfirm iptables curl bc jq sed zip unzip grep gawk iproute2 hostname systemd
      elif [ "$DISTRO" == "alpine" ]; then
        apk update && apk add iptables curl bc jq sed zip unzip grep gawk iproute2 hostname systemd
      elif [ "$DISTRO" == "freebsd" ]; then
        pkg update && pkg install curl jq zip unzip gawk
      fi
    fi
  else
    echo "Error: $DISTRO not supported."
    exit
  fi
}

# Run the function and check for requirements
installing-system-requirements


function usage-guide() {
    echo "usage: ./$(basename "$0") <command>"
    echo "  --install     Install shadowsocks Server"
    echo "  --start       Start shadowsocks Server"
    echo "  --stop        Stop shadowsocks Server"
    echo "  --restart     Restart shadowsocks Server"
    echo "  --reinstall   Reinstall shadowsocks Server"
    echo "  --uninstall   Uninstall shadowsocks Server"
    echo "  --update      Update shadowsocks Script"
    echo "  --help        Show Usage Guide"
    exit
}

function usage() {
    while [ $# -ne 0 ]; do
        case "${1}" in
        --install)
            shift
            HEADLESS_INSTALL=${HEADLESS_INSTALL:-y}
            ;;
        --start)
            shift
            SHADOWSOCKS_OPTIONS=${SHADOWSOCKS_OPTIONS:-1}
            ;;
        --stop)
            shift
            SHADOWSOCKS_OPTIONS=${SHADOWSOCKS_OPTIONS:-2}
            ;;
        --restart)
            shift
            SHADOWSOCKS_OPTIONS=${SHADOWSOCKS_OPTIONS:-3}
            ;;
        --reinstall)
            shift
            SHADOWSOCKS_OPTIONS=${SHADOWSOCKS_OPTIONS:-5}
            ;;
        --uninstall)
            shift
            SHADOWSOCKS_OPTIONS=${SHADOWSOCKS_OPTIONS:-4}
            ;;
        --update)
            shift
            SHADOWSOCKS_OPTIONS=${SHADOWSOCKS_OPTIONS:-6}
            ;;
        --help)
            shift
            usage-guide
            ;;
        *)
            echo "Invalid argument: $1"
            usage-guide
            exit
            ;;
        esac
        shift
    done
}

usage "$@"

# Skips all questions and just get a client conf after install.
function headless-install() {
    if [ "$HEADLESS_INSTALL" == "y" ]; then
        PORT_CHOICE_SETTINGS=${IPV4_SUBNET_SETTINGS:-1}
        PASSWORD_CHOICE_SETTINGS=${IPV6_SUBNET_SETTINGS:-1}
        ENCRYPTION_CHOICE_SETTINGS=${ENCRYPTION_CHOICE_SETTINGS:-1}
        TIMEOUT_CHOICE_SETTINGS=${TIMEOUT_CHOICE_SETTINGS:-1}
        SERVER_HOST_V4_SETTINGS=${SERVER_HOST_V4_SETTINGS:-1}
        SERVER_HOST_V6_SETTINGS=${SERVER_HOST_V6_SETTINGS:-1}
        SERVER_HOST_SETTINGS=${SERVER_HOST_SETTINGS:-1}
        DISABLE_HOST_SETTINGS=${DISABLE_HOST_SETTINGS:-1}
        MODE_CHOICE_SETTINGS=${MODE_CHOICE_SETTINGS:-1}
        INSTALL_BBR=${INSTALL_BBR:-y}
    fi
}

# No GUI
headless-install

SHADOWSOCK_PATH="/var/snap/shadowsocks-libev"
SHADOWSOCK_CONFIG_PATH="$SHADOWSOCK_PATH/common/etc/shadowsocks-libev/config.json"
SHADOWSOCKS_IP_FORWARDING_PATH="/etc/sysctl.d/shadowsocks.conf"
SHADOWSOCKS_MANAGER_URL="https://raw.githubusercontent.com/complexorganizations/shadowsocks-manager/master/shadowsocks-server.sh"

if [ ! -f "$SHADOWSOCK_CONFIG_PATH" ]; then

    # Question 1: Determine host port
    function set-port() {
        echo "What port do you want Shadowsocks to listen to?"
        echo "   1) 80 (Recommended)"
        echo "   2) 443"
        echo "   3) Custom (Advanced)"
        until [[ "$PORT_CHOICE_SETTINGS" =~ ^[1-3]$ ]]; do
            read -rp "Port choice [1-3]: " -e -i 1 PORT_CHOICE_SETTINGS
        done

        # Apply port response
        case $PORT_CHOICE_SETTINGS in
        1)
            SERVER_PORT="80"
            ;;
        2)
            SERVER_PORT="443"
            ;;
        3)
            until [[ "$SERVER_PORT" =~ ^[0-9]+$ ]] && [ "$SERVER_PORT" -ge 1 ] && [ "$SERVER_PORT" -le 65535 ]; do
                read -rp "Custom port [1-65535]: " -e -i 80 SERVER_PORT
            done
            ;;
        esac
    }

    # Set the port number
    set-port

    # Determine password
    function shadowsocks-password() {
        echo "Choose your password"
        echo "   1) Random (Recommended)"
        echo "   2) Custom (Advanced)"
        until [[ "$PASSWORD_CHOICE_SETTINGS" =~ ^[1-2]$ ]]; do
            read -rp "Password choice [1-2]: " -e -i 1 PASSWORD_CHOICE_SETTINGS
        done
        case $PASSWORD_CHOICE_SETTINGS in
        1)
            PASSWORD_CHOICE="$(openssl rand -base64 25)"
            ;;
        2)
            PASSWORD_CHOICE="read -rp "Password " -e PASSWORD_CHOICE"
            ;;
        esac
    }

    # Password
    shadowsocks-password

    # Determine Encryption
    function shadowsocks-encryption() {
        echo "Choose your Encryption"
        echo "   1) aes-256-gcm (Recommended)"
        echo "   2) aes-128-gcm"
        echo "   3) chacha20-ietf-poly1305"
        until [[ "$ENCRYPTION_CHOICE_SETTINGS" =~ ^[1-3]$ ]]; do
            read -rp "Encryption choice [1-3]: " -e -i 1 ENCRYPTION_CHOICE_SETTINGS
        done
        case $ENCRYPTION_CHOICE_SETTINGS in
        1)
            ENCRYPTION_CHOICE="aes-256-gcm"
            ;;
        2)
            ENCRYPTION_CHOICE="aes-128-gcm"
            ;;
        3)
            ENCRYPTION_CHOICE="chacha20-ietf-poly1305"
            ;;
        esac
    }

    # encryption
    shadowsocks-encryption

    # Determine Encryption
    function shadowsocks-timeout() {
        echo "Choose your timeout"
        echo "   1) 60 (Recommended)"
        echo "   2) 180"
        echo "   3) Custom (Advanced)"
        until [[ "$TIMEOUT_CHOICE_SETTINGS" =~ ^[1-3]$ ]]; do
            read -rp "Timeout choice [1-3]: " -e -i 1 TIMEOUT_CHOICE_SETTINGS
        done
        case $TIMEOUT_CHOICE_SETTINGS in
        1)
            TIMEOUT_CHOICE="60"
            ;;
        2)
            TIMEOUT_CHOICE="180"
            ;;
        3)
            until [[ "$TIMEOUT_CHOICE" =~ ^[0-9]+$ ]] && [ "$TIMEOUT_CHOICE" -ge 1 ] && [ "$TIMEOUT_CHOICE" -le 900 ]; do
                read -rp "Custom [1-900]: " -e -i 60 TIMEOUT_CHOICE
            done
            ;;
        esac
    }

    # timeout
    shadowsocks-timeout

    # Determine host port
    function test-connectivity-v4() {
        echo "How would you like to detect IPV4?"
        echo "  1) Curl (Recommended)"
        echo "  2) IP (Advanced)"
        echo "  3) Custom (Advanced)"
        until [[ "$SERVER_HOST_V4_SETTINGS" =~ ^[1-3]$ ]]; do
            read -rp "ipv4 choice [1-3]: " -e -i 1 SERVER_HOST_V4_SETTINGS
        done
        case $SERVER_HOST_V4_SETTINGS in
        1)
            SERVER_HOST_V4="$(curl -4 -s 'https://api.ipengine.dev' | jq -r '.network.ip')"
            ;;
        2)
            SERVER_HOST_V4=$(ip addr | grep 'inet' | grep -v inet6 | grep -vE '127\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}' | grep -oE '[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}' | head -1)
            ;;
        3)
            read -rp "Custom IPV4: " -e -i "$(curl -4 -s 'https://api.ipengine.dev' | jq -r '.network.ip')" SERVER_HOST_V4
            ;;
        esac
    }

    # Set Port
    test-connectivity-v4

    # Determine ipv6
    function test-connectivity-v6() {
        echo "How would you like to detect IPV6?"
        echo "  1) Curl (Recommended)"
        echo "  2) IP (Advanced)"
        echo "  3) Custom (Advanced)"
        until [[ "$SERVER_HOST_V6_SETTINGS" =~ ^[1-3]$ ]]; do
            read -rp "ipv6 choice [1-3]: " -e -i 1 SERVER_HOST_V6_SETTINGS
        done
        # Apply port response
        case $SERVER_HOST_V6_SETTINGS in
        1)
            SERVER_HOST_V6="$(curl -6 -s 'https://api.ipengine.dev' | jq -r '.network.ip')"
            ;;
        2)
            SERVER_HOST_V6=$(ip r get to 2001:4860:4860::8888 | perl -ne '/src ([\w:]+)/ && print "$1\n"')
            ;;
        3)
            read -rp "Custom IPV6: " -e -i "$(curl -6 -s 'https://api.ipengine.dev' | jq -r '.network.ip')" SERVER_HOST_V6
            ;;
        esac
    }

    # Set Port
    test-connectivity-v6

    # What ip version would you like to be available on this VPN?
    function ipvx-select() {
        echo "What IPv do you want to use to connect to ShadowSocks server?"
        echo "  1) IPv4 (Recommended)"
        echo "  2) IPv6"
        echo "  3) Custom (Advanced)"
        until [[ "$SERVER_HOST_SETTINGS" =~ ^[1-3]$ ]]; do
            read -rp "IP Choice [1-3]: " -e -i 1 SERVER_HOST_SETTINGS
        done
        case $SERVER_HOST_SETTINGS in
        1)
            SERVER_HOST="$SERVER_HOST_V4"
            ;;
        2)
            SERVER_HOST="[$SERVER_HOST_V6]"
            ;;
        3)
            read -rp "Custom Domain: " -e -i "$(curl -4 -s 'https://api.ipengine.dev' | jq -r '.network.hostname')" SERVER_HOST
            ;;
        esac
    }

    # IPv4 or IPv6 Selector
    ipvx-select

    # Do you want to disable IPv4 or IPv6 or leave them both enabled?
    function disable-ipvx() {
        echo "Do you want to disable IPv4 or IPv6 on the server?"
        echo "  1) No (Recommended)"
        echo "  2) Disable IPV4"
        echo "  3) Disable IPV6"
        until [[ "$DISABLE_HOST_SETTINGS" =~ ^[1-3]$ ]]; do
            read -rp "Disable Host Choice [1-3]: " -e -i 1 DISABLE_HOST_SETTINGS
        done
        case $DISABLE_HOST_SETTINGS in
        1)
                echo "net.ipv4.ip_forward=1" >>SHADOWSOCKS_IP_FORWARDING_PATH
                echo "net.ipv6.conf.all.forwarding=1" >>SHADOWSOCKS_IP_FORWARDING_PATH
                sysctl -p
            ;;
        2)
                echo "net.ipv6.conf.all.forwarding=1" >>SHADOWSOCKS_IP_FORWARDING_PATH
                sysctl -p
            ;;
        3)
                echo "net.ipv4.ip_forward=1" >>SHADOWSOCKS_IP_FORWARDING_PATH
                sysctl -p
            ;;
        esac
    }

    # Disable Ipv4 or Ipv6
    disable-ipvx

    # Determine TCP or UDP
    function shadowsocks-mode() {
        echo "Choose your method (UDP|TCP)"
        echo "   1) (TCP|UDP) (Recommended)"
        echo "   2) TCP"
        echo "   3) UDP"
        until [[ "$MODE_CHOICE_SETTINGS" =~ ^[1-3]$ ]]; do
            read -rp "Mode choice [1-3]: " -e -i 1 MODE_CHOICE_SETTINGS
        done

        # Apply port response
        case $MODE_CHOICE_SETTINGS in
        1)
            MODE_CHOICE="tcp_and_udp"
            ;;
        2)
            MODE_CHOICE="tcp"
            ;;
        3)
            MODE_CHOICE="udp"
            ;;
        esac
    }

    # Mode
    shadowsocks-mode

    function sysctl-install() {
        # Ammend configuration specifics for sysctl.conf
        echo \
        'fs.file-max = 51200
net.core.rmem_max = 67108864
net.core.wmem_max = 67108864
net.core.netdev_max_backlog = 250000
net.core.somaxconn = 4096
net.ipv4.tcp_syncookies = 1
net.ipv4.tcp_tw_reuse = 1
net.ipv4.tcp_fin_timeout = 30
net.ipv4.tcp_keepalive_time = 1200
net.ipv4.ip_local_port_range = 10000 65000
net.ipv4.tcp_max_syn_backlog = 8192
net.ipv4.tcp_max_tw_buckets = 5000
net.ipv4.tcp_fastopen = 3
net.ipv4.tcp_mem = 25600 51200 102400
net.ipv4.tcp_rmem = 4096 87380 67108864
net.ipv4.tcp_wmem = 4096 65536 67108864
net.ipv4.tcp_mtu_probing = 1
net.ipv4.tcp_congestion_control = hybla' \
        >>/etc/sysctl.d/shadowsocks.conf
        sysctl -p
    }

    function install-bbr() {
        if [ "$INSTALL_BBR" == "" ]; then
            read -rp "Do You Want To Install TCP bbr (y/n): " -e -i y INSTALL_BBR
        fi
        if [ "$INSTALL_BBR" = "y" ]; then
            # Run the systemctl install command
            sysctl-install
            # Check if tcp brr can be installed and if yes than install
            KERNEL_VERSION_LIMIT=4.1
            KERNEL_CURRENT_VERSION=$(uname -r | cut -c1-3)
            if (($(echo "$KERNEL_CURRENT_VERSION >= $KERNEL_VERSION_LIMIT" | bc -l))); then
                modprobe tcp_bbr
                echo "tcp_bbr" >>/etc/modules-load.d/modules.conf
                echo "net.core.default_qdisc=fq" >>/etc/sysctl.d/shadowsocks.conf
                echo "net.ipv4.tcp_congestion_control=bbr" >>/etc/sysctl.d/shadowsocks.conf
                sysctl -p
            else
                echo "Error: Please update your kernel to 4.1 or higher" >&2
            fi
        fi
    }

    # Install TCP BBR
    install-bbr

    # Install shadowsocks Server
    function install-shadowsocks-server() {
    if [ ! -x "$(command -v ss)" ]; then
        if { [ "$DISTRO" == "ubuntu" ] || [ "$DISTRO" == "debian" ] || [ "$DISTRO" == "raspbian" ] || [ "$DISTRO" == "pop" ] || [ "$DISTRO" == "kali" ] || [ "$DISTRO" == "linuxmint" ] || [ "$DISTRO" == "fedora" ] || [ "$DISTRO" == "centos" ] || [ "$DISTRO" == "rhel" ] || [ "$DISTRO" == "arch" ] || [ "$DISTRO" == "manjaro" ] || [ "$DISTRO" == "alpine" ] || [ "$DISTRO" == "freebsd" ]; }; then
            apt-get update
            apt-get install snapd haveged qrencode -y
            snap install core shadowsocks-libev
        elif { [ "$DISTRO" == "fedora" ] || [ "$DISTRO" == "centos" ] || [ "$DISTRO" == "rhel" ]; }; then
            dnf upgrade -y
            dnf install epel-release -y
            yum install snapd haveged -y
            snap install core shadowsocks-libev
        fi
    fi
    }

    # Install shadowsocks Server
    install-shadowsocks-server

    function v2ray-install() {
        CHECK_ARCHITECTURE=$(dpkg --print-architecture)
        FILE_NAME=$(v2ray-plugin-linux-"$CHECK_ARCHITECTURE"-v1.3.1.tar.gz)
        curl https://github.com/shadowsocks/v2ray-plugin/releases/download/v1.3.1/"$FILE_NAME" --create-dirs -o /etc/shadowsocks-libev/"$FILE_NAME"
        tar xvzf /etc/shadowsocks-libev/"$FILE_NAME"
        rm -f /etc/shadowsocks-libev/"$FILE_NAME"
    }

    function shadowsocks-configuration() {
        mkdir /var/snap/shadowsocks-libev/common/etc
        mkdir /var/snap/shadowsocks-libev/common/etc/shadowsocks-libev
        echo "{
  ""\"server""\":""\"$SERVER_HOST""\",
  ""\"mode""\":""\"$MODE_CHOICE""\",
  ""\"server_port""\":""\"$SERVER_PORT""\",
  ""\"password""\":""\"$PASSWORD_CHOICE""\",
  ""\"timeout""\":""\"$TIMEOUT_CHOICE""\",
  ""\"method""\":""\"$ENCRYPTION_CHOICE""\"
  }" >>/var/snap/shadowsocks-libev/common/etc/shadowsocks-libev/config.json
        if pgrep systemd-journal; then
            snap run shadowsocks-libev.ss-server &
        else
            snap run shadowsocks-libev.ss-server &
        fi
    }

    # Shadowsocks Config
    shadowsocks-configuration

    function show-config() {
        qrencode -t ansiutf8 -l L </var/snap/shadowsocks-libev/common/etc/shadowsocks-libev/config.json
        echo "Config File ---> /var/snap/shadowsocks-libev/common/etc/shadowsocks-libev/config.json"
        echo "Shadowsocks Server IP: $SERVER_HOST"
        echo "Shadowsocks Server Port: $SERVER_PORT"
        echo "Shadowsocks Server Password: $PASSWORD_CHOICE"
        echo "Shadowsocks Server Encryption: $ENCRYPTION_CHOICE"
        echo "Shadowsocks Server Mode: $MODE_CHOICE"
    }

    # Show the config
    show-config

# After Shadowsocks Install
else

    # Already installed what next?
    function shadowsocks-next-questions() {
        echo "What do you want to do?"
        echo "   1) Start ShadowSocks"
        echo "   2) Stop ShadowSocks"
        echo "   3) Restart ShadowSocks"
        echo "   4) Uninstall ShadowSocks"
        echo "   5) Reinstall ShadowSocks"
        echo "   6) Update this script"
        until [[ "$SHADOWSOCKS_OPTIONS" =~ ^[1-6]$ ]]; do
            read -rp "Select an Option [1-6]: " -e -i 1 SHADOWSOCKS_OPTIONS
        done
        case $SHADOWSOCKS_OPTIONS in
        1)
            snap run shadowsocks-libev.ss-server &
            ;;
        2)
            snap stop shadowsocks-libev.ss-server &
            ;;
        3)
            snap restart shadowsocks-libev.ss-server &
            ;;
        4)
            snap stop shadowsocks-libev.ss-server &
            if { [ "$DISTRO" == "ubuntu" ] || [ "$DISTRO" == "debian" ] || [ "$DISTRO" == "raspbian" ] || [ "$DISTRO" == "pop" ] || [ "$DISTRO" == "kali" ] || [ "$DISTRO" == "linuxmint" ] || [ "$DISTRO" == "fedora" ] || [ "$DISTRO" == "centos" ] || [ "$DISTRO" == "rhel" ] || [ "$DISTRO" == "arch" ] || [ "$DISTRO" == "manjaro" ] || [ "$DISTRO" == "alpine" ] || [ "$DISTRO" == "freebsd" ]; }; then
                snap remove --purge shadowsocks-libev -y
                apt-get remove --purge snapd haveged -y
            elif [ "$DISTRO" == "centos" ]; then
                snap remove --purge shadowsocks-libev -y
                yum remove snapd -y
            elif [ "$DISTRO" == "fedora" ]; then
                snap remove --purge shadowsocks-libev -y
                yum remove snapd -y
            elif [ "$DISTRO" == "rhel" ]; then
                snap remove --purge shadowsocks-libev -y
                yum remove snapd -y
            fi
            rm -rf $SHADOWSOCK_PATH
            rm -f $SHADOWSOCK_CONFIG_PATH
            sed -i 's/\* soft nofile 51200//d' /etc/security/limits.conf
            sed -i 's/\* hard nofile 51200//d' /etc/security/limits.conf
            sed -i 's/\tcp_bbr//d' /etc/modules-load.d/modules.conf
            rm -f /etc/sysctl.d/shadowsocks.conf
            ;;
        5)
            if pgrep systemd-journal; then
                dpkg-reconfigure shadowsocks-libev
                modprobe shadowsocks-libev
                systemctl restart shadowsocks-libev
            else
                dpkg-reconfigure shadowsocks-libev
                modprobe shadowsocks-libev
                service shadowsocks-libev restart
            fi
            ;;
        6) # Update the script
        CURRENT_FILE_PATH="$(realpath "$0")"
        if [ -f "$CURRENT_FILE_PATH" ]; then
            curl -o "$CURRENT_FILE_PATH" $SHADOWSOCKS_MANAGER_URL
            chmod +x "$CURRENT_FILE_PATH" || exit
        fi
            ;;
        esac
    }

    # Running Questions Command
    shadowsocks-next-questions

fi
