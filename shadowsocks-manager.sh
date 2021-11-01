#!/usr/bin/env bash
# https://github.com/complexorganizations/shadowsocks-manager

# Require script to be run as root
function super-user-check() {
    if [ "${EUID}" -ne 0 ]; then
        echo "You need to run this script as super user."
        exit
    fi
}

# Require script to be run as root
super-user-check

# Get the current system information
function system-information() {
    if [ -f /etc/os-release ]; then
        # shellcheck disable=SC1091
        source /etc/os-release
        CURRENT_DISTRO=${ID}
    fi
}

# Get the current system information
system-information

# Pre-Checks system requirements
function installing-system-requirements() {
    if { [ "${CURRENT_DISTRO}" == "ubuntu" ] || [ "${CURRENT_DISTRO}" == "debian" ] || [ "${CURRENT_DISTRO}" == "raspbian" ] || [ "${CURRENT_DISTRO}" == "pop" ] || [ "${CURRENT_DISTRO}" == "kali" ] || [ "${CURRENT_DISTRO}" == "linuxmint" ] || [ "${CURRENT_DISTRO}" == "neon" ] || [ "${CURRENT_DISTRO}" == "fedora" ] || [ "${CURRENT_DISTRO}" == "centos" ] || [ "${CURRENT_DISTRO}" == "rhel" ] || [ "${CURRENT_DISTRO}" == "almalinux" ] || [ "${CURRENT_DISTRO}" == "rocky" ] || [ "${CURRENT_DISTRO}" == "arch" ] || [ "${CURRENT_DISTRO}" == "archarm" ] || [ "${CURRENT_DISTRO}" == "manjaro" ]; }; then
        if { [ ! -x "$(command -v curl)" ] || [ ! -x "$(command -v cut)" ] || [ ! -x "$(command -v jq)" ] || [ ! -x "$(command -v ip)" ] || [ ! -x "$(command -v lsof)" ] || [ ! -x "$(command -v awk)" ] || [ ! -x "$(command -v pgrep)" ] || [ ! -x "$(command -v grep)" ] || [ ! -x "$(command -v sed)" ] || [ ! -x "$(command -v zip)" ] || [ ! -x "$(command -v unzip)" ] || [ ! -x "$(command -v openssl)" ] || [ ! -x "$(command -v snap)" ]; }; then
            if { [ "${CURRENT_DISTRO}" == "ubuntu" ] || [ "${CURRENT_DISTRO}" == "debian" ] || [ "${CURRENT_DISTRO}" == "raspbian" ] || [ "${CURRENT_DISTRO}" == "pop" ] || [ "${CURRENT_DISTRO}" == "kali" ] || [ "${CURRENT_DISTRO}" == "linuxmint" ] || [ "${CURRENT_DISTRO}" == "neon" ]; }; then
                apt-get update
                apt-get install curl coreutils jq iproute2 lsof gawk procps grep sed zip unzip openssl snapd -y
            elif { [ "${CURRENT_DISTRO}" == "fedora" ] || [ "${CURRENT_DISTRO}" == "centos" ] || [ "${CURRENT_DISTRO}" == "rhel" ] || [ "${CURRENT_DISTRO}" == "almalinux" ] || [ "${CURRENT_DISTRO}" == "rocky" ]; }; then
                yum update
                yum install epel-release -y
                yum install curl coreutils jq iproute2 lsof gawk procps-ng grep sed zip unzip openssl snapd -y
            elif { [ "${CURRENT_DISTRO}" == "arch" ] || [ "${CURRENT_DISTRO}" == "archarm" ] || [ "${CURRENT_DISTRO}" == "manjaro" ]; }; then
                pacman -Syu --noconfirm --needed curl coreutils jq iproute2 lsof gawk procps-ng grep sed zip unzip openssl snapd
            fi
        fi
    else
        echo "Error: ${CURRENT_DISTRO} is not supported."
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
    if [[ ${HEADLESS_INSTALL} =~ ^[Yy]$ ]]; then
        SERVER_HOST_V4_SETTINGS=${SERVER_HOST_V4_SETTINGS:-1}
        SERVER_HOST_V6_SETTINGS=${SERVER_HOST_V6_SETTINGS:-1}
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
SHADOWSOCKS_BIN_PATH="/snap/bin/shadowsocks-rust.ssserver"
PASSWORD_CHOICE="$(openssl rand -base64 25)"
MODE_CHOICE="tcp_only"
SERVER_PORT="443"
ENCRYPTION_CHOICE="aes-256-gcm"

# Shadowsocks Config
if [ ! -f "${SHADOWSOCKS_CONFIG_PATH}" ]; then

    # Get the IPv4
    function test-connectivity-v4() {
        echo "How would you like to detect IPv4?"
        echo "  1) Curl (Recommended)"
        echo "  2) Custom (Advanced)"
        until [[ "${SERVER_HOST_V4_SETTINGS}" =~ ^[1-2]$ ]]; do
            read -rp "IPv4 Choice [1-2]:" -e -i 1 SERVER_HOST_V4_SETTINGS
        done
        case ${SERVER_HOST_V4_SETTINGS} in
        1)
            SERVER_HOST_V4="$(curl -4 -s 'https://api.ipengine.dev' | jq -r '.network.ip')"
            if [ -z "${SERVER_HOST_V4}" ]; then
                SERVER_HOST_V4="$(curl -4 -s 'https://checkip.amazonaws.com')"
            fi
            ;;
        2)
            read -rp "Custom IPv4:" SERVER_HOST_V4
            if [ -z "${SERVER_HOST_V4}" ]; then
                SERVER_HOST_V4="$(curl -4 -s 'https://api.ipengine.dev' | jq -r '.network.ip')"
            fi
            if [ -z "${SERVER_HOST_V4}" ]; then
                SERVER_HOST_V4="$(curl -4 -s 'https://checkip.amazonaws.com')"
            fi
            ;;
        esac
    }

    # Get the IPv4
    test-connectivity-v4

    # Determine IPv6
    function test-connectivity-v6() {
        echo "How would you like to detect IPv6?"
        echo "  1) Curl (Recommended)"
        echo "  2) Custom (Advanced)"
        until [[ "${SERVER_HOST_V6_SETTINGS}" =~ ^[1-2]$ ]]; do
            read -rp "IPv6 Choice [1-2]:" -e -i 1 SERVER_HOST_V6_SETTINGS
        done
        case ${SERVER_HOST_V6_SETTINGS} in
        1)
            SERVER_HOST_V6="$(curl -6 -s 'https://api.ipengine.dev' | jq -r '.network.ip')"
            if [ -z "${SERVER_HOST_V6}" ]; then
                SERVER_HOST_V6="$(curl -6 -s 'https://checkip.amazonaws.com')"
            fi
            ;;
        2)
            read -rp "Custom IPv6:" SERVER_HOST_V6
            if [ -z "${SERVER_HOST_V6}" ]; then
                SERVER_HOST_V6="$(curl -6 -s 'https://api.ipengine.dev' | jq -r '.network.ip')"
            fi
            if [ -z "${SERVER_HOST_V6}" ]; then
                SERVER_HOST_V6="$(curl -6 -s 'https://checkip.amazonaws.com')"
            fi
            ;;
        esac
    }

    # Get the IPv6
    test-connectivity-v6

    # Install shadowsocks Server
    function install-shadowsocks-server() {
        if [ ! -f "${SHADOWSOCKS_BIN_PATH}" ]; then
            snap install core
            snap install shadowsocks-rust
        fi
        if [ "${CURRENT_DISTRO}" == "raspbian" ]; then
            sed -i "s/\usr/#\/usr/" /etc/ld.so.preload
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
ExecStart=/snap/bin/shadowsocks-rust.ssserver -c ${SHADOWSOCKS_CONFIG_PATH}

[Install]
WantedBy=multi-user.target" >>${SHADOWSOCKS_SERVICE_PATH}
        fi
        if pgrep systemd-journal; then
            systemctl daemon-reload
            systemctl enable shadowsocks-rust
            systemctl start shadowsocks-rust
        else
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
            if pgrep systemd-journal; then
                systemctl start shadowsocks-rust
            else
                service shadowsocks-rust start
            fi
            ;;
        2)
            if pgrep systemd-journal; then
                systemctl stop shadowsocks-rust
            else
                service shadowsocks-rust stop
            fi
            ;;
        3)
            if pgrep systemd-journal; then
                systemctl restart shadowsocks-rust
            else
                service shadowsocks-rust restart
            fi
            ;;
        4)
            cat ${SHADOWSOCKS_CONFIG_PATH}
            ;;
        5)
            if pgrep systemd-journal; then
                systemctl disable shadowsocks-rust
                systemctl stop shadowsocks-rust
            else
                service shadowsocks-rust disable
                service shadowsocks-rust stop
            fi
            # Todo: Complete uninstall.
            snap remove shadowsocks-rust
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
            if pgrep systemd-journal; then
                systemctl restart shadowsocks-rust
            else
                service shadowsocks-rust restart
            fi
            ;;
        esac
    }

    # Running Questions Command
    shadowsocks-next-questions

fi
