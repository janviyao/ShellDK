make;                                       install_from_net make
make.local;                                 cd ${MY_VIM_DIR}/deps;install_from_rpm 'make-.+\.rpm' true
g++;                                        install_from_net gcc-c++
gcc;                                        install_from_net gcc
gcc.local;                                  cd ${MY_VIM_DIR}/deps;wget -c http://ftp.gnu.org/gnu/gcc/gcc-4.9.2/gcc-4.9.2.tar.gz;install_from_tar 'gcc-.+\.tar\.gz' true '--prefix=/usr/local/gcc --enable-bootstrap --enable-checking=release --enable-languages=c,c++ --disable-multilib';rm -fr gcc-*/;sudo_it "echo 'export PATH=/usr/local/gcc/bin:$PATH' > /etc/profile.d/gcc.sh";source /etc/profile.d/gcc.sh

ppid;                                       cd ${MY_VIM_DIR}/tools/app;gcc ppid.c -g -o ppid;mv -f ppid ${LOCAL_BIN_DIR}
fstat;                                      cd ${MY_VIM_DIR}/tools/app;gcc fstat.c -g -o fstat;mv -f fstat ${LOCAL_BIN_DIR}
chk_passwd;                                 cd ${MY_VIM_DIR}/tools/app;gcc chk_passwd.c -g -lcrypt -o chk_passwd;mv -f chk_passwd ${LOCAL_BIN_DIR}

deno;                                       cd ${MY_VIM_DIR}/deps;unzip deno-x86_64-unknown-linux-gnu.zip;mv -f deno ${LOCAL_BIN_DIR}
ctags;                                      cd ${MY_VIM_DIR}/deps;install_from_tar 'universal-ctags-.+\.tar\.gz' true;rm -fr universal-ctags-*/
cscope;                                     cd ${MY_VIM_DIR}/deps;install_from_tar 'cscope-.+\.tar\.gz' true;rm -fr cscope-*/
tig;                                        cd ${MY_VIM_DIR}/deps;install_from_tar 'tig-.+\.tar\.gz' true;rm -fr tig-*/
ag;                                         cd ${MY_VIM_DIR}/deps;install_from_rpm 'the_silver_searcher-.+\.rpm' true
#ag;                                         cd ${MY_VIM_DIR}/deps;install_from_tar 'the_silver_searcher-.+\.tar\.gz' true;rm -fr the_silver_searcher-*/

glibc-2.28;                                 cd ${MY_VIM_DIR}/deps;install_from_tar 'glibc-2.28.tar.xz' true;rm -fr glibc-2.28/
glibc-common;                               cd ${MY_VIM_DIR}/deps;install_from_rpm 'glibc-common-.+\.rpm' true

m4;                                         cd ${MY_VIM_DIR}/deps;install_from_tar 'm4-.+\.tar\.gz' true;rm -fr m4-*/
autoconf;                                   cd ${MY_VIM_DIR}/deps;install_from_tar 'autoconf-.+\.tar\.gz' true;rm -fr autoconf-*/
automake;                                   cd ${MY_VIM_DIR}/deps;install_from_tar 'automake-.+\.tar\.gz' true;rm -fr automake-*/
sshpass;                                    cd ${MY_VIM_DIR}/deps;install_from_tar 'sshpass-.+\.tar\.gz' true;rm -fr sshpass-*/
tclsh8.6;                                   cd ${MY_VIM_DIR}/deps;install_from_tar 'tcl.+\.tar\.gz' true;rm -fr tcl*/
expect;                                     cd ${MY_VIM_DIR}/deps;install_from_tar 'tcl.+\.tar\.gz' true;cd ${MY_VIM_DIR}/deps;install_from_tar 'expect.+\.tar\.gz' true;rm -fr expect*/;rm -fr tcl*/
unzip;                                      cd ${MY_VIM_DIR}/deps;install_from_rpm 'unzip-.+\.rpm' true

netperf;                                    cd ${MY_VIM_DIR}/deps;install_from_tar 'netperf-.+\.tar\.gz' true;rm -fr netperf-*/
perf;                                       install_from_net perf
atop;                                       cd ${MY_VIM_DIR}/deps;install_from_rpm 'atop-.+\.rpm' true
iperf3;                                     cd ${MY_VIM_DIR}/deps;install_from_rpm 'iperf3-.+\.rpm' true
ss;                                         cd ${MY_VIM_DIR}/deps;install_from_rpm 'iproute-.+\.rpm' true
rsync;                                      cd ${MY_VIM_DIR}/deps;install_from_rpm 'rsync-.+\.rpm' true
nc;                                         cd ${MY_VIM_DIR}/deps;install_from_rpm 'nmap-ncat-.+\.rpm' true
m4;                                         cd ${MY_VIM_DIR}/deps;install_from_rpm 'm4-.+\.rpm' true
sar;                                        cd ${MY_VIM_DIR}/deps;install_from_rpm 'sysstat-.+\.rpm' true
autoconf;                                   cd ${MY_VIM_DIR}/deps;install_from_rpm 'autoconf-.+\.rpm' true
automake;                                   cd ${MY_VIM_DIR}/deps;install_from_rpm 'automake-.+\.rpm' true

/usr/libexec/sudo/libsudo_util.so.0;        cd ${MY_VIM_DIR}/deps;install_from_rpm 'sudo-.+\.rpm' true
/lib64/libreadline.so.6;                    cd ${MY_VIM_DIR}/deps;install_from_rpm 'readline-.+\.rpm' true
/usr/include/readline;                      cd ${MY_VIM_DIR}/deps;install_from_rpm 'readline-devel-.+\.rpm' true
/usr/lib64/libssl.so.10;                    cd ${MY_VIM_DIR}/deps;install_from_rpm 'compat-openssl10-.+\.rpm' true
/usr/bin/python-config;                     cd ${MY_VIM_DIR}/deps;install_from_rpm 'python-devel.+\.rpm' true
/usr/lib64/libpython2.7.so.1.0;             cd ${MY_VIM_DIR}/deps;install_from_rpm 'python-libs.+\.rpm' true
/usr/bin/python3-config;                    cd ${MY_VIM_DIR}/deps;install_from_rpm 'python3-devel.+\.rpm' true
/usr/lib64/libpython3.so;                   cd ${MY_VIM_DIR}/deps;install_from_rpm 'python3-libs-.+\.rpm' true
/usr/lib64/liblzma.so.5;                    cd ${MY_VIM_DIR}/deps;install_from_rpm 'xz-libs.+\.rpm' true
/usr/lib64/liblzma.so;                      cd ${MY_VIM_DIR}/deps;install_from_rpm 'xz-devel.+\.rpm' true
/usr/libiconv/lib64/libiconv.so.2;          cd ${MY_VIM_DIR}/deps;install_from_rpm 'libiconv-1.+\.rpm' true
/usr/libiconv/lib64/libiconv.so;            cd ${MY_VIM_DIR}/deps;install_from_rpm 'libiconv-devel.+\.rpm' true
/usr/lib64/libpcre.so.1;                    cd ${MY_VIM_DIR}/deps;install_from_rpm 'pcre-8.+\.rpm' true
/usr/lib64/libpcre.so;                      cd ${MY_VIM_DIR}/deps;install_from_rpm 'pcre-devel.+\.rpm' true
#/usr/lib64/libpcrecpp.so.0;                cd ${MY_VIM_DIR}/deps;install_from_rpm 'pcre-cpp.+\.rpm' true
#/usr/lib64/libpcre16.so.0;                 cd ${MY_VIM_DIR}/deps;install_from_rpm 'pcre-utf16.+\.rpm' true
#/usr/lib64/libpcre32.so.0;                 cd ${MY_VIM_DIR}/deps;install_from_rpm 'pcre-utf32.+\.rpm' true
/usr/share/terminfo/x/xterm;                cd ${MY_VIM_DIR}/deps;install_from_rpm 'ncurses-base.+\.rpm' true
/usr/lib64/libncurses.so.5;                 cd ${MY_VIM_DIR}/deps;install_from_rpm 'ncurses-libs.+\.rpm' true
/usr/lib64/libncurses.so;                   cd ${MY_VIM_DIR}/deps;install_from_rpm 'ncurses-devel.+\.rpm' true
/usr/lib64/libz.so.1;                       cd ${MY_VIM_DIR}/deps;install_from_rpm 'zlib-1.+\.rpm' true
/usr/lib64/libz.so;                         cd ${MY_VIM_DIR}/deps;install_from_rpm 'zlib-devel.+\.rpm' true
/usr/share/doc/perl-Data-Dumper;            cd ${MY_VIM_DIR}/deps;install_from_rpm 'perl-Data-Dumper-2.167.+\.rpm' true
/usr/share/doc/perl-Thread-Queue-3.02;      cd ${MY_VIM_DIR}/deps;install_from_rpm 'perl-Thread-Queue-.+\.rpm' true
locale;                                     cd ${MY_VIM_DIR}/deps;install_from_rpm 'glibc-common-.+\.rpm' true
#/usr/lib/golang/api;                       cd ${MY_VIM_DIR}/deps;install_from_rpm 'golang-1.+\.rpm' true
#/usr/lib/golang/src;                       cd ${MY_VIM_DIR}/deps;install_from_rpm 'golang-src-.+\.rpm' true
#/usr/lib/golang/bin;                       cd ${MY_VIM_DIR}/deps;install_from_rpm 'golang-bin-.+\.rpm' true
