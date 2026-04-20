#!/bin/bash

author=233boy

# ===== 你的仓库 =====
MY_REPO="wxcang/Xray"

# colors
red='\e[31m'
yellow='\e[33m'
green='\e[92m'
none='\e[0m'
_red() { echo -e ${red}$@${none}; }
_green() { echo -e ${green}$@${none}; }

err() {
    echo -e "\n$(_red 错误!) $@\n" && exit 1
}

warn() {
    echo -e "\n${yellow}警告!${none} $@\n"
}

# root check
[[ $EUID != 0 ]] && err "请使用 ROOT 用户运行"

# pkg manager
cmd=$(type -P apt-get || type -P yum)
[[ ! $cmd ]] && err "仅支持 Debian/Ubuntu/CentOS"

# systemd
[[ ! $(type -P systemctl) ]] && err "系统缺少 systemd"

# 架构（强制限制）
case $(uname -m) in
amd64 | x86_64)
    ;;
*)
    err "当前脚本仅支持 x86_64 架构（你已写死文件名）"
    ;;
esac

is_core=xray
is_core_dir=/etc/$is_core
is_core_bin=$is_core_dir/bin/$is_core
is_conf_dir=$is_core_dir/conf
is_log_dir=/var/log/$is_core
is_sh_bin=/usr/local/bin/$is_core
is_sh_dir=$is_core_dir/sh

tmpdir=$(mktemp -d)

tmpcore=$tmpdir/core.zip
tmpsh=$tmpdir/code.zip
tmpjq=$tmpdir/jq

# wget
_wget() {
    wget --no-check-certificate "$@"
}

msg() {
    echo -e "$(date +'%T')) $1"
}

# 安装依赖
install_pkg() {
    msg "安装依赖..."
    $cmd update -y &>/dev/null
    $cmd install -y wget unzip curl &>/dev/null || err "依赖安装失败"
}

# 下载（核心已改）
download() {
    case $1 in
    core)
        link="https://github.com/${MY_REPO}/releases/latest/download/Xray-linux-64.zip"
        out=$tmpcore
        name="Xray Core"
        ;;
    sh)
        link="https://github.com/${MY_REPO}/releases/latest/download/code.zip"
        out=$tmpsh
        name="Xray Script"
        ;;
    jq)
        link="https://github.com/jqlang/jq/releases/download/jq-1.7.1/jq-linux-amd64"
        out=$tmpjq
        name="jq"
        ;;
    esac

    msg "下载 $name"
    _wget -t 3 -q -c "$link" -O "$out" || err "下载失败: $link"
}

# 获取IP
get_ip() {
    ip=$(curl -s4 https://api.ip.sb/ip)
}

# 清理
cleanup() {
    rm -rf $tmpdir
}

main() {

    # 防重复安装
    [[ -f $is_sh_bin ]] && err "检测到已安装，如需重装请先卸载"

    clear
    echo "====== Xray 一键安装（自定义源） ======"

    install_pkg

    # 下载
    download core
    download sh

    if ! type -P jq &>/dev/null; then
        download jq
        mv $tmpjq /usr/bin/jq
        chmod +x /usr/bin/jq
    fi

    get_ip
    [[ -z $ip ]] && err "获取IP失败"

    # 创建目录
    mkdir -p $is_sh_dir
    mkdir -p $is_core_dir/bin
    mkdir -p $is_conf_dir
    mkdir -p $is_log_dir

    # 解压
    unzip -qo $tmpsh -d $is_sh_dir || err "脚本解压失败"
    unzip -qo $tmpcore -d $is_core_dir/bin || err "core解压失败"

    # 命令
    ln -sf $is_sh_dir/xray.sh $is_sh_bin
    echo "alias xray=$is_sh_bin" >> /root/.bashrc

    chmod +x $is_core_bin
    chmod +x $is_sh_bin

    # systemd
    if [[ -f $is_sh_dir/src/systemd.sh ]]; then
        . $is_sh_dir/src/systemd.sh
        install_service xray &>/dev/null
    fi

    # 初始化配置
    if [[ -f $is_sh_dir/src/core.sh ]]; then
        . $is_sh_dir/src/core.sh
        add reality
    fi

    cleanup

    _green "安装完成！"
}

main
