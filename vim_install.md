Ubuntu 安装：
sudo apt-get install liblua5.1-dev
copy all files from /usr/include/lua5.1/ to /usr/include/lua5.1/include/
sudo ln -s /usr/lib/x86_64-linux-gnu/liblua5.1.so /usr/local/lib/liblua.so

Go to vim source folder:
./configure --with-features=huge --enable-cscope --enable-pythoninterp=yes --with-python-config-dir=/usr/lib/python2.7/config-x86_64-linux-gnu --enable-multibyte --enable-fontset --disable-gui --disable-netbeans --enable-luainterp=yes --with-lua-prefix=/usr/include/lua5.1 --enable-largefile
make
sudo make install



Centos 安装：

Centos下配置Lua运行环境
http://www.centoscn.com/yunwei/Lua/2013/0817/1284.html

编译安装lua 时 lua.c:67:31: fatal error: readline/readline.h: No such file or directory 
http://blog.csdn.net/swanabin/article/details/46971839

编译安装lua 时 lua.c:67:31: fatal error: readline/readline.h: No such file or directory
http://www.vcerror.com/?p=1786

0. yum install -y readline-devel ncurses-devel
1. wget http://www.lua.org/ftp/lua-5.3.3.tar.gz
2. tar zxf lua-5.3.3.tar.gz
3. cd lua-5.3.3
4. vim Makefile
INSTALL_TOP= /usr/local/lua5.3.3
5. make linux
6. make install

yum install python-devel

./configure --with-features=huge --enable-cscope --enable-pythoninterp=yes --with-python-config-dir=/usr/lib64/python2.7/config --enable-multibyte --enable-fontset --disable-gui --disable-netbeans --enable-luainterp=yes --with-lua-prefix=/usr/local/lua5.3.3 --enable-largefile

make
sudo make install



