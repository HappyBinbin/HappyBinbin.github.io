## 清除修改

1. 在未发生任何add或commit的情况下：

    git checkout .

    这条命令，只能清除所有修改的文件，但是新建的文件和文件夹无法清除，还必须使用：

    git clean -df

    清除所有新建的文件及文件夹


2. 对于add的部分，先要撤销add：

    git reset .

    然后再进行第一步的操作即可

## 缓存用户名和密码

1. git config --global credential.helper store
2. git push 或者 git clone，输入用户名和密码即可

## git 清空密码和用户名配置

- git config --system --unset credential.helper

