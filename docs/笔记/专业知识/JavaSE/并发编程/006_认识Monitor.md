# 从synchronized中的锁认识Monitor

**Monitor作为一种同步机制**，它并非Java所特有，但Java实现了这一机制。

## 医院排队理解Monitor机制

我们去医院时，情况一般是这样的：

- 首先，我们在**门诊大厅**前台或自助挂号机**进行挂号**；

- 随后，挂号结束后我们找到对应的

    诊室就诊

    ：

    - 诊室每次只能有一个患者就诊；
    - 如果此时诊室空闲，直接进入就诊；
    - 如果此时诊室内有患者正在就诊，那么我们进入**候诊室**，等待叫号；

- 就诊结束后，**走出就诊室**，候诊室的**下一位候诊患者**进入就诊室。

<img src="https://gitee.com/HappyBinbin/pcigo/raw/master/image-20211214195521637.png" alt="image-20211214195521637" style="zoom:50%;" />

医院

- **互斥（mutual exclusion ）**：每次只允许一个患者进入候诊室就诊
- **协作（cooperation）**：就诊室中的患者就诊结束后，可以通知候诊区的下一位患者

Monitor

- **互斥（mutual exclusion ）**：每次只允许一个线程进入临界区
- **协作（cooperation）**：当临界区的线程执行结束后满足特定条件时，可以通知其他的等待线程进入

而就诊过程中的**门诊大厅**、**就诊室**、**候诊室**则恰好对应着Monitor中的三个关键概念。其中：

- **门诊大厅**：所有待进入的线程都必须先在**入口（Entry Set）**挂号才有资格
- **就诊室**：一个每次只能有一个线程进入的**特殊房间（Special Room）**
- **候诊室**：就诊室繁忙时，进入**等待区（Wait Set）**

<img src="https://gitee.com/HappyBinbin/pcigo/raw/master/image-20211214195619550.png" alt="image-20211214195619550" style="zoom:50%;" />

**synchronized正是对Monitor机制的一种实现**。而在Java中，**每一个对象都会关联一个监视器**

























