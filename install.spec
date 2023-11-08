ppid;                                       cd ${ROOT_DIR}/tools/app;gcc ppid.c -g -o ppid;mv -f ppid ${BIN_DIR}
fstat;                                      cd ${ROOT_DIR}/tools/app;gcc fstat.c -g -o fstat;mv -f fstat ${BIN_DIR}
chk_passwd;                                 cd ${ROOT_DIR}/tools/app;gcc chk_passwd.c -g -lcrypt -o chk_passwd;mv -f chk_passwd ${BIN_DIR}
deno;                                       cd ${ROOT_DIR}/deps;unzip deno-x86_64-unknown-linux-gnu.zip;mv -f deno ${BIN_DIR}

make;                                       install_from_net make
g++;                                        install_from_net gcc-c++

ctags;                                      cd ${ROOT_DIR}/deps;install_from_tar 'universal-ctags-.+\.tar\.gz';rm -fr universal-ctags-*/
cscope;                                     cd ${ROOT_DIR}/deps;install_from_tar 'cscope-.+\.tar\.gz';rm -fr cscope-*/
tig;                                        cd ${ROOT_DIR}/deps;install_from_tar 'tig-.+\.tar\.gz';rm -fr tig-*/
#ag;                                        cd ${ROOT_DIR}/deps;install_from_tar 'the_silver_searcher-.+\.tar\.gz';rm -fr the_silver_searcher-*/
ag;                                         cd ${ROOT_DIR}/deps;install_from_rpm 'the_silver_searcher-.+\.rpm'

glibc-2.28;                                 cd ${ROOT_DIR}/deps;install_from_tar 'glibc-2.28.tar.xz';rm -fr glibc-2.28/
glibc-common;                               cd ${ROOT_DIR}/deps;install_from_rpm 'glibc-common-.+\.rpm'

m4;                                         cd ${ROOT_DIR}/deps;install_from_tar 'm4-.+\.tar\.gz';rm -fr m4-*/
autoconf;                                   cd ${ROOT_DIR}/deps;install_from_tar 'autoconf-.+\.tar\.gz';rm -fr autoconf-*/
automake;                                   cd ${ROOT_DIR}/deps;install_from_tar 'automake-.+\.tar\.gz';rm -fr automake-*/
sshpass;                                    cd ${ROOT_DIR}/deps;install_from_tar 'sshpass-.+\.tar\.gz';rm -fr sshpass-*/
tclsh8.6;                                   cd ${ROOT_DIR}/deps;install_from_tar 'tcl.+\.tar\.gz';rm -fr tcl*/
expect;                                     cd ${ROOT_DIR}/deps;install_from_tar 'tcl.+\.tar\.gz';cd ${ROOT_DIR}/deps;install_from_tar 'expect.+\.tar\.gz';rm -fr expect*/;rm -fr tcl*/
unzip;                                      cd ${ROOT_DIR}/deps;install_from_rpm 'unzip-.+\.rpm'

netperf;                                    cd ${ROOT_DIR}/deps;install_from_tar 'netperf-.+\.tar\.gz';rm -fr netperf-*/
perf;                                       install_from_net perf
atop;                                       cd ${ROOT_DIR}/deps;install_from_rpm 'atop-.+\.rpm'
iperf3;                                     cd ${ROOT_DIR}/deps;install_from_rpm 'iperf3-.+\.rpm'
ss;                                         cd ${ROOT_DIR}/deps;install_from_rpm 'iproute-.+\.rpm'
rsync;                                      cd ${ROOT_DIR}/deps;install_from_rpm 'rsync-.+\.rpm'
nc;                                         cd ${ROOT_DIR}/deps;install_from_rpm 'nmap-ncat-.+\.rpm'
m4;                                         cd ${ROOT_DIR}/deps;install_from_rpm 'm4-.+\.rpm'
sar;                                        cd ${ROOT_DIR}/deps;install_from_rpm 'sysstat-.+\.rpm'
autoconf;                                   cd ${ROOT_DIR}/deps;install_from_rpm 'autoconf-.+\.rpm'
automake;                                   cd ${ROOT_DIR}/deps;install_from_rpm 'automake-.+\.rpm'

/usr/libexec/sudo/libsudo_util.so.0;        cd ${ROOT_DIR}/deps;install_from_rpm 'sudo-.+\.rpm'
/lib64/libreadline.so.6;                    cd ${ROOT_DIR}/deps;install_from_rpm 'readline-.+\.rpm'
/usr/include/readline;                      cd ${ROOT_DIR}/deps;install_from_rpm 'readline-devel-.+\.rpm'
/usr/lib64/libssl.so.10;                    cd ${ROOT_DIR}/deps;install_from_rpm 'compat-openssl10-.+\.rpm'
/usr/bin/python-config;                     cd ${ROOT_DIR}/deps;install_from_rpm 'python-devel.+\.rpm'
/usr/lib64/libpython2.7.so.1.0;             cd ${ROOT_DIR}/deps;install_from_rpm 'python-libs.+\.rpm'
/usr/bin/python3-config;                    cd ${ROOT_DIR}/deps;install_from_rpm 'python3-devel.+\.rpm'
/usr/lib64/libpython3.so;                   cd ${ROOT_DIR}/deps;install_from_rpm 'python3-libs-.+\.rpm'
/usr/lib64/liblzma.so.5;                    cd ${ROOT_DIR}/deps;install_from_rpm 'xz-libs.+\.rpm'
/usr/lib64/liblzma.so;                      cd ${ROOT_DIR}/deps;install_from_rpm 'xz-devel.+\.rpm'
/usr/libiconv/lib64/libiconv.so.2;          cd ${ROOT_DIR}/deps;install_from_rpm 'libiconv-1.+\.rpm'
/usr/libiconv/lib64/libiconv.so;            cd ${ROOT_DIR}/deps;install_from_rpm 'libiconv-devel.+\.rpm'
/usr/lib64/libpcre.so.1;                    cd ${ROOT_DIR}/deps;install_from_rpm 'pcre-8.+\.rpm'
/usr/lib64/libpcre.so;                      cd ${ROOT_DIR}/deps;install_from_rpm 'pcre-devel.+\.rpm'
#/usr/lib64/libpcrecpp.so.0;                cd ${ROOT_DIR}/deps;install_from_rpm 'pcre-cpp.+\.rpm'
#/usr/lib64/libpcre16.so.0;                 cd ${ROOT_DIR}/deps;install_from_rpm 'pcre-utf16.+\.rpm'
#/usr/lib64/libpcre32.so.0;                 cd ${ROOT_DIR}/deps;install_from_rpm 'pcre-utf32.+\.rpm'
/usr/share/terminfo/x/xterm;                cd ${ROOT_DIR}/deps;install_from_rpm 'ncurses-base.+\.rpm'
/usr/lib64/libncurses.so.5;                 cd ${ROOT_DIR}/deps;install_from_rpm 'ncurses-libs.+\.rpm'
/usr/lib64/libncurses.so;                   cd ${ROOT_DIR}/deps;install_from_rpm 'ncurses-devel.+\.rpm'
/usr/lib64/libz.so.1;                       cd ${ROOT_DIR}/deps;install_from_rpm 'zlib-1.+\.rpm'
/usr/lib64/libz.so;                         cd ${ROOT_DIR}/deps;install_from_rpm 'zlib-devel.+\.rpm'
/usr/share/doc/perl-Data-Dumper;            cd ${ROOT_DIR}/deps;install_from_rpm 'perl-Data-Dumper-2.167.+\.rpm'
/usr/share/doc/perl-Thread-Queue-3.02;      cd ${ROOT_DIR}/deps;install_from_rpm 'perl-Thread-Queue-.+\.rpm'
locale;                                     cd ${ROOT_DIR}/deps;install_from_rpm 'glibc-common-.+\.rpm'
#/usr/lib/golang/api;                       cd ${ROOT_DIR}/deps;install_from_rpm 'golang-1.+\.rpm'
#/usr/lib/golang/src;                       cd ${ROOT_DIR}/deps;install_from_rpm 'golang-src-.+\.rpm'
#/usr/lib/golang/bin;                       cd ${ROOT_DIR}/deps;install_from_rpm 'golang-bin-.+\.rpm'
