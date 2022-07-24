# ThreadLocal 详解

重点理解

- set( )
- get( )
- expungeStaleEntry( )
- getEntry( )
- ThreadLocal、Thread、ThreadLocalMap 之间的关系
- 弱引用是如何造成内存泄漏的？什么情况下会？如何防止？
- ThreadLocal 的使用场景



## 什么是 ThreadLocal

变量值的共享可以使用public [static](https://so.csdn.net/so/search?q=static&spm=1001.2101.3001.7020)的形式，所有线程都使用同一个变量，如果想实现**每一个线程都有自己的共享变量**该如何实现呢？JDK 中的ThreadLocal类正是为了解决这样的问题

ThreadLocal类并不是用来解决多线程环境下的共享变量问题，而是用来提供线程内部的共享变量，在多线程环境下，可以保证各个线程之间的变量互相隔离、相互独立。在线程中，可以通过get()/set()方法来访问变量

ThreadLocal实例通常来说都是private static类型的，它们希望将状态与线程进行关联。这种变量在线程的生命周期内起作用，可以减少同一个线程内多个函数或者组件之间一些公共变量的传递的复杂度

## 应用场景

- 在进行对象跨层传递的时候，使用 ThreadLocal 可以避免多次传递，打破层次间的约束
- 线程间数据隔离
- 进行事务操作，用于存储线程事务信息
- 数据库连接，Session会话管理

## 简单示例

可以看到，线程之间是独立的，thread2 线程 threadLocal1.get( ) 没有获得My name is threadLocal1

```java
public class ThreadLocalTest {

    private static ThreadLocal<String> threadLocal1 = new ThreadLocal<>();

    public static void main(String[] args) {
        Thread thread1 = new Thread(() -> {
            threadLocal1.set("My name is threadLocal1");
            System.out.println("thread1 name:" + threadLocal1.get());
            try {
                Thread.sleep(1000);
            } catch (InterruptedException e) {
                e.printStackTrace();
            }
        });

        Thread thread2 = new Thread(() -> {
            System.out.println("thread2 name:" + threadLocal1.get());
        });
        thread1.start();
        thread2.start();
    }
}
```

结果：

```java
thread2 name:null
thread1 name:My name is threadLocal1
```

## ThreadLocal、Thread、ThreadLocalMap 之间的关系

- 以例子中的结构分析

![image-20220408210915729](https://happychan.oss-cn-shenzhen.aliyuncs.com/img/pic/202204082109855.png)

线程1和线程2各自持有类型为ThreadLocal.ThreadLocalMap的threadLocals变量，key是ThreadLocal的引用，value为线程各自需要保持的值

一个 ThreadLocal 只能存储一个 Object 对象，如果需要存储多个Object对象那么就需要多个ThreadLocal，这也是 threadLocals 是一个类似 java.util.Map 的原因

```java
ThreadLocal.ThreadLocalMap threadLocals = null;
```

![image-20220408211021242](https://happychan.oss-cn-shenzhen.aliyuncs.com/img/pic/202204082110391.png)

- 一个 Thread 维护着一个 ThreadLocalMap 的引用
- ThreadLocalMap 是 ThreadLocal 的内部类，用 Entry 来进行存储，Entry 又是 ThreadLocalMap 的内部类
- ThreadLocalMap 的键 key 为 ThreadLocal 对象，一个 ThreadLocal只能保持一个Object对象，如果要保存多个，就需要创建多个 ThreadLocal 对象

## 重点方法

**ThreadLoaal#set( ) 方法**

```java
public void set(T value) {
    // 获得当前线程,即调用线程
    Thread t = Thread.currentThread();
    // 以当前线程为参数，获得当前线程的map，这个就是线程局部变量
    ThreadLocalMap map = getMap(t);
    if (map != null)
        // 如果map不为空，则以ThreadLocal实例引用为key保存vaue值
        map.set(this, value);
    else
        // 如果map为空，则创建map，并保存value。
        createMap(t, value);
}
```

对与 getMap( ) 方法，返回的是线程的变量 threadlocals

```java
ThreadLocalMap getMap(Thread t) {
    return t.threadLocals;
}
```

可以看到线程 Thread 类下持有一个ThreadLocal.ThreadLocalMap类型的类变量threadLocals，这个变量就是****线程局部变量****，这就是为什么线程之间互不影响的原因

```java
/* ThreadLocal values pertaining to this thread. This map is maintained
     * by the ThreadLocal class. */
ThreadLocal.ThreadLocalMap threadLocals = null;
```

从上面的分析中，可以看到，ThreadLocal的实现离不开ThreadLocalMap类，ThreadLocalMap类是ThreadLocal的静态内部类。每个Thread维护一个ThreadLocalMap映射表，这个映射表的key是ThreadLocal实例本身，value是真正需要存储的Object。这样的设计主要有以下几点优势：

- 这样设计之后每个Map的Entry数量变小了：之前是Thread的数量，现在是ThreadLocal的数量，能提高性能；
- 当Thread销毁之后对应的ThreadLocalMap也就随之销毁了，能减少内存使用量



**ThreadLocalMap#set( ) 方法**

- 这里的 key 就是示例代码中的 threadlocal1 的引用，并不是当前线程

```java
private void set(ThreadLocal<?> key, Object value) {
    Entry[] tab = table;
    int len = tab.length;
    int i = key.threadLocalHashCode & (len-1);
}
```



**ThreadLocal#get() 方法**

```java
public T get() {
    // 获得当前线程,即调用线程
    Thread t = Thread.currentThread();
    // 以当前线程为参数，获得当前线程的map，这个就是线程局部变量
    ThreadLocalMap map = getMap(t);
    if (map != null) {
        // 获取value值，这里的this还是变量**threadLocal1**的引用
        ThreadLocalMap.Entry e = map.getEntry(this);
        if (e != null) {
            @SuppressWarnings("unchecked")
            T result = (T)e.value;
            return result;
        }
    }
    //初始化线程的threadLocals变量
    return setInitialValue();
}
```



## 内存泄漏问题

### 前置知识

- 强引用：Java中默认的引用类型，一个对象如果具有强引用那么只要这种引用还存在就不会被GC

- 软引用：如果一个对象具有软引用，在JVM发生OOM之前（即内存充足够使用），是不会GC这个对象的；只有到JVM内存不足的时候才会GC掉这个对象

- 弱引用：如果一个对象只具有弱引用，那么这个对象只能生存到下一次GC之前，当发生GC时候，无论当前内存是否足够，弱引用所引用的对象都会被回收掉)

- 虚引用：所有引用中最弱的一种引用，其存在就是为了将关联虚引用的对象在被GC掉之后收到一个通知。对象随时可能被GC掉

- 内存泄漏：对象占用着内存，但是因为忘记在哪里，不能被回收，当这种对象越来越多时，内存不过，服务宕机

**Entry 结构**

ThreadLocalMap是用来存储与线程关联的value的哈希表，它具有 HashMap 的部分特性，比如容量、扩容阈值等，它内部通过Entry类来存储key和value，Entry类的定义为：

```java
static class Entry extends WeakReference<ThreadLocal<?>> {
    /** The value associated with this ThreadLocal. */
    Object value;

    Entry(ThreadLocal<?> k, Object v) {
        super(k);
        value = v;
    }
}
```

可以看到，Entry 继承自 WeakReference，意思就是 ThreadLocalMap 是使用 ThreadLocal 的弱引用作为 Key 的

分析到这里，我们可以得到下面这个对象之间的引用结构图（其中，实线为强引用，虚线为弱引用）

![image-20220408210353270](https://happychan.oss-cn-shenzhen.aliyuncs.com/img/pic/202204082103331.png)

我们知道，弱引用对象在Java虚拟机进行垃圾回收时，就会被释放，那我们考虑这样一个问题：

ThreadLocalMap 使用 ThreadLocal 的弱引用作为key，如果一个 ThreadLocal 没有外部关联的强引用，那么在虚拟机进行垃圾回收时，这个 ThreadLocal 会被回收，这样，ThreadLocalMap中就会出现 key 为 null 的 Entry，这些 key 对应的 value 也就再无妨访问，但是 value 却存在一条从Current Thread 过来的强引用链。因此只有当Current Thread销毁时，value才能得到释放

该强引用链如下：

> CurrentThread Ref -> Thread -> ThreadLocalMap -> Entry -> value

因此，只要这个线程对象被 gc 回收，那些 key 为 null 对应的 value 也会被回收，这样也没什么问题，但在线程对象不被回收的情况下，比如使用线程池的时候，核心线程是一直在运行的，线程对象不会回收，若是在这样的线程中存在上述现象，就可能出现内存泄露的问题

那在ThreadLocalMap中是如何解决这个问题的呢？

在获取key对应的value时，会调用ThreadLocalMap的getEntry(ThreadLocal<?> key)方法，该方法源码如下：

**ThreadLocal#getEntry( )方法**

```java
private Entry getEntry(ThreadLocal<?> key) {
    int i = key.threadLocalHashCode & (table.length - 1);
    Entry e = table[i];
    if (e != null && e.get() == key)
        return e;
    else
        return getEntryAfterMiss(key, i, e);
}
```

通过 key.threadLocalHashCode & (table.length - 1) 来计算存储 key 的 Entry 的索引位置，然后判断对应的 key 是否存在，若存在，则返回其对应的 value，否则，调用 getEntryAfterMiss(ThreadLocal<?>, int, Entry) 方法，源码如下：

```java
private Entry getEntryAfterMiss(ThreadLocal<?> key, int i, Entry e) {
    Entry[] tab = table;
    int len = tab.length;
 
    while (e != null) {
        ThreadLocal<?> k = e.get();
        if (k == key)
            return e;
        if (k == null)
            expungeStaleEntry(i);
        else
            i = nextIndex(i, len);
        e = tab[i];
    }
    return null;
}
```

ThreadLocalMap 采用线性探查的方式来处理哈希冲突，所以会有一个 while 循环去查找对应的 key，在查找过程中，若发现 key 为 null，即通过弱引用的 key 被回收了，会调用 expungeStaleEntry(int) 方法，其源码如下：

```java
private int expungeStaleEntry(int staleSlot) {
    Entry[] tab = table;
    int len = tab.length;
 
    // expunge entry at staleSlot
    tab[staleSlot].value = null;
    tab[staleSlot] = null;
    size--;
 
    // Rehash until we encounter null
    Entry e;
    int i;
    for (i = nextIndex(staleSlot, len);
            (e = tab[i]) != null;
            i = nextIndex(i, len)) {
        ThreadLocal<?> k = e.get();
        if (k == null) {
            e.value = null;
            tab[i] = null;
            size--;
        } else {
            int h = k.threadLocalHashCode & (len - 1);
            if (h != i) {
                tab[i] = null;
 
                // Unlike Knuth 6.4 Algorithm R, we must scan until
                // null because multiple entries could have been stale.
                while (tab[h] != null)
                    h = nextIndex(h, len);
                tab[h] = e;
            }
        }
    }
    return i;
}
```

通过上述代码可以发现，若 key 为 null，则该方法通过下述代码来清理与 key 对应的 value 以及 Entry：

```java
// expunge entry at staleSlot
tab[staleSlot].value = null;
tab[staleSlot] = null;
```

此时，CurrentThread Re f不存在一条到Entry对象的强引用链，Entry到 value 对象也不存在强引用，那在程序运行期间，它们自然也就会被回收。expungeStaleEntry(int) 方法的后续代码就是以线性探查的方式，调整后续 Entry 的位置，同时检查 key 的有效性

在 ThreadLocalMap 中的 set()/getEntry() 方法中，都会调用 expungeStaleEntry(int) 方法，但是如果我们既不需要添加 value，也不需要获取 value，那还是有可能产生内存泄漏的。所以很多情况下需要使用者手动调用 ThreadLocal 的 remove() 函数，手动删除不再需要的 ThreadLocal，防止内存泄露。若对应的 key 存在， remove() 方法也会调用 expungeStaleEntry(int) 方法，来删除对应的 Entry和value

其实，最好的方式就是将 ThreadLocal 变量定义成 private static 的，这样的话 ThreadLocal 的生命周期就更长，由于一直存在 ThreadLocal 的强引用，所以 ThreadLocal 也就不会被回收，也就能保证任何时候都能根据 ThreadLocal 的弱引用访问到 Entry 的 value 值，然后 remove 它，可以防止内存泄露

