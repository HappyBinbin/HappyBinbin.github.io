# 初体验Synchronized

1. 认识 synchronized 是什么？
2. 理解Java中的锁概念，锁的原理？
3. synchronize 的几种用法？



## 1、认识 synchronized 是什么？

synchronized 是 Java 中的一个关键字，能够提供一种预防线程干扰和内存一致性错误的简单策略，即如果一个对象对多个线程可见，那么该对象变量（`final`修饰的除外）的读写都需要通过`synchronized`来完成。

**线程干扰（Thread Interference）**：不同线程中运行但作用于相同数据的两个操作交错时，就会发生干扰。这意味着这两个操作由多个步骤组成，并且步骤顺序重叠；

**内存一致性错误（Memory Consistency Errors）**：当不同的线程对应为相同数据的视图不一致时，将发生内存一致性错误。内存一致性错误的原因很复杂，幸运的是，我们不需要详细了解这些原因，所需要的只是避免它们的策略。

从竞态的角度讲，线程干扰对应的是**Read-modify-write**，而内存一致性错误对应的则是**Check-then-act**。

结合**锁**和**synchronized**的概念可以理解为，锁是多线程安全的基础机制，而**synchronized**是锁机制的一种实现。

## 2、理解Java中的锁概念，锁的原理？

在 Java 中，每个对象都有一把锁，当多个线程都需要访问对象时，那么就需要通过获得锁来获得许可，只有获得锁的线程才能访问对象，并且其他线程将进入等待状态，等待其他线程释放锁。

<img src="https://gitee.com/HappyBinbin/pcigo/raw/master/image-20211213103351211.png" alt="image-20211213103351211" style="zoom:80%;" />

## 3、synchronize 的几种用法？

### 3.1 在实例方法中使用synchronized

```java
public synchronized int decreaseBlood() {
       blood = blood - 5;
       return blood;
}
```

它表示**当前方法每次能且仅能有一个线程访问**。另外，由于当前方法是实例方法，所以如果该对象存在多个实例的话，不同的实例可以由不同的线程访问，它们之间并无协作关系。

> 如果当前线程中有两个`synchronized`方法，不同的线程是否可以访问不同的`synchronized`方法呢？
>
> 答案是：**不能**
>
> 这是因为每个**实例内的同步方法，能且仅能有一个线程访问**

### 3.2 在静态方法中使用synchronized

```java
public static synchronized int decreaseBlood() {
       blood = blood - 5;
       return blood;
}
```

静态方法的`synchronized`是基于当前方法所属的类，即`Master.class`，而每个类在虚拟机上有且只有一个类对象。所以，对于同一类而言，每次有且只能有一个线程能访问静态`synchronized`方法。

当类中包含有多个静态的`synchronized`方法时，每次也仍然有且只能有一个线程可以访问其中的方法。

### 3.3 在实例方法的代码块中使用synchronized

```java
public int decreaseBlood() {
    synchronized(this) {
       blood = blood - 5;
       return blood;
    }
}
```

`synchronized`的并发限制取决于其参数，在上面这段代码中的参数是`this`，即当前类的实例对象。而在前面的`public synchronized int decreaseBlood()`中，`synchronized`的参数也是当前类的实例对象。因此，下面这两段代码是等同的：

```java
public int decreaseBlood() {
    synchronized(this) {
       blood = blood - 5;
       return blood;
    }
}

public synchronized int decreaseBlood() {
       blood = blood - 5;
       return blood;
}
```

### 3.4 在静态方法的代码块中使用synchronized

```java
public static int decreaseBlood() {
    synchronized(Master.class) {
       blood = blood - 5;
       return blood;
    }
}

public static synchronized int decreaseBlood() {
       blood = blood - 5;
       return blood;
}
```

## 小结

1. Java中的`synchronized`关键字用于解决多线程访问共享资源时的同步，以解决**线程干扰**和**内存一致性**问题
2. 你可以通过 **代码块（code block）** 或者 **方法（method）** 来使用`synchronized`关键字
3. synchronized`的原理基于**对象中的锁**，当线程需要进入`synchronized`修饰的方法或代码块时，它需要先**获得**锁并在执行结束后**释放**它
4. 当线程进入**非静态（non-static）\**同步方法时，它获得的是对象实例（Object level）的锁。而线程进入\**静态**同步方法时，它所获得的是类实例（Class level）的锁，两者没有必然关系
5. 如果`synchronized`中使用的对象是**null**，将会抛出`NullPointerException`错误
6. synchronized`**对方法的性能有一定影响**，因为线程要等待获取锁`
7. `使用`synchronized`时**尽量使用代码块**，而不是整个方法，以免阻塞整个方法
8. **尽量不要使用\*String\*类型和\*原始类型\*作为参数**。这是因为，JVM在处理字符串、原始类型时会对它们进行优化。比如，你原本是想对不同的字符串进行加锁，然而JVM认为它们是同一个，很显然这不是你想要的结果



















