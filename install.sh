#!/bin/bash

author=233boy
# github=https://github.com/233boy/xray

# bash fonts colors
red='\e[31m'
yellow='\e[33m'
gray='\e[90m'
green='\e[92m'
blue='\e[94m'
none='\e[0m'
_red() { echo -e ${red}$@${none}; }
_green() { echo -e ${green}$@${none}; }
_yellow() { echo -e ${yellow}$@${none}; }
_red_bg() { echo -e "\e[41m$@${none}"; }

is_err=$(_red_bg 错误!)
is_warn=$(_red_bg 警告!)

err() {
    echo -e "\n$is_err $@\n" && exit 1
}

warn() {
    echo -e "\n$is_warn $@\n"
}

# root check
[[ $EUID != 0 ]] && err "当前非 ${yellow}ROOT用户.${none}"

# system check
cmd=$(type -P apt-get || type -P yum)
[[ ! $cmd ]] && err "此脚本仅支持 ${yellow}(Ubuntu or Debian or CentOS)${none}."
[[ ! $(type -P systemctl) ]] && err "此系统缺少 ${yellow}(systemctl)${none}."

# arch check
case $(uname -m) in
amd64 | x86_64)
    is_jq_arch=amd64
    is_core_arch="64"
    ;;
*aarch64* | *armv8*)
    is_jq_arch=arm64
    is_core_arch="arm64-v8a"
    ;;
*)
    err "此脚本仅支持 64 位系统..."
    ;;
esac

is_core=xray
is_core_name=Xray
is_core_dir=/etc/$is_core
is_core_bin=$is_core_dir/bin/$is_core
is_conf_dir=$is_core_dir/conf
is_log_dir=/var/log/$is_core
is_sh_bin=/usr/local/bin/$is_core
is_sh_dir=$is_core_dir/sh
is_pkg="wget unzip"

tmpdir=$(mktemp -u)
[[ ! $tmpdir ]] && tmpdir=/tmp/tmp-$RANDOM
tmpcore=$tmpdir/tmpcore
tmpsh=$tmpdir/tmpsh
tmpjq=$tmpdir/tmpjq
is_core_ok=$tmpdir/is_core_ok
is_sh_ok=$tmpdir/is_sh_ok
is_jq_ok=$tmpdir/is_jq_ok
is_pkg_ok=$tmpdir/is_pkg_ok

load() {
    . $is_sh_dir/src/$1
}

_wget() {
    [[ $proxy ]] && export https_proxy=$proxy
    wget --no-check-certificate $*
}

msg() {
    case $1 in
    warn) color=$yellow ;;
    err) color=$red ;;
    ok) color=$green ;;
    esac
    echo -e "${color}$(date +'%T')${none}) ${2}"
}

# ---------- 核心修改：精准定向下载源 ----------
download() {
    case $1 in
    core)
        # 1. 核心文件：从您的私有仓库下载
        link=https://github.com/wxcang/Xray/releases/latest/download/Xray-linux-64.zip
        [[ $is_core_ver ]] && link="https://github.com/wxcang/Xray/releases/download/${is_core_ver}/Xray-linux-64.zip"
        name=$is_core_name
        tmpfile=$tmpcore
        is_ok=$is_core_ok
        ;;
    sh)
        # 2. 脚本包：从您的私有仓库下载
        link=https://github.com/wxcang/Xray/releases/latest/download/code.zip
        name="$is_core_name 脚本"
        tmpfile=$tmpsh
        is_ok=$is_sh_ok
        ;;
    jq)
        # 3. jq工具：维持官方地址下载，确保稳定性
        link=https://github.com/jqlang/jq/releases/download/jq-1.7.1/jq-linux-$is_jq_arch
        name="jq"
        tmpfile=$tmpjq
        is_ok=$is_jq_ok
        ;;
    esac

    msg warn "下载 ${name} > ${link}"
    if _wget -t 3 -q -c $link -O $tmpfile; then
        mv -f $tmpfile $is_ok
    fi
}
# --------------------------------------------

get_ip() {
    export "$(_wget -4 -qO- https://one.one.one.one/cdn-cgi/trace | grep ip=)" &>/dev/null
    [[ -z $ip ]] && export "$(_wget -6 -qO- https://one.one.one.one/cdn-cgi/trace | grep ip=)" &>/dev/null
}

check_status() {
    [[ ! -f $is_pkg_ok ]] && msg err "安装依赖包失败" && is_fail=1
    if [[ $(type -P wget) ]]; then
        [[ ! -f $is_core_ok ]] && msg err "下载 ${is_core_name} 失败" && is_fail=1
        [[ ! -f $is_sh_ok ]] && msg err "下载 ${is_core_name} 脚本失败" && is_fail=1
        [[ ! -f $is_jq_ok ]] && msg err "下载 jq 失败" && is_fail=1
    fi
    [[ $is_fail ]] && exit_and_del_tmpdir
}

exit_and_del_tmpdir() {
    rm -rf $tmpdir
    [[ ! $1 ]] && exit 1
    exit
}

install_pkg() {
    $cmd install -y $* &>/dev/null && >$is_pkg_ok
}

main() {
    clear
    echo "........... $is_core_name script by $author .........."
    mkdir -p $tmpdir
    msg warn "开始安装..."

    install_pkg $is_pkg &
    [[ ! $(type -P jq) ]] && jq_not_found=1

    download core &
    download sh &
    [[ $jq_not_found ]] && download jq &
    get_ip
    wait
    check_status

    mkdir -p $is_sh_dir $is_core_dir/bin $is_log_dir $is_conf_dir
    unzip -qo $is_sh_ok -d $is_sh_dir
    unzip -qo $is_core_ok -d $is_core_dir/bin

    ln -sf $is_sh_dir/$is_core.sh $is_sh_bin
    [[ $jq_not_found ]] && mv -f $is_jq_ok /usr/bin/jq
    chmod +x $is_core_bin $is_sh_bin /usr/bin/jq
    echo "alias $is_core=$is_sh_bin" >>/root/.bashrc

    load systemd.sh
    install_service $is_core &>/dev/null

    load core.sh
    # 默认创建 VLESS + REALITY 协议
    add reality

    msg ok "安装完成！"
    exit_and_del_tmpdir ok
}

main $@
