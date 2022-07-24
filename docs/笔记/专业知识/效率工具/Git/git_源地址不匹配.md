​	Git 常见错误 之 error: src refspec xxx does not match any / error: failed to push some refs to 简单解决方法



github 现在默认的主干分支名为 ：main

而我们习惯性是 master 

所以 pull 和 push 时会报错

```bash
error: src refspec master does not match any
error: failed to push some refs to 'git@github.com:HappyBinbin/HappyBinbin.github.io.git'
```

## 解决方法

统一远程和本地的仓库名称即可

1、把本地的 master 仓库名称修改为远端的 main

重命名命令： git branch -m oldBranchName newBranchName

然后 push 就好



2、重新建立本地和远端的连接

```bash
git remote remove origin
git remote add origin git@github.com:XXX/XXX.github.io.git
git push origin master
```

