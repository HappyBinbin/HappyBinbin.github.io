# ThreadLocal

​	 ThreadLocal 的作用是：提供线程内的局部变量，不同的线程之间不会相互干扰，这种变量在线程的生命周期内起作用，减少同一个线程内多个函数或组件之间一些公共变量传递的复杂度。

1. 线程并发: 在多线程并发的场景下
2. 传递数据: 我们可以通过ThreadLocal在同一线程，不同组件中传递公共变量
3. 线程隔离: 每个线程的变量都是独立的，不会互相影响



## 数据结构

<img src="https://happychan.oss-cn-shenzhen.aliyuncs.com/img/202111012324841.png" alt="image-20211101232448784" style="zoom: 80%;" />

