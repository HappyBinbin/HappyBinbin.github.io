# IO多路复用

## 先导知识

1. 用户空间和内核空间
2. 进程切换
3. 进程的阻塞
4. 文件描述符
5. 缓存IO
    - 缓存 IO 又被称作标准 IO，大多数文件系统的默认 IO 操作都是缓存 IO。在 Linux 的缓存 IO 机制中，操作系统会将 IO 的数据缓存在文件系统的页缓存（ page cache ）中，也就是说，**数据会先被拷贝到操作系统内核的缓冲区中，然后才会从操作系统内核的缓冲区拷贝到应用程序的地址空间**

## 引出问题

网络IO的本质是socket的读取，socket在linux系统被抽象为流，IO可以理解为对流的操作。刚才说了，对于一次IO访问（以read举例），数据会先被拷贝到操作系统内核的缓冲区中，然后才会从操作系统内核的缓冲区拷贝到应用程序的地址空间。

所以说，当一个read操作发生时，它会经历两个阶段：

> 1. 第一阶段：等待数据准备 (Waiting for the data to be ready)。
> 2. 第二阶段：将数据从内核拷贝到进程中 (Copying the data from the kernel to the process)。

对于socket流而言，

> 1. 第一步：通常涉及等待网络上的数据分组**文件描述符**到达，然后被复制到内核的某个缓冲区。
> 2. 第二步：把数据从内核缓冲区复制到应用进程缓冲区。

网络应用需要处理的无非就是两大类问题：网络IO、数据计算。而网络IO的延迟所带来的性能瓶颈往往大于后者。因此，有了许许多多的网络IO模型来解决不同场景下的问题：

- **同步模型（synchronous IO）**
- 阻塞IO（bloking IO）
- 非阻塞IO（non-blocking IO）
- 多路复用IO（multiplexing IO）
- 信号驱动式IO（signal-driven IO）：不常用
- **异步IO（asynchronous IO）**

## IO多路复用

### 概念引出

由于同步非阻塞的方式需要不断主动轮询，这个操作消耗大量CPU时间，而 “后台” 可能有多个任务在同时进行，人们就想到了循环查询多个任务的完成状态，只要有任何一个任务完成，就去处理它。并且轮询的操作不是进程的用户态来负责的，而是kernel来监视。这个就是所谓的**“IO多路复用”**

> 也就是通过一种机制，监视多个描述符，一旦某个描述符就绪（一般是读就绪或者写就绪），能够通知程序进行相应的读写操作。

### 如何实现

I/O复用模型会用到select、poll、epoll函数，也是由内核来实现的

- 和阻塞I/O所不同的的，它们可以同时阻塞多个I/O操作。而且可以同时对多个读操作，多个写操作的I/O函数进行检测，直到有数据可读或可写时（注意不是全部数据可读或可写），才真正调用I/O操作函数。
- 和非阻塞I/O不同的是，前者可以等待多个socket，**能实现同时对多个IO端口进行监听。**当其中任何一个socket的数据准好了，就能返回进行可读，然后进程再进行recvform系统调用，**将数据由内核拷贝到用户进程，**当然这个过程是阻塞的，此时的select不是等到socket数据全部到达再处理, 而是**有了一部分数据就会调用用户进程来处理，**如何知道有一部分数据到达了呢？监视的事情交给了内核，kernel负责数据到达的处理。也可以理解为"非阻塞"吧。

![输入图片说明](https://static.oschina.net/uploads/img/201604/20164149_LD8E.png)

实际中，对于每一个socket，一般都设置成为non-blocking，但是，如上图所示，整个用户的process其实是一直被block的。只不过process是被select这个函数block，而不是被socket IO给block。所以**IO多路复用是阻塞在select，epoll这样的系统调用之上，而没有阻塞在真正的I/O系统调用如recvfrom之上。**

### 应用场景

- 服务器需要同时处理多个处于监听状态或者多个连接状态的套接字。
- 服务器需要同时处理多种网络协议的套接字。

但是，如果处理的连接数不是很高的话，使用select/epoll的web server不一定比使用multi-threading + blocking IO的web server性能更好，可能延迟还更大。（select/epoll的优势并不是对于单个连接能处理得更快，而是在于能处理更多的连接。）因为IO多路复用，需要使用两个system call (select 和 recvfrom)，而blocking IO只调用了一个system call (recvfrom)。

### 总结

从整个IO过程来看，他们都是顺序执行的，因此可以归为同步模型(synchronous)。都是进程主动等待且向内核检查状态。【此句很重要！！！】

高并发的程序一般使用**同步非阻塞方式**而非**多线程 + 同步阻塞方式。**

IO多路复用在阻塞到select阶段时，用户进程是主动等待并调用select函数获取数据就绪状态消息，并且其进程状态为阻塞。**所以，把IO多路复用归为同步阻塞模式。**

## select、poll、epoll区别

|            |                       select                       |                       poll                       |                            epoll                             |
| :--------- | :------------------------------------------------: | :----------------------------------------------: | :----------------------------------------------------------: |
| 操作方式   |                        遍历                        |                       遍历                       |                             回调                             |
| 底层实现   |                        数组                        |                       链表                       |                            红黑树                            |
| IO效率     |      每次调用都进行线性遍历，时间复杂度为O(n)      |     每次调用都进行线性遍历，时间复杂度为O(n)     | 事件通知方式，每当fd就绪，系统注册的回调函数就会被调用，将就绪fd放到readyList里面，时间复杂度O(1) |
| 最大连接数 |              1024（x86）或2048（x64）              |                      无上限                      |                            无上限                            |
| fd拷贝     | 每次调用select，都需要把fd集合从用户态拷贝到内核态 | 每次调用poll，都需要把fd集合从用户态拷贝到内核态 |  调用epoll_ctl时拷贝进内核并保存，之后每次epoll_wait不拷贝   |

## 三种轮询方式

#### 忙轮询

忙轮询方式是通过不停的把所有的流从头到尾轮询一遍，查询是否有流已经准备就绪，然后又从头开始。如果所有流都没有准备就绪，那么只会白白浪费CPU时间。轮询过程可以参照如下：

```python
while true {
    for i in stream[]; {
        if i has data
              read until unavailable
    }
}
```

#### 无差别的轮询方式

为了避免白白浪费CPU时间，我们采用另外一种轮询方式，无差别的轮询方式。即通过引进一个代理，这个代理为select/poll,这个代理可以同时观察多个流的I/O事件。当所有的流都没有准备就绪时，会把当前线程阻塞掉；当有一个或多个流的I/O事件就绪时，就从阻塞状态中醒来，然后轮询一遍所有的流，处理已经准备好的I/O事件。轮询的过程可以参照如下：

```python
while true {
    select(streams[])
    for i in streams[] {
        if i has data
              read until unavailable
    }
}
```

如果I/O事件准备就绪，那么我们的程序就会阻塞在select处。我们通过select那里只是知道了有I/O事件准备好了，但不知道具体是哪几个流（可能有一个，也可能有多个），所以需要无差别的轮询所有的流，找出已经准备就绪的流。可以看到，使用select时，我们需要O(n)的时间复杂度来处理流，处理的流越多，消耗的时间也就越多。

#### 最小轮询方式

无差别的轮询方式有一个缺点就是，随着监控的流越来越多，需要轮询的时间也会随之增加，效率也会随之降低。所以还有另外一种轮询方式，最小轮询方式，即通过epoll方式来观察多个流，epoll只会把发生了I/O事件的流通知我们，我们对这些流的操作都是有意义的，时间复杂度降低到O（k），其中k为产生I/O事件的流个数。轮询的过程如下：

```python
while true {
    active_stream[] = epoll_wait(epollfd)
    for i in active_stream[] {
        read or write till unavailable
    }
}
```

select/poll/epoll都是采用I/O多路复用机制的，其中select/poll是采用无差别轮询方式，而epoll是采用最小的轮询方式。

## 问题的解决

### 实现1：select

**多路分离函数select**

IO多路复用模型是建立在内核提供的多路分离函数select基础之上的，使用select函数可以避免同步非阻塞IO模型中轮询等待的问题。

![img](https://img-blog.csdnimg.cn/20190516194215468.png?x-oss-process=image/watermark,type_ZmFuZ3poZW5naGVpdGk,shadow_10,text_aHR0cHM6Ly9ibG9nLmNzZG4ubmV0L2Rpd2Vpa2FuZw==,size_16,color_FFFFFF,t_70)

如上图所示，用户线程发起请求的时候，首先会将socket添加到select中，这时阻塞等待select函数返回。当数据到达时，select被激活，select函数返回，此时用户线程才正式发起read请求，读取数据并继续执行。

从流程上来看，使用select函数进行I/O请求和同步阻塞模型没有太大的区别，甚至还多了添加监视socket，以及调用select函数的额外操作，效率更差。但是，使用select以后最大的优势是用户可以在一个线程内同时处理多个socket的I/O请求。用户可以注册多个socket，然后不断地调用select读取被激活的socket，即可达到在同一个线程内同时处理多个I/O请求的目的。而在同步阻塞模型中，必须通过多线程的方式才能达到这个目的。

###  Reactor（反应器模式）

![img](https://img-blog.csdnimg.cn/20190516194238372.png?x-oss-process=image/watermark,type_ZmFuZ3poZW5naGVpdGk,shadow_10,text_aHR0cHM6Ly9ibG9nLmNzZG4ubmV0L2Rpd2Vpa2FuZw==,size_16,color_FFFFFF,t_70)

如上图，I/O多路复用模型使用了Reactor设计模式实现了这一机制。通过Reactor的方式，可以将**用户线程轮询I/O操作状态的工作统一交给handle_events事件循环进行处理。**用户线程注册事件处理器之后可以继续执行做其他的工作（异步），而Reactor线程负责调用内核的select函数检查socket状态。当有socket被激活时，**则通知相应的用户线程（或执行用户线程的回调函数），执行handle_event进行数据读取、处理的工作。**由于select函数是阻塞的，因此多路I/O复	用模型也被称为**异步阻塞I/O模型**。注意，这里的所说的阻塞是指select函数执行时线程被阻塞，而不是指socket。一般在使用I/O多路复用模型时，socket都是设置为NONBLOCK的，不过这并不会产生影响，因为用户发起I/O请求时，数据已经到达了，用户线程一定不会被阻塞。



