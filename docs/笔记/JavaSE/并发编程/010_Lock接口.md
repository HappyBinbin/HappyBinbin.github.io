# 理解 Lock 接口

## 为什么会有Lock 接口，不是有 synchronized 了吗？

synchronized 非常好用、易用，但是它的灵活度十分有限，不能灵活地控制加锁和释放锁的时机。 Lock 接口则提供了更多的使用场景，并且更加灵活

## Lock 核心 Api

- `void lock()`：获取锁。**如果当前锁不可用，则会被阻塞直至锁释放**；
- `void lockInterruptibly()`：获取锁并允许被中断。**这个方法和`lock( )`类似，不同的是，它允许被中断并抛出中断异常**。
- `boolean tryLock()`：尝试获取锁。**会立即返回结果，而不会被阻塞**。
- `boolean tryLock(long timeout, TimeUnit timeUnit)`：尝试获取锁并等待一段时间。这个方法和`tryLock()`，但是它会根据参数等待–会，**如果在规定的时间内未能获取到锁就会放弃**；
- `void unlock()`：释放锁。

## 自定义 Lock

```java
// 自定义锁
public class WildMonsterLock implements Lock {
    private boolean isLocked = false;

    // 实现lock方法
    public void lock() {
        synchronized (this) {
            while (isLocked) {
                try {
                    wait();
                } catch (InterruptedException e) {
                    e.printStackTrace();
                }
            }
            isLocked = true;
        }
    }

    // 实现unlock方法
    public void unlock() {
        synchronized (this) {
            isLocked = false;
            this.notify();
        }
    }
}
```

在使用`synchronized`时我们无需关心锁的释放，JVM会帮助我们自动完成。然而，**在使用自定义的锁时，一定要使用`try...finally`来确保锁最终一定会被释放**，否则将造成后续线程被阻塞的严重后果。

## 可重入锁

在 `synchronized` 中，锁是可以重入的。可重入的意思就是，锁可以被线程重复或递归地调用。

例如，加锁对象中存在多个加锁方法，当线程在获取到锁并进入其中一个方法后，该线程依然可以进入其他的加锁方法，而不会出现被阻塞的情况。前提条件是，这个加锁的方法用的是同一个对象的锁（监视器）

```java
// 在 A 中调用 B ，也就是锁重入
public class DiyLock {
    public synchronized void A() {
        B();
    }
    
    public synchronized void B() {
       doSomething...
    }
}
```

```java
public class WildMonsterLock implements Lock {
    private boolean isLocked = false;

    // 重点：增加字段保存当前获得锁的线程
    private Thread lockedBy = null;
    // 重点：增加字段记录上锁次数
    private int lockedCount = 0;

    public void lock() {
        synchronized (this) {
            Thread callingThread = Thread.currentThread();
            // 重点：判断是否为当前线程，该锁是否被占用
            while (isLocked && lockedBy != callingThread) {
                try {
                    wait();
                } catch (InterruptedException e) {
                    e.printStackTrace();
                }
            }
            isLocked = true;
            lockedBy = callingThread;
            lockedCount++;
        }
    }

    public void unlock() {
        synchronized (this) {
            // 重点：判断是否为当前线程
            if (Thread.currentThread() == this.lockedBy) {
                lockedCount--;
                if (lockedCount == 0) {
                    isLocked = false;
                    this.notify();
                }
            }
        }
    }
}
```



## 小结

synchronized 所不具备的优势

- `synchronized`用于方法体或代码块，而Lock可以灵活使用，甚至可以跨越方法；
- `synchronized`没有公平性，任何线程都可以获取并长期持有，从而可能饿死其他线程。而基于Lock接口，我们可以实现公平锁，从而避免一些线程活跃性问题
- `synchronized`被阻塞时只有等待，而Lock则提供了`tryLock`方法，可以快速试错，并可以设定时间限制，使用时更加灵活；
- `synchronized`不可以被中断，而Lock提供了`lockInterruptibly`方法，可以实现中断。



