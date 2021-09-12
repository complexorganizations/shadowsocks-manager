#!/usr/bin/env bash
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

# Get the current system information
function system-information() {
    if [ -f /etc/os-release ]; then
        # shellcheck disable=SC1091
        source /etc/os-release
        DISTRO=${ID}
        ALLOWED_DISTRO="debian"
        DISTRO_VERSION=${VERSION_ID}
        ALLOWED_DISTRO_VERSION="11"
        DISTRO_KERNEL_VERSION=$(uname -r | cut -d'.' -f1-2)
        ALLOWED_DISTRO_KERNEL_VERSION="5.10"
    fi
}

# Get the current system information
system-information

# Pre-Checks system requirements
function installing-system-requirements() {
    if { [ ! -x "$(command -v curl)" ] || [ ! -x "$(command -v cut)" ] || [ ! -x "$(command -v jq)" ] || [ ! -x "$(command -v ip)" ] || [ ! -x "$(command -v lsof)" ] || [ ! -x "$(command -v cron)" ] || [ ! -x "$(command -v awk)" ] || [ ! -x "$(command -v pgrep)" ] || [ ! -x "$(command -v grep)" ] || [ ! -x "$(command -v qrencode)" ] || [ ! -x "$(command -v sed)" ] || [ ! -x "$(command -v zip)" ] || [ ! -x "$(command -v unzip)" ] || [ ! -x "$(command -v openssl)" ] || [ ! -x "$(command -v ifupdown)" ] || [ ! -x "$(command -v nftables)" ] || [ ! -x "$(command -v snap)" ]; }; then
        if { [ "${DISTRO}" == ${ALLOWED_DISTRO} ] && [ "${DISTRO_VERSION}" == ${ALLOWED_DISTRO_VERSION} ]; }; then
            apt-get update
            apt-get install curl coreutils jq iproute2 lsof cron gawk procps grep qrencode sed zip unzip openssl ifupdown nftables snapd -y
        else
            echo "Error: ${DISTRO} is not supported."
            exit
        fi
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
    if [[ ${HEADLESS_INSTALL} =~ ^[Yy]$ ]]; then
        PORT_CHOICE_SETTINGS=${IPV4_SUBNET_SETTINGS:-1}
        PASSWORD_CHOICE_SETTINGS=${IPV6_SUBNET_SETTINGS:-1}
        ENCRYPTION_CHOICE_SETTINGS=${ENCRYPTION_CHOICE_SETTINGS:-1}
        SERVER_HOST_V4_SETTINGS=${SERVER_HOST_V4_SETTINGS:-1}
        SERVER_HOST_V6_SETTINGS=${SERVER_HOST_V6_SETTINGS:-1}
        MODE_CHOICE_SETTINGS=${MODE_CHOICE_SETTINGS:-1}
    fi
}

# No GUI
headless-install

# Global variable
SHADOWSOCKS_PATH="/var/snap/shadowsocks-rust/common/etc/shadowsocks-rust"
SHADOWSOCKS_CONFIG_PATH="${SHADOWSOCKS_PATH}/config.json"
SHADOWSOCKS_SERVICE_PATH="/etc/systemd/system/shadowsocks-rust.service"
SHADOWSOCKS_MANAGER_URL="https://raw.githubusercontent.com/complexorganizations/shadowsocks-manager/main/shadowsocks-manager.sh"
SHADOWSOCKS_BACKUP_PATH="/var/backups/shadowsocks-manager.zip"

# Shadowsocks Config
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

    # Get the IPv4
    function test-connectivity-v4() {
        echo "How would you like to detect IPv4?"
        echo "  1) Curl (Recommended)"
        echo "  2) IP (Advanced)"
        echo "  3) Custom (Advanced)"
        until [[ "${SERVER_HOST_V4_SETTINGS}" =~ ^[1-3]$ ]]; do
            read -rp "IPv4 Choice [1-3]: " -e -i 1 SERVER_HOST_V4_SETTINGS
        done
        case ${SERVER_HOST_V4_SETTINGS} in
        1)
            SERVER_HOST_V4="$(curl -4 -s 'https://api.ipengine.dev' | jq -r '.network.ip')"
            if [ -z "${SERVER_HOST_V4}" ]; then
                echo "Error: Curl unable to locate your server's public IP address."
            fi
            ;;
        2)
            SERVER_HOST_V4="$(ip route get 8.8.8.8 | grep src | sed 's/.*src \(.* \)/\1/g' | cut -f1 -d ' ')"
            if [ -z "${SERVER_HOST_V4}" ]; then
                echo "Error: IP unable to locate your server's public IP address."
            fi
            ;;
        3)
            read -rp "Custom IPv4: " -e -i "$(curl -4 -s 'https://api.ipengine.dev' | jq -r '.network.ip')" SERVER_HOST_V4
            if [ -z "${SERVER_HOST_V4}" ]; then
                SERVER_HOST_V4="$(curl -4 -s 'https://api.ipengine.dev' | jq -r '.network.ip')"
            fi
            ;;
        esac
    }

    # Get the IPv4
    test-connectivity-v4

    # Determine ipv6
    function test-connectivity-v6() {
        echo "How would you like to detect IPv6?"
        echo "  1) Curl (Recommended)"
        echo "  2) IP (Advanced)"
        echo "  3) Custom (Advanced)"
        until [[ "${SERVER_HOST_V6_SETTINGS}" =~ ^[1-3]$ ]]; do
            read -rp "IPv6 Choice [1-3]: " -e -i 1 SERVER_HOST_V6_SETTINGS
        done
        case ${SERVER_HOST_V6_SETTINGS} in
        1)
            SERVER_HOST_V6="$(curl -6 -s 'https://api.ipengine.dev' | jq -r '.network.ip')"
            if [ -z "${SERVER_HOST_V6}" ]; then
                echo "Error: Curl unable to locate your server's public IP address."
            fi
            ;;
        2)
            SERVER_HOST_V6="$(ip -6 addr | sed -ne 's|^.* inet6 \([^/]*\)/.* scope global.*$|\1|p' | head -1)"
            if [ -z "${SERVER_HOST_V6}" ]; then
                echo "Error: IP unable to locate your server's public IP address."
            fi
            ;;
        3)
            read -rp "Custom IPv6: " -e -i "$(curl -6 -s 'https://api.ipengine.dev' | jq -r '.network.ip')" SERVER_HOST_V6
            if [ -z "${SERVER_HOST_V6}" ]; then
                SERVER_HOST_V6="$(curl -6 -s 'https://api.ipengine.dev' | jq -r '.network.ip')"
            fi
            ;;
        esac
    }

    # Set Port
    test-connectivity-v6

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
        if [ ! -x "$(command -v snap run shadowsocks-rust.ssserver)" ]; then
            snap install core
            snap install --candidate shadowsocks-rust
        fi
        if [ ! -x "$(command -v shadowsocks-rust.ssserver)" ]; then
            ln -s /snap/bin/shadowsocks-rust.ssserver /usr/bin/shadowsocks-rust.ssserver
        fi
    }

    # Install shadowsocks Server
    install-shadowsocks-server

    function shadowsocks-configuration() {
        if [ ! -f "${SHADOWSOCKS_CONFIG_PATH}" ]; then
            echo "{
  \"server\":\"0.0.0.0\",
  \"mode\":\"${MODE_CHOICE}\",
  \"server_port\":${SERVER_PORT},
  \"password\":\"${PASSWORD_CHOICE}\",
  \"method\":\"${ENCRYPTION_CHOICE}\"
}" >>${SHADOWSOCKS_CONFIG_PATH}
        fi
        # Install the service
        if [ ! -f "${SHADOWSOCKS_SERVICE_PATH}" ]; then
            echo "[Unit]
Description=Shadowsocks-rust Server
After=network.target

[Service]
Type=simple
ExecStart=shadowsocks-rust.ssserver -c ${SHADOWSOCKS_CONFIG_PATH}

[Install]
WantedBy=multi-user.target" >>${SHADOWSOCKS_SERVICE_PATH}
        fi
        if ! pgrep systemd-journal; then
            service shadowsocks-rust enable
            service shadowsocks-rust start
        fi
    }

    # Shadowsocks Config
    shadowsocks-configuration

    function show-config() {
        echo "Config File ---> ${SHADOWSOCKS_CONFIG_PATH}"
        if [ -z "${SERVER_HOST_V4}" ]; then
            echo "Shadowsocks IPv4: ${SERVER_HOST_V4}"
        fi
        if [ -z "${SERVER_HOST_V6}" ]; then
            echo "Shadowsocks IPv6: ${SERVER_HOST_V6}"
        fi
        echo "Shadowsocks Port: ${SERVER_PORT}"
        echo "Shadowsocks Password: ${PASSWORD_CHOICE}"
        echo "Shadowsocks Encryption: ${ENCRYPTION_CHOICE}"
        echo "Shadowsocks Mode: ${MODE_CHOICE}"
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
            if ! pgrep systemd-journal; then
                service shadowsocks-rust start
            fi
            ;;
        2)
            if ! pgrep systemd-journal; then
                service shadowsocks-rust stop
            fi
            ;;
        3)
            if ! pgrep systemd-journal; then
                service shadowsocks-rust restart
            fi
            ;;
        4)
            cat ${SHADOWSOCKS_CONFIG_PATH}
            ;;
        5)
            if ! pgrep systemd-journal; then
                service shadowsocks-rust stop
                service shadowsocks-rust disable
            fi
            snap remove --purge shadowsocks-rust -y
            apt-get remove --purge snapd -y
            if [ -d "${SHADOWSOCKS_PATH}" ]; then
                rm -rf "${SHADOWSOCKS_PATH}"
            fi
            if [ -f "${SHADOWSOCKS_CONFIG_PATH}" ]; then
                rm -f "${SHADOWSOCKS_CONFIG_PATH}"
            fi
            if [ -f "${SHADOWSOCKS_SERVICE_PATH}" ]; then
                rm -f "${SHADOWSOCKS_SERVICE_PATH}"
            fi
            if [ -f "${SHADOWSOCKS_BACKUP_PATH}" ]; then
                rm -f ${SHADOWSOCKS_BACKUP_PATH}
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
                    zip -rej ${SHADOWSOCKS_BACKUP_PATH} ${SHADOWSOCKS_CONFIG_PATH}
                else
                    exit
                fi
            fi
            ;;
        8)
            if [ -d "${SHADOWSOCKS_COMMON_PATH}" ]; then
                rm -rf "${SHADOWSOCKS_COMMON_PATH}"
            fi
            if [ -f "${SHADOWSOCKS_CONFIG_PATH}" ]; then
                unzip ${SHADOWSOCKS_CONFIG_PATH} -d "${SHADOWSOCKS_COMMON_PATH}"
            else
                exit
            fi
            if ! pgrep systemd-journal; then
                service shadowsocks-rust restart
            fi
            ;;
        esac
    }

    # Running Questions Command
    shadowsocks-next-questions

fi
