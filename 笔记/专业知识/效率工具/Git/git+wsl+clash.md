通过 clash 配置，是使得 wsl 能够访问外网，并且通过 git 配置，使得 git 能够访问 github，正常执行 git 命令

## clash 

打开 tun 模式，允许局域网链接，打开 TAP 网络适配器，可以看到wsl的网络地址

![image-20220319101729227](https://happychan.oss-cn-shenzhen.aliyuncs.com/img/pic/202203191017289.png)

## wsl

进入 wsl，查看 .gitconfig 配置

```bash
[http]
[https]
[http "https://github.com"]
        proxy = http://xxx:7890
[https "https://github.com"]
        proxy = https://xxx:7890
```

讲 xxx 更换为上面的  wsl 地址即可

如果没有配置过，则通过 git config 命令进行配置

git config --global user.name "happy"















