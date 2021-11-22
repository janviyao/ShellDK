# vim
Personal VIM configure.

Use it to meet any issue, Pleae connect me with QQ 9971289.

SSH免密配置：
1）ssh-keygen -t rsa -b 4096 -C "9971289.com"  +  chmod 700 -R .ssh/
2）把id_rsa.pub内容拷贝到github新建的SSH keys中
3）项目使用SSH clone
4）如果本地已经有https源，可以通过修改git仓库地址：
4.1）git remote origin set-url [url]
4.2）git remote rm origin  +  git remote add origin [url]
4.3）直接修改.gitconfig文件，把项目地址替换成新的
