#!/bin/bash

author=233boy

red='\e[31m'
yellow='\e[33m'
gray='\e[90m'
green='\e[92m'
blue='\e[94m'
magenta='\e[95m'
cyan='\e[96m'
none='\e[0m'
_red() { echo -e ${red}$@${none}; }
_blue() { echo -e ${blue}$@${none}; }
_cyan() { echo -e ${cyan}$@${none}; }
_green() { echo -e ${green}$@${none}; }
_yellow() { echo -e ${yellow}$@${none}; }
_magenta() { echo -e ${magenta}$@${none}; }
_red_bg() { echo -e "\e[41m$@${none}"; }

is_err=$(_red_bg 错误!)
is_warn=$(_red_bg 警告!)

err() { echo -e "\n$is_err $@\n" && exit 1; }
warn() { echo -e "\n$is_warn $@\n"; }

[[ $EUID != 0 ]] && err "当前非 ROOT用户."

cmd=$(type -P apt-get || type -P yum)
[[ ! $cmd ]] && err "仅支持 Ubuntu/Debian/CentOS."

[[ ! $(type -P systemctl) ]] && err "缺少 systemctl"

is_wget=$(type -P wget)

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
    err "仅支持64位"
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
is_config_json=$is_core_dir/config.json

tmpdir=$(mktemp -u)
[[ ! $tmpdir ]] && tmpdir=/tmp/tmp-$RANDOM

tmpcore=$tmpdir/tmpcore
tmpsh=$tmpdir/tmpsh
tmpjq=$tmpdir/tmpjq
is_core_ok=$tmpdir/coreok
is_sh_ok=$tmpdir/shok
is_jq_ok=$tmpdir/jqok
is_pkg_ok=$tmpdir/pkgok

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

install_pkg() {
    for i in $*; do
        [[ ! $(type -P $i) ]] && need="$need $i"
    done
    if [[ $need ]]; then
        $cmd install -y $need &>/dev/null
        [[ $? == 0 ]] && >$is_pkg_ok
    else
        >$is_pkg_ok
    fi
}

########################################
# ✅ 核心修改就在这里
########################################
download() {
    case $1 in
    core)
        # 👉 你的 core
        link=https://raw.githubusercontent.com/wxcang/Xray/main/xray-linux-${is_core_arch}.zip
        name="Xray Core"
        tmpfile=$tmpcore
        is_ok=$is_core_ok
        ;;
    sh)
        # 👉 你的 code.zip
        link=https://raw.githubusercontent.com/wxcang/Xray/main/code.zip
        name="Xray Script"
        tmpfile=$tmpsh
        is_ok=$is_sh_ok
        ;;
    jq)
        link=https://github.com/jqlang/jq/releases/download/jq-1.7.1/jq-linux-$is_jq_arch
        name="jq"
        tmpfile=$tmpjq
        is_ok=$is_jq_ok
        ;;
    esac

    msg warn "下载 ${name}"
    if _wget -t 3 -q -c $link -O $tmpfile; then
        mv -f $tmpfile $is_ok
    else
        msg err "下载失败: $link"
    fi
}

get_ip() {
    export "$(_wget -4 -qO- https://one.one.one.one/cdn-cgi/trace | grep ip=)" &>/dev/null
}

main() {

    mkdir -p $tmpdir

    install_pkg $is_pkg &

    [[ $is_wget ]] && {
        download core &
        download sh &
        download jq &
        get_ip
    }

    wait

    [[ ! -f $is_core_ok ]] && err "core 下载失败"
    [[ ! -f $is_sh_ok ]] && err "脚本下载失败"
    [[ ! -f $is_jq_ok ]] && err "jq 下载失败"

    mkdir -p $is_sh_dir
    unzip -qo $is_sh_ok -d $is_sh_dir

    mkdir -p $is_core_dir/bin
    unzip -qo $is_core_ok -d $is_core_dir/bin

    ln -sf $is_sh_dir/$is_core.sh $is_sh_bin
    chmod +x $is_core_bin $is_sh_bin

    mkdir -p $is_log_dir

    msg ok "安装完成"
}

main
