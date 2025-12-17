#!/bin/bash

red='\033[0;31m'
green='\033[0;32m'
yellow='\033[0;33m'
plain='\033[0m'

cur_dir=$(pwd)

# check root
[[ $EUID -ne 0 ]] && echo -e "${red}错误：${plain} 必须使用root用户运行此脚本！\n" && exit 1

if [ "$(getconf WORD_BIT)" != '32' ] && [ "$(getconf LONG_BIT)" != '64' ]; then
    echo "本软件不支持 32 位系统(x86)，请使用 64 位系统(x86_64)，如果检测有误，请联系作者"
    exit 2
fi

arch=$(arch)
if [[ $arch == "x86_64" || $arch == "x64" || $arch == "amd64" ]]; then
    arch="amd64"
elif [[ $arch == "aarch64" || $arch == "arm64" ]]; then
    arch="arm64"
else
    arch="amd64"
    echo -e "${red}检测架构失败，使用默认架构: ${arch}${plain}"
fi
echo "架构: ${arch}"

install_base() {
    yum install curl -y 2>/dev/null
    apt install curl -y 2>/dev/null
    apk add curl 2>/dev/null
}

# 0: running, 1: not running, 2: not installed
check_status() {
    if [[ ! -f /usr/lib/systemd/system/dalacin.service ]]; then
        return 2
    fi
    temp=$(systemctl status dalacin | grep Active | awk '{print $3}' | cut -d "(" -f2 | cut -d ")" -f1)
    if [[ x"${temp}" == x"running" ]]; then
        return 0
    else
        return 1
    fi
}

work_systemd() {
    cp -f dalacin.service /usr/lib/systemd/system/
    systemctl daemon-reload
    systemctl stop dalacin
    systemctl enable dalacin
    echo -e "${green}dalacin${plain} 安装完成，已设置开机自启"
    if [[ ! -f /etc/dalacin/config.yaml ]]; then
        mkdir /etc/dalacin/ -p
        cp -f config.yaml /etc/dalacin/
        echo -e ""
        echo -e "全新安装，请先配置 /etc/dalacin/config.yaml"
    else
        systemctl start dalacin
        sleep 2
        echo -e ""
        check_status
        if [[ $? == 0 ]]; then
            echo -e "${green}dalacin 重启成功${plain}"
        else
            echo -e "${red}dalacin 可能启动失败${plain}"
        fi
    fi
}

install_dalacin() {
    mkdir -p /tmp/dalacin-installer/
    cd /tmp/dalacin-installer/

    url="https://github.com/wloot/dalacin/archive/master.tar.gz"
    echo -e "开始安装 dalacin"
    curl -L -o ./dalacin.tar.gz ${url}
    if [[ $? -ne 0 ]]; then
        echo -e "${red}下载 dalacin 失败${plain}"
        exit 1
    fi

    tar -xzf dalacin.tar.gz
    cd dalacin-master

    mkdir -p /usr/share/dalacin/
    rm -rf /usr/share/dalacin/*
    cp -f v2ray-${arch} /usr/share/dalacin/v2ray
    chmod +x /usr/share/dalacin/v2ray
    cp -f dalacin-${arch} /usr/sbin/dalacin
    chmod +x /usr/sbin/dalacin
    cp -f dalacin.sh /usr/local/bin/dalacin
    chmod +x /usr/local/bin/dalacin

    curl -L -o ./geosite.dat https://github.com/v2fly/domain-list-community/releases/latest/download/dlc.dat
    curl -L -o ./geoip.dat https://github.com/v2fly/geoip/releases/latest/download/geoip.dat
    cp -f geosite.dat geoip.dat /usr/share/dalacin/

    if [ -n "$(command -v systemctl)" ]; then
        work_systemd
    else
        cp -f dalacin /etc/init.d/
        rc-update add dalacin
        mkdir /etc/dalacin/ -p
        rc-service dalacin status && rc-service dalacin restart
    fi

    rm -rf /tmp/dalacin-installer/
}

echo -e "${green}开始安装${plain}"
install_base
install_dalacin
