# TCP 网络编程

## 伪代码

### Server端

1. Socket ss = new Socket(port) // 新建一个socket绑定端口
2. while(true) // 一直等待客户端发送的请求
   1. 监听端口，等待客户端确认连接，Socket socket = ss.accept();
   2. 获取客户端的请求信息后，执行相关业务逻辑

```java
@Override
    public void run() {
        try{
            //获取socket的输出流
            OutputStream os = socket.getOutputStream();
            //获取socket的输入流
            InputStream is = socket.getInputStream();
            int ch = 0;
            byte[] buff = new byte[1024];
            //buff主要用来读取输入的内容，存成byte数组，ch主要是用来获取读取数组的长度
            ch = is.read(buff);
            String content = new String(buff,0,ch);
            System.out.println(content);
            //往输出流里写入获得的字符串的长度，回法给 客户端
            os.write(String.valueOf(content.length()).getBytes());
            //关闭 is os socket
            is.close();
            os.close();
            socket.close();
        }catch (Exception e){
            e.printStackTrace();
        }
    }
```



### Client

1. 新建socket端口，绑定 ip地址和客户端，Socket socket = new Socket("127.0.0.1",65000);
2. 通过 socket 获取输入和输出流

```
OutputStream os = socket.getOutputStream();
InputStream is = socket.getInputStream();
```

3. os.write 向服务器写数组，以字节数组形式
4. 定义一个字节数组，用来接受从服务器的数据
5. int ch = is.read(buff);
6. 将读到buff的数据转成 String，输出到控制台
7. 关闭 is os socket

# UDP 网络编程

## 伪代码

### Server端

1. 服务器接受客户端的数据报

   ```java
   DatagramSocket socket = new DatagramSocket(port);
   ```

2. 定义一个DatagramPacket

   ```java
   byte[] buff = new byte[1024];
   DatagramPacket packet = new DatagramPacket(buff, buff.length);       
   ```

3. 接受客户端发送过来的内容，封装到packet中

   ```java
   socket.receive(packet);
   ```

4. 从packet读取数据并打印输出

   ```java
   byte[] data = packet.getData();//从packet中获取到data
           String content = new String(data, 0, packet.getLength());
           System.out.println(content);
   ```

5. 将要发送给客户端的数据转成字节流

   ```java
   byte[] sendedContent = String.valueOf(content.length()).getBytes();
   ```

6. 再将数据封装成packet包，发送给客户端

   ```java
   DatagramPacket packetToClient = new DatagramPacket(sendedContent, sendedContent.length, packet.getAddress(), packet.getPort());
           socket.send(packetToClient);
   ```

7. 关闭 socket

### Client 端

1. 客户端发送数据给服务器，先将IP地址封装成InetAddress对象，再通过封装进DatagramPacket里面

   ```java
   DatagramSocket socket = new DatagramSocket();
   //要发送的给服务端的数据
   byte[] buf = "Hello Server".getBytes();
   //将IP地址封装成InetAddress对象
   InetAddress address = InetAddress.getByName("127.0.0.1");
   //将要发送给服务端的数据封装成DatagramPacket对象，需要填写上Ip地址和端口号
   DatagramPacket packet = new DatagramPacket(buf,buf.length,address,65001);
   //发送数据给服务器
   socket.send(packet);
   ```

2. 客户端接受数据

   ```java
   byte[] data = new byte[100];
   //创建DatagramPacket对象，用来存储服务端发送过来的数据
   DatagramPacket receivedPacket = new DatagramPacket(data, data.length);
   //将接受到的数据存储到DatagramPacket对象中
   socket.receive(receivedPacket);
   //打印
   String content = new String(receivedPacket.getData(), 0,
                               receivedPacket.getLength());
   System.out.println(content);
   ```

3. 关闭socket











