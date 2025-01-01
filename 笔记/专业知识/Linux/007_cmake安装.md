# cmake安装



编译流程如下：

```javascript
wget -c https://github.com/Kitware/CMake/releases/download/v3.17.0-rc3/cmake-3.17.0-rc3.tar.gz
tar zxvf cmake-3.17.0-rc3.tar.gz
cd cmake-3.17.0-rc3./bootstrap
gmake
gmake install
```

cmake编译比较简单，gcc环境和libstdc++.so.6没问题的情况下一般不会出现什么问题 查看编译后的版本：

```javascript
ln -s /usr/local/bin/cmake /usr/bin/cmake
cmake --version
```

如果本地使用了yum进行安装过，则需要卸载

```javascript
yum remove cmake
ln -s /usr/local/bin/cmake /usr/bin/cmake
cmake --version
```

到此安装完毕

## Reference

https://cloud.tencent.com/developer/article/1668873