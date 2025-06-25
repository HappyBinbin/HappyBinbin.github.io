# meta

接收aops-spm上报的心跳信息，并且将最新版本的aops-spm版本号以及各类agent版本号返回给aops-spm；
并且提供aops-spm和各类agent的安装包下载功能

## 设计理念

- 对于一个公司而言，agent并不多，也就有个监控agent、部署agent、naming agent，所以sf-meta直接采用配置文件而不是数据库之类的大型存储来存放agent信息
- 公司级别agent升级慢一点没关系，比如一晚上升级完问题都不大，所以aops-spm与sf-meta的通信周期默认是5min，比较长。如果做成长连接，周期调小，是否就可以不光用来部署agent，也可以部署一些业务程序？不要这么做！部署其他业务组件是部署agent的责任，aops-spm做的事情少才不容易出错。aops-spm推荐在装机的时候直接安装好，功能少基本不升级。
- aops-spm会汇报自己管理的各个agent的状态、版本号，这个信息直接存放在sf-meta模块的内存中，因为数据量真没多少，100w机器，3个agent……

## 使用方法
1. 修改配置文件：
 - 上传spm和各类agent的tarball到配置文件中的tarballDir目录,agent包的命名方式为<name>-<version>_<os>_<arch>.tar.gz;
 - spm中填写aops-spm的版本号，如果不想使用meta作为文件服务器，可以将tarball字段设置为自定义的文件下载服务器，需要确保<tarball>/aops-spm-<version>_<os>_<arch>.tar.gz地址可以正常下载文件
 - agents中每一个agent占用一个map,name不可以与其他的重复,configFile是agent的配置文件路径;

2. 编译运行
```shell script
./control build   # 会生成一个aops-sf-meta的二进制文件
mv cfg.example.json cfg.json
./control start # 也可以将sf-meta服务托管给systemctl管理
```

## 注意

- 虽然sf-meta提供了http服务，可以直接用来提供tarball下载，但是不推荐这样用，最好单独再搭建一个服务（比如nginx，如果觉得麻烦再搭一个sf-meta专门用于下载都可以）专门用于文件下载，这样sf-meta做的事情少，稳定。