## 分布式Session

利用Redis来实现，达到多台机器共享Session

在登录完成的最后一步，需要带着Session信息。 

1. 利用uuid生成秘钥（sessionId） 
2. 将user信息，对象。同时写入cookie cookie作为response返回给客户端，另外 将sessionId +前缀 一起作为Key,存入Redis 缓存中
3. 当访问其他页面的时候，就可以从cookie中获取 token,再访问redis 拿到用户信息来判断登录情况了

<img src="https://happychan.oss-cn-shenzhen.aliyuncs.com/img/202111012321902.png" alt="image-20211101232101803"  />

