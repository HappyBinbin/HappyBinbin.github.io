[TOC]



# lab2

在lab0中，我们实现了一个流量控制字节流(ByteStream) 的抽象，在lab1中，我们实现了 StreamReassembler，接受从相同字节流中摘录的子字符串序列，并将它们重新组装回原始流。

这些模块将在TCP实现中被证明是有用的，但其中没有什么是特定于传输控制协议的细节的。现在改变了。在lab2中你将会实验 TCPReceiver，这是TCP实现中处理传入字节流的部分。TCPReceiver 在传入的TCP段(Internet上传送的数据报的有效负载)和传入的字节流之间进行转换。

TCPReceiver从Internet接收片段(通过segment received()方法)，并将它们转换为对StreamReassembler的调用，后者最终写入传入的 ByteStream。应用程序从这个 ByteStream 读取数据，就像您在lab0中通过从TCPSocket读取数据那样。

<img src="https://happychan.oss-cn-shenzhen.aliyuncs.com/img/image-20210613120727703.png" alt="image-20210613120727703"  />

有几个比较重要的点

- TCPSegment 的组成
    - TCPSender
        - seqno
        - SYN
        - payload，FIN
    - TCPReceiver
        - ackno : 这个就是 first unassembled 的 index，接收器需要从对等端的发送器接收的第一个字节
        - window_size：这个就是 lab1 中红色区域的大小，窗口大小

所以，有时会参考地把 ackno 作为窗口的左边界“left edge”（TCPReceiver 感兴趣的最小索引），把 ackno + window size 作为有边界“right edge”（刚超出 TCPReceiver 感兴趣的最大索引）

## 3.1 Translating between 64-bit indexes and 32-bit seqnos

热身活动，实现TCP的索引表示方法。上周我们创建了一个流重组器，其重组的子串每个字节都有一个 64 位的流下标，流中的第一个字节的索引总是为0。一个 64 位的索引足够大，我们认为它永远不会溢出。但实际上，在 TCP 头部中，空间是非常宝贵的，流中每个字节的下标不是 64索引表示的，而是用32位的“序列号”或“seqno”表示的。

所以增加了三个复杂性：

1. 你的实现需要为32位整数的循环使用而规划
    - 因为在 TCP 中的流可以任意长，所以仅 2^32 bytes = 4GB 可能不够用，所以要循环使用序号
2. TCP 序号是从一个随机值开始的
    - 一方面是为了安全考虑，一方面是改进，避免被属于同一端点之间早期连接的旧段所混淆
    - ISN：流中的第一个序列号是一个随机的32位数字，称为初始序列号(ISN)。
    - 后序的序号都是 (ISN + 1) mod 2^32、(ISN + 2) mod 2^32 ……
3. 交换控制信息的逻辑开始和结束都需要占有一个序号
    - SYN 和 FIN，记住，它们不是流本身的一部分，也不是字节，它们只是代表了流本身的开始和结束

下面的图是引用某个老哥：https://blog.csdn.net/weixin_44520881/article/details/108911578

![image-20210619170234357](https://happychan.oss-cn-shenzhen.aliyuncs.com/img/image-20210619170234357.png)

这个表格展示了TCP设计的三种不一样类型的下标：

| Sequence Numbers  | Absolute Sequence Numbers |    Stream Indices     |
| :---------------: | :-----------------------: | :-------------------: |
| Start at the ISN  |        Start at 0         |      Start at 0       |
|  Include SYN/FIN  |      Include SYN/FIN      |     Omit SYN/FIN      |
| 32 bits, wrapping |   64 bits, non-wrapping   | 64 bits, non-wrapping |
|      “seqno”      |     “absolute seqno”      |    “stream index”     |

在Absolute Sequence Numbers 和 Stream Indices 之间转换很简单，±1就好了

在 Sequence Numbers 和 Absolute Sequence Numbers 之间转换就比较困难了，把它们搞混淆会产生很多棘手的bugs，所以为了系统地防止这些bugs，我们将使用自定义类型WrappingInt32来表示序列号，并写入它与绝对序列号(uint64 t)之间的转换。WrappingInt32是包装类型的一个例子:包含内部类型(在本例中是uint32 t)但提供一组不同的函数/操作符的类型

### interface

```c++
WrappingInt32 wrap(uint64_t n, WrappingInt32 isn)；
uint64 t unwrap(WrappingInt32 n, WrappingInt32 isn, uint64 t checkpoint)；
```

#### 绝对序号 -> 序号 的包装

稍为思考一下，一个序号是 32位循环使用的，一个绝对序号是64位用不完的，如何进行转换？

我的做法是通过模拟4位和2位cycle的方法得出规律

- ISN 就是每个流随机开始的序号

- (absolute seqno + isn) mod 2^32 == seqno

#### 序号 -> 绝对序号的拆包

这个确实比较难想，我也是看了大佬们的代码才懂的，这个需要学过计组可能才比较好懂。大佬们都直接位运算操作的，刚开始都看懵了都

根据lab给的解释，因为为了节约空间，所以 TCP header 中只用了 32 位来表示流中每个字节的index，不够用，要循环使用。如果一个流的大小超过了2^32，则seqno 会有重复的。因此接收的时候要对其进行转换，转成 absolute seqno，就是这个接口要做的事情。

怎么转？lab提示，由于seqno是循环的，假设 ISN 为0， 那么 seqno 为 17 时对应的 absolute seqno 可能位 17 + k * 2^32 (k=1,2,3.....)，我们无法判断是哪个。所以给多了 checkpoint 来帮助我们定位，这个比较难理解，不知道是俺英文水品差还是理解能力太差，看了大佬们的解释，半天才懂一点点

这个 checkpoint，lab中有讲`you’ll use the index of the last reassembled byte as the checkpoint`，即最后一个重新组装的字节的索引作为 checkpoint，我们的任务就是计算与checkpoint最近距离的n对应的绝对序列号

根据上面的假设 ISN 为 0 的情况，我们来找规律：

接口给的 n 、isn、checkpoint，n.raw_value() - isn.raw_value() 的值即为序号 n 与 isn 的差值。当 isn 为 0 时，那么它们的差值就是 n.raw_value()，它们之间的差值的绝对值 和 转成 absolute seqno 表示时的差值绝对值是相等的。那么我们可以知道，如果在第一个循环内，n 转换成 absolute seqno 就为 n.raw_value()，但是我们不知道现在是第几个循环了，所以 absolute seqno 就为 n.raw_value() + k * 2^32。

现在缺一个k，这个条件需要通过checkpoint来得出。

lab提示，checkpoint 是为了给定一个大概的范围，即 n 转为 absolute seqno  后的值会在 checkpoint ± 2^31 这个范围。

那么根据前面的推理，可以得出公式：

absolute_seqno = n - isn + k*(1uL << 32)；

而根据lab所给的要求和 checkpoint：

absolute_seqno 要接近 checkpoint ,同时满足 absolute_seqno >= 0 （即 n 和 isn 不会超过 2^31），求 k

即 k * (1ULL << 32) 接近 checkpoint - absolute_seqno ， 求k

那么我们要选择一个与checkpoint相距不超过2^31的且距离checkpoint最近的那一个。这么做的依据是假定接收端两次接收到的子串位置不会相差太大而超过2^31（没有给出说明，暂且认为这个假设是合理的）。另外，我们完全可以默认字节流不会溢出64位空间。

### 代码实现

多说无益，看代码最简单

```c++
//! Transform an "absolute" 64-bit sequence number (zero-indexed) into a WrappingInt32
//! \param n The input absolute 64-bit sequence number
//! \param isn The initial sequence number
WrappingInt32 wrap(uint64_t n, WrappingInt32 isn) {
    uint32_t ans = (n << 32) >> 32;
    return isn + ans;
}

//! Transform a WrappingInt32 into an "absolute" 64-bit sequence number (zero-indexed)
//! \param n The relative sequence number
//! \param isn The initial sequence number
//! \param checkpoint A recent absolute 64-bit sequence number
//! \returns the 64-bit sequence number that wraps to `n` and is closest to `checkpoint`
//!
//! \note Each of the two streams of the TCP connection has its own ISN. One stream
//! runs from the local TCPSender to the remote TCPReceiver and has one ISN,
//! and the other stream runs from the remote TCPSender to the local TCPReceiver and
//! has a different ISN.
uint64_t unwrap(WrappingInt32 n, WrappingInt32 isn, uint64_t checkpoint) {
    // 绝对差值，不论是在 seqno 还是 absolute_seqno钟，isn 和 n 之间的差的绝对值是相同的
    //绝对 n -> 相对ans 
    // ans = n - isn + k*(1ULL << 32)
    //n - isn + k * (1ULL << 32) 接近 checkpoint ,同时满足ans >= 0  ,求k
    //即 k * (1ULL << 32) 接近 checkpoint - n + isn，整个过程其实就是在求k
    uint64_t absolute_seqno = n.raw_value() - isn.raw_value();
    if(checkpoint <= absolute_seqno){
        //如果出现了超过 2^31 的序号出现，说明传输过程出现了错误
        return absolute_seqno;
    }else{
        uint64_t cycle_size = 1uL << 32; //seqno 的一个周期是 2^32
        uint64_t k = (checkpoint - absolute_seqno) >> 32; //取商
        uint64_t remainder = ((checkpoint - absolute_seqno) << 32) >> 32; //取余数
        if(remainder < cycle_size >> 1){
            return k * cycle_size + absolute_seqno;
            // 不做这个判断也是可以的，说明测试用例中没有 k == 0  &&  n - isn < 0 的情况
            // if(k == 0 && n.raw_value() < isn.raw_value()){
            //     return cycle_size + absolute_seqno;
            // }else{
            //     return k * cycle_size + absolute_seqno;
            // }
        }else{
            return (k+1) * cycle_size + absolute_seqno;
        }
    }
}
```

## 3.2 Implementing the TCP receiver

 在这个实验剩下的部分，我们将会实现TCPReceiver

1. 从对等端接受 TCPSegment
2. 使用流重组器重新组装字节流
3. 计算ackno 和 window size，它们最后被发送回对等端



下面的图是两个端点相互发送的信息，是下一层数据包的载荷。非灰色的字段是这个lab关注的部分

- 序号 Sequence Number
- SYN and FIN flags
- Payload
- 它们被发送端写入，被接收端读取和操作

<img src="https://happychan.oss-cn-shenzhen.aliyuncs.com/img/image-20210621113618612.png" alt="image-20210621113618612" style="zoom:67%;" />

可以去官方的TCP library查看DataStructure和一些 API，还是很有帮助的，虽然看代码也一样

```c++
// Construct a `TCPReceiver` that will store up to `capacity` bytes
TCPReceiver(const size_t capacity); // implemented for you in .hh file

// Handle an inbound TCP segment
void segment_received(const TCPSegment &seg);

// The ackno that should be sent to the peer
// returns empty if no SYN has been received
// This is the beginning of the receiver's window, or in other words,
// the sequence number of the first byte in the stream
// that the receiver hasn't received.
std::optional<WrappingInt32> ackno() const;

// The window size that should be sent to the peer
// Formally: this is the size of the window of acceptable indices
// that the receiver is willing to accept. It's the distance between
// the ``first unassembled'' and the ``first unacceptable'' index.
// In other words: it's the capacity minus the number of bytes that the
// TCPReceiver is holding in the byte stream.
size_t window_size() const;

// number of bytes stored but not yet reassembled
size_t unassembled_bytes() const; // implemented for you in .hh file

// Access the reassembled byte stream
ByteStream &stream_out(); // implemented for you in .hh file
```

### 3.2.1 要工作，每次从对等端接收一个新的数据段时，都会调用一次 segment_received()

实现这个函数是本次实验的主要工作，每次从对等端接收一个新的数据段时，都会调用一次 segment_received()

方法所需：

- 在需要的时候初始化ISN。第一个携带SYN 标志集到达的段的seqno就是 ISN。我们将会跟踪该值，以便使得能够在32位包装的seqnos/acknos 和 它们的绝对值对等项之间转换。（记住： SYN flag 值是TCP头部的一个标志位。同样的段也能够同时携带 FIN 标志位，所以 SYN 和 FIN 可能在一个段内一起到达）
- 把所有的数据和流结束标志交给 StreamReassembler。如果TCP header 中的 FIN标志位被设置了，那么就意味着负载的最后一个字节就是整个流的最后一个字节。记住：StreamReassembler 期望 stream indexes 从 zero 开始，你需要 unwrap seqno 来生成 stream indexes

### 3.2.2 ackno( )

返回一个 optional <WrappingIne32> 类型的包含接受方expected的第一个字节的序号。这个是接收窗口的左边界：接收者想要接收的第一个字节。如果 ISN 还没有被设置，则返回 empty optional

### 3.2.3 window_size( )

返回“first unassembled”到 “first unacceptable”下标之间的距离，就是capacity中红色区域的值( lab1 的图)

<img src="https://happychan.oss-cn-shenzhen.aliyuncs.com/img/image-20210613235101348.png" alt="image-20210613235101348" style="zoom:67%;" />

## 3.3 Evolution of the TCPReceiver over the life of the connection

TCPReceiver 在连接过程中的整个生命周期的一系列状态演化（从上到下）：

1. waiting for a SYN ( with empty ackno )
2. an in-progress stream，一个正在进行的流
3. to a stream that's finished，流已经完成，意味着ByteStream关闭
4. 不考虑错误状态

<img src="https://happychan.oss-cn-shenzhen.aliyuncs.com/img/image-20210621161642727.png" alt="image-20210621161642727" style="zoom:67%;" />

### 代码实现

```c++
//设置isn，用于保存syn到来时的seqno index，也作为 ackno 的返回值标志
size_t isn = 0;
size_t base = 0; //TCPReceiver希望接收的ackno

bool finFlag = false;
bool synFlag = false;
```



```c++
void TCPReceiver::segment_received(const TCPSegment &seg) {
    uint64_t absolute_seqno = 0;
    // 需要 string data,uint64_t index,bool eof
    //判断该 TCPSegment 是否包含 syn set
    if(seg.header().syn){
        if(synFlag){
            // 拒绝其他 syn 请求
            return;
        }
        //更改标志位，以便ackno()
        //记录 isn
        synFlag = true;
        absolute_seqno = 1; //这里一定要初始化为1，不能为0。不然后面转为stream index 传递给  _reassembler.push_substring()时，可能会导致 0 - 1 溢出，然后就会直接返回，导致错误
        isn = seg.header().seqno.raw_value();
        // base = 1; //stream index 开启标志，免得 ackno 误判
    }else if(synFlag){
        //计算 absolute_seqno index
        WrappingInt32 seqno = seg.header().seqno;
        //checkpoint 就是 you’ll use the index of the last reassembled byte as the checkpoint -> first unassembled
        absolute_seqno = unwrap(seqno, WrappingInt32(isn), _reassembler.get_unassembled_index());
    }else{
        // listen 状态 拒绝所有 segment
        return;
    }

    //可能是携带 FIN 的数据报文段，所以要考虑
    if(seg.header().fin){
        if(finFlag){
            return; //拒绝其他fin
        }
        finFlag = true;
    }
    _reassembler.push_substring(seg.payload().copy(), absolute_seqno - 1, finFlag);
    base = _reassembler.get_unassembled_index() + 1; // 期望接收的值未重组部分的第一个字节，即window的left edge，因为 get_unassembled_index 返回的是 _header_index：绿色区域的最后一个字节index，所以要+1，表示

    // 这里不能用 finFlag 来判断，只有当流关闭的时候，base才要+1,finFlag是收到fin标志位就变为true，而此时的ByteStream可能还有剩余的数据没有交付完，尚未关闭，因此不能以finFlag作为TCPReceiver结束的标志,而应该以_reassembler.input_ended()是否关闭作为标志
    if(_reassembler.input_ended()) {
        base++; // FIN be count as one byte
    }
}

optional<WrappingInt32> TCPReceiver::ackno() const {
    if(base > 0){
        return WrappingInt32(wrap(base,WrappingInt32(isn)));
    }else{
        return {};
    }
}

size_t TCPReceiver::window_size() const {
    size_t size = _capacity - _reassembler.stream_out().bytes_written() + _reassembler.stream_out().bytes_read();
    return size;
}
```

## 复盘

还是读不太懂题目，或者说对实验的要求分析的不够，导致无法完全理解。lab2 比 lab1 好多了，在lab1的基础上，至少自己也动手写了一点代码。有大概的思路，对于一些c++的语法问题不是很懂（问题不大），最主要是还是太急躁了，太想完成实验了，功利心导致我无法冷静下来好好思考整个过程。复盘来看，其实只要读懂lab的文档，好好体会这个状态图，那么其实并不难解决。

测试用例确实能够检测我们所写代码的逻辑周密性，比如

- 思考 SYN 和 FIN 同时到达怎么处理？
- 三个流之间是如何进行转化的？
-  finFlag 和 _reassembler.stream_out().input_end() 是否是线程安全的？（它们在执行重排序之后，会造成不一致，导致finFlag变了而end没变，即使逻辑上是先改变end在改变flag）

Debug的时候也太坑了，gcc自动优化了程序，导致断点是跟不上的，乱跳，很难捋清楚错的地方在哪里。搞了我很多的时间。下次看看怎么取消自动优化。

## 问题

### make时发现找不到<pcap.h>文件

```shell
解决办法是：安装libpcap-devel
yum install libpcap-devel
```

## Reference

https://www.cnblogs.com/kangyupl/p/stanford_cs144_labs.html

https://zhuanlan.zhihu.com/p/262274265

https://blog.csdn.net/weixin_44520881/article/details/108911578

https://blog.csdn.net/u012495807/article/details/113193379

https://cs144.github.io/