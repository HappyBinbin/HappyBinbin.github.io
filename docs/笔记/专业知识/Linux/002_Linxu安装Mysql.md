### Linux安装Mysql->MariaDB过程

1. 下载mysql的tar包

   ```
   MySQL-5.6.22-1.el6.i686.rpm-bundle.tar
   ```

2. 卸载 centos 预安装的 mysql

   ```
   rpm -qa | grep -i mysql
   rpm -e mysql-libs-5.1.71-1.el6.x86_64 --nodeps
   ```

3. 解压

   ```shell
   mkdir mysql 
   tar -xvf MySQL-5.6.22-1.el6.i686.rpm-bundle.tar -C /root/mysql
   ```

4. 安装依赖包

   ```shell
   yum -y install libaio.so.1 libgcc_s.so.1 libstdc++.so.6 libncurses.so.5 -- setopt=protected_multilib=false 
   
   yum update libstdc++-4.4.7-4.el6.x86_64
   ```

   

5. 安装mysql-client

   安装的时候可能会出现缺陷依赖的情况，缺啥补啥，例如：

   ![20190826115641227](https://happychan.oss-cn-shenzhen.aliyuncs.com/img/20190826115641227.png)

   ```shell
   yum install -y perl-Module-Install.noarch
   ```

   如何还有问题，则直接安装 perl

   ```
   yum install -y perl
   ```

   再继续安装

   ```
   rpm -ivh MySQL-client-5.6.22-1.el6.i686.rpm
   ```

6. 安装mysql-server

   ```
   rpm -ivh MySQL-server-5.6.22-1.el6.i686.rpm
   ```

   又缺少依赖

   ![image-20210315162803353](https://happychan.oss-cn-shenzhen.aliyuncs.com/img/image-20210315162803353.png)

   继续补依赖

   ![image-20210315162921969](https://happychan.oss-cn-shenzhen.aliyuncs.com/img/image-20210315162921969.png)

   继续安装

7. 启动mysql

   ```
   service mysql start
   ```

   又出问题

   ```
   Redirecting to /bin/systemctl start mysql.service
   Failed to start mysql.service: Unit not found.
   ```

   好的，一查发现mysql再centos中要收费了，他狗日的不装mysql了，搞了个mariadb，如果装mysql就会导致两个文件冲突，所以二选一，我直接吐了

8. 卸载mysql

   ```
   yum install -y mariadb-server
   ```

9. 安装mariadb

   ```
   yum install -y mariadb-server
   ```

10. 启动服务，添加开启启动

    ```
    systemctl start mariadb.service
    systemctl enable mariadb.service
    ```

11. 进行一些安全设置

    ```
    [root@localhost]$  mysql_secure_installation
    ```

    