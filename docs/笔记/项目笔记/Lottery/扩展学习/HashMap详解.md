# HashMap 详解

## Reference

[1]https://blog.csdn.net/weixin_44015043/article/details/105346187

[2] https://blog.csdn.net/swpu_ocean/article/details/88917958



在学完 HashMap 后，如果能回答出这些问题，那么就可以认为掌握了其核心方法以及其里面的算法设计

- 认识一些重要变量？

- 为什么使用链表+数组？
    - 用 LinkedList 替数组结构可以吗？
    - 既然可以，那为什么偏偏用数组呢？
    - 那用 ArrayList 可以吗？它底层也是数组，查找也快
    - 为什么 ArrayList 的扩容机制是 1.5 倍扩容？
- HashMap 的 put( ) 过程是怎样的？
- HashMap 的 resize( ) 过程是怎样的？
    - HashMap 的扩容机制是怎样的？ 负载因子呢？
- HashMap 的 get( ) 过程是怎样的？
- 说一说 String 的 hashcode( ) 的实现，为什么要以 31 为质数呢？
- JDK1.8 中，HashMap 改动了什么？
- JDK1.7 和 JDK1.8中HashMap为什么是线程不安全的？
- 为什么hashmap的在链表元素数量超过8时候改为红黑树
- 为什么 HashMap 的红黑树节点数量小于6时候改为链表？
- 重写 hashCode 和 equals 方法？
- HashMap 里的 hash 问题
    - 为什么数组的长度一直都要为 2 的 n 次方？
    - HashMap 是如何利用扰动函数解决碰撞问题的？
    - 为什么要将 key.hashCode( ) 右移 16 位？
    - 为什么要用与运算？
    - 为什么可以用与运算实现取模运算呢？
- 一般用什么作为HashMap的key值？
    - key可以是null吗，value可以是null吗
    - 一般用什么作为key值
    - 用可变类当Hashmap1的Key会有什么问题
    - 让你实现一个自定义的class作为HashMap的Key该如何实现



待完成

- ​	Q：重写 hashCode 和 equals 方法？

## Q：认识一些重要变量？

- `DEFAULT_INITIAL_CAPACITY` Table数组的初始化长度： 1 << 4 ，2^4=16（为什么要是 2的n次方？）
- `MAXIMUM_CAPACITY` Table数组的最大长度： `1<<30 2^30=1073741824`
- `DEFAULT_LOAD_FACTOR` 负载因子：默认值为0.75。 当元素的总个数 >当前数组的长度 * 负载因子。数组会进行扩容，扩容为原来的两倍（todo：为什么是两倍？）
- `TREEIFY_THRESHOLD` 链表树化阙值： 默认值为 `8` 。表示在一个node（Table）节点下的值的个数大于8时候，会将链表转换成为红黑树。
- `UNTREEIFY_THRESHOLD` 红黑树链化阙值： 默认值为 `6` 。 表示在进行扩容期间，单个Node节点下的红黑树节点的个数小于6时候，会将红黑树转化成为链表。
- `MIN_TREEIFY_CAPACITY = 64` 最小树化阈值，当Table所有元素超过改值，才会进行树化（为了防止前期阶段频繁扩容和树化过程冲突）



## Q：为什么使用链表+数组？

### 为什么使用链表？

得先知道 hash 冲突是啥。建议可以先去查阅一下

由于我们的数组的值是限制死的，我们在对key值进行散列取到下标以后，放入到数组中时，难免出现两个key值不同，但是却放入到下标相同的格子中，此时我们就可以使用链表来对其进行链式的存放。

### 为什么使用数组？

我用 LinkedList 代替数组结构可以吗？

```java
// 源码
Entry[] table=new Entry[capacity];
// entry就是一个链表的节点

// LinkedList 替代后 
List<Entry> table=new LinkedList<Entry>();


```

是否可以行得通？ 答案当然是肯定的。

### 那既然可以使用进行替换处理，为什么有偏偏使用到数组呢？

因为用数组效率最高！ 在HashMap中，定位节点的位置是利用元素的key的哈希值对数组⻓度取模得到。此时，我们已得到节点的位置。显然数组的查找效率比**LinkedList**大（底层是链表结构）。

那**ArrayList**，底层也是数组，查找也快啊，为啥不用ArrayList? 因为采用基本数组结构，扩容机制可以⾃己定义，HashMap中数组扩容刚好是2的次幂，在做取模运算的效率高。 而 ArrayList 的扩容机制是1.5倍扩容（这一点我相信学习过的都应该清楚）。



## Q：为什么 HashMap 的链表元素数量超过8时候改为红黑树

这个问题也可以是“为什么不一开始就使用红黑树，不是效率很高吗?”

- 因为红⿊树需要进⾏左旋，右旋，变⾊这些操作来保持平衡，而单链表不需要。 
- 当元素小于8个当时候，此时做查询操作，链表结构已经能保证查询性能。
- 当元素大于8个的时候，此时需要红⿊树来加快查 询速度，但是新增节点的效率变慢了。 
- 因此，如果⼀开始就用红⿊树结构，元素太少，新增效率⼜⽐较慢，⽆疑这是浪费性能的。

## Q：为什么 HashMap 的红黑树节点数量小于6时候改为链表？

- 因为中间有个差值7可以防⽌链表和树之间频繁的转换。
- 如果设计成链表个数超过8则链表转 换成树结构，链表个数⼩于8则树结构转换成链表。那么当⼀个HashMap不停的插⼊、删除元素，链表个数在8左右徘徊，就会频繁的发⽣树转链表、链表转树，效率会很低。

## Q：HashMap 的 put( ) 过程是怎样的？

1. 判断bucket是否为空或者尚未初始化，通过resize进行初始化
2. 对key的hashCode()做hash运算，计算index;
3. 如果没碰撞直接放到bucket⾥；
4. 如果碰撞了，以链表的形式存在buckets后；
5. 如果碰撞导致链表过长(⼤于等于TREEIFY_THRESHOLD)，就把链表转换成红⿊树(JDK1.8中的改动)；
6. 如果节点已经存在就替换old value(保证key的唯⼀性)
7. 如果bucket满了(超过load factor*current capacity)，就要resize

在得到下标值以后，可以开始put值进入到数组+链表中，会有三种情况：

1. 数组的位置为空
2. 数组的位置不为空，且面是链表的格式
3. 数组的位置不为空，且下面是红黑树的格式

同时 对于Key 和Value 也要经历一下步骤

- 通过 Key 散列获取到对于的Table
- 遍历Table 下的Node节点，做更新/添加操作
- 扩容检测

```java
final V putVal(int hash, K key, V value, boolean onlyIfAbsent,
               boolean evict) {
    Node<K,V>[] tab; Node<K,V> p; int n, i;
    if ((tab = table) == null || (n = tab.length) == 0)
        // HashMap的懒加载策略，当执行put操作时检测Table数组初始化。
        n = (tab = resize()).length;
    if ((p = tab[i = (n - 1) & hash]) == null)
        //通过 Hash 函数获取到对应的Table，如果当前Table为空，则直接初始化一个新的Node并放入该Table中。       
        tab[i] = newNode(hash, key, value, null);
    else {
        Node<K,V> e; K k;
        //进行值的判断： 判断对于是不是对于相同的key值传进来不同的value，若是如此，将原来的value进行返回
        if (p.hash == hash &&
            ((k = p.key) == key || (key != null && key.equals(k))))
            e = p;
        else if (p instanceof TreeNode)
            // 如果当前Node类型为TreeNode，调用 PutTreeVal 方法。
            e = ((TreeNode<K,V>)p).putTreeVal(this, tab, hash, key, value);
        else {
            //如果不是TreeNode，则就是链表，遍历并与输入key做命中碰撞。 
            for (int binCount = 0; ; ++binCount) {
                if ((e = p.next) == null) {

                    //如果当前Table中不存在当前key，则添加。
                    p.next = newNode(hash, key, value, null);
                    if (binCount >= TREEIFY_THRESHOLD - 1) // -1 for 1st

                        //超过了``TREEIFY_THRESHOLD``则转化为红黑树。
                        treeifyBin(tab, hash);
                    break;
                }
                if (e.hash == hash &&
                    ((k = e.key) == key || (key != null && key.equals(k))))            
                    //做命中碰撞，使用hash、内存和equals同时判断（不同的元素hash可能会一致）。
                    break;
                p = e;
            }
        }
        if (e != null) { // existing mapping for key
            //如果命中不为空，更新操作。
            V oldValue = e.value;
            if (!onlyIfAbsent || oldValue == null)
                e.value = value;
            afterNodeAccess(e);
            return oldValue;
        }
    }
    ++modCount;
    if (++size > threshold)
        //扩容检测！
        resize();
    afterNodeInsertion(evict);
    return null;
}
```



## HashMap 的 resize( ) 过程是怎样的？

HashMap 的扩容实现机制是将老table数组中所有的Entry取出来，重新对其 Hashcode 做`Hash散列`到新的Table中，可以看到注解 `Initializes or doubles table size. resize` 表示的是对数组进行初始化或
进行Double处理。现在我们来一步一步进行分析

```java
/**
* Initializes or doubles table size.  If null, allocates in
* accord with initial capacity target held in field threshold.
* Otherwise, because we are using power-of-two expansion, the
* elements from each bin must either stay at same index, or move
* with a power of two offset in the new table.
*
* @return the table
*/
final Node<K,V>[] resize() {
    //先将老的Table取别名，这样利于后面的操作。
    Node<K,V>[] oldTab = table;
    int oldCap = (oldTab == null) ? 0 : oldTab.length;
    int oldThr = threshold;
    int newCap, newThr = 0;
    //表示之前的数组容量不为空。
    if (oldCap > 0) {
        // 如果 此时的数组容量大于最大值
        if (oldCap >= MAXIMUM_CAPACITY) {
            // 扩容 阙值为 Int类型的最大值，这种情况很少出现
            threshold = Integer.MAX_VALUE;
            return oldTab;
        }


        //表示 old数组的长度没有那么大，进行扩容，两倍（这里也是有讲究的）对阙值也进行扩容
        else if ((newCap = oldCap << 1) < MAXIMUM_CAPACITY &&
                 oldCap >= DEFAULT_INITIAL_CAPACITY)
            newThr = oldThr << 1; // double threshold
    }
    //表示之前的容量是0 但是之前的阙值却大于零， 此时新的hash表长度等于此时的阙值
    else if (oldThr > 0) // initial capacity was placed in threshold
        newCap = oldThr;
    else {               // zero initial threshold signifies using defaults
        //表示是初始化时候，采用默认的 数组长度* 负载因子
        newCap = DEFAULT_INITIAL_CAPACITY;
        newThr = (int)(DEFAULT_LOAD_FACTOR * DEFAULT_INITIAL_CAPACITY);
    }
    //此时表示若新的阙值为0 就得用 新容量* 加载因子重新进行计算。
    if (newThr == 0) {
        float ft = (float)newCap * loadFactor;
        newThr = (newCap < MAXIMUM_CAPACITY && ft < (float)MAXIMUM_CAPACITY ?
                  (int)ft : Integer.MAX_VALUE);
    }
    // 开始对新的hash表进行相对应的操作。
    threshold = newThr;
    @SuppressWarnings({"rawtypes","unchecked"})
    Node<K,V>[] newTab = (Node<K,V>[])new Node[newCap];
    table = newTab;
    if (oldTab != null) {
        //遍历旧的hash表，将之内的元素移到新的hash表中。
        for (int j = 0; j < oldCap/***此时旧的hash表的阙值*/; ++j) {
            Node<K,V> e;
            if ((e = oldTab[j]) != null) {
                //表示这个格子不为空
                oldTab[j] = null;
                if (e.next == null)
                    // 表示当前只有一个元素，重新做hash散列并赋值计算。
                    newTab[e.hash & (newCap - 1)] = e;
                else if (e instanceof TreeNode)
                    // 如果在旧哈希表中，这个位置是树形的结果，就要把新hash表中也变成树形结构，
                    ((TreeNode<K,V>)e).split(this, newTab, j, oldCap);
                else { // preserve order
                    //保留 旧hash表中是链表的顺序
                    Node<K,V> loHead = null, loTail = null;
                    Node<K,V> hiHead = null, hiTail = null;
                    Node<K,V> next;
                    do {// 遍历当前Table内的Node 赋值给新的Table。
                        next = e.next;
                        // 原索引
                        if ((e.hash & oldCap) == 0) {
                            if (loTail == null)
                                loHead = e;
                            else
                                loTail.next = e;
                            loTail = e;
                        }
                        // 原索引+oldCap
                        else {
                            if (hiTail == null)
                                hiHead = e;
                            else
                                hiTail.next = e;
                            hiTail = e;
                        }
                    } while ((e = next) != null);
                    // 原索引放到bucket里面
                    if (loTail != null) {
                        loTail.next = null;
                        newTab[j] = loHead;
                    }
                    // 原索引+oldCap 放到bucket里面
                    if (hiTail != null) {
                        hiTail.next = null;
                        newTab[j + oldCap] = hiHead;
                    }
                }
            }
        }
    }
    return newTab;
}
```

## HashMap 的 get( ) 过程是怎样的？

1. 对key的hashCode()做hash运算，计算index

2. 如果在bucket⾥的第⼀个节点⾥直接命中，则直接返回

3. 如果有冲突，则通过key.equals(k)去查找对应的Entry

4. 若为树，则在树中通过key.equals(k)查找，O(logn)
5. 若为链表，则在链表中通过key.equals(k)查找，O(n)

```java
final Node<K,V> getNode(int hash, Object key) {
    Node<K,V>[] tab; Node<K,V> first, e; int n; K k;
    // 判断 表是否为空，表重读是否大于零，并且根据此 key 对应的表内是否存在 Node节点。    
    if ((tab = table) != null && (n = tab.length) > 0 &&
        (first = tab[(n - 1) & hash]) != null) {
        if (first.hash == hash && // always check first node
            ((k = first.key) == key || (key != null && key.equals(k))))
            // 检查第一个Node 节点，若是命中则不需要进行do... whirle 循环。
            return first;
        if ((e = first.next) != null) {
            if (first instanceof TreeNode)
                //树形结构，采用 对应的检索方法，进行检索。
                return ((TreeNode<K,V>)first).getTreeNode(hash, key);
            do {
                //链表方法 做while循环，直到命中结束或者遍历结束。
                if (e.hash == hash &&
                    ((k = e.key) == key || (key != null && key.equals(k))))
                    return e;
            } while ((e = e.next) != null);
        }
    }
    return null;
}
```

## Q：说一说 String 的 hashcode( ) 的实现，为什么要以 31 为质数呢？

```java
public int hashCode() {
    int h = hash;
    if (h == 0 && value.length > 0) {
        char val[] = value;

        for (int i = 0; i < value.length; i++) {
            h = 31 * h + val[i];
        }
        hash = h;
    }
    return h;
}
```

以31为权，每⼀位为字符的ASCII值进⾏运算，用⾃然溢出来等效 取模。

那为什么以31为质数呢? 

主要是因为31是⼀个奇质数，所以31i=32i-i=(i<<5)-i，这种位移与减法结合的计算相⽐⼀般的运算快很多

## Q：JDK1.8 中，HashMap 改动了什么？

1. 由数组+链表的结构改为数组+链表+红⿊树。
2. 优化了高位运算的hash算法：h^(h>>>16)
3. 扩容后，元素要么是在原位置，要么是在原位置再移动2次幂的位置，且链表顺序不变

注意： 最后⼀条是重点，因为最后⼀条的变动，hashmap在1.8中，不会在出现死循环问题。

## Q：JDK1.7 和 JDK1.8 中HashMap为什么是线程不安全的？

- JDK1.7 中，并发环境下会造成死循环和数据丢失
- JDK1.8中，并发环境下会有数据覆盖问题

### JDK1.7 扩容下的线程不安全

`HashMap`的线程不安全主要是发生在扩容函数中，即根源是在**transfer函数**中

```java
void transfer(Entry[] newTable, boolean rehash) {
    int newCapacity = newTable.length;
    for (Entry<K,V> e : table) {
        while(null != e) {
            Entry<K,V> next = e.next;
            if (rehash) {
                e.hash = null == e.key ? 0 : hash(e.key);
            }
            int i = indexFor(e.hash, newCapacity);
            e.next = newTable[i];
            newTable[i] = e;
            e = next;
        }
    }
}
```

这段代码是`HashMap`的扩容操作，重新定位每个桶的下标，并采用头插法将元素迁移到新数组中。头插法会将链表的顺序翻转，这也是形成死循环的关键点。理解了头插法后再继续往下看是如何造成死循环以及数据丢失的。

### 扩容造成死循环和数据丢失的分析过程

假设现在有两个线程A、B同时对下面这个`HashMap`进行扩容操作：

> 注意：线程A、线程B 在运行时是线程隔离的，但是对于此时主存中的HashMap的table 和 newTable而言，只有一份

![image-20220222111139807](https://gitee.com/HappyBinbin/pcigo/raw/master/image-20220222111139807.png)

正常扩容后的结果是下面这样的：

![image-20220222111206350](https://gitee.com/HappyBinbin/pcigo/raw/master/image-20220222111206350.png)

但是当线程A执行到上面`transfer`函数的第11行代码 `newTable[i] = e;`时，CPU时间片耗尽，线程A被挂起。此时线程A中：e=3、next=7、e.next=null

![image-20220222111308030](https://gitee.com/HappyBinbin/pcigo/raw/master/image-20220222111308030.png)

当线程A的时间片耗尽后，CPU开始执行线程B，并在线程B中成功的完成了数据迁移

![image-20220222111321011](https://gitee.com/HappyBinbin/pcigo/raw/master/image-20220222111321011.png)

> 重点来了，根据Java内存模式可知，线程B执行完数据迁移后，此时主内存中`newTable`和`table`都是最新的，也就是说：7.next=3、3.next=null。

随后线程A获得CPU时间片继续执行`newTable[i] = e`，将3放入新数组对应的位置，执行完此轮循环后线程A的情况如下：

![image-20220222111403254](https://gitee.com/HappyBinbin/pcigo/raw/master/image-20220222111403254.png)

接着继续执行下一轮循环，此时e=7，从主内存中读取e.next时发现主内存中7.next=3，于是乎next=3，并将7采用头插法的方式放入新数组中，并继续执行完此轮循环，结果如下：

![image-20220222111421037](https://gitee.com/HappyBinbin/pcigo/raw/master/image-20220222111421037.png)

上面说了此时e.next=null即next=null，当执行完e=null后，将不会进行下一轮循环。到此线程A、B的扩容操作完成，很明显当线程A执行完后，`HashMap`中出现了环形结构，当在以后对该`HashMap`进行操作时会出现死循环。

并且从上图可以发现，元素5在扩容期间被莫名的丢失了，这就发生了数据丢失的问题。

### JDK1.8 的线程不安全

根据上面JDK1.7出现的问题，在JDK1.8中已经得到了很好的解决，如果你去阅读1.8的源码会发现找不到`transfer`函数，因为JDK1.8直接在`resize`函数中完成了数据迁移。另外说一句，JDK1.8在进行元素插入时使用的是尾插法。

为什么说JDK1.8会出现数据覆盖的情况喃，我们来看一下下面这段JDK1.8中的put操作代码：

```java
final V putVal(int hash, K key, V value, boolean onlyIfAbsent,
               boolean evict) {
    Node<K,V>[] tab; Node<K,V> p; int n, i;
    if ((tab = table) == null || (n = tab.length) == 0)
        n = (tab = resize()).length;
    if ((p = tab[i = (n - 1) & hash]) == null) // 如果没有hash碰撞则直接插入元素
        tab[i] = newNode(hash, key, value, null);
    else {
        Node<K,V> e; K k;
        if (p.hash == hash &&
            ((k = p.key) == key || (key != null && key.equals(k))))
            e = p;
        else if (p instanceof TreeNode)
            e = ((TreeNode<K,V>)p).putTreeVal(this, tab, hash, key, value);
        else {
            for (int binCount = 0; ; ++binCount) {
                if ((e = p.next) == null) {
                    p.next = newNode(hash, key, value, null);
                    if (binCount >= TREEIFY_THRESHOLD - 1) // -1 for 1st
                        treeifyBin(tab, hash);
                    break;
                }
                if (e.hash == hash &&
                    ((k = e.key) == key || (key != null && key.equals(k))))
                    break;
                p = e;
            }
        }
        if (e != null) { // existing mapping for key
            V oldValue = e.value;
            if (!onlyIfAbsent || oldValue == null)
                e.value = value;
            afterNodeAccess(e);
            return oldValue;
        }
    }
    ++modCount;
    if (++size > threshold)
        resize();
    afterNodeInsertion(evict);
    return null;
}
```

其中第六行代码是判断`是否出现 hash 碰撞`，假设两个线程A、B都在进行put操作，并且hash函数计算出的插入下标是相同的，当线程A执行完第六行代码后由于时间片耗尽导致被挂起，而线程B得到时间片后在该下标处插入了元素，完成了正常的插入。然后线程A获得时间片，由于之前已经进行了hash碰撞的判断，所有此时不会再进行判断，而是直接进行插入，这就导致了线程B插入的数据被线程A覆盖了，从而线程不安全。

除此之前，还有就是代码的第38行处有个`++size`，我们这样想，还是线程A、B，这两个线程同时进行put操作时，假设当前`HashMap`的 size 大小为 10，当线程A执行到第38行代码时，从主内存中获得size的值为10后准备进行+1操作，但是由于时间片耗尽只好让出CPU，线程B拿到 CPU 后还是从主内存中拿到size的值10进行+1操作，完成了put操作，并将size=11写回主内存。然后线程A再次拿到 CPU 并继续执行(此时size的值仍为10)，当执行完put操作后，还是将size=11写回内存，此时，线程A、B都执行了一次put操作，但是size的值只增加了1，所有说还是由于数据覆盖又导致了线程不安全。

### 总结

`HashMap`的线程不安全主要体现在下面两个方面：
1.在JDK1.7中，当并发执行扩容操作时会造成环形链和数据丢失的情况。
2.在JDK1.8中，在并发执行put操作时会发生数据覆盖的情况。

## Q：HashMap 里的 hash 问题

我们都知道在HashMap中 使用数组加链表，这样问题就来了，数组使用起来是有下标的，但是我们平时使用HashMap都是这样使用的：

```java
HashMap<Integer,String> hashMap=new HashMap<>();
hashMap.put(2,"dd");
```

可以看到的是并没有特地为我们存放进来的值指定下标，那是因为我们的hashMap对存放进来的key值进行了hashcode()，生成了一个值，但是这个值很大，我们不可以直接作为下标，此时我们想到了可以使用取余的方法，例如这样：

```java
key.hashcode()%Table.length；
```

即可以得到对于任意的一个key值，进行这样的操作以后，其值都落在`0-Table.length-1` 中，但是 HashMap的源码却不是这样做？

HashMap 对其进行了与操作，对Table的表长度减一再与生产的hash值进行相与：

```java
if ((p = tab[i = (n - 1) & hash]) == null)
    tab[i] = newNode(hash, key, value, null);
```

我们来画张图进行进一步的了解：

<img src="https://gitee.com/HappyBinbin/pcigo/raw/master/image-20220221141549063.png" alt="image-20220221141549063" style="zoom:80%;" />

这里我们也就得知为什么Table数组的长度要一直都为`2的n次方`，只有这样，减一进行相与时候，才能够达到最大的n-1值。

举个栗子来反证一下：

我们现在数组的长度为 15 减一为 14 ，二进制表示 `0000 1110` 进行相与时候，最后一位永远是0，这样就可能导致，不能够完完全全的进行Table数组的使用。违背了我们最开始的想要对Table数组进行`最大限度的无序使用`的原则，因为HashMap为了能够存取高效，，要尽量较少碰撞，就是要尽量把数据分配均匀，每个链表长度⼤致相同。

这个时候还有一个问题：我们对key值进行hashcode以后，进行相与时候都是只用到了后四位，前面的很多位都没有能够得到使用,这样也可能会导致我们所生成的下标值不能够完全散列，从而导致碰撞问题。

### HashMap 是如何利用扰动函数解决碰撞问题的？

```java
static final int hash(Object key) {
    int h;
    return (key == null) ? 0 : (h = key.hashCode()) ^ (h >>> 16);
}
```

如果不使用扰动函数，则直接将 key.hashCode( ) 进行与运算，则会出现以下问题

以初始长度16为例，16-1=15；2进制表示是 00000000 00000000 00001111。和某散列值做“与”操作如下，结果就是截取了最低的四位值

<img src="https://gitee.com/HappyBinbin/pcigo/raw/master/image-20220221131742029.png" alt="image-20220221131742029" style="zoom:80%;" />

这样就算散列值分布再松散，要是只取后四位的话，碰撞也会很严重。如果散列本身做得不好，分布上成等差数列的漏洞，恰好使最后几个低位呈现规律性重复，则碰撞会更严重。

### 扰动函数是怎么实现的？

1. 使用 key.hashCode( ) 计算 hash 值并复制给变量h
2. 将变量 h 无符号右移 16 位
3. 将变量 h 与 右移后的 h 进行异或运算

<img src="https://gitee.com/HappyBinbin/pcigo/raw/master/image-20220221132030358.png" alt="image-20220221132030358" style="zoom:80%;" />

### 为什么要将 key.hashCode( ) 右移 16 位？

右移16位正好为32bit的一半，自己的高半区和低半区做异或，是为了混合原始哈希吗的高位和低位，来加大低位的随机性。而且混合后的低位掺杂了高位的部分特征，使高位的信息也被保留下来

### 为什么要用与运算？

- 若直接使用key.hashCode()计算出hash值，则范围为：**-2147483648**到**2147483648**，大约40亿的映射空间。若映射得比较均匀，是很难出现碰撞的。但是这么大范围无法放入内存中，况且HashMap的 初始容量为16。所以必须要进行与运算取模。
- 位运算(&)效率要比代替取模运算(%)高很多，主要原因是位运算直接对内存数据进行操作，不需要转成十进制，因此处理速度非常快。
- 可以很好的解决负数的问题：hashcode的结果是int类型，而int的取值范围是-2^31 ~ 2^31 - 1，即[ -2147483648, 2147483647]；这里面是包含负数的，我们知道，对于一个负数取模还是有些麻烦的。如果使用二进制的位运算的话就可以很好的避免这个问题。首先，不管hashcode的值是正数还是负数。length-1这个值一定是个正数。那么，他的二进制的第一位一定是0（有符号数用最高位作为符号位，“0”代表“+”，“1”代表“-”），这样里两个数做按位与运算之后，第一位一定是个0，也就是，得到的结果一定是个正数。

### 为什么可以用与运算实现取模运算呢？

X % 2^n = X & (2^n - 1)

2^n表示2的n次方，也就是说，一个数对2^n取模 == 一个数和(2^n - 1)做按位与运算 。

假设n为3，则2^3 = 8，表示成2进制就是1000。2^3 -1 = 7 ，即0111。

此时X & (2^3 - 1) 就相当于取X的2进制的最后三位数

从2进制角度来看，X / 8相当于 X >> 3，即把X右移3位，此时得到了X / 8的商，而被移掉的部分(后三位)，则是X % 8，也就是余数。

这里也回答了下面 2^n 的问题

#### 为什么数组的长度一直都要为 2 的 n 次方？

- **不同的hash值发生碰撞的概率比较小，这样就会使得数据在table数组中分布较均匀，空间利用率较高，查询速度也较快；**
- **h&(length - 1) 就相当于对length取模，而且在速度、效率上比直接取模要快得多，即二者是等价不等效的，这是HashMap在速度和效率上的一个优化。**



## Q：一般用什么作为 HashMap 的 key 值

### key 可以是 null 吗？ value 呢？

当然都是可以的，但是对于 key来说只能运行出现一个key值为null，但是可以出现多个value值为null

### 一般用什么作为 key 值？

⼀般用Integer、String这种不可变类当HashMap当key，而且String最为常用。

- 因为字符串是不可变的，所以在它创建的时候hashcode就被缓存了，不需要重新计算。 这就使得字符串很适合作为Map中的键，字符串的处理速度要快过其它的键对象。 这就是HashMap中的键往往都使用字符串。

- 因为获取对象的时候要用到equals()和hashCode()方法，那么键对象正确的重写这两个方法是⾮常重要的,这些类已 经很规范的覆写了hashCode()以及equals()方法。

### 用可变类当 Hashmap 的Key会有什么问题

hashcode可能会发生变化，导致put进行的值，无法get出来，如下代码所示：

```java
HashMap<List<String>,Object> map=new HashMap<>();
List<String> list=new ArrayList<>();
list.add("hello");
Object object=new Object();
map.put(list,object);
System.out.println(map.get(list));
list.add("hello world");
System.out.println(map.get(list));
```

输出值如下：

```java
java.lang.Object@1b6d3586
null
```

### 实现一个自定义的 class 作为 Hashmap 的 key 该如何实现

对于这个问题考查到了下面的两个知识点

- 重写hashcode和equals方法需要注意什么？
- 如何设计一个不变的类。

#### 针对问题1，记住下⾯四个原则即可

- 两个对象相等，hashcode⼀定相等
- 两个对象不等，hashcode不⼀定不等
- hashcode相等，两个对象不⼀定相等
- hashcode不等，两个对象⼀定不等

#### 针对问题2，记住如何写⼀个不可变类

1. 类添加final修饰符，保证类不被继承。 如果类可以被继承会破坏类的不可变性机制，只要继承类覆盖父类的方法并且继承类可以改变成员变量值，那么⼀旦⼦类 以父类的形式出现时，不能保证当前类是否可变。
2. 保证所有成员变量必须私有，并且加上final修饰 通过这种⽅式保证成员变量不可改变。但只做到这⼀步还不够，因为如果是对象成员变量有可能再外部改变其值。所以第 4 点弥补这个不⾜。
3. 不提供改变成员变量的方法，包括 setter 避免通过其他接⼝改变成员变量的值，破坏不可变特性。
4. 通过构造器初始化所有成员，进行深拷贝(deep copy)
5.  在getter方法中，不要直接返回对象本⾝，而是克隆对象，并返回对象的拷贝 这种做法也是防⽌对象外泄，防止通过getter获得内部可变成员对象后对成员变量直接操作，导致成员变量发⽣改变

## 重写hashcode和equals方法需要注意什么？

记住下⾯四个原则即可

- 两个对象相等，hashcode⼀定相等
- 两个对象不等，hashcode不⼀定不等
- hashcode相等，两个对象不⼀定相等
- hashcode不等，两个对象⼀定不等







