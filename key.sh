#!/usr/bin/env bash
#=============================================================
# https://github.com/P3TERX/SSH_Key_Installer
# Description: Install SSH keys via GitHub, URL or local files
# Version: 2.6
# Author: P3TERX
# Blog: https://p3terx.com
#=============================================================

VERSION=3.0

USAGE() {
    echo "
SSH Key Installer $VERSION

Usage:
  bash <(curl -fsSL bit.ly/4713CYL) [options...] <arg>

  or:

  bash <(curl -fsSL t.ly/WnAmT) [options...] <arg>

Options:
  -D    Only for myself
  -o	Overwrite mode, this option is valid at the top
  -g	Get the public key from GitHub, the arguments is the GitHub ID
  -u	Get the public key from the URL, the arguments is the URL
  -f	Get the public key from the local file, the arguments is the local file path
  -p	Change SSH port, the arguments is port number
  -d	Disable password login"
}

if [ $# -eq 0 ]; then
    USAGE
    exit 1
fi

select_pub_key() {
    if [ "${KEY_NUM}" == '' ]; then
        echo -e "1.Low security\n2.Medium security\n3.High security\nPlease select a public key[1-3]:"
        read -e  KEY_NUM
        case $KEY_NUM in
        "1")
            KEY_URL="https://public.144444.xyz/low.txt"
            ;;
        "2")
            KEY_URL="https://public.144444.xyz/medium.txt"
            ;;
        "3")
            KEY_URL="https://public.144444.xyz/high.txt"
            ;;
        esac
        [ "${KEY_NUM}" == '' ] && echo "Error: Invalid input." && exit 1
    fi
    echo "Get key from URL..."
    PUB_KEY=$(curl -fsSL ${KEY_URL})
    #echo $PUB_KEY
}
get_github_key() {
    if [ "${KEY_ID}" == '' ]; then
        read -e -p "Please enter the GitHub account:" KEY_ID
        [ "${KEY_ID}" == '' ] && echo "Error: Invalid input." && exit 1
    fi
    echo "The GitHub account is: ${KEY_ID}"
    echo "Get key from GitHub..."
    PUB_KEY=$(curl -fsSL https://github.com/${KEY_ID}.keys)
    if [ "${PUB_KEY}" == 'Not Found' ]; then
        echo "Error: GitHub account not found."
        exit 1
    elif [ "${PUB_KEY}" == '' ]; then
        echo "Error: This account ssh key does not exist."
        exit 1
    fi
}

get_url_key() {
    if [ "${KEY_URL}" == '' ]; then
        read -e -p "Please enter the URL:" KEY_URL
        [ "${KEY_URL}" == '' ] && echo "Error: Invalid input." && exit 1
    fi
    echo "Get key from URL..."
    PUB_KEY=$(curl -fsSL ${KEY_URL})
}

get_loacl_key() {
    if [ "${KEY_PATH}" == '' ]; then
        read -e -p "Please enter the path:" KEY_PATH
        [ "${KEY_PATH}" == '' ] && echo "Error: Invalid input." && exit 1
    fi
    echo "Get key from $(${KEY_PATH})..."
    PUB_KEY=$(cat ${KEY_PATH})
}

install_key() {
    [ "${PUB_KEY}" == '' ] && echo "Error: ssh key does not exist." && exit 1
    if [ ! -f "${HOME}/.ssh/authorized_keys" ]; then
        echo "${HOME}/.ssh/authorized_keys is missing..."
        echo "Creating ${HOME}/.ssh/authorized_keys..."
        mkdir -p ${HOME}/.ssh/
        touch ${HOME}/.ssh/authorized_keys
        if [ ! -f "${HOME}/.ssh/authorized_keys" ]; then
            echo "Failed to create SSH key file."
        else
            echo "Key file created, proceeding..."
        fi
    fi
    if [ "${OVERWRITE}" == 1 ]; then
        echo "Overwriting SSH key..."
        echo -e "${PUB_KEY}\n" >${HOME}/.ssh/authorized_keys
    else
        echo "Adding SSH key..."
        echo -e "\n${PUB_KEY}\n" >>${HOME}/.ssh/authorized_keys
    fi
    chmod 700 ${HOME}/.ssh/
    chmod 600 ${HOME}/.ssh/authorized_keys
    [[ $(grep "${PUB_KEY}" "${HOME}/.ssh/authorized_keys") ]] &&
        echo "SSH Key installed successfully!"
}

change_port() {
    echo "Changing SSH port to ${SSH_PORT} ..."
    if [ $(uname -o) == Android ]; then
        [[ -z $(grep "Port " "$PREFIX/etc/ssh/sshd_config") ]] &&
            echo "Port ${SSH_PORT}" >>$PREFIX/etc/ssh/sshd_config ||
            sed -i "s@.*\(Port \).*@\1${SSH_PORT}@" $PREFIX/etc/ssh/sshd_config
        [[ $(grep "Port " "$PREFIX/etc/ssh/sshd_config") ]] && {
            echo "SSH port changed successfully !"
            RESTART_SSHD=2
        } || RESTART_SSHD=0

    else
        $SUDO sed -i "s@.*\(Port \).*@\1${SSH_PORT}@" /etc/ssh/sshd_config && {
            echo "SSH port changed successfully !"
            RESTART_SSHD=1
        } || RESTART_SSHD=0
    fi
}

disable_password() {
    echo "Disabled password login in SSH."
    if [ $(uname -o) == Android ]; then
        sed -i "s@.*\(PasswordAuthentication \).*@\1no@" $PREFIX/etc/ssh/sshd_config &&
            RESTART_SSHD=2 ||
            RESTART_SSHD=0
    else
        [ $EUID != 0 ] && SUDO=sudo
        $SUDO sed -i "s@.*\(PasswordAuthentication \).*@\1no@" /etc/ssh/sshd_config &&
            RESTART_SSHD=1 ||
            RESTART_SSHD=0
    fi
}

while getopts "oDg:u:f:p:d" OPT; do
    case $OPT in
    o)
        OVERWRITE=1
        ;;
    D)
        select_pub_key
        install_key
        ;;
    g)
        KEY_ID=$OPTARG
        get_github_key
        install_key
        ;;
    u)
        KEY_URL=$OPTARG
        get_url_key
        install_key
        ;;
    f)
        KEY_PATH=$OPTARG
        get_loacl_key
        install_key
        ;;
    p)
        SSH_PORT=$OPTARG
        change_port
        ;;
    d)
        disable_password
        ;;
    ?)
        USAGE
        exit 1
        ;;
    :)
        USAGE
        exit 1
        ;;
    *)
        USAGE
        exit 1
        ;;
    esac
done

if [ "$RESTART_SSHD" = 1 ]; then
    echo "Restarting sshd..."
    $SUDO systemctl restart sshd && echo "Done."
elif [ "$RESTART_SSHD" = 2 ]; then
    echo "Restart sshd or Termux App to take effect."
fi
