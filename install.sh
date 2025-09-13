#!/bin/bash

red='\033[0;31m'
green='\033[0;32m'
blue='\033[0;34m'
yellow='\033[0;33m'
plain='\033[0m'

cur_dir=$(pwd)

# check root
[[ $EUID -ne 0 ]] && echo -e "${red}Fatal error: ${plain} Please run this script with root privilege \n " && exit 1

# Check OS and set release variable
if [[ -f /etc/os-release ]]; then
    source /etc/os-release
    release=$ID
elif [[ -f /usr/lib/os-release ]]; then
    source /usr/lib/os-release
    release=$ID
else
    echo "Failed to check the system OS, please contact the author!" >&2
    exit 1
fi
echo "The OS release is: $release"

arch() {
    case "$(uname -m)" in
    x86_64 | x64 | amd64) echo 'amd64' ;;
    i*86 | x86) echo '386' ;;
    armv8* | armv8 | arm64 | aarch64) echo 'arm64' ;;
    armv7* | armv7 | arm) echo 'armv7' ;;
    armv6* | armv6) echo 'armv6' ;;
    armv5* | armv5) echo 'armv5' ;;
    s390x) echo 's390x' ;;
    *) echo -e "${green}Unsupported CPU architecture! ${plain}" && rm -f install.sh && exit 1 ;;
    esac
}

echo "Arch: $(arch)"

install_base() {
    case "${release}" in
    ubuntu | debian | armbian)
        apt-get update && apt-get install -y -q wget curl tar tzdata qrencode
        ;;
    centos | rhel | almalinux | rocky | ol)
        yum -y update && yum install -y -q wget curl tar tzdata qrencode
        ;;
    fedora | amzn | virtuozzo)
        dnf -y update && dnf install -y -q wget curl tar tzdata qrencode
        ;;
    arch | manjaro | parch)
        pacman -Syu && pacman -Syu --noconfirm wget curl tar tzdata qrencode
        ;;
    opensuse-tumbleweed)
        zypper refresh && zypper -q install -y wget curl tar timezone qrencode
        ;;
    *)
        apt-get update && apt-get install -y -q wget curl tar tzdata qrencode
        ;;
    esac
}

gen_random_string() {
    local length="$1"
    local random_string=$(LC_ALL=C tr -dc 'a-zA-Z0-9' </dev/urandom | fold -w "$length" | head -n 1)
    echo "$random_string"
}

generate_qr_code() {
    local username="$1"
    local password="$2"
    local port="$3"
    local webBasePath="$4"
    local server_ip="$5"
    
    # æž„å»ºJSONå­—ç¬¦ä¸²
    local json_data="{\"name\":\"3XUI\",\"url\":\"${server_ip}:${port}/${webBasePath}/\",\"protocol\":\"http\",\"type\":\"3x-ui\",\"username\":\"${username}\",\"password\":\"${password}\"}"
    
    echo -e ""
    echo -e "${green}Generating QR Code for easy access...${plain}"
    echo -e "###############################################"
    
    # ç"ŸæˆäºŒç»´ç 
    if command -v qrencode >/dev/null 2>&1; then
        echo "$json_data" | qrencode -t ANSIUTF8
        echo -e ""
        echo -e "${blue}QR Code Data:${plain}"
        echo -e "${yellow}$json_data${plain}"
    else
        echo -e "${red}qrencode not found. Installing...${plain}"
        case "${release}" in
        ubuntu | debian | armbian)
            apt-get install -y qrencode
            ;;
        centos | rhel | almalinux | rocky | ol)
            yum install -y qrencode
            ;;
        fedora | amzn | virtuozzo)
            dnf install -y qrencode
            ;;
        arch | manjaro | parch)
            pacman -S --noconfirm qrencode
            ;;
        opensuse-tumbleweed)
            zypper install -y qrencode
            ;;
        *)
            apt-get install -y qrencode
            ;;
        esac
        
        if command -v qrencode >/dev/null 2>&1; then
            echo "$json_data" | qrencode -t ANSIUTF8
            echo -e ""
            echo -e "${blue}QR Code Data:${plain}"
            echo -e "${yellow}$json_data${plain}"
        else
            echo -e "${red}Failed to install qrencode. Please install manually and scan this data:${plain}"
            echo -e "${yellow}$json_data${plain}"
        fi
    fi
    echo -e "###############################################"
}

config_after_install() {
    local existing_hasDefaultCredential=$(/usr/local/x-ui/x-ui setting -show true | grep -Eo 'hasDefaultCredential: .+' | awk '{print $2}')
    local existing_webBasePath=$(/usr/local/x-ui/x-ui setting -show true | grep -Eo 'webBasePath: .+' | awk '{print $2}')
    local existing_port=$(/usr/local/x-ui/x-ui setting -show true | grep -Eo 'port: .+' | awk '{print $2}')
    local URL_lists=(
        "https://api4.ipify.org"
		"https://ipv4.icanhazip.com"
		"https://v4.api.ipinfo.io/ip"
		"https://ipv4.myexternalip.com/raw"
		"https://4.ident.me"
		"https://check-host.net/ip"
    )
    local server_ip=""
    for ip_address in "${URL_lists[@]}"; do
        server_ip=$(curl -s --max-time 3 "${ip_address}" 2>/dev/null | tr -d '[:space:]')
        if [[ -n "${server_ip}" ]]; then
            break
        fi
    done

    # å£°æ˜Žå˜é‡ç"¨äºŽäºŒç»´ç ç"Ÿæˆ
    local qr_username=""
    local qr_password=""
    local qr_port=""
    local qr_webBasePath=""

    if [[ ${#existing_webBasePath} -lt 4 ]]; then
        if [[ "$existing_hasDefaultCredential" == "true" ]]; then
            local config_webBasePath=$(gen_random_string 18)
            local config_username=$(gen_random_string 10)
            local config_password=$(gen_random_string 10)

            read -rp "Would you like to customize the Panel Port settings? (If not, a random port will be applied) [y/n]: " config_confirm
            if [[ "${config_confirm}" == "y" || "${config_confirm}" == "Y" ]]; then
                read -rp "Please set up the panel port: " config_port
                echo -e "${yellow}Your Panel Port is: ${config_port}${plain}"
            else
                local config_port=$(shuf -i 1024-62000 -n 1)
                echo -e "${yellow}Generated random port: ${config_port}${plain}"
            fi

            /usr/local/x-ui/x-ui setting -username "${config_username}" -password "${config_password}" -port "${config_port}" -webBasePath "${config_webBasePath}"
            echo -e "This is a fresh installation, generating random login info for security concerns:"
            echo -e "###############################################"
            echo -e "${green}Username: ${config_username}${plain}"
            echo -e "${green}Password: ${config_password}${plain}"
            echo -e "${green}Port: ${config_port}${plain}"
            echo -e "${green}WebBasePath: ${config_webBasePath}${plain}"
            echo -e "${green}Access URL: http://${server_ip}:${config_port}/${config_webBasePath}${plain}"
            echo -e "###############################################"
            
            # è®¾ç½®äºŒç»´ç å‚æ•°
            qr_username="${config_username}"
            qr_password="${config_password}"
            qr_port="${config_port}"
            qr_webBasePath="${config_webBasePath}"
        else
            local config_webBasePath=$(gen_random_string 18)
            echo -e "${yellow}WebBasePath is missing or too short. Generating a new one...${plain}"
            /usr/local/x-ui/x-ui setting -webBasePath "${config_webBasePath}"
            echo -e "${green}New WebBasePath: ${config_webBasePath}${plain}"
            echo -e "${green}Access URL: http://${server_ip}:${existing_port}/${config_webBasePath}${plain}"
            
            # èŽ·å–çŽ°æœ‰ç"¨æˆ·åå'Œå¯†ç ç"¨äºŽäºŒç»´ç 
            local existing_username=$(/usr/local/x-ui/x-ui setting -show true | grep -Eo 'username: .+' | awk '{print $2}')
            local existing_password=$(/usr/local/x-ui/x-ui setting -show true | grep -Eo 'password: .+' | awk '{print $2}')
            
            qr_username="${existing_username}"
            qr_password="${existing_password}"
            qr_port="${existing_port}"
            qr_webBasePath="${config_webBasePath}"
        fi
    else
        if [[ "$existing_hasDefaultCredential" == "true" ]]; then
            local config_username=$(gen_random_string 10)
            local config_password=$(gen_random_string 10)

            echo -e "${yellow}Default credentials detected. Security update required...${plain}"
            /usr/local/x-ui/x-ui setting -username "${config_username}" -password "${config_password}"
            echo -e "Generated new random login credentials:"
            echo -e "###############################################"
            echo -e "${green}Username: ${config_username}${plain}"
            echo -e "${green}Password: ${config_password}${plain}"
            echo -e "###############################################"
            
            qr_username="${config_username}"
            qr_password="${config_password}"
            qr_port="${existing_port}"
            qr_webBasePath="${existing_webBasePath}"
        else
            echo -e "${green}Username, Password, and WebBasePath are properly set. Exiting...${plain}"
            
            # èŽ·å–çŽ°æœ‰è®¾ç½®ç"¨äºŽäºŒç»´ç 
            local existing_username=$(/usr/local/x-ui/x-ui setting -show true | grep -Eo 'username: .+' | awk '{print $2}')
            local existing_password=$(/usr/local/x-ui/x-ui setting -show true | grep -Eo 'password: .+' | awk '{print $2}')
            
            qr_username="${existing_username}"
            qr_password="${existing_password}"
            qr_port="${existing_port}"
            qr_webBasePath="${existing_webBasePath}"
        fi
    fi

    /usr/local/x-ui/x-ui migrate
    
    # ç"ŸæˆäºŒç»´ç 
    if [[ -n "$qr_username" && -n "$qr_password" && -n "$qr_port" && -n "$qr_webBasePath" ]]; then
        generate_qr_code "$qr_username" "$qr_password" "$qr_port" "$qr_webBasePath" "$server_ip"
    fi
}

install_x-ui() {
    cd /usr/local/

    # 固定安装v2.7.0版本
    tag_version="v2.7.0"
    echo -e "Installing x-ui version: ${tag_version}"
    wget -N -O /usr/local/x-ui-linux-$(arch).tar.gz https://github.com/MHSanaei/3x-ui/releases/download/${tag_version}/x-ui-linux-$(arch).tar.gz
    if [[ $? -ne 0 ]]; then
        echo -e "${red}Downloading x-ui ${tag_version} failed, please be sure that your server can access GitHub ${plain}"
        exit 1
    fi

    wget -O /usr/bin/x-ui-temp https://raw.githubusercontent.com/MHSanaei/3x-ui/main/x-ui.sh

    # Stop x-ui service and remove old resources
    if [[ -e /usr/local/x-ui/ ]]; then
        systemctl stop x-ui
        rm /usr/local/x-ui/ -rf
    fi

    # Extract resources and set permissions
    tar zxvf x-ui-linux-$(arch).tar.gz
    rm x-ui-linux-$(arch).tar.gz -f
    
    cd x-ui
    chmod +x x-ui
    chmod +x x-ui.sh

    # Check the system's architecture and rename the file accordingly
    if [[ $(arch) == "armv5" || $(arch) == "armv6" || $(arch) == "armv7" ]]; then
        mv bin/xray-linux-$(arch) bin/xray-linux-arm
        chmod +x bin/xray-linux-arm
    fi
    chmod +x x-ui bin/xray-linux-$(arch)

    # Update x-ui cli and se set permission
    mv -f /usr/bin/x-ui-temp /usr/bin/x-ui
    chmod +x /usr/bin/x-ui
    config_after_install

    cp -f x-ui.service /etc/systemd/system/
    systemctl daemon-reload
    systemctl enable x-ui
    systemctl start x-ui
    echo -e "${green}x-ui ${tag_version}${plain} installation finished, it is running now..."
    echo -e ""
    echo -e "┌─────────────────────────────────────────────────────┐"
    echo -e "│  ${blue}x-ui control menu usages (subcommands):${plain}              │"
    echo -e "│                                                       │"
    echo -e "│  ${blue}x-ui${plain}              - Admin Management Script          │"
    echo -e "│  ${blue}x-ui start${plain}        - Start                            │"
    echo -e "│  ${blue}x-ui stop${plain}         - Stop                             │"
    echo -e "│  ${blue}x-ui restart${plain}      - Restart                          │"
    echo -e "│  ${blue}x-ui status${plain}       - Current Status                   │"
    echo -e "│  ${blue}x-ui settings${plain}     - Current Settings                 │"
    echo -e "│  ${blue}x-ui enable${plain}       - Enable Autostart on OS Startup   │"
    echo -e "│  ${blue}x-ui disable${plain}      - Disable Autostart on OS Startup  │"
    echo -e "│  ${blue}x-ui log${plain}          - Check logs                       │"
    echo -e "│  ${blue}x-ui banlog${plain}       - Check Fail2ban ban logs          │"
    echo -e "│  ${blue}x-ui update${plain}       - Update                           │"
    echo -e "│  ${blue}x-ui legacy${plain}       - legacy version                   │"
    echo -e "│  ${blue}x-ui install${plain}      - Install                          │"
    echo -e "│  ${blue}x-ui uninstall${plain}    - Uninstall                        │"
    echo -e "└─────────────────────────────────────────────────────┘"
}

echo -e "${green}Running...${plain}"
install_base
install_x-ui
