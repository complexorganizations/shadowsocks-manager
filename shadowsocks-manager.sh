#!/bin/bash
# https://github.com/complexorganizations/shadowsocks-manager

# Require script to be run as root
function super-user-check() {
    if [ "${EUID}" -ne 0 ]; then
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
        DISTRO=${ID}
    fi
}

# Check Operating System
dist-check

# Pre-Checks system requirements
function installing-system-requirements() {
    if { [ "${DISTRO}" == "ubuntu" ] || [ "${DISTRO}" == "debian" ] || [ "${DISTRO}" == "raspbian" ] || [ "${DISTRO}" == "pop" ] || [ "${DISTRO}" == "kali" ] || [ "${DISTRO}" == "linuxmint" ] || [ "${DISTRO}" == "fedora" ] || [ "${DISTRO}" == "centos" ] || [ "${DISTRO}" == "rhel" ]; }; then
        if { [ ! -x "$(command -v curl)" ] || [ ! -x "$(command -v bc)" ] || [ ! -x "$(command -v jq)" ] || [ ! -x "$(command -v sed)" ] || [ ! -x "$(command -v zip)" ] || [ ! -x "$(command -v unzip)" ] || [ ! -x "$(command -v grep)" ] || [ ! -x "$(command -v awk)" ] || [ ! -x "$(command -v ip)" ]; }; then
            if { [ "${DISTRO}" == "ubuntu" ] || [ "${DISTRO}" == "debian" ] || [ "${DISTRO}" == "raspbian" ] || [ "${DISTRO}" == "pop" ] || [ "${DISTRO}" == "kali" ] || [ "${DISTRO}" == "linuxmint" ]; }; then
                apt-get update && apt-get install iptables curl coreutils bc jq sed e2fsprogs zip unzip grep gawk iproute2 hostname systemd -y
            elif { [ "${DISTRO}" == "fedora" ] || [ "${DISTRO}" == "centos" ] || [ "${DISTRO}" == "rhel" ]; }; then
                yum update -y && yum install epel-release iptables curl coreutils bc jq sed e2fsprogs zip unzip grep gawk iproute2 hostname systemd -y
            fi
        fi
    else
        echo "Error: ${DISTRO} not supported."
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
        --show-config)
            shift
            SHADOWSOCKS_OPTIONS=${SHADOWSOCKS_OPTIONS:-4}
            ;;
        --reinstall)
            shift
            SHADOWSOCKS_OPTIONS=${SHADOWSOCKS_OPTIONS:6}
            ;;
        --uninstall)
            shift
            SHADOWSOCKS_OPTIONS=${SHADOWSOCKS_OPTIONS:-5}
            ;;
        --update)
            shift
            SHADOWSOCKS_OPTIONS=${SHADOWSOCKS_OPTIONS:-7}
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
    if [ "${HEADLESS_INSTALL}" == "y" ]; then
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

SHADOWSOCKS_PATH="/var/snap/shadowsocks-libev"
SHADOWSOCKS_COMMON_PATH="${SHADOWSOCKS_PATH}/common/etc/shadowsocks-libev"
SHADOWSOCKS_CONFIG_PATH="${SHADOWSOCKS_COMMON_PATH}/config.json"
SHADOWSOCKS_SERVICE_PATH="/etc/systemd/system/shadowsocks-libev.service"
SHADOWSOCKS_IP_FORWARDING_PATH="/etc/sysctl.d/shadowsocks-libev.conf"
SHADOWSOCKS_BIN_PATH="/usr/bin/shadowsocks-libev.ss-server"
SHADOWSOCKS_MANAGER_URL="https://raw.githubusercontent.com/complexorganizations/shadowsocks-manager/main/shadowsocks-manager.sh"
CHECK_ARCHITECTURE="$(dpkg --print-architecture)"
if { [ "${CHECK_ARCHITECTURE}" == "arm" ] || [ "${CHECK_ARCHITECTURE}" == "arm64" ] || [ "${CHECK_ARCHITECTURE}" == "armhf" ]; }; then
    CHECK_ARCHITECTURE="arm"
fi
V2RAY_DOWNLOAD="https://github.com/shadowsocks/v2ray-plugin/releases/download/v1.3.1/v2ray-plugin-linux-${CHECK_ARCHITECTURE}-v1.3.1.tar.gz"
V2RAY_PLUGIN_PATH_ZIPPED="${SHADOWSOCKS_COMMON_PATH}/v2ray-plugin-linux-${CHECK_ARCHITECTURE}-v1.3.1.tar.gz"
V2RAY_PLUGIN_PATH="${SHADOWSOCKS_COMMON_PATH}/v2ray-plugin"
LETS_ENCRYPT_CERT_PATH="/etc/letsencrypt/live/${DOMAIN_NAME}/fullchain.pem"
SHADOWSOCKS_LETS_ENCRYPT_CERT_PATH="${SHADOWSOCKS_COMMON_PATH}/fullchain.pem"
LETS_ENCRYPT_KEY_PATH="/etc/letsencrypt/live/${DOMAIN_NAME}/privkey.pem"
SHADOWSOCKS_LETS_ENCRYPT_KEY_PATH="${SHADOWSOCKS_COMMON_PATH}/privkey.pem"
SERVER_INPUT_IP="0.0.0.0"
SHADOWSOCKS_BACKUP_PATH="/var/backups/shadowsocks-manager.zip"

if [ ! -f "${SHADOWSOCKS_CONFIG_PATH}" ]; then

    # Question 1: Determine host port
    function set-port() {
        echo "What port do you want Shadowsocks to listen to?"
        echo "   1) 80 (Recommended)"
        echo "   2) 443"
        until [[ "${PORT_CHOICE_SETTINGS}" =~ ^[1-2]$ ]]; do
            read -rp "Port choice [1-2]: " -e -i 1 PORT_CHOICE_SETTINGS
        done
        case ${PORT_CHOICE_SETTINGS} in
        1)
            SERVER_PORT="80"
            ;;
        2)
            SERVER_PORT="443"
            ;;
        esac
    }

    # Set the port number
    set-port

    # Determine password
    function shadowsocks-password() {
        echo "Choose your password"
        echo "   1) Random (Recommended)"
        until [[ "${PASSWORD_CHOICE_SETTINGS}" =~ ^[1-1]$ ]]; do
            read -rp "Password choice [1-1]: " -e -i 1 PASSWORD_CHOICE_SETTINGS
        done
        case ${PASSWORD_CHOICE_SETTINGS} in
        1)
            PASSWORD_CHOICE="$(openssl rand -base64 25)"
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
        until [[ "${ENCRYPTION_CHOICE_SETTINGS}" =~ ^[1-3]$ ]]; do
            read -rp "Encryption choice [1-3]: " -e -i 1 ENCRYPTION_CHOICE_SETTINGS
        done
        case ${ENCRYPTION_CHOICE_SETTINGS} in
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

    # Determine host port
    function test-connectivity-v4() {
        echo "How would you like to detect IPV4?"
        echo "  1) Curl (Recommended)"
        echo "  2) IP (Advanced)"
        echo "  3) Custom (Advanced)"
        until [[ "${SERVER_HOST_V4_SETTINGS}" =~ ^[1-3]$ ]]; do
            read -rp "ipv4 choice [1-3]: " -e -i 1 SERVER_HOST_V4_SETTINGS
        done
        case ${SERVER_HOST_V4_SETTINGS} in
        1)
            SERVER_HOST_V4="$(curl -4 -s 'https://api.ipengine.dev' | jq -r '.network.ip')"
            ;;
        2)
            SERVER_HOST_V4="$(ip route get 8.8.8.8 | grep src | sed 's/.*src \(.* \)/\1/g' | cut -f1 -d ' ')"
            ;;
        3)
            read -rp "Custom IPV4: " -e -i "$(curl -4 -s 'https://api.ipengine.dev' | jq -r '.network.ip')" SERVER_HOST_V4
            if [ -z "${SERVER_HOST_V4}" ]; then
                SERVER_HOST_V4="$(curl -4 -s 'https://api.ipengine.dev' | jq -r '.network.ip')"
            fi
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
        until [[ "${SERVER_HOST_V6_SETTINGS}" =~ ^[1-3]$ ]]; do
            read -rp "ipv6 choice [1-3]: " -e -i 1 SERVER_HOST_V6_SETTINGS
        done
        case ${SERVER_HOST_V6_SETTINGS} in
        1)
            SERVER_HOST_V6="$(curl -6 -s 'https://api.ipengine.dev' | jq -r '.network.ip')"
            ;;
        2)
            SERVER_HOST_V6="$(ip -6 addr | sed -ne 's|^.* inet6 \([^/]*\)/.* scope global.*$|\1|p' | head -1)"
            ;;
        3)
            read -rp "Custom IPV6: " -e -i "$(curl -6 -s 'https://api.ipengine.dev' | jq -r '.network.ip')" SERVER_HOST_V6
            if [ -z "${SERVER_HOST_V6}" ]; then
                SERVER_HOST_V6="$(curl -6 -s 'https://api.ipengine.dev' | jq -r '.network.ip')"
            fi
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
            if [ -n "${SERVER_HOST_V4}" ]; then
                SERVER_HOST="${SERVER_HOST_V4}"
            else
                SERVER_HOST="[${SERVER_HOST_V6}]"
            fi
            ;;
        2)
            if [ -n "${SERVER_HOST_V6}" ]; then
                SERVER_HOST="[${SERVER_HOST_V6}]"
            else
                SERVER_HOST="${SERVER_HOST_V4}"
            fi
            ;;
        3)
            read -rp "Custom Domain: " -e -i "$(curl -4 -s 'https://api.ipengine.dev' | jq -r '.network.hostname')" SERVER_HOST
            if [ -z "${SERVER_HOST}" ]; then
                SERVER_HOST="$(curl -4 -s 'https://api.ipengine.dev' | jq -r '.network.ip')"
            fi
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
        until [[ "${DISABLE_HOST_SETTINGS}" =~ ^[1-3]$ ]]; do
            read -rp "Disable Host Choice [1-3]: " -e -i 1 DISABLE_HOST_SETTINGS
        done
        case ${DISABLE_HOST_SETTINGS} in
        1)
            if [ -f "${SHADOWSOCKS_IP_FORWARDING_PATH}" ]; then
                rm -f ${SHADOWSOCKS_IP_FORWARDING_PATH}
            fi
            if [ ! -f "${SHADOWSOCKS_IP_FORWARDING_PATH}" ]; then
                echo "net.ipv4.ip_forward=1" >>${SHADOWSOCKS_IP_FORWARDING_PATH}
                echo "net.ipv6.conf.all.forwarding=1" >>${SHADOWSOCKS_IP_FORWARDING_PATH}
                sysctl -p ${SHADOWSOCKS_IP_FORWARDING_PATH}
            fi
            ;;
        2)
            if [ -f "${SHADOWSOCKS_IP_FORWARDING_PATH}" ]; then
                rm -f ${SHADOWSOCKS_IP_FORWARDING_PATH}
            fi
            if [ ! -f "${SHADOWSOCKS_IP_FORWARDING_PATH}" ]; then
                echo "net.ipv6.conf.all.forwarding=1" >>${SHADOWSOCKS_IP_FORWARDING_PATH}
                sysctl -p ${SHADOWSOCKS_IP_FORWARDING_PATH}
            fi
            ;;
        3)
            if [ -f "${SHADOWSOCKS_IP_FORWARDING_PATH}" ]; then
                rm -f ${SHADOWSOCKS_IP_FORWARDING_PATH}
            fi
            if [ ! -f "${SHADOWSOCKS_IP_FORWARDING_PATH}" ]; then
                echo "net.ipv4.ip_forward=1" >>${SHADOWSOCKS_IP_FORWARDING_PATH}
                sysctl -p ${SHADOWSOCKS_IP_FORWARDING_PATH}
            fi
            ;;
        esac
    }

    # Disable Ipv4 or Ipv6
    disable-ipvx

    # Determine TCP or UDP
    function shadowsocks-mode() {
        echo "Choose your method TCP"
        echo "   1) TCP (Recommended)"
        until [[ "${MODE_CHOICE_SETTINGS}" =~ ^[1-1]$ ]]; do
            read -rp "Mode choice [1-1]: " -e -i 1 MODE_CHOICE_SETTINGS
        done
        case ${MODE_CHOICE_SETTINGS} in
        1)
            MODE_CHOICE="tcp_only"
            ;;
        esac
    }

    # Mode
    shadowsocks-mode

    # Install shadowsocks Server
    function install-shadowsocks-server() {
        if { [ ! -x "$(command -v snap run shadowsocks-libev.ss-server)" ] || [ ! -x "$(command -v socat)" ] || [ ! -x "$(command -v snap)" ] || [ ! -x "$(command -v haveged)" ]; }; then
            if { [ "${DISTRO}" == "ubuntu" ] || [ "${DISTRO}" == "debian" ] || [ "${DISTRO}" == "raspbian" ] || [ "${DISTRO}" == "pop" ] || [ "${DISTRO}" == "kali" ] || [ "${DISTRO}" == "linuxmint" ]; }; then
                apt-get update
                apt-get install snapd haveged socat -y
                snap install core shadowsocks-libev
            elif { [ "${DISTRO}" == "fedora" ] || [ "${DISTRO}" == "centos" ] || [ "${DISTRO}" == "rhel" ]; }; then
                dnf upgrade -y
                dnf install epel-release -y
                yum install snapd haveged socat -y
                snap install core shadowsocks-libev
            fi
        fi
        if [ ! -f "${SHADOWSOCKS_BIN_PATH}" ]; then
            ln -s /snap/bin/shadowsocks-libev.ss-server ${SHADOWSOCKS_BIN_PATH}
        fi
    }

    # Install shadowsocks Server
    install-shadowsocks-server

    function v2ray-installer() {
        if { [ "${MODE_CHOICE}" == "tcp_only" ] && [ "${SERVER_PORT}" == "80" ] || [ "${SERVER_PORT}" == "443" ]; }; then
            if [ -f "${V2RAY_PLUGIN_PATH_ZIPPED}" ]; then
                rm -f "${V2RAY_PLUGIN_PATH_ZIPPED}"
            fi
            if [ ! -f "${V2RAY_PLUGIN_PATH_ZIPPED}" ]; then
                curl -L "${V2RAY_DOWNLOAD}" --create-dirs -o "${V2RAY_PLUGIN_PATH_ZIPPED}"
                tar xvzf "${V2RAY_PLUGIN_PATH_ZIPPED}" -C "${SHADOWSOCKS_COMMON_PATH}"
                rm -f "${V2RAY_PLUGIN_PATH_ZIPPED}"
                # find "${SHADOWSOCKS_COMMON_PATH}" -name "v2ray*" -exec mv {} ${SHADOWSOCKS_COMMON_PATH}/v2ray-plugin \;
            fi
            if { [ "${MODE_CHOICE}" == "tcp_only" ] && [ "${SERVER_PORT}" == "80" ]; }; then
                PLUGIN_OPTS="server"
            elif { [ "${MODE_CHOICE}" == "tcp_only" ] && [ "${SERVER_PORT}" == "443" ]; }; then
                read -rp "Custom Domain: " -e -i "example.com" DOMAIN_NAME
                if [ ! -x "$(command -v snap run certbot)" ]; then
                    snap install --classic certbot
                fi
                if [ -f "/snap/bin/certbot" ]; then
                    if [ ! -f "/usr/bin/certbot" ]; then
                        ln -s /snap/bin/certbot /usr/bin/certbot
                    fi
                fi
                if { [ ! -f "${LETS_ENCRYPT_CERT_PATH}" ] && [ ! -f "${LETS_ENCRYPT_KEY_PATH}" ]; }; then
                    certbot certonly --standalone -n -d "${DOMAIN_NAME}" --agree-tos --register-unsafely-without-email
                    sleep 15
                    certbot renew --dry-run
                fi
                if [ -f "${LETS_ENCRYPT_CERT_PATH}" ]; then
                    if [ ! -f "${SHADOWSOCKS_LETS_ENCRYPT_CERT_PATH}" ]; then
                        mv "${LETS_ENCRYPT_CERT_PATH}" ${SHADOWSOCKS_LETS_ENCRYPT_CERT_PATH}
                    fi
                fi
                if [ -f "${LETS_ENCRYPT_KEY_PATH}" ]; then
                    if [ ! -f "${SHADOWSOCKS_LETS_ENCRYPT_KEY_PATH}" ]; then
                        mv "${LETS_ENCRYPT_KEY_PATH}" ${SHADOWSOCKS_LETS_ENCRYPT_KEY_PATH}
                    fi
                fi
                PLUGIN_OPTS="server;tls;cert=${SHADOWSOCKS_LETS_ENCRYPT_CERT_PATH};key=${SHADOWSOCKS_LETS_ENCRYPT_KEY_PATH};host=${SERVER_HOST}"
            fi
        fi
    }

    v2ray-installer

    function shadowsocks-configuration() {
        if [ -f "${SHADOWSOCKS_CONFIG_PATH}" ]; then
            rm -f ${SHADOWSOCKS_CONFIG_PATH}
        fi
        if [ ! -f "${SHADOWSOCKS_CONFIG_PATH}" ]; then
            echo "{
  \"server\":\"${SERVER_INPUT_IP}\",
  \"mode\":\"${MODE_CHOICE}\",
  \"server_port\":\"${SERVER_PORT}\",
  \"password\":\"${PASSWORD_CHOICE}\",
  \"method\":\"${ENCRYPTION_CHOICE}\",
  \"plugin\":\"${V2RAY_PLUGIN_PATH}\",
  \"plugin_opts\":\"${PLUGIN_OPTS}\"
}" >>${SHADOWSOCKS_CONFIG_PATH}
        fi
        if pgrep systemd-journal; then
            systemctl enable snap.shadowsocks-libev.ss-server-daemon.service
            systemctl start snap.shadowsocks-libev.ss-server-daemon.service
        else
            service shadowsocks-libev snap.shadowsocks-libev.ss-server-daemon.service
            service shadowsocks-libev snap.shadowsocks-libev.ss-server-daemon.service
        fi
    }

    # Shadowsocks Config
    shadowsocks-configuration

    function show-config() {
        echo "Config File ---> ${SHADOWSOCKS_CONFIG_PATH}"
        if [ -n "${DOMAIN_NAME}" ]; then
            echo "Shadowsocks Server Domain: ${DOMAIN_NAME}"
        else
            echo "Shadowsocks Server IP: ${SERVER_HOST}"
        fi
        echo "Shadowsocks Server Port: ${SERVER_PORT}"
        echo "Shadowsocks Server Password: ${PASSWORD_CHOICE}"
        echo "Shadowsocks Server Encryption: ${ENCRYPTION_CHOICE}"
        echo "Shadowsocks Server Mode: ${MODE_CHOICE}"
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
        echo "   4) Show Config"
        echo "   5) Uninstall ShadowSocks"
        echo "   6) Update this script"
        echo "   7) Backup Config"
        echo "   8) Restore Config"
        until [[ "${SHADOWSOCKS_OPTIONS}" =~ ^[1-8]$ ]]; do
            read -rp "Select an Option [1-8]: " -e -i 1 SHADOWSOCKS_OPTIONS
        done
        case ${SHADOWSOCKS_OPTIONS} in
        1)
            if pgrep systemd-journal; then
                systemctl start snap.shadowsocks-libev.ss-server-daemon.service
            else
                service snap.shadowsocks-libev.ss-server-daemon.service start
            fi
            ;;
        2)
            if pgrep systemd-journal; then
                systemctl stop snap.shadowsocks-libev.ss-server-daemon.service
            else
                service snap.shadowsocks-libev.ss-server-daemon.service stop
            fi
            ;;
        3)
            if pgrep systemd-journal; then
                systemctl restart snap.shadowsocks-libev.ss-server-daemon.service
            else
                service snap.shadowsocks-libev.ss-server-daemon.service restart
            fi
            ;;
        4)
            cat ${SHADOWSOCKS_CONFIG_PATH}
            ;;
        5)
            if pgrep systemd-journal; then
                systemctl disable snap.shadowsocks-libev.ss-server-daemon.service
                systemctl stop snap.shadowsocks-libev.ss-server-daemon.service
            else
                service snap.shadowsocks-libev.ss-server-daemon.service disable
                service snap.shadowsocks-libev.ss-server-daemon.service stop
            fi
            if { [ "${DISTRO}" == "ubuntu" ] || [ "${DISTRO}" == "debian" ] || [ "${DISTRO}" == "raspbian" ] || [ "${DISTRO}" == "pop" ] || [ "${DISTRO}" == "kali" ] || [ "${DISTRO}" == "linuxmint" ]; }; then
                snap remove --purge shadowsocks-libev -y
                apt-get remove --purge snapd haveged -y
            elif [ "${DISTRO}" == "centos" ]; then
                snap remove --purge shadowsocks-libev -y
                yum remove snapd -y
            elif [ "${DISTRO}" == "fedora" ]; then
                snap remove --purge shadowsocks-libev -y
                yum remove snapd -y
            elif [ "${DISTRO}" == "rhel" ]; then
                snap remove --purge shadowsocks-libev -y
                yum remove snapd -y
            fi
            if [ -d "${SHADOWSOCKS_PATH}" ]; then
                rm -rf "${SHADOWSOCKS_PATH}"
            fi
            if [ -d "${SHADOWSOCKS_COMMON_PATH}" ]; then
                rm -rf "${SHADOWSOCKS_COMMON_PATH}"
            fi
            if [ -f "${SHADOWSOCKS_CONFIG_PATH}" ]; then
                rm -f "${SHADOWSOCKS_CONFIG_PATH}"
            fi
            if [ -f "${SHADOWSOCKS_IP_FORWARDING_PATH}" ]; then
                rm -f "${SHADOWSOCKS_IP_FORWARDING_PATH}"
            fi
            if [ -f "${V2RAY_PLUGIN_PATH_ZIPPED}" ]; then
                rm -f "${V2RAY_PLUGIN_PATH_ZIPPED}"
            fi
            if [ -f "${SHADOWSOCKS_LETS_ENCRYPT_CERT_PATH}" ]; then
                rm -f "${SHADOWSOCKS_LETS_ENCRYPT_CERT_PATH}"
            fi
            if [ -f "${SHADOWSOCKS_LETS_ENCRYPT_KEY_PATH}" ]; then
                rm -f "${SHADOWSOCKS_LETS_ENCRYPT_KEY_PATH}"
            fi
            if [ -f "${SHADOWSOCKS_BACKUP_PATH}" ]; then
                read -rp "Do you really want to remove ShadowSocks Backup? (y/n): " -n 1 -r
                if [[ $REPLY =~ ^[Yy]$ ]]; then
                    rm -f ${SHADOWSOCKS_BACKUP_PATH}
                elif [[ $REPLY =~ ^[Nn]$ ]]; then
                    exit
                fi
            fi
            ;;
        6) # Update the script
            CURRENT_FILE_PATH="$(realpath "$0")"
            if [ -f "${CURRENT_FILE_PATH}" ]; then
                curl -o "${CURRENT_FILE_PATH}" ${SHADOWSOCKS_MANAGER_URL}
                chmod +x "${CURRENT_FILE_PATH}" || exit
            fi
            ;;
        7)
            if [ -d "${SHADOWSOCKS_COMMON_PATH}" ]; then
                if [ -f "${SHADOWSOCKS_BACKUP_PATH}" ]; then
                    rm -f ${SHADOWSOCKS_BACKUP_PATH}
                fi
                if [ -f "${SHADOWSOCKS_CONFIG_PATH}" ]; then
                    zip -rej ${SHADOWSOCKS_BACKUP_PATH} ${SHADOWSOCKS_CONFIG_PATH} ${SHADOWSOCKS_SERVICE_PATH} ${SHADOWSOCKS_IP_FORWARDING_PATH} ${SHADOWSOCKS_BIN_PATH} ${SHADOWSOCKS_BIN_PATH} ${V2RAY_PLUGIN_PATH} ${SHADOWSOCKS_LETS_ENCRYPT_CERT_PATH} ${SHADOWSOCKS_LETS_ENCRYPT_KEY_PATH}
                else
                    exit
                fi
            fi
            ;;
        8)
            if [ -d "${SHADOWSOCKS_COMMON_PATH}" ]; then
                rm -rf ${SHADOWSOCKS_COMMON_PATH}
            fi
            if [ -f "${SHADOWSOCKS_CONFIG_PATH}" ]; then
                unzip ${SHADOWSOCKS_CONFIG_PATH} -d ${SHADOWSOCKS_COMMON_PATH}
            else
                exit
            fi
            if pgrep systemd-journal; then
                systemctl restart snap.shadowsocks-libev.ss-server-daemon.service
            else
                service snap.shadowsocks-libev.ss-server-daemon.service restart
            fi
            ;;
        esac
    }

    # Running Questions Command
    shadowsocks-next-questions

fi
