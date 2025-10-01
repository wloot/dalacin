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
    if [[ ! -f /usr/lib/systemd/system/dalacin2.service ]]; then
        return 2
    fi
    temp=$(systemctl status dalacin2 | grep Active | awk '{print $3}' | cut -d "(" -f2 | cut -d ")" -f1)
    if [[ x"${temp}" == x"running" ]]; then
        return 0
    else
        return 1
    fi
}

work_systemd() {
    cp -f dalacin.service /usr/lib/systemd/system/dalacin2.service
    systemctl daemon-reload
    systemctl stop dalacin2
    systemctl enable dalacin2
    echo -e "${green}dalacin${plain} 安装完成，已设置开机自启"
    if [[ ! -f /etc/dalacin/config.json ]]; then
        mkdir /etc/dalacin/ -p
        touch /etc/dalacin/config.json
        echo -e ""
        echo -e "全新安装，请先配置 /etc/dalacin/config.json"
    else
        systemctl start dalacin2
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

    url="https://github.com/wloot/dalacin/archive/next.tar.gz"
    echo -e "开始安装 dalacin"
    curl -L -o ./dalacin.tar.gz ${url}
    if [[ $? -ne 0 ]]; then
        echo -e "${red}下载 dalacin 失败${plain}"
        exit 1
    fi

    tar -xzf dalacin.tar.gz
    cd dalacin-next

    mkdir -p /var/lib/dalacin/
    rm -rf /var/lib/dalacin/*
    chown nobody /var/lib/dalacin
    cp -f dalacin-${arch} /usr/bin/dalacin
    chmod +x /usr/bin/dalacin

    if [ -n "$(command -v systemctl)" ]; then
        work_systemd
        systemctl disable dalacin 2>/dev/null
    else
        cp -f dalacin /etc/init.d/dalacin2
        rc-update add dalacin2
        mkdir /etc/dalacin/ -p
        rc-service dalacin2 status && rc-service dalacin2 restart
        rc-update delete dalacin 2>/dev/null
    fi

    rm -rf /tmp/dalacin-installer/
}

echo -e "${green}开始安装${plain}"
install_base
install_dalacin
