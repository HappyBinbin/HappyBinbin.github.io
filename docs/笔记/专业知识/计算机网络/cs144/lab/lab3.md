# lab3

lab3 要我们做的事情是什么呢？细读文档（至少也得读它个三遍），就是要我们实现 TCPSender，其实也就给了四个接口

- void fill_windows( )
- void ack_received( const WrappingInt32 ackno, const uint16_t windows_size )
- void tick( const size_t ms_since_last_tick )
- void send_empty_segment( )

## fill_windows( )

该接口就是 TCPSender 用来填充发送窗口的，它从 ByteStream 里面读取字节，然后根据构造一个 TCPSegment ，放到 queue<TCPSegment> 里面（lab 中是假设只要放入队列中就算发送出去了）；只要当窗口有空位或者 ByteStream 里还有字节未读完，就一直填充。注意：TCPSegment 的大小不能超过TCPConfig限制的 1452 字节。

注意看下图 TCPSegment 所需要的东西

- seqno，序列号，这个需要 wrap(_next_seqno, _isn) 来构建，下一个要发送的字节的序列号和ISN可以构建
- SYN，同步信息，如果尚未构建连接，则要先发送 SYN 包，此时的 seqno 应该为 0
- payload，有效载荷，从ByteStream中读取的所有字节数据
- FIN，断开位，最后一个包，可以携带数据，也可以不携带

<img src="https://happychan.oss-cn-shenzhen.aliyuncs.com/img/image-20210613120727703.png" alt="image-20210613120727703" style="zoom:60%;" />

## ack_received（）

这个接口，会接收两个参数值，一个是 ackno，一个是window_size，即对等端接收窗口的左边界和窗口大小。这个接口要做的功能就是，根据发送方的窗口信息，来调整自己的信息，并选择重传报文段

1. 根据 ackno，可以知道哪些数据段中的所有序号已经确认被完全接收了，这样的已经发送但尚未确认交付的段（FAQs中提示这些段我们是要保留其引用的，这样才能重传），就可以不用保留了，我们可以剔除掉
2. 根据 window_size，可以调整 TCPSender 这边的窗口大小
3. 在剔除掉已经完全确认接收的段后，因为窗口大小已经更新，调用 fill_windows（）看看是否能继续传送
4. 当对等端的接受方发送ackno 成功确认报文段时，就需要重置RTO的值为初始值1s，重启_timer，以便其他报文段能使用超时重传计时器，重置连续重传次数

## tick( )



## 代码实现

多说无益，直接看代码就完事了

### tcp_sender.hh

```c++
class TCPSender {
  private:
    //! our initial sequence number, the number for our SYN.
    WrappingInt32 _isn;

    //! outbound queue of segments that the TCPSender wants sent
    std::queue<TCPSegment> _segments_out{};

    //! retransmission timer for the connection
    unsigned int _initial_retransmission_timeout;

    //! outgoing stream of bytes that have not yet been sent
    ByteStream _stream;

    //! the (absolute) sequence number for the next byte to be sent
    uint64_t _next_seqno{0};

    //已经确认的ack序号
    size_t _recv_ackno{};

    //开始和结束flag
    bool _syn{};
    bool _fin{};

    //窗口大小
    size_t _win_size{};
    //已发送但尚未确认的段占用的序号数
    size_t _byte_in_flight{};

    //已发送但尚未确认的段
    std::queue<TCPSegment> _segments_outstanding{};

    //timer
    unsigned int _retransmission_timeout;
    bool _time_run{false};
    size_t _timer = 0;
    unsigned int _consecutive_retransmissions{0};


  public:
    //! Initialize a TCPSender
    TCPSender(const size_t capacity = TCPConfig::DEFAULT_CAPACITY,
              const uint16_t retx_timeout = TCPConfig::TIMEOUT_DFLT,
              const std::optional<WrappingInt32> fixed_isn = {});

    //! \name "Input" interface for the writer
    //!@{
    ByteStream &stream_in() { return _stream; }
    const ByteStream &stream_in() const { return _stream; }
    //!@}

    //! \name Methods that can cause the TCPSender to send a segment
    //!@{

    //! \brief A new acknowledgment was received
    void ack_received(const WrappingInt32 ackno, const uint16_t window_size);

    //! \brief Generate an empty-payload segment (useful for creating empty ACK segments)
    void send_empty_segment();

    //! \brief create and send segments to fill as much of the window as possible
    void fill_window();

    //! \brief Notifies the TCPSender of the passage of time
    void tick(const size_t ms_since_last_tick);
    //!@}

    //! \name Accessors
    //!@{

    //! \brief How many sequence numbers are occupied by segments sent but not yet acknowledged?
    //! \note count is in "sequence space," i.e. SYN and FIN each count for one byte
    //! (see TCPSegment::length_in_sequence_space())
    size_t bytes_in_flight() const;

    //! \brief Number of consecutive retransmissions that have occurred in a row
    unsigned int consecutive_retransmissions() const;

    //! \brief TCPSegments that the TCPSender has enqueued for transmission.
    //! \note These must be dequeued and sent by the TCPConnection,
    //! which will need to fill in the fields that are set by the TCPReceiver
    //! (ackno and window size) before sending.
    std::queue<TCPSegment> &segments_out() { return _segments_out; }
    //!@}

    //! \name What is the next sequence number? (used for testing)
    //!@{

    //! \brief absolute seqno for the next byte to be sent
    uint64_t next_seqno_absolute() const { return _next_seqno; }

    //! \brief relative seqno for the next byte to be sent
    WrappingInt32 next_seqno() const { return wrap(_next_seqno, _isn); }
    //!@}
};
```



### tcp_sender.cc

```c++

//! \param[in] capacity the capacity of the outgoing byte stream
//! \param[in] retx_timeout the initial amount of time to wait before retransmitting the oldest outstanding segment
//! \param[in] fixed_isn the Initial Sequence Number to use, if set (otherwise uses a random ISN)
TCPSender::TCPSender(const size_t capacity, const uint16_t retx_timeout, const std::optional<WrappingInt32> fixed_isn)
    : _isn(fixed_isn.value_or(WrappingInt32{random_device()()}))
    , _initial_retransmission_timeout{retx_timeout}
    , _stream(capacity)
    , _retransmission_timeout(retx_timeout) {}

uint64_t TCPSender::bytes_in_flight() const {
    return _byte_in_flight;
}

void TCPSender::fill_window() {
    TCPSegment seg; //本次方法要发送的段
    //syn包是否已经发送
    if(!_syn){
        //如果还未发送,进行包装
        seg.header().syn = true;
        seg.header().seqno = wrap(0,_isn);
        //更新值与状态
        _syn = true;
        _next_seqno = 1;
        _segments_outstanding.push(seg);
        _byte_in_flight += 1;
        //发送
        _segments_out.push(seg);
    }else{
        //发送其他段
        uint64_t window_size = (_win_size == 0 ? 1 : _win_size);
        uint64_t remain_size{};
        /// when window isn't full and never sent FIN
        while(!_fin && (remain_size = window_size - (_next_seqno - _recv_ackno)) != 0){
            size_t payload_size = min(TCPConfig::MAX_PAYLOAD_SIZE,remain_size);
            string str = _stream.read(payload_size);
            seg.payload() = Buffer(std::move(str));
            // fin段也可以携带数据
            if(_stream.eof() && seg.length_in_sequence_space() < remain_size){
                seg.header().fin = true;
                _fin = true;
            }
            
            //stream is empty, break
            if(seg.length_in_sequence_space() == 0){
                break;
            }
            // stream不为空，则封装TCPSegment，然后发送，更新状态信息
            seg.header().seqno = next_seqno();
            _next_seqno += seg.length_in_sequence_space();
            _byte_in_flight += seg.length_in_sequence_space();
            _segments_out.push(seg);
            _segments_outstanding.push(seg);
        }
    }
    // 每次发送段时，如果timer未启动，则启动
    if(!_time_run){
        _time_run = true;
        _timer = 0;
    }  
}

//! \param ackno The remote receiver's ackno (acknowledgment number)
//! \param window_size The remote receiver's advertised window size
void TCPSender::ack_received(const WrappingInt32 ackno, const uint16_t window_size) {
    size_t abs_ackno = unwrap(ackno,_isn,_recv_ackno);
    _win_size = window_size;
    //说明改ackno之前的段已经都确认过了，直接返回
    if(abs_ackno <= _recv_ackno) return;
    //否则更新_recv_ackno 的值为当前ackno
    _recv_ackno = abs_ackno;
    TCPSegment seg;
    //剔除掉ackno之前已经全部确认的段
    while(!_segments_outstanding.empty()){
        seg = _segments_outstanding.front(); // lab采用的是回退N步
        //判断取得的头段，其序号值的范围是否小于 abs_ackno
        if(unwrap(seg.header().seqno,_isn,_recv_ackno) + seg.length_in_sequence_space() <= abs_ackno){
            //是则说明该段不需要重发,可以从重发queue中删掉了
            //更新状态值
            _byte_in_flight -= seg.length_in_sequence_space();
            _segments_outstanding.pop();
        }else{
            break;
        }
    }
    //继续调用填充窗口函数，看看是否能继续发送
    fill_window();
    //Lab讲到，当对等端的接受方发送ackno 成功确认报文段时，就需要重置RTO的值为初始值1s，重启_timer，以便其他报文段能使用超时重传计时器，重置连续重传次数
    _retransmission_timeout = _initial_retransmission_timeout;
    _consecutive_retransmissions = 0;
    _timer = 0;
    return;
}

//! \param[in] ms_since_last_tick the number of milliseconds since the last call to this method
void TCPSender::tick(const size_t ms_since_last_tick) { 
    //_timer每次加上ms_since_last_tick（即自上次tick()被调用经过的时间）
    _timer += ms_since_last_tick;
    //判断 _timer 是否已经超过我们设定的 _retransmission_timeout 即 1s（刚开始是 1s）
    if(_timer >= _retransmission_timeout && _time_run && !_segments_outstanding.empty()){
        //超时则重传
        _segments_out.push(_segments_outstanding.front());
        //重传次数+1
        _consecutive_retransmissions ++;
        //如果此时 tick 被调用 && 超时 && 窗口大小不为0，则认为是网络阻塞，指数规避，延长重传时间
        if(_segments_outstanding.front().header().syn == true || _win_size != 0){
            _retransmission_timeout *= 2;
        }
        // 将 _timer 重新置0，以重新计算到达下一次超时的时间
        _timer = 0;
    }
 }

unsigned int TCPSender::consecutive_retransmissions() const { return _consecutive_retransmissions;}

void TCPSender::send_empty_segment() {
    TCPSegment seg;
    seg.header().seqno = next_seqno();
    _segments_out.push(seg);
}
```



















































