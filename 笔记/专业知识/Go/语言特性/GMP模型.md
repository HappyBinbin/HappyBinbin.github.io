
## Reference
- https://www.cnblogs.com/oaoa/p/17315130.html  写的真好


GMP模型
- Goutinue 协程
- Machine：内核线程
- Process：处理器


GMP之间的关系：

![image.png](https://happychan.oss-cn-shenzhen.aliyuncs.com/picgo/20250223221851.png)

GMP 调度模型：

![image.png](https://happychan.oss-cn-shenzhen.aliyuncs.com/picgo/20250223221929.png)

### 重要的设计理念

#### 复用线程：

避免频繁的创建、销毁线程，而是对线程的复用

- work stealing线程：当本线程无可运行的G时，尝试从其他线程绑定的P偷取G，而不是销毁线程
- hand off机制：当本线程因为G进行系统调用阻塞时，线程释放绑定的P，把P转移给其他空闲的线程执行

#### 利用并行：

GOMAXPROCS设置P的数量，最多有GOMAXPROCS个线程分布在多个CPU上同时运行

#### 抢占：

在goroutine中要等待一个协程主动让出CPU才能执行下一个协程，在Go中，一个goroutine最多占用CPU 10ms，防止其他goroutine被饿死

#### 全局G队列：

当M执行work stealing从其他P偷不到G时，它可以从全局G队列获取G