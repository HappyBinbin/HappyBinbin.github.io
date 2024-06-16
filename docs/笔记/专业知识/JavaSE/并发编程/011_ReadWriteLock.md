# ReadWriteLock

## 解决了什么问题？

<img src="https://happychan.oss-cn-shenzhen.aliyuncs.com/img/image-20220103172342789.png" alt="image-20220103172342789" style="zoom:67%;" />

- 大量线程在竞争同一份资源
- 有读请求，也有写请求
- 读请求明显多于写请求

可以看出，这是很明显的缓存应用场景。关键的问题在于，为了保持数据的一致性，读写缓存的时候，不能让读请求拿到脏数据，这就需要用到锁。读读之间不互斥，读写之间互斥。

- 

## 如何理解

也就是说：

- 数据允许多个线程同时读取，但只允许一个线程进行写入
- 在读取数据的时候，不可以存在写操作
- 在写数据的时候，不可以存在读操作

<img src="https://happychan.oss-cn-shenzhen.aliyuncs.com/img/image-20220103173026000.png" alt="image-20220103173026000" style="zoom:67%;" />

## 自定义 ReadWriteLock

```java
public class ReadWriteLock{

    private int readers       = 0;
    private int writers       = 0;
    private int writeRequests = 0;

    public synchronized void lockRead() throws InterruptedException{
        while(writers > 0 || writeRequests > 0){
            wait();
        }
        readers++;
    }

    public synchronized void unlockRead(){
        readers--;
        notifyAll();
    }

    public synchronized void lockWrite() throws InterruptedException{
        writeRequests++;

        while(readers > 0 || writers > 0){
            wait();
        }
        writeRequests--;
        writers++;
    }

    public synchronized void unlockWrite() throws InterruptedException{
        writers--;
        notifyAll();
    }
}
```

## Java 中的 ReadWriteLock 

ReentrantReadWriteLock 中，包含了两个内部类，实现了 ReadWriteLock 接口，而两个内部类又实现了 Lock 接口

<img src="https://happychan.oss-cn-shenzhen.aliyuncs.com/img/image-20220103174443055.png" alt="image-20220103174443055" style="zoom: 67%;" />

### 读写锁的升级与降级

**从读锁到写锁，称之为锁的升级，反之为锁的降级**

下面看两段代码和输出结果，立即 ReentrantReadWriteLock 的升降级策略

#### 代码1

```java
public class ReadWriteLockDemo {
    public static void main(String[] args) {
        ReadWriteLock readWriteLock = new ReentrantReadWriteLock();
        readWriteLock.readLock().lock();
        System.out.println("已经获取读锁...");
        readWriteLock.writeLock().lock();
        System.out.println("已经获取写锁...");
    }
}
```

输出结果如下：

```shell
已经获取读锁...
```

#### 代码2

```java
public class ReadWriteLockDemo {
    public static void main(String[] args) {
        ReadWriteLock readWriteLock = new ReentrantReadWriteLock();
        readWriteLock.writeLock().lock();
        System.out.println("已经获取写锁...");
        readWriteLock.readLock().lock();
        System.out.println("已经获取读锁...");
    }
}
```

输出结果如下：

```shell
已经获取写锁...
已经获取读锁...

Process finished with exit code 0
```

很明显，ReentrantReadWriteLock支持锁的降级，但不支持锁的升级

### 读写锁中的公平性

**在ReentrantReadWriteLock中，同时提供了公平和非公平两种模式，且默认为非公平模式**。从下面摘取的源码片段中，可以清晰地看到。

```java
public ReentrantReadWriteLock() {
    this(false);
}

/**
   /**
 * Creates a new {@code ReentrantReadWriteLock} with
 * default (nonfair) ordering properties.
 */
public ReentrantReadWriteLock() {
    this(false);
}

/**
 * Creates a new {@code ReentrantReadWriteLock} with
 * the given fairness policy.
 *
 * @param fair {@code true} if this lock should use a fair ordering policy
 */
public ReentrantReadWriteLock(boolean fair) {
    sync = fair ? new FairSync() : new NonfairSync();
    readerLock = new ReadLock(this);
    writerLock = new WriteLock(this);
}
```

## 课外阅读

http://tutorials.jenkov.com/

## 课外阅读

OS 的公平读写锁的实现代码