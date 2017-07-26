Ubuntu 安装：
sudo apt-get install liblua5.1-dev
copy all files from /usr/include/lua5.1/ to /usr/include/lua5.1/include/
sudo ln -s /usr/lib/x86_64-linux-gnu/liblua5.1.so /usr/local/lib/liblua.so

Go to vim source folder:
./configure --with-features=huge --enable-cscope --enable-pythoninterp=yes --with-python-config-dir=/usr/lib/python2.7/config-x86_64-linux-gnu --enable-multibyte --enable-fontset --disable-gui --disable-netbeans --enable-luainterp=yes --with-lua-prefix=/usr/include/lua5.1 --enable-largefile
make
sudo make install

Centos 安装：

编译安装lua 时 lua.c:67:31: fatal error: readline/readline.h: No such file or directory 
http://blog.csdn.net/swanabin/article/details/46971839

编译安装lua 时 lua.c:67:31: fatal error: readline/readline.h: No such file or directory
http://www.vcerror.com/?p=1786

Centos下配置Lua运行环境
http://www.centoscn.com/yunwei/Lua/2013/0817/1284.html

./configure --with-features=huge --enable-cscope --enable-pythoninterp=yes --with-python-config-dir=/usr/lib64/python2.7/config --enable-multibyte --enable-fontset --disable-gui --disable-netbeans --enable-luainterp=yes --with-lua-prefix=/usr/local/lua --enable-largefile

yum install python-devel
