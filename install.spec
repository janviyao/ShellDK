bash;                install_check 'bash' 'bash-.+\.tar\.gz' true;cd ${MY_VIM_DIR}/deps;install_from_tar 'bash-.+\.tar\.gz' true;rm -fr bash-*/
make-3.82;           install_check 'make' 'make-.+\.rpm' true;cd ${MY_VIM_DIR}/deps/packages;install_from_rpm 'make-.+\.rpm' true
make-4.3;            install_check 'make' 'make-.+\.tar\.gz' true;cd ${MY_VIM_DIR}/deps;install_from_tar 'make-.+\.tar\.gz' true;rm -fr make-*/
autoconf;            install_check 'autoconf' 'autoconf-.+\.tar\.gz' true;cd ${MY_VIM_DIR}/deps;install_from_tar 'autoconf-.+\.tar\.gz' true;rm -fr autoconf-*/
automake;            install_check 'automake' 'automake-.+\.tar\.gz' true;cd ${MY_VIM_DIR}/deps;install_from_tar 'automake-.+\.tar\.gz' true;rm -fr automake-*/
python3.12;          ! have_cmd 'python3.12';cd ${MY_VIM_DIR}/deps;install_from_tar 'Python-3.12.11.tgz' false '--enable-shared';sudo_it rm -fr Python-*/

gcc-4.9.2;           install_check 'gcc' 'gcc-.*\.tar\.gz' true;cd ${MY_VIM_DIR}/deps;wget -c http://ftp.gnu.org/gnu/gcc/gcc-4.9.2/gcc-4.9.2.tar.gz;install_from_tar 'gcc-.+\.tar\.gz' true '--prefix=/usr/local/gcc --enable-bootstrap --enable-checking=release --enable-languages=c,c++ --disable-multilib';rm -fr gcc-*/;sudo_it "echo 'export PATH=/usr/local/gcc/bin:$PATH' > /etc/profile.d/gcc.sh";source /etc/profile.d/gcc.sh
gcc-9.2.0;           install_check 'gcc' 'gcc-.*\.tar\.gz' true;cd ${MY_VIM_DIR}/deps;wget -c http://ftp.gnu.org/gnu/gcc/gcc-9.2.0/gcc-9.2.0.tar.gz;install_from_tar 'gcc-.+\.tar\.gz' true '--prefix=/usr/local/gcc --enable-bootstrap --enable-checking=release --enable-languages=c,c++ --disable-multilib';rm -fr gcc-*/;sudo_it "echo 'export PATH=/usr/local/gcc/bin:$PATH' > /etc/profile.d/gcc.sh";source /etc/profile.d/gcc.sh
glibc-common;        math_bool 'true';cd ${MY_VIM_DIR}/deps/packages;install_from_rpm 'glibc-common-.+\.rpm' true

ppid;                ! have_cmd 'ppid';cd ${MY_VIM_DIR}/tools/app;gcc ppid.c -g -o ppid;emove 'ppid(\.exe)?$' ${LOCAL_BIN_DIR};chmod +x ${LOCAL_BIN_DIR}/ppid*
fstat;               ! have_cmd 'fstat';cd ${MY_VIM_DIR}/tools/app;gcc fstat.c -g -o fstat;emove 'fstat(\.exe)?$' ${LOCAL_BIN_DIR};chmod +x ${LOCAL_BIN_DIR}/fstat*
perror;              ! have_cmd 'perror';cd ${MY_VIM_DIR}/tools/app;gcc perror.c -g -o perror;emove 'perror(\.exe)?$' ${LOCAL_BIN_DIR};chmod +x ${LOCAL_BIN_DIR}/perror*
chk_passwd;          ! have_cmd 'chk_passwd';cd ${MY_VIM_DIR}/tools/app;gcc chk_passwd.c -g -lcrypt -o chk_passwd;emove 'chk_passwd(\.exe)?$' ${LOCAL_BIN_DIR};chmod +x ${LOCAL_BIN_DIR}/chk_passwd*
cygwin.sudo;         ! have_cmd 'cygwin-sudo.py';cd ${MY_VIM_DIR}/deps/cygwin-sudo;cp -f cygwin-sudo.py ${LOCAL_BIN_DIR};chmod +x ${LOCAL_BIN_DIR}/cygwin-sudo.py

astyle;              install_check 'astyle' 'astyle-.+\.tar\.gz' true;cd ${MY_VIM_DIR}/deps;install_from_tar 'astyle.+\.tar\.gz' true;cp -f astyle*/build/gcc/bin/astyle* ${LOCAL_BIN_DIR};chmod 777 ${LOCAL_BIN_DIR}/astyle*;rm -fr astyle*/
ctags;               install_check 'ctags' 'universal-ctags-.+\.tar\.gz' true;cd ${MY_VIM_DIR}/deps;install_from_tar 'universal-ctags-.+\.tar\.gz' true;rm -fr universal-ctags-*/
cscope;              install_check 'cscope' 'cscope-.+\.tar\.gz' true;cd ${MY_VIM_DIR}/deps;install_from_tar 'cscope-.+\.tar\.gz' true;rm -fr cscope-*/
ag;                  install_check 'ag' 'the_silver_searcher-.+\.rpm' true;cd ${MY_VIM_DIR}/deps/packages;install_from_rpm 'the_silver_searcher-.+\.rpm' true
#ag;                 install_check 'ag' 'the_silver_searcher-.+\.tar\.gz' true;cd ${MY_VIM_DIR}/deps;install_from_tar 'the_silver_searcher-.+\.tar\.gz' true;rm -fr the_silver_searcher-*/
ack-grep;            ! have_cmd 'ack-grep';cd ${MY_VIM_DIR}/deps;cp -f ack-* ${LOCAL_BIN_DIR}/ack-grep;chmod +x ${LOCAL_BIN_DIR}/ack-grep
tig;                 install_check 'tig' 'tig-.+\.tar\.gz' true;cd ${MY_VIM_DIR}/deps;install_from_tar 'tig-.+\.tar\.gz' true;rm -fr tig-*/

sshpass;             install_check 'sshpass' 'sshpass-.+\.tar\.gz' true;cd ${MY_VIM_DIR}/deps;install_from_tar 'sshpass-.+\.tar\.gz' true;rm -fr sshpass-*/
tcl;                 ! have_cmd 'tclsh8.6';cd ${MY_VIM_DIR}/deps;install_from_tar 'tcl.+\.tar\.gz' true;rm -fr tcl*/
expect;              install_check 'expect' 'expect.+\.tar\.gz' true;cd ${MY_VIM_DIR}/deps;install_from_tar 'tcl.+\.tar\.gz' true;cd ${MY_VIM_DIR}/deps;install_from_tar 'expect.+\.tar\.gz' true;rm -fr expect*/;rm -fr tcl*/
unzip;               ! have_cmd 'unzip';cd ${MY_VIM_DIR}/deps/packages;install_from_rpm 'unzip-.+\.rpm' true

netperf;             install_check 'netperf' 'netperf-.+\.tar\.gz' true;cd ${MY_VIM_DIR}/deps;install_from_tar 'netperf-.+\.tar\.gz' true;rm -fr netperf-*/
atop;                ! have_cmd 'atop';cd ${MY_VIM_DIR}/deps/packages;install_from_rpm 'atop-.+\.rpm' true
iperf3;              install_check 'iperf3' 'iperf3-.+\.rpm' true;cd ${MY_VIM_DIR}/deps/packages;install_from_rpm 'iperf3-.+\.rpm' true
iproute;             ! have_cmd 'ss';cd ${MY_VIM_DIR}/deps/packages;install_from_rpm 'iproute-.+\.rpm' true
rsync;               install_check 'rsync' 'rsync-.+\.rpm' true;cd ${MY_VIM_DIR}/deps/packages;install_from_rpm 'rsync-.+\.rpm' true
nmap-ncat;           install_check 'nc' 'nmap-ncat-.+\.rpm' true;cd ${MY_VIM_DIR}/deps/packages;install_from_rpm 'nmap-ncat-.+\.rpm' true
sar;                 ! have_cmd 'sar';cd ${MY_VIM_DIR}/deps/packages;install_from_rpm 'sysstat-.+\.rpm' true

sudo;                ! file_exist '/usr/libexec/sudo/libsudo_util.so.0';cd ${MY_VIM_DIR}/deps/packages;install_from_rpm 'sudo-.+\.rpm' true
readline;            ! file_exist '/lib64/libreadline.so.6';cd ${MY_VIM_DIR}/deps/packages;install_from_rpm 'readline-.+\.rpm' true
readline-devel;      ! file_exist '/usr/include/readline';cd ${MY_VIM_DIR}/deps/packages;install_from_rpm 'readline-devel-.+\.rpm' true
compat-openssl10;    ! file_exist '/usr/lib64/libssl.so.10';cd ${MY_VIM_DIR}/deps/packages;install_from_rpm 'compat-openssl10-.+\.rpm' true
python-devel;        ! file_exist '/usr/bin/python-config';cd ${MY_VIM_DIR}/deps/packages;install_from_rpm 'python-devel.+\.rpm' true
python-libs;         ! file_exist '/usr/lib64/libpython2.7.so.1.0';cd ${MY_VIM_DIR}/deps/packages;install_from_rpm 'python-libs.+\.rpm' true
python3-devel;       ! file_exist '/usr/bin/python3-config';cd ${MY_VIM_DIR}/deps/packages;install_from_rpm 'python3-devel.+\.rpm' true
python3-libs;        ! file_exist '/usr/lib64/libpython3.so';cd ${MY_VIM_DIR}/deps/packages;install_from_rpm 'python3-libs-.+\.rpm' true
xz-libs;             ! file_exist '/usr/lib64/liblzma.so.5';cd ${MY_VIM_DIR}/deps/packages;install_from_rpm 'xz-libs.+\.rpm' true
xz-devel;            ! file_exist '/usr/lib64/liblzma.so';cd ${MY_VIM_DIR}/deps/packages;install_from_rpm 'xz-devel.+\.rpm' true
libiconv;            ! file_exist '/usr/libiconv/lib64/libiconv.so.2';cd ${MY_VIM_DIR}/deps/packages;install_from_rpm 'libiconv-1.+\.rpm' true
libiconv-devel;      ! file_exist '/usr/libiconv/lib64/libiconv.so';cd ${MY_VIM_DIR}/deps/packages;install_from_rpm 'libiconv-devel.+\.rpm' true
pcre;                ! file_exist '/usr/lib64/libpcre.so.1';cd ${MY_VIM_DIR}/deps/packages;install_from_rpm 'pcre-8.+\.rpm' true
pcre-devel;          ! file_exist '/usr/lib64/libpcre.so';cd ${MY_VIM_DIR}/deps/packages;install_from_rpm 'pcre-devel.+\.rpm' true
#pcre-cpp;           ! file_exist '/usr/lib64/libpcrecpp.so.0';cd ${MY_VIM_DIR}/deps/packages;install_from_rpm 'pcre-cpp.+\.rpm' true
#cpre-utf16;         ! file_exist '/usr/lib64/libpcre16.so.0';cd ${MY_VIM_DIR}/deps/packages;install_from_rpm 'pcre-utf16.+\.rpm' true
#pcre-utf32;         ! file_exist '/usr/lib64/libpcre32.so.0';cd ${MY_VIM_DIR}/deps/packages;install_from_rpm 'pcre-utf32.+\.rpm' true
ncurses-base;        ! file_exist '/usr/share/terminfo/x/xterm';cd ${MY_VIM_DIR}/deps/packages;install_from_rpm 'ncurses-base.+\.rpm' true
ncurses-libs;        ! file_exist '/usr/lib64/libncurses.so.5';cd ${MY_VIM_DIR}/deps/packages;install_from_rpm 'ncurses-libs.+\.rpm' true
ncurses-devel;       ! file_exist '/usr/lib64/libncurses.so';cd ${MY_VIM_DIR}/deps/packages;install_from_rpm 'ncurses-devel.+\.rpm' true
zlib;                ! file_exist '/usr/lib64/libz.so.1';cd ${MY_VIM_DIR}/deps/packages;install_from_rpm 'zlib-1.+\.rpm' true
zlib-devel;          ! file_exist '/usr/lib64/libz.so';cd ${MY_VIM_DIR}/deps/packages;install_from_rpm 'zlib-devel.+\.rpm' true
perl-Data-Dumper;    ! file_exist '/usr/share/doc/perl-Data-Dumper';cd ${MY_VIM_DIR}/deps/packages;install_from_rpm 'perl-Data-Dumper-2.167.+\.rpm' true
perl-Thread-Queue;   ! file_exist '/usr/share/doc/perl-Thread-Queue-3.02';cd ${MY_VIM_DIR}/deps/packages;install_from_rpm 'perl-Thread-Queue-.+\.rpm' true
locale;              ! file_exist 'locale';cd ${MY_VIM_DIR}/deps/packages;install_from_rpm 'glibc-common-.+\.rpm' true
m4;                  ! file_exist 'm4';cd ${MY_VIM_DIR}/deps;install_from_tar 'm4-.+\.tar\.gz' true;rm -fr m4-*/
#golang;             ! file_exist '/usr/lib/golang/api';cd ${MY_VIM_DIR}/deps/packages;install_from_rpm 'golang-1.+\.rpm' true
#golang-src;         ! file_exist '/usr/lib/golang/src';cd ${MY_VIM_DIR}/deps/packages;install_from_rpm 'golang-src-.+\.rpm' true
#golang-bin;         ! file_exist '/usr/lib/golang/bin';cd ${MY_VIM_DIR}/deps/packages;install_from_rpm 'golang-bin-.+\.rpm' true

