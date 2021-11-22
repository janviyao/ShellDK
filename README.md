# vim
Personal VIM configure.

Use it to meet any issue, Pleae connect me with QQ 9971289.

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

git remote set-url origin https://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@github.com/janviyao/vimrc.git

免密配置：
1）ssh-keygen -t rsa -b 4096 -C "9971289.com"   +  chmod 700 -R .ssh/
2）把 id_rsa.pub 内容拷贝到 github 新建的 SSH keys 中
3）项目得使用 SSH clone
4）如果本地是https 源，那么就修改git 仓库地址：
4.1）git remote origin set-url [url]
4.2）git remote rm origin +  git remote add origin [url]
4.3）直接修改.gitconfig文件，把项目地址替换成新的
