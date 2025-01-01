# centos 下git--version找不到命令问题



#### 现象

今天源码安装一个git后，执行git命令后报如下错误:

```
$ git --version
-bash: /usr/bin/git: No such file or directory
```

#### 分析过程

开始我以为是PATH路径的问题，检查PATH路径发现是正常的，而且找不到命令的报错也不应该是这样的

```
$ echo $PATH
/usr/local/bin:/bin:/usr/bin:/usr/local/sbin:/usr/sbin:/sbin:/home/admin/bin
$ abcd
-bash: abcd: command not found
$ /usr/local/bin/git --version
git version 2.17.0
```

可以看出 git 命令是在PATH路径下，且应该是正常安装了，因为使用绝对路径能正常使用

而且找不到命令的报错应该是 command not found

使用root用户，执行git --version就是正常的，我开始以为是admin的用户有设置什么变量，导致执行git命令时，固定在/usr/bin下找

后来查找发现，并没有这类参数

最后在stackoverflow上找到了答案，链接如下：

https://stackoverflow.com/questions/19698901/why-is-git-looking-in-the-wrong-directory-for-the-git-installation-os-x

原来是因为，我事先卸载的旧的git路径为/usr/bin/git，然后新安装的git在/usr/local/bin下，终端session保存了原来的路径，重新打开新的终端即可解决

虽然是个很简单的问题，但是问了几个群都没人反馈，可能是没遇到，或者别人懒得答复吧

但是对于当事人，可能以为是安装哪里有问题，可能会查找半天，记录一下，以便以后查阅



## Reference

https://www.cnblogs.com/salt-fish1/p/10207878.html