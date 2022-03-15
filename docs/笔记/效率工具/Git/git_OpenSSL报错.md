git 访问github 报错：OpenSSL SSL_read: Connection was reset, errno 10054
打开Git命令页面，执行git命令脚本：修改设置，解除ssl验证

```bash
git config --global http.sslVerify "false"
```


此时，再执行git操作即可。


