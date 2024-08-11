## 为什么需要 WebSocket？

通过 HTTP 协议，客户端只能单向地去发去请求，服务器返回查询结果；无法做到服务端主动向客户端推送消息；如果客户端需要知道服务端的状态变化，就只能通过轮询的方式，但这种方式非常消耗资源，因此衍生出了 WebSocket 的概念

## 什么是 WebSocket？

一种通信协议，用于在Web应用程序和服务器之间建立实施、双向的连接

特点：

- 建立于TCP协议之上，属于应用层协议，服务端实现比较简单
- 能兼容HTTP协议，默认端口为 80 和 443
- 数据格式轻量，性能开销小
- 客户端可以与任意服务器通信
- 协议表示为 ws，如果加密则是 wss

![1723338430539](https://happychan.oss-cn-shenzhen.aliyuncs.com/img/202408110907912.jpg)

## 如何使用？

### 客户端

```javascript
var ws = new WebSocket("wss://echo.websocket.org");

ws.onopen = function(evt) { 
  console.log("Connection open ..."); 
  ws.send("Hello WebSockets!");
};

ws.onmessage = function(evt) {
  console.log( "Received Message: " + evt.data);
  ws.close();
};

ws.onclose = function(evt) {
  console.log("Connection closed.");
};     
```

请求格式：

```http
GET /chat HTTP/1.1
Host: example.com:8000
Upgrade: websocket
Connection: Upgrade
Sec-WebSocket-Key: dGhlIHNhbXBsZSBub25jZQ==
Sec-WebSocket-Version: 13
```



### 服务端

可以直接使用对应语言的开源库，websocket 服务器就是一个 TCP 应用程序，做的事情就是监听服务器上任何遵循特定协议的端口；

返回格式：

```http
HTTP/1.1 101 Switching Protocols
Upgrade: websocket
Connection: Upgrade
Sec-WebSocket-Accept: s3pPLMBiTxaQ9kYGzzhZRbK+xOo=
```

































