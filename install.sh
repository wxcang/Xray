#!/bin/bash

author=233boy

# ===== 你的仓库 =====
MY_REPO="wxcang/Xray"

# github=https://github.com/233boy/xray

# bash fonts colors
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

err() {
    echo -e "\n$is_err $@\n" && exit 1
}

warn() {
    echo -e "\n$is_warn $@\n"
}

[[ $EUID != 0 ]] && err "当前非 ROOT用户."

cmd=$(type -P apt-get || type -P yum)
[[ ! $cmd ]] && err "仅支持 Ubuntu/Debian/CentOS"

[[ ! $(type -P systemctl) ]] && err "缺少 systemctl"

is_wget=$(type -P wget)

case $(uname -m) in
amd64 | x86_64)
    is_jq_arch=amd64
    ;;
*)
    err "此脚本仅支持 x86_64（你已写死文件名）"
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

tmp_var_lists=(
    tmpcore
    tmpsh
    tmpjq
    is_core_ok
    is_sh_ok
    is_jq_ok
    is_pkg_ok
)

tmpdir=$(mktemp -u)

for i in ${tmp_var_lists[*]}; do
    export $i=$tmpdir/$i
done

load() {
    . $is_sh_dir/src/$1
}

_wget() {
    [[ $proxy ]] && export https_proxy=$proxy
    wget --no-check-certificate $*
}

msg() {
    case $1 in
    warn) local color=$yellow ;;
    err) local color=$red ;;
    ok) local color=$green ;;
    esac
    echo -e "${color}$(date +'%T')${none}) ${2}"
}

# ===== 核心修改在这里 =====
download() {
    case $1 in
    core)
        # 👉 写死你的文件
        link=https://github.com/${MY_REPO}/releases/latest/download/Xray-linux-64.zip
        name=$is_core_name
        tmpfile=$tmpcore
        is_ok=$is_core_ok
        ;;
    sh)
        # 👉 写死你的 code.zip
        link=https://github.com/${MY_REPO}/releases/latest/download/code.zip
        name="$is_core_name 脚本"
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

    msg warn "下载 ${name} > ${link}"
    if _wget -t 3 -q -c $link -O $tmpfile; then
        mv -f $tmpfile $is_ok
    fi
}

# ===== 后面全部原封不动 =====

get_ip() {
    export "$(_wget -4 -qO- https://one.one.one.one/cdn-cgi/trace | grep ip=)" &>/dev/null
}

check_status() {
    [[ ! -f $is_pkg_ok ]] && {
        msg err "安装依赖包失败"
        is_fail=1
    }

    [[ ! -f $is_core_ok ]] && {
        msg err "下载 Xray 失败"
        is_fail=1
    }
    [[ ! -f $is_sh_ok ]] && {
        msg err "下载 脚本失败"
        is_fail=1
    }

    [[ $is_fail ]] && exit 1
}

install_pkg() {
    $cmd update -y &>/dev/null
    $cmd install -y $is_pkg &>/dev/null && >$is_pkg_ok
}

main() {

    clear
    echo
    echo "........... Xray script by $author .........."
    echo

    msg warn "开始安装..."

    mkdir -p $tmpdir

    install_pkg &
    download core &
    download sh &
    get_ip

    wait
    check_status

    mkdir -p $is_sh_dir
    unzip -qo $is_sh_ok -d $is_sh_dir

    mkdir -p $is_core_dir/bin
    unzip -qo $is_core_ok -d $is_core_dir/bin

    echo "alias xray=$is_sh_bin" >>/root/.bashrc
    ln -sf $is_sh_dir/$is_core.sh $is_sh_bin

    chmod +x $is_core_bin $is_sh_bin

    mkdir -p $is_log_dir

    msg ok "生成配置文件..."

    load systemd.sh
    install_service $is_core &>/dev/null

    mkdir -p $is_conf_dir

    load core.sh
    add reality

    rm -rf $tmpdir
}

main $@
