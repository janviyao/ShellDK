#!/bin/bash
#set -e # when error, then exit
#set -u # variable not exist, then exit
ROOT_DIR=$(cd `dirname $0`;pwd)
BIN_DIR="${HOME}/.local/bin"
mkdir -p ${BIN_DIR}

export MY_VIM_DIR=${ROOT_DIR}
export BTASK_LIST=${BTASK_LIST:-"mdat,ncat"}
#export REMOTE_IP=${REMOTE_IP:-"127.0.0.1"}

declare -A FUNC_MAP
declare -A INST_GUIDE

CMD1="cd ${ROOT_DIR}/deps"
CMD2="cd ${ROOT_DIR}/tools/app"
INST_GUIDE["ppid"]="${CMD2};gcc ppid.c -g -o ppid;mv -f ppid ${BIN_DIR}"
INST_GUIDE["fstat"]="${CMD2};gcc fstat.c -g -o fstat;mv -f fstat ${BIN_DIR}"
INST_GUIDE["deno"]="${CMD1};unzip deno-x86_64-unknown-linux-gnu.zip;mv -f deno ${BIN_DIR}"

INST_GUIDE["make"]="install_from_net make"
INST_GUIDE["g++"]="install_from_net gcc-c++"

INST_GUIDE["ctags"]="${CMD1};install_from_tar ctags-*.tar.gz;rm -fr ctags-*/"
INST_GUIDE["cscope"]="${CMD1};install_from_tar cscope-*.tar.gz;rm -fr cscope-*/"
INST_GUIDE["tig"]="${CMD1};install_from_tar tig-*.tar.gz;rm -fr tig-*/"
INST_GUIDE["ag"]="${CMD1};install_from_tar the_silver_searcher-*.tar.gz;rm -fr the_silver_searcher-*/"

INST_GUIDE["glibc-2.18"]="${CMD1};install_from_tar glibc-2.18.tar.gz;rm -fr glibc-2.18/"
INST_GUIDE["glibc-common"]="${CMD1};install_from_rpm glibc-common-.+\.rpm"

INST_GUIDE["m4"]="${CMD1};install_from_tar m4-*.tar.gz;rm -fr m4-*/"
INST_GUIDE["autoconf"]="${CMD1};install_from_tar autoconf-*.tar.gz;rm -fr autoconf-*/"
INST_GUIDE["automake"]="${CMD1};install_from_tar automake-*.tar.gz;rm -fr automake-*/"
INST_GUIDE["sshpass"]="${CMD1};install_from_tar sshpass-*.tar.gz;rm -fr sshpass-*/"
INST_GUIDE["tclsh8.6"]="${CMD1};install_from_tar tcl*-src.tar.gz"
INST_GUIDE["expect"]="${CMD1};install_from_tar expect*.tar.gz;rm -fr expect*/;rm -fr tcl*/"
INST_GUIDE["unzip"]="${CMD1};install_from_rpm unzip-.+\.rpm"

INST_GUIDE["ss"]="${CMD1};install_from_rpm iproute-.+\.rpm"
INST_GUIDE["rsync"]="${CMD1};install_from_rpm rsync-.+\.rpm"
INST_GUIDE["nc"]="${CMD1};install_from_rpm nmap-ncat-.+\.rpm"
INST_GUIDE["m4"]="${CMD1};install_from_rpm m4-.+\.rpm"
INST_GUIDE["autoconf"]="${CMD1};install_from_rpm autoconf-.+\.rpm"
INST_GUIDE["automake"]="${CMD1};install_from_rpm automake-.+\.rpm"
INST_GUIDE["ag"]="${CMD1};install_from_rpm the_silver_searcher-.+\.rpm"

INST_GUIDE["/usr/lib64/libssl.so.10"]="${CMD1};install_from_rpm compat-openssl10-.+\.rpm"
INST_GUIDE["/usr/bin/python-config"]="${CMD1};install_from_rpm python-devel.+\.rpm"
INST_GUIDE["/usr/lib64/libpython2.7.so.1.0"]="${CMD1};install_from_rpm python-libs.+\.rpm"
INST_GUIDE["/usr/bin/python3-config"]="${CMD1};install_from_rpm python3-devel.+\.rpm"
INST_GUIDE["/usr/lib64/libpython3.so"]="${CMD1};install_from_rpm python3-libs-.+\.rpm"
INST_GUIDE["/usr/lib64/liblzma.so.5"]="${CMD1};install_from_rpm xz-libs.+\.rpm"
INST_GUIDE["/usr/lib64/liblzma.so"]="${CMD1};install_from_rpm xz-devel.+\.rpm"
INST_GUIDE["/usr/libiconv/lib64/libiconv.so.2"]="${CMD1};install_from_rpm libiconv-1.+\.rpm"
INST_GUIDE["/usr/libiconv/lib64/libiconv.so"]="${CMD1};install_from_rpm libiconv-devel.+\.rpm"
INST_GUIDE["/usr/lib64/libpcre.so.1"]="${CMD1};install_from_rpm pcre-8.+\.rpm"
INST_GUIDE["/usr/lib64/libpcre.so"]="${CMD1};install_from_rpm pcre-devel.+\.rpm"
#INST_GUIDE["/usr/lib64/libpcrecpp.so.0"]="${CMD1};install_from_rpm pcre-cpp.+\.rpm"
#INST_GUIDE["/usr/lib64/libpcre16.so.0"]="${CMD1};install_from_rpm pcre-utf16.+\.rpm"
#INST_GUIDE["/usr/lib64/libpcre32.so.0"]="${CMD1};install_from_rpm pcre-utf32.+\.rpm"
INST_GUIDE["/usr/lib64/libncurses.so"]="${CMD1};install_from_rpm ncurses-devel.+\.rpm"
INST_GUIDE["/usr/lib64/libncurses.so.5"]="${CMD1};install_from_rpm ncurses-libs.+\.rpm"
INST_GUIDE["/usr/lib64/libz.so.1"]="${CMD1};install_from_rpm zlib-1.+\.rpm"
INST_GUIDE["/usr/lib64/libz.so"]="${CMD1};install_from_rpm zlib-devel.+\.rpm"
INST_GUIDE["/usr/share/doc/perl-Data-Dumper"]="${CMD1};install_from_rpm perl-Data-Dumper-2.167.+\.rpm"
INST_GUIDE["/usr/share/doc/perl-Thread-Queue-3.02"]="${CMD1};install_from_rpm perl-Thread-Queue-.+\.rpm"
INST_GUIDE["locale"]="${CMD1};install_from_rpm glibc-common-.+\.rpm"
#INST_GUIDE["/usr/lib/golang/api"]="${CMD1};install_from_rpm golang-1.+\.rpm"
#INST_GUIDE["/usr/lib/golang/src"]="${CMD1};install_from_rpm golang-src-.+\.rpm"
#INST_GUIDE["/usr/lib/golang/bin"]="${CMD1};install_from_rpm golang-bin-.+\.rpm"

FUNC_MAP["env"]="inst_env"
FUNC_MAP["update"]="inst_update"
FUNC_MAP["clean"]="clean_env"
FUNC_MAP["vim"]="inst_vim"
FUNC_MAP["ctags"]="inst_ctags"
FUNC_MAP["cscope"]="inst_cscope"
FUNC_MAP["tig"]="inst_tig"
FUNC_MAP["ack"]="inst_ack"
FUNC_MAP["astyle"]="inst_astyle"
FUNC_MAP["system"]="inst_system"
FUNC_MAP["deps"]="inst_deps"
FUNC_MAP["all"]="inst_deps inst_ctags inst_cscope inst_vim inst_tig inst_astyle inst_ack clean_env inst_env inst_system"
FUNC_MAP["glibc2.18"]="inst_glibc"

function do_action
{     
    local check_arr=($*)

    for usr_cmd in ${check_arr[*]};
    do
        if ! can_access "${usr_cmd}";then
            local guides="${INST_GUIDE["${usr_cmd}"]}"
            local total=$(echo "${guides}" | awk -F';' '{ print NF }')

            for (( idx = 1; idx <= ${total}; idx++))
            do
                local action=$(echo "${guides}" | awk -F';' "{ print \$${idx} }")         
                echo_debug "${action}"
                eval "${action}"
                if [ $? -ne 0 ];then
                    exit 1
                fi
            done
        fi
    done
}

function version_gt() { array_cmp "$(echo "$1" | tr '.' ' ')" "$(echo "$2" | tr '.' ' ')"; [ $? -eq 1 ]; }
function version_lt() { array_cmp "$(echo "$1" | tr '.' ' ')" "$(echo "$2" | tr '.' ' ')"; [ $? -eq 255 ]; }
function version_eq() { array_cmp "$(echo "$1" | tr '.' ' ')" "$(echo "$2" | tr '.' ' ')"; [ $? -eq 0 ]; }

function update_check
{
    local local_cmd="$1"
    local fname_reg="$2"

    if can_access "${local_cmd}";then
        local tmp_file="$(temp_file)"
        ${local_cmd} --version &> ${tmp_file} 
        if [ $? -ne 0 ];then
            return 1
        fi

        local version_cur=$(grep -P "\d+\.\d+" -o ${tmp_file} | head -n 1)
        rm -f ${tmp_file}
        local local_dir=$(pwd)
        cd ${ROOT_DIR}/deps

        local file_list=$(find . -regextype posix-awk  -regex "\.?/?${fname_reg}")
        for full_nm in ${file_list}    
        do
            local file_name=$(path2fname ${full_nm})
            echo_debug "local version: ${version_cur}  install version: ${file_name}"

            local version_new=$(echo "${file_name}" | grep -P "\d+\.\d+(\.\d+)*" -o)
            if version_lt ${version_cur} ${version_new}; then
                cd ${local_dir}
                return 0
            fi
        done

        cd ${local_dir}
        return 1
    else
        return 0
    fi
}

function inst_usage
{
    echo "=================== Usage ==================="
    echo "install.sh -n true       @all installation packages from net"
    echo "install.sh -r true       @install packages into other host in '/etc/hosts'"
    echo "install.sh -o clean      @clean vim environment"
    echo "install.sh -o env        @deploy vim's usage environment"
    echo "install.sh -o vim        @install vim package"
    echo "install.sh -o tig        @install tig package"
    echo "install.sh -o astyle     @install astyle package"
    echo "install.sh -o ack        @install ack package"
    echo "install.sh -o glibc2.18  @install glibc2.18 package"
    echo "install.sh -o system     @configure run system: linux & windows"
    echo "install.sh -o deps       @install all rpm package being depended on"
    echo "install.sh -o all        @install all vim's package"
    echo "install.sh -j num        @install with thread-num"

    echo ""
    echo "=================== Opers ==================="
    for key in ${!FUNC_MAP[@]};
    do
        printf "Op: %-10s Funcs: %s\n" ${key} "${FUNC_MAP[${key}]}"
    done
}

source $MY_VIM_DIR/bashrc
. ${ROOT_DIR}/tools/paraparser.sh

declare -a mustDeps=("ppid" "fstat" "unzip" "m4" "autoconf" "automake" "sshpass" "tclsh8.6" "expect")
do_action "${mustDeps[*]}"

REMOTE_INST="${parasMap['-r']}"
REMOTE_INST="${REMOTE_INST:-${parasMap['--remote']}}"
REMOTE_INST="${REMOTE_INST:-0}"

NEED_OP="${parasMap['-o']}"
NEED_OP="${NEED_OP:-${parasMap['--op']}}"
NEED_OP="${NEED_OP:?'Please specify -o option'}"

MAKE_TD=${parasMap['-j']:-8}

NEED_NET="${parasMap['-n']}"
NEED_NET="${NEED_NET:-${parasMap['--net']}}"
NEED_NET="${NEED_NET:-0}"

OP_MATCH=0
for func in ${!FUNC_MAP[*]};
do
    if contain_str "${NEED_OP}" "${func}"; then
        let OP_MATCH=OP_MATCH+1
    fi
done

if [ ${OP_MATCH} -eq ${#FUNC_MAP[*]} ]; then
    echo_erro "unkown op: ${NEED_OP}"
    echo ""
    inst_usage
    exit -1
fi

echo_info "$(printf "[%13s]: %-6s" "Install Ops" "${NEED_OP}")"
echo_info "$(printf "[%13s]: %-6s" "Make Thread" "${MAKE_TD}")"
echo_info "$(printf "[%13s]: %-6s" "Need Netwrk" "${NEED_NET}")"
echo_info "$(printf "[%13s]: %-6s" "Remote Inst" "${REMOTE_INST}")"

if bool_v "${NEED_NET}"; then
    if check_net; then
        NEED_NET=1
        echo_info "$(printf "[%13s]: %-6s" "Netwk ping" "Ok")"
    else
        NEED_NET=0
        echo_info "$(printf "[%13s]: %-6s" "Netwk ping" "Fail")"
    fi
fi

CMD_PRE="my"
declare -A commandMap
commandMap["${CMD_PRE}sudo"]="${ROOT_DIR}/tools/sudo.sh"
commandMap["${CMD_PRE}loop"]="${ROOT_DIR}/tools/loop.sh"
commandMap["${CMD_PRE}progress"]="${ROOT_DIR}/tools/progress.sh"
commandMap["${CMD_PRE}collect"]="${ROOT_DIR}/tools/collect.sh"
commandMap["${CMD_PRE}stop"]="${ROOT_DIR}/tools/stop_p.sh"
commandMap["${CMD_PRE}scplogin"]="${ROOT_DIR}/tools/scplogin.sh"
commandMap["${CMD_PRE}scphosts"]="${ROOT_DIR}/tools/scphosts.sh"
commandMap["${CMD_PRE}sshlogin"]="${ROOT_DIR}/tools/sshlogin.sh"
commandMap["${CMD_PRE}sshhosts"]="${ROOT_DIR}/tools/sshhosts.sh"
commandMap["${CMD_PRE}gitloop"]="${ROOT_DIR}/tools/gitloop.sh"
commandMap["${CMD_PRE}gitdiff"]="${ROOT_DIR}/tools/gitdiff.sh"
commandMap["${CMD_PRE}syndir"]="${ROOT_DIR}/tools/sync_dir.sh"
commandMap["${CMD_PRE}threads"]="${ROOT_DIR}/tools/threads.sh"
commandMap["${CMD_PRE}paraparser"]="${ROOT_DIR}/tools/paraparser.sh"
commandMap["${CMD_PRE}replace"]="${ROOT_DIR}/tools/replace.sh"

commandMap[".vimrc"]="${ROOT_DIR}/vimrc"
commandMap[".minttyrc"]="${ROOT_DIR}/minttyrc"
commandMap[".inputrc"]="${ROOT_DIR}/inputrc"
commandMap[".astylerc"]="${ROOT_DIR}/astylerc"

function clean_env
{
    for linkf in ${!commandMap[@]};
    do
        local link_file=${commandMap["${linkf}"]}
        echo_debug "remove slink: ${linkf}"
        if [[ ${linkf:0:1} == "." ]];then
            can_access "${MY_HOME}/${linkf}" && rm -f ${MY_HOME}/${linkf}
        else
            can_access "${BIN_DIR}/${linkf}" && ${SUDO} rm -f ${BIN_DIR}/${linkf}
        fi
    done

    can_access "${MY_HOME}/.bashrc" && sed -i "/source.\+\/bashrc/d" ${MY_HOME}/.bashrc
    can_access "${MY_HOME}/.bashrc" && sed -i "/export.\+MY_VIM_DIR.\+/d" ${MY_HOME}/.bashrc
    can_access "${MY_HOME}/.bashrc" && sed -i "/export.\+TEST_SUIT_ENV.\+/d" ${MY_HOME}/.bashrc
    #can_access "${MY_HOME}/.bash_profile" && sed -i "/source.\+\/bash_profile/d" ${MY_HOME}/.bash_profile
}

function inst_env
{ 
    for linkf in ${!commandMap[@]};
    do
        local link_file=${commandMap["${linkf}"]}
        echo_debug "create slink: ${linkf}"
        if [[ ${linkf:0:1} == "." ]];then
            can_access "${MY_HOME}/${linkf}" && rm -f ${MY_HOME}/${linkf}
            ln -s ${link_file} ${MY_HOME}/${linkf}
        else
            can_access "${BIN_DIR}/${linkf}" && ${SUDO} rm -f ${BIN_DIR}/${linkf}
            ${SUDO} ln -s ${link_file} ${BIN_DIR}/${linkf}
        fi
    done
  
    cd ${ROOT_DIR}/deps

    # build vim-work environment
    mkdir -p ${MY_HOME}/.vim

    cp -fr ${ROOT_DIR}/colors ${MY_HOME}/.vim
    cp -fr ${ROOT_DIR}/syntax ${MY_HOME}/.vim

    if ! can_access "${MY_HOME}/.vim/bundle/vundle"; then
        cd ${ROOT_DIR}/deps
        if [ -f bundle.tar.gz ]; then
            tar -xzf bundle.tar.gz
            mv -f bundle ${MY_HOME}/.vim/
        fi
    fi
    
    can_access "${MY_HOME}/.bashrc" || can_access "/etc/skel/.bashrc" && cp -f /etc/skel/.bashrc ${MY_HOME}/.bashrc
    can_access "${MY_HOME}/.bash_profile" || can_access "/etc/skel/.bash_profile" && cp -f /etc/skel/.bash_profile ${MY_HOME}/.bash_profile

    can_access "${MY_HOME}/.bashrc" || touch ${MY_HOME}/.bashrc
    #can_access "${MY_HOME}/.bash_profile" || touch ${MY_HOME}/.bash_profile

    sed -i "/export.\+MY_VIM_DIR.\+/d" ${MY_HOME}/.bashrc
    sed -i "/export.\+TEST_SUIT_ENV.\+/d" ${MY_HOME}/.bashrc
    sed -i "/source.\+\/bashrc/d" ${MY_HOME}/.bashrc
    #sed -i "/source.\+\/bash_profile/d" ${MY_HOME}/.bash_profile

    echo "export MY_VIM_DIR=\"${ROOT_DIR}\"" >> ${MY_HOME}/.bashrc
    echo "export TEST_SUIT_ENV=\"${MY_HOME}/.testrc\"" >> ${MY_HOME}/.bashrc
    echo "source ${ROOT_DIR}/bashrc" >> ${MY_HOME}/.bashrc
    #echo "source ${ROOT_DIR}/bash_profile" >> ${MY_HOME}/.bash_profile
    
    if can_access "/var/spool/cron/$(whoami)";then
        sed -i "/.\+timer\.sh/d" /var/spool/cron/$(whoami)
        echo "*/1 * * * * ${MY_VIM_DIR}/timer.sh" >> /var/spool/cron/$(whoami)
    else
        ${SUDO} "echo '*/1 * * * * ${MY_VIM_DIR}/timer.sh' > /var/spool/cron/$(whoami)"
    fi
    ${SUDO} chmod 0644 /var/spool/cron/$(whoami) 
    ${SUDO} systemctl restart crond
}

function inst_update
{
    if bool_v "${NEED_NET}"; then
        local need_update=1
        if can_access "${MY_HOME}/.vim/bundle/vundle"; then
            git clone https://github.com/gmarik/vundle.git ${MY_HOME}/.vim/bundle/vundle
            vim +BundleInstall +q +q
            need_update=0
        fi

        if [ ${need_update} -eq 1 ]; then
            vim +BundleUpdate +q +q
        fi
    fi
}

function inst_deps
{
    local rid_arr=(glibc-2.18 glibc-common)
    local -A inst_map

    for key in ${!INST_GUIDE[*]}
    do
        inst_map[${key}]="${INST_GUIDE["${key}"]}"
    done

    for key in ${rid_arr[*]}
    do
        unset inst_map[${key}]
    done

    do_action ${!inst_map[*]}
}

function inst_system
{     
    cd ${ROOT_DIR}/deps
    if [[ "$(string_start $(uname -s) 5)" == "Linux" ]]; then
        ${SUDO} chmod 777 /etc/ld.so.conf

        ${SUDO} "sed -i '#/usr/local/lib#d' /etc/ld.so.conf"
        ${SUDO} "sed -i '#/home/.\+/.local/lib#d' /etc/ld.so.conf"

        ${SUDO} "echo '/usr/local/lib' >> /etc/ld.so.conf"
        ${SUDO} "echo '${MY_HOME}/.local/lib' >> /etc/ld.so.conf"
        ${SUDO} ldconfig
    elif [[ "$(string_start $(uname -s) 9)" == "CYGWIN_NT" ]]; then
        # Install deno
        unzip deno-x86_64-pc-windows-msvc.zip
        mv -f deno.exe ${BIN_DIR}
        chmod +x ${BIN_DIR}/deno.exe
        
        cp -f apt-cyg ${BIN_DIR}
        chmod +x ${BIN_DIR}/apt-cyg
    fi 
}

function inst_ctags
{
    if bool_v "${NEED_NET}"; then
        git clone https://github.com/universal-ctags/ctags.git ctags
    else
        do_action "ctags"
    fi
}

function inst_cscope
{
    if bool_v "${NEED_NET}"; then
        git clone https://git.code.sf.net/p/cscope/cscope cscope
    else
        do_action "cscope"
    fi
}

function inst_vim
{
    if ! update_check "vim" "vim-.*\.tar\.gz";then
        return 0     
    fi

    cd ${ROOT_DIR}/deps

    if bool_v "${NEED_NET}"; then
        git clone https://github.com/vim/vim.git vim
    else
        tar -xzf vim-*.tar.gz
    fi

    cd vim*/

    echo_info "$(printf "[%13s]: %-50s" "Doing" "configure")"
    ./configure --prefix=/usr --with-features=huge --enable-cscope --enable-multibyte --enable-fontset \
        --enable-largefile \
        --enable-pythoninterp=yes \
        --enable-python3interp=yes \
        --disable-gui --disable-netbeans &>> build.log
        #--enable-luainterp=yes \
    if [ $? -ne 0 ]; then
        echo_erro "Configure: vim fail"
        exit -1
    fi

    echo_info "$(printf "[%13s]: %-50s" "Doing" "make")"
    make -j ${MAKE_TD} &>> build.log
    if [ $? -ne 0 ]; then
        echo_erro "Make: vim fail"
        exit -1
    fi

    echo_info "$(printf "[%13s]: %-50s" "Doing" "make install")"
    ${SUDO} "make install &>> build.log"
    if [ $? -ne 0 ]; then
        echo_erro "Install: vim fail"
        exit -1
    fi

    cd ${ROOT_DIR}/deps
    rm -fr vim*/

    ${SUDO} rm -f /usr/local/bin/vim

    can_access "${BIN_DIR}/vim" && rm -f ${BIN_DIR}/vim
    ${SUDO} ln -s /usr/bin/vim ${BIN_DIR}/vim
}

function inst_tig
{
    cd ${ROOT_DIR}/deps

    if bool_v "${NEED_NET}"; then
        git clone https://github.com/jonas/tig.git tig
    else
        do_action "tig"
    fi
}

function inst_astyle
{
    if ! update_check "astyle" "astyle.*\.tar\.gz";then
        return 0     
    fi

    cd ${ROOT_DIR}/deps

    if bool_v "${NEED_NET}"; then
        svn checkout https://svn.code.sf.net/p/astyle/code/trunk astyle
        cd astyle*/AStyle/build/gcc
    else
        tar -xzf astyle_*.tar.gz
        cd astyle*/build/gcc
    fi

    echo_info "$(printf "[%13s]: %-50s" "Doing" "make")"
    make -j ${MAKE_TD}
    if [ $? -ne 0 ]; then
        echo_erro "Make: astyle fail"
        exit -1
    fi

    cp -f bin/astyle* ${BIN_DIR}
    chmod 777 ${BIN_DIR}/astyle*

    cd ${ROOT_DIR}/deps
    rm -fr astyle*/
}

function inst_ack
{
    # install ack
    cd ${ROOT_DIR}/deps

    cp -f ack-* ${BIN_DIR}/ack-grep
    chmod 777 ${BIN_DIR}/ack-grep
    
    # install ag
    if bool_v "${NEED_NET}"; then
        git clone https://github.com/ggreer/the_silver_searcher.git the_silver_searcher
    else
        do_action "ag"
    fi
}

function inst_glibc
{
    # install ack
    cd ${ROOT_DIR}/deps

    local version_cur=`getconf GNU_LIBC_VERSION | grep -P "\d+\.\d+" -o`
    local version_new=2.18

    if version_lt ${version_cur} ${version_new}; then
        # Install glibc
        do_action "glibc-2.18"
        do_action "glibc-common"

        ${SUDO} "echo 'LANG=en_US.UTF-8' >> /etc/environment"
        ${SUDO} "echo 'LC_ALL=' >> /etc/environment"
        ${SUDO} "localedef -v -c -i en_US -f UTF-8 en_US.UTF-8 &> /dev/null"
    fi
}

if ! bool_v "${REMOTE_INST}"; then
    for key in ${!FUNC_MAP[*]};
    do
        if contain_str "${NEED_OP}" "${key}"; then
            echo_info "$(printf "[%13s]: %-6s" "Op" "${key}")"
            echo_info "$(printf "[%13s]: %-6s" "Funcs" "${FUNC_MAP[${key}]}")"
            for func in ${FUNC_MAP[${key}]};
            do
                echo_info "$(printf "[%13s]: %-13s start" "Install" "${func}")"
                ${func}
                echo_info "$(printf "[%13s]: %-13s done" "Install" "${func}")"
            done
        fi
    done
else
    declare -A routeMap
    declare -a ip_array=($(echo "${other_paras[*]}" | grep -P "\d+\.\d+\.\d+\.\d+" -o))
    if [ -z "${ip_array[*]}" ];then
        declare -i count=0
        while read line
        do
            ipaddr=$(echo "${line}" | awk '{ print $1 }')
            hostnm=$(echo "${line}" | awk '{ print $2 }')
            match_regex ""${ipaddr}"" "^\d+\.\d+\.\d+\.\d+$" || continue

            [ -z "${ipaddr}" ] && continue 
            echo_info "HostName: ${hostnm} IP: ${ipaddr}"

            if ip addr | grep -F "${ipaddr}" &> /dev/null;then
                continue
            fi

            if ! contain_str "${ip_array[*]}" "${ipaddr}";then
                ip_array[${count}]="${ipaddr}"
                routeMap[${ipaddr}]="${hostnm}"
                let count++
            fi
        done < /etc/hosts
    else
        for ipaddr in ${ip_array[*]}
        do
            hostnm=$(cat /etc/hosts | grep -F "${ipaddr}" | awk '{ print $2 }')
            routeMap[${ipaddr}]="${hostnm}"
        done
    fi
    echo_info "Remote install into { ${ip_array[*]} }"

    inst_paras=""
    for key in ${!parasMap[*]}
    do
        if match_regex "${key}" "\-?\-r[a-zA-Z]*";then
            continue
        fi

        if [ -n "${inst_paras}" ];then
            inst_paras="${inst_paras} ${key} ${parasMap[$key]}"
        else
            inst_paras="${inst_paras} ${key} ${parasMap[$key]}"
        fi
    done

    $MY_VIM_DIR/tools/collect.sh "/tmp/vim.tar"
    for ((idx=0; idx < ${#ip_array[@]}; idx++))
    do
        ipaddr="${ip_array[idx]}"
        echo_info "Install ${inst_paras} into { ${ipaddr} }"

        ${MY_VIM_DIR}/tools/sshlogin.sh "${ipaddr}" "${SUDO} hostnamectl set-hostname ${routeMap[${ipaddr}]}"
        ${MY_VIM_DIR}/tools/scplogin.sh "/tmp/vim.tar" "${ipaddr}:${MY_HOME}"
        ${MY_VIM_DIR}/tools/sshlogin.sh "${ipaddr}" "tar -xf ${MY_HOME}/vim.tar"
        ${MY_VIM_DIR}/tools/sshlogin.sh "${ipaddr}" "${MY_VIM_DIR}/install.sh ${inst_paras}"
    done
fi

#if can_access "git";then
#    git config --global user.email "9971289@qq.com"
#    git config --global user.name "Janvi Yao"
#    git config --global --unset http.proxy
#    git config --global --unset https.proxy
#fi
