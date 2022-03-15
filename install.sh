#!/bin/bash

red='\033[0;31m'
green='\033[0;32m'
yellow='\033[0;33m'
plain='\033[0m'

cur_dir=$(pwd)

# check root
[[ $EUID -ne 0 ]] && echo -e "${red}Lưu ý：${plain} Vui lòng chạy tệp cài đăt này với tư cách root\n" && exit 1

# check os
if [[ -f /etc/redhat-release ]]; then
    release="centos"
elif cat /etc/issue | grep -Eqi "debian"; then
    release="debian"
elif cat /etc/issue | grep -Eqi "ubuntu"; then
    release="ubuntu"
elif cat /etc/issue | grep -Eqi "centos|red hat|redhat"; then
    release="centos"
elif cat /proc/version | grep -Eqi "debian"; then
    release="debian"
elif cat /proc/version | grep -Eqi "ubuntu"; then
    release="ubuntu"
elif cat /proc/version | grep -Eqi "centos|red hat|redhat"; then
    release="centos"
else
    echo -e "${red}Phiên bản hệ thống không được phát hiện ！${plain}\n" && exit 1
fi

arch=$(arch)

if [[ $arch == "x86_64" || $arch == "x64" || $arch == "amd64" ]]; then
    arch="amd64"
elif [[ $arch == "aarch64" || $arch == "arm64" ]]; then
    arch="arm64"
else
    arch="amd64"
    echo -e "${red}Không phát hiện được cấu trúc, sử dụng cấu trúc mặc định: ${arch}${plain}"
fi

echo "Cấu Trúc: ${arch}"

if [ $(getconf WORD_BIT) != '32' ] && [ $(getconf LONG_BIT) != '64' ]; then
    echo "Phần mềm này không hỗ trợ hệ thống 32-bit (x86), vui lòng sử dụng hệ thống 64-bit (x86_64), nếu phát hiện sai, vui lòng liên hệ với tác giả"
    exit -1
fi

os_version=""

# os version
if [[ -f /etc/os-release ]]; then
    os_version=$(awk -F'[= ."]' '/VERSION_ID/{print $3}' /etc/os-release)
fi
if [[ -z "$os_version" && -f /etc/lsb-release ]]; then
    os_version=$(awk -F'[= ."]+' '/DISTRIB_RELEASE/{print $2}' /etc/lsb-release)
fi

if [[ x"${release}" == x"centos" ]]; then
    if [[ ${os_version} -le 6 ]]; then
        echo -e "${red}Vui lòng sử dụng CentOS 7 trở lên！${plain}\n" && exit 1
    fi
elif [[ x"${release}" == x"ubuntu" ]]; then
    if [[ ${os_version} -lt 16 ]]; then
        echo -e "${red}Vui lòng sử dụng Ubuntu 16 trở lên！${plain}\n" && exit 1
    fi
elif [[ x"${release}" == x"debian" ]]; then
    if [[ ${os_version} -lt 8 ]]; then
        echo -e "${red}Vui lòng sử dụng Debian 8 trở lên！${plain}\n" && exit 1
    fi
fi

install_base() {
    if [[ x"${release}" == x"centos" ]]; then
        yum install wget curl tar -y
    else
        apt install wget curl tar -y
    fi
}

#This function will be called when user installed x-ui out of sercurity
config_after_install() {
    echo -e "${yellow}Vì lý do bảo mật, cần phải thay đổi cổng và mật khẩu tài khoản sau khi cài đặt xong.${plain}"
    read -p "Vui lòng đặt tên tài khoản của bạn:" config_account
    echo -e "${yellow}Tên tài khoản của bạn sẽ được đặt thành:${config_account}${plain}"
    read -p "Vui lòng đặt mật khẩu tài khoản của bạn:" config_password
    echo -e "${yellow}Mật khẩu tài khoản của bạn sẽ được đặt thành:${config_password}${plain}"
    read -p "Cổng Truy Cập:" config_port
    echo -e "${yellow}Cổng truy cập bảng điều khiển của bạn sẽ được đặt thành:${config_port}${plain}"
    read -p "Xác nhận cài đặt hoàn tất？[y/n]": config_confirm
    echo -e "Việt hóa bởi Stowe https://github.com/Corey-Stowe"
    read -p "nhập y để hoàn thành quá trình cài đặt": config_confirm
    if [[ x"${config_confirm}" == x"y" || x"${config_confirm}" == x"Y" ]]; then
        echo -e "${yellow}Xác nhận cài đặt, cài đặt${plain}"
        /usr/local/x-ui/x-ui setting -username ${config_account} -password ${config_password}
        echo -e "${yellow}Đã hoàn tất cài đặt mật khẩu tài khoản${plain}"
        /usr/local/x-ui/x-ui setting -port ${config_port}
        echo -e "${yellow}Đã hoàn tất cài đặt cổng bảng điều khiển${plain}"
    else
        echo -e "${red}Đã hủy, tất cả các mục cài đặt là cài đặt mặc định, vui lòng sửa đổi kịp thời${plain}"
    fi
}

install_x-ui() {
    systemctl stop x-ui
    cd /usr/local/

    if [ $# == 0 ]; then
        last_version=$(curl -Ls "https://api.github.com/repos/Corey-Stowe/x-ui/releases/latest" | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/')
        if [[ ! -n "$last_version" ]]; then
            echo -e "${red}Không thể phát hiện phiên bản x-ui, có thể đã vượt quá giới hạn API Github, vui lòng thử lại sau hoặc chỉ định phiên bản x-ui để cài đặt theo cách thủ công${plain}"
            exit 1
        fi
        echo -e "Đã phát hiện phiên bản mới nhất của x-ui：${last_version}，bắt đầu cài đặt"
        wget -N --no-check-certificate -O /usr/local/x-ui-linux-${arch}.tar.gz https://github.com/Corey-Stowe/x-ui/releases/download/${last_version}/x-ui-linux-${arch}.tar.gz
        if [[ $? -ne 0 ]]; then
            echo -e "${red}下载 x-ui 失败，请确保你的服务器能够下载 Github 的文件${plain}"
            exit 1
        fi
    else
        last_version=$1
        url="https://github.com/Corey-Stowe/x-ui/releases/download/${last_version}/x-ui-linux-${arch}.tar.gz"
        echo -e "开始安装 x-ui v$1"
        wget -N --no-check-certificate -O /usr/local/x-ui-linux-${arch}.tar.gz ${url}
        if [[ $? -ne 0 ]]; then
            echo -e "${red}下载 x-ui v$1 失败，请确保此版本存在${plain}"
            exit 1
        fi
    fi

    if [[ -e /usr/local/x-ui/ ]]; then
        rm /usr/local/x-ui/ -rf
    fi

    tar zxvf x-ui-linux-${arch}.tar.gz
    rm x-ui-linux-${arch}.tar.gz -f
    cd x-ui
    chmod +x x-ui bin/xray-linux-${arch}
    cp -f x-ui.service /etc/systemd/system/
    wget --no-check-certificate -O /usr/bin/x-ui https://raw.githubusercontent.com/Corey-Stowe/x-ui/x-ui.sh
    chmod +x /usr/local/x-ui/x-ui.sh
    chmod +x /usr/bin/x-ui
    config_after_install
    #echo -e "如果是全新安装，默认网页端口为 ${green}54321${plain}，用户名和密码默认都是 ${green}admin${plain}"
    #echo -e "请自行确保此端口没有被其他程序占用，${yellow}并且确保 54321 端口已放行${plain}"
    #    echo -e "若想将 54321 修改为其它端口，输入 x-ui 命令进行修改，同样也要确保你修改的端口也是放行的"
    #echo -e ""
    #echo -e "如果是更新面板，则按你之前的方式访问面板"
    #echo -e ""
    systemctl daemon-reload
    systemctl enable x-ui
    systemctl start x-ui
    echo -e "${green}x-ui v${last_version}${plain} hưỡng dẫn sử dụng，"
    echo -e ""
    echo -e "Cách sử dụng tập lệnh quản lý x-ui: "
    echo -e "----------------------------------------------"
    echo -e "x-ui              - Hiển thị menu quản lý (nhiều chức năng hơn)"
    echo -e "x-ui start        - Chạy x-ui"
    echo -e "x-ui stop         - Dừng x-ui"
    echo -e "x-ui restart      - Khởi động lại"
    echo -e "x-ui status       - trạng thái"
    echo -e "x-ui enable       - kích hoạt x-ui"
    echo -e "x-ui disable      - tắt x-ui"
    echo -e "x-ui log          - phiên bản của x-ui"
    echo -e "x-ui v2-ui        - Di chuyển dữ liệu tài khoản v2-ui của máy này sang x-ui"
    echo -e "x-ui update       - cập nhật x-ui (khồng khuyến nghị khi cài bản việt hóa)"
    echo -e "x-ui install      - Cài lại x-ui"
    echo -e "x-ui uninstall    - Gỡ cài đặt x-ui"
    echo -e "phiên bản vh      - V 1.0"
    echo -e "việt hóa bởi: Stowe"
    echo -e "----------------------------------------------"
}

echo -e "${green}bắt đầu cài đặt${plain}"
install_base
install_x-ui $1
