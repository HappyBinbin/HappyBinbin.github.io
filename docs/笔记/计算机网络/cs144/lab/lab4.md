# lab4（未完，待续）

[TOC]

啊，做到lab4，我真的已经快被掏空了，脑子都是一片混乱的，lab的文档有些都看不懂，难度确实太大了（对我来说

最后只能借鉴大佬们的思路了，就摁抄

但还是有些测试用例没通过，不知道是前几个lab的问题还是哪里出错了，哎，累了，过几天有兴趣再搞，pass 掉先

## tcp_connection.hh

```c++
//! record the time_since_last_segment_received
size_t _time_since_last_segment_received{};
bool _active {true};
//! \brief send the segments from TCPSender's segment_out
void send_sender_segments();
//! \brief brain-bending part, clean shutdown 
void clean_shutdown();
//! \brief brain-bending part, unclean shutdown
void unclean_shutdown();
```



那么什么是 clean shutdown 什么是 unclean shutdown 呢？

在 unclean shutdown 情况下，发送或接收的报文段包会含有 RST 的标志，在这个时候，出站和入站的字节流都是处于一个错误状态，并且 active() 也处于 false 状态

在 clean shutdown 情况下呢，自然就是在没有错误的情况下关闭连接了。什么时候可以 clean shutdown 呢？
    1. 入站字节流已经被完整组装
    2. 出站字节流已经被全部发送（包括 FIN ）
    3. 出站字节流被接收方全部确认
    4. 本地 TCPConnection 确保远端也满足条件 3，具体实现呢，他给了两种方法
		当条件 1 到 3 都满足并且至少 10 倍的初始重传时间内本地都没有收到对方的新报文
		被动关闭，但是这个我看的不是太懂 Prerequisites #1 through #3 are true, and the local peer is 100% certain that the remote peer can satisfy prerequisite #3. How can this be, if TCP doesn’t acknowledge acknowledgments? Because the remote peer was the first one to end its stream.
            	
除此之外，还有一个 _linger_after_streams_finish 变量用于指示在出入流都结束后是否还需要保持 active 状态直到 10 倍重传时间之后。5.1 中提到，当入站流在出站流到达 EOF 之前结束的话，该变量需要设置成 false

## tcp_connection.cc

```c++

size_t TCPConnection::remaining_outbound_capacity() const { 
    return _sender.stream_in().remaining_capacity();
}

size_t TCPConnection::bytes_in_flight() const {
    return _sender.bytes_in_flight(); 
}

size_t TCPConnection::unassembled_bytes() const {
    return _receiver.unassembled_bytes();
}

size_t TCPConnection::time_since_last_segment_received() const {
    return _time_since_last_segment_received;
}

bool TCPConnection::active() const { 
    return _active; 
}

void TCPConnection::segment_received(const TCPSegment &seg) {
    //判断TCPConnection 的状态
    if(!_active){
        return;
    }

    //计时，最近一次 segment 到达的时间
    _time_since_last_segment_received = 0;

    //State: closed
    //发送来的没值，而且下一个要发的byte的absolute seqo是0
    //说明是要建立连接
    if(!_receiver.ackno().has_value() && _sender.next_seqno_absolute() == 0){
        if(!seg.header().syn){
            return;
        }
        _receiver.segment_received(seg);
        connect();
        return;
    }

    //State: syn sent
    //发过syn了且recvived为空，表明未收到发来的syn
    if(_sender.next_seqno_absolute() > 0 && _sender.bytes_in_flight() == _sender.next_seqno_absolute()
    && !_receiver.ackno().has_value()){
        //收到的payload有值，不管
        if(seg.payload().size()){
            return;
        }
        //如果在 syn-sent 状态下，收到对方的 syn
        if(!seg.header().ack){
            if(seg.header().syn){
                // simultaneous open,切换到 State: sent-received 
                _receiver.segment_received(seg);
                _sender.send_empty_segment();
            }
            return;
        }
        //收到 reset
        if(seg.header().rst){
            _receiver.stream_out().set_error();
            _sender.stream_in().set_error();
            _active = false;
            return;
        }
    }

    //收到的是建立连接之后的数据
    _receiver.segment_received(seg);
    //存下ack number，以及weindow size，为下次发送做准备
    _sender.ack_received(seg.header().ackno,seg.header().win);

    // Lab3 behavior: fill_window() will directly return without sending any segment.
    if(_sender.stream_in().buffer_empty() && seg.length_in_sequence_space()){
        _sender.send_empty_segment();
    }

    //建立连接之后收到 reset
    if(seg.header().rst){
        _sender.send_empty_segment();
        unclean_shutdown();
        return;
    }
    //发数据
    send_sender_segments();
}




size_t TCPConnection::write(const string &data) {
    if(!data.size()){
        return 0;
    }
    size_t written_len = _sender.stream_in().write(data);
    
     _sender.fill_window();
    //发送，其实感觉可以没这个发送
    send_sender_segments();
    
    return written_len;
}

//! \param[in] ms_since_last_tick number of milliseconds since the last call to this method
void TCPConnection::tick(const size_t ms_since_last_tick){ 
    //时间检查，超时重发
    if(!_active){
        return;
    }
    _time_since_last_segment_received += ms_since_last_tick;
    //递归等return
    _sender.tick(ms_since_last_tick);
    //超时重传次数过多
    if(_sender.consecutive_retransmissions() > TCPConfig::MAX_RETX_ATTEMPTS){
        //异常
        unclean_shutdown();
    }
    //发
    send_sender_segments();
  
}

void TCPConnection::end_input_stream() {
    // stop outbound byte stream input
    _sender.stream_in().end_input();

    //发送断开连接的segment
    _sender.fill_window();
    send_sender_segments();
}

void TCPConnection::send_sender_segments(){
    
    TCPSegment seg;
    while(!_sender.segments_out().empty()){
        //获取sender头
        seg = _sender.segments_out().front();
        //更新状态
        _sender.segments_out().pop();
        //根据 receiver 的 ackno 值 设置 segments 的标志位
        if(_receiver.ackno().has_value()){
            seg.header().ack = true;
            seg.header().ackno = _receiver.ackno().value();
            seg.header().win = _receiver.window_size();
        }
        _segments_out.push(seg);
    }
    clean_shutdown();
}

void TCPConnection::connect() {
    //给 Sender 上数据
    _sender.fill_window();
    
    //用 TCPConnection 发出去
    send_sender_segments();

}

TCPConnection::~TCPConnection() {
    try {
        if (active()) {
            cerr << "Warning: Unclean shutdown of TCPConnection\n";
            // Your code here: need to send a RST segment to the peer
            // 当调用析构函数，并且 active() 值为 true 时，需要发送一个空的segments附带 RST FALG
            _sender.send_empty_segment();
            unclean_shutdown();
        }
    } catch (const exception &e) {
        std::cerr << "Exception destructing TCP FSM: " << e.what() << std::endl;
    }
}

void TCPConnection::clean_shutdown(){
    if(_receiver.stream_out().input_ended()){
        if(!_sender.stream_in().eof()){
            _linger_after_streams_finish = false;
        }else if(_sender.bytes_in_flight() == 0){
            if(!_linger_after_streams_finish || time_since_last_segment_received() >= 10 * _cfg.rt_timeout){
                _active = false;
            }
        }
    }
}

void TCPConnection::unclean_shutdown(){
    // When this being called, _sender.stream_out() should not be empty.
    _receiver.stream_out().set_error();
    _sender.stream_in().set_error();
    _active = false;
    TCPSegment seg = _sender.segments_out().front();
    _sender.segments_out().pop();
    seg.header().ack = true;
    if(_receiver.ackno().has_value()){
        seg.header().ackno = _receiver.ackno().value();
    }
    seg.header().win = _receiver.window_size();
    seg.header().rst = true;
    _segments_out.push(seg);
}

```

