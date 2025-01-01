# ID生成策略

## 全局唯一 ID 介绍

拿MySQL数据库举个栗子：


在我们业务数据量不大的时候，单库单表完全可以支撑现有业务，数据再大一点搞个MySQL主从同步读写分离也能对付。


但随着数据日渐增长，主从同步也扛不住了，就需要对数据库进行分库分表，但分库分表后需要有一个唯一ID来标识一条数据，数据库的自增ID显然不能满足需求；特别一点的如订单、优惠券也都需要有`唯一ID`做标识。此时一个能够生成`全局唯一ID`的系统是非常必要的。那么这个`全局唯一ID`就叫`分布式ID`。

### 全局唯一 ID 特点

1. 全局唯一性：不能出现重复的ID号，既然是唯一标识，这是最基本的要求
2. 趋势递增：在MySQL InnoDB引擎中使用的是聚集索引，由于多数RDBMS使用B-tree的数据结构来存储索引数据，在主键的选择上面我们应该尽量使用有序的主键保证写入性能
3. 单调递增：保证下一个ID一定大于上一个ID，例如事务版本号、IM增量消息、排序等特殊需求
4. 信息安全：如果ID是连续的，恶意用户的扒取工作就非常容易做了，直接按照顺序下载指定URL即可；如果是订单号就更危险了，竞对可以直接知道我们一天的单量。所以在一些应用场景下，会需要ID无规则、不规则
5. 高可用性：同时除了对ID号码自身的要求，业务还对ID号生成系统的可用性要求极高，想象一下，如果ID生成系统瘫痪，这就会带来一场灾难。所以不能有单点故障
6. 分片支持：可以控制ShardingId。比如某一个用户的文章要放在同一个分片内，这样查询效率高，修改也容易
7. 长度适中

## 分布式ID生成方式

- UUID
- 数据库自增ID
- 数据库多主模式
- 号段模式
- Redis
- 雪花算法（SnowFlake）
- 滴滴出品（TinyID）
- 百度 （Uidgenerator）
- 美团（Leaf）

### UUID

UUID (Universally Unique Identifier) 的标准形式包含32个16进制数字，以连字号分为五段，形式为8-4-4-4-12的36个字符

示例：550e8400-e29b-41d4-a716-446655440000

在Java中我们可以直接使用下面的API生成UUID:

```java
UUID uuid  =  UUID.randomUUID(); 
String s = UUID.randomUUID().toString();
```

#### 优点

1. 非常简单，本地生成，代码方便
2. 性能非常高，生成ID的性能很好，没有网络消耗
3. 全球唯一

#### 缺点

1. 存储成本高。UUID 太长，16B，128b，通常以36长度的字符串表示，很多场景不适用。如果是海量数据库，就需要考虑存储量的问题
2. 信息不安全。基于MAC地址生成的UUID算法可能会造成MAC地址泄露
3. 不适合作为主键。ID作为主键时在特定的环境会存在一些问题，比如做DB主键的场景下，UUID就非常不适用。UUID往往是使用字符串存储，查询的效率比较低（无序且长度太长）
4. UUID 是无序的。不是单调递增的，而现阶段主流的数据库主键索引都是选用的B+树索引，对于无序长度过长的主键插入效率比较低。
5. 传输数据量大
6. 可读性低，根本无法根据ID判断内容

### 数据库的自增ID

基于数据库的`auto_increment`自增ID完全可以充当`分布式ID`

#### 优点

1. 非常简单。利用现有数据库的功能即可实现，成本小，性能可接受
2. ID 号单调递增。有利于业务和性能

#### 缺点

1. 强依赖DB：不同数据库语法和实现不同，数据库迁移的时候、多数据库版本支持的时候、或分表分库的时候需要处理，会比较麻烦。当DB异常时整个系统不可用，属于致命问题。
2. 单点故障：在单个数据库或读写分离或一主多从的情况下，只有一个主库可以生成。有单点故障的风险。
3. 数据一致性问题：配置主从复制可以尽可能的增加可用性，但是数据一致性在特殊情况下难以保证。主从切换时的不一致可能会导致重复发号。
4. 难以扩展：在性能达不到要求的情况下，比较难于扩展。ID发号性能瓶颈限制在单台MySQL的读写性能。

### 数据库集群模式

前边说了单点数据库方式不可取，那对上边的方式做一些高可用优化，换成主从模式集群。害怕一个主节点挂掉没法用，那就做双主模式集群，也就是两个Mysql实例都能单独的生产自增ID

那这样还会有个问题，两个MySQL实例的自增ID都从1开始，**会生成重复的ID怎么办？**

**解决方案**：设置`起始值`和`自增步长`

不同的MYSQL实例，设置不同的起始值与相同的自增步长

- mysql1：起始值为1，自增步长为2
- mysql2：起始值为2，自增步长为2

这样两个MySQL实例的自增ID分别就是：

```text
1、3、5、7、9
2、4、6、8、10
```

那如果集群后的性能还是扛不住高并发咋办？就要进行MySQL扩容增加节点，这是一个比较麻烦的事。

<img src="https://happychan.oss-cn-shenzhen.aliyuncs.com/img/image-20220219191127814.png" alt="image-20220219191127814" style="zoom:80%;" />

从上图可以看出，水平扩展的数据库集群，有利于解决数据库单点压力的问题，同时为了ID生成特性，将自增步长按照机器数量来设置

增加第三台`MySQL`实例需要人工修改一、二两台`MySQL实例`的起始值和步长，把`第三台机器的ID`起始生成位置设定在比现有`最大自增ID`的位置远一些，但必须在一、二两台`MySQL实例`ID还没有增长到`第三台MySQL实例`的`起始ID`值的时候，否则`自增ID`就要出现重复了，**必要时可能还需要停机修改**。

#### 优点：

- 解决DB单点问题

#### 缺点

- 不利于后续扩容，而且实际上单个数据库自身压力还是大，依旧无法满足高并发场景

### 数据库的号段模式

号段模式是当下分布式ID生成器的主流实现方式之一，号段模式可以理解为从数据库批量的获取自增ID，每次从数据库取出一个号段范围，例如 (1,1000] 代表1000个ID，具体的业务服务将本号段，生成1~1000的自增ID并加载到内存。表结构如下：

```sql
CREATE TABLE id_generator (
    id int(10) NOT NULL,
    max_id bigint(20) NOT NULL COMMENT '当前最大id',
    step int(20) NOT NULL COMMENT '号段的布长',
    biz_type    int(20) NOT NULL COMMENT '业务类型',
    version int(20) NOT NULL COMMENT '版本号',
    PRIMARY KEY (`id`)
) 
```

- biz_type ：代表不同业务类型
- max_id ：当前最大的可用id
- step ：代表号段的长度
- version ：是一个乐观锁，每次都更新version，保证并发时数据的正确性

<img src="https://happychan.oss-cn-shenzhen.aliyuncs.com/img/image-20220219191355189.png" alt="image-20220219191355189" style="zoom:80%;" />

等这批号段ID用完，再次向数据库申请新号段，对`max_id`字段做一次`update`操作，`update max_id= max_id + step`，update成功则说明新号段获取成功，新的号段范围是`(max_id ,max_id +step]`。

```sql
update id_generator set max_id = #{max_id+step}, version = version + 1 where version = # {version} and biz_type = XXX
```

#### 优点

- 由于多业务端可能同时操作，所以采用版本号`version`乐观锁方式更新，这种`分布式ID`生成方式不强依赖于数据库，不会频繁的访问数据库，对数据库的压力小很多

### Redis 生成 ID

当使用数据库来生成ID性能不够要求的时候，我们可以尝试使用Redis来生成ID。这主要依赖于Redis是单线程的，所以也可以用生成全局唯一的ID。可以用Redis的原子操作 INCR 和 INCRBY 来实现。

也可以使用Redis集群来获取更高的吞吐量。假如一个集群中有5台Redis。可以初始化每台Redis的值分别是1,2,3,4,5，然后步长都是5。各个Redis生成的ID为

```text
A：1,6,11,16,21

B：2,7,12,17,22

C：3,8,13,18,23

D：4,9,14,19,24

E：5,10,15,20,25
```

这个负载到哪台机器上需要提前设定好，未来很难做修改。但是3-5台服务器基本能够满足，都可以获得不同的ID。步长和初始值一定需要事先设定好。使用Redis集群也可以防止单点故障的问题

> 比较适合使用Redis来生成日切流水号
>
> - 比如订单号=日期+当日自增长号。可以每天在Redis中生成一个Key，使用INCR进行累加。
> - 

#### 优点

1. 不依赖数据库，灵活方便，性能由于数据库
2. 数字 ID 天然排序，对分页和排序需求有显要帮助

#### 缺点

1. 需要编码和配置的工作量比较大
2. Redis单点故障，影响序列服务的可用性。

#### 注意点

用`redis`实现需要注意一点，要考虑到redis持久化的问题。`redis`有两种持久化方式`RDB`和`AOF`

- `RDB`会定时打一个快照进行持久化，假如连续自增但`redis`没及时持久化，而这会Redis挂掉了，重启Redis后会出现ID重复的情况。
- `AOF`会对每条写命令进行持久化，即使`Redis`挂掉了也不会出现ID重复的情况，但由于incr命令的特殊性，会导致`Redis`重启恢复的数据时间过长。

### SnowFlake 算法（简单介绍）

具体介绍：xxx

雪花算法（Snowflake）是twitter公司内部分布式项目采用的ID生成算法，开源后广受国内大厂的好评，在该算法影响下各大公司相继开发出各具特色的分布式生成器。

<img src="https://happychan.oss-cn-shenzhen.aliyuncs.com/img/image-20220219222359136.png" alt="image-20220219222359136" style="zoom:80%;" />

`Snowflake`生成的是Long类型的ID，一个Long类型占8个字节，每个字节占8比特，也就是说一个Long类型占64个比特。

- 第一个bit位：Java中 long 的最高位是符号位代表正负，正数是0，负数是1，一般生成ID都为正数，所以默认为0
- 时间戳部分：毫秒级的时间，不建议存当前时间戳，而是用（当前时间戳 - 固定开始时间戳）的差值，可以使产生的ID从更小的值开始
- 41位可以表示`2^24 - 1`个数字，如果只用来表示正整数（计算机中正数包含0），可以表示的数值范围是：0 至 2^24 - 1，减1是因为可表示的数值范围是从0开始算的，而不是1。也就是说41位可以表示 `2^24 - 1`个毫秒的值，转化成单位年则是(2^24-1) / (1000L * 60 * 60 * 24 * 365) = 69年
- 工作机器id：也被叫做`workId`，这个可以灵活配置，机房或者机器号组合都可以。
- 序列号部分，自增值支持同一毫秒内同一个节点可以生成4096个ID

snowflake算法可以根据自身项目的需要进行一定的修改。比如估算未来的数据中心个数，每个数据中心的机器数以及统一毫秒可以能的并发数来调整在算法中所需要的bit数。

### 优点

1. 稳定性高：不依赖于数据库等第三方系统，以服务的方式部署，稳定性更高，生成ID的性能也是非常高的
2. 灵活方便：可以根据自身业务特性分配bit位
3. 单机上ID单调自增：毫秒数在高位，自增序列在低位，整个ID都是趋势递增的
4. 分布式系统下的ID唯一

#### 缺点

1. 强制依赖机器时钟：如果机器上时钟回拨，会导致发号重复或者服务会处于不可用状态，解决时钟回拨问题 https://www.jianshu.com/p/b1124283fc43
2. ID 可能不是全局递增的：在单机上是递增的，但是由于涉及到分布式环境，每台机器上的时钟不可能完全同步，也许有时候也会出现不是全局递增的情况

#### 使用建议

如果你的业务不需要69年这么长，或者需要更长时间

- 用42位存储时间戳，(1L << 42) / (1000L * 60 * 60 * 24 * 365) = 139年
- 用41位存储时间戳，(1L << 41) / (1000L * 60 * 60 * 24 * 365) = 69年
- 用40位存储时间戳，(1L << 40) / (1000L * 60 * 60 * 24 * 365) = 34年

如果你的机器没有那么1024个这么多，或者比1024还多

- 用9位存储机器id，(1L << 9) = 512
- 用10位存储机器id，(1L << 10) = 1024
- 用11位存储机器id，(1L << 11) = 2048

如果你的业务，每个机器，每毫秒最多也不会4096个id要生成，或者比这个还多

- 用11位存储随机序列，(1L << 11) = 2048
- 用12位存储随机序列，(1L << 12) = 4096
- 用13位存储随机序列，(1L << 13) = 8192

> 总而言之，根据业务调整算法。可以参考 百度、美团、滴滴 改进后的版本

#### 待改进点

- 支持时间回拨
- 支持手工插入
- 简单生成长度
- 提升生成速度

#### 具体实现

```java
package cn.dgut.IdGenerator;

/**
 * @author Happy
 * @description: 雪花算法实现
 * @date 2022/2/19
 */
public class SnowFlakeWorker {

    /**
     * 开始时间戳(2015-01-01)
     */
    private final long beginTimestamp = 1420041600000L;

    /**
     * 机器标识所占bit位数
     */
    private final long workerIdBits = 5L;

    /**
     * 数据中心/机房标识所占bit位数
     */
    private final long datacenterIdBits = 5L;

    /**
     * 数据中心掩码，即最大支持32个机房
     */
    private final long maxDatacenterId = ~(-1L << workerIdBits);

    /**
     * 机器掩码，即最大支持32个机器
     */
    private final long maxWorkerId = ~(-1L << workerIdBits);

    /**
     * 每毫秒下的序列号所占bit位数
     */
    private final long sequenceBits = 12L;

    /**
     * 每毫秒序列号的掩码
     */
    private final long sequenceMask = ~(-1L << sequenceBits);


    /**
     * 机器ID表示的bit在long中位置，需要左移的位数（12）
     */
    private final long workerIdShift = sequenceBits;

    /**
     * 数据中心ID表示的bit在long中的位置，需要左移的位数(12+5)
     */
    private final long datacenterIdShift = sequenceBits + workerIdBits;

    /**
     * 时间截部分需要左移的位数(5+5+12)
     */
    private final long timestampLeftShift = sequenceBits + workerIdBits + datacenterIdBits;

    /**
     * 机器ID（0~31）
     */
    private long workerId;

    /**
     * 数据中心ID（0~31）
     */
    private long datacenterId;

    /**
     * 每毫秒内序列（0~4095）
     */
    private long sequence = 0L;

    /**
     * 最后一次生成ID时的时间戳
     */
    private long lastTimestamp = -1L;

    /**
     * 构造函数
     *
     * @param workerId
     * @param datacenterId
     */
    public SnowFlakeWorker(long workerId, long datacenterId) {

        if (workerId > maxWorkerId || workerId < 0) {
            throw new IllegalArgumentException(String.format("workerId can't be great than %d or less than 0", maxWorkerId));
        }

        if (datacenterId > maxDatacenterId || datacenterId < 0) {
            throw new IllegalArgumentException(String.format("datacenterId can't be great than %d or less than 0", maxDatacenterId));
        }

        this.workerId = workerId;
        this.datacenterId = datacenterId;
    }

    /**
     * 获取下一个snowflake ID， synchronized 进行同步
     *
     * @return
     */
    public synchronized long nextId() {
        long timestamp = timeGen();

        // 若当前时间戳小于最后一次生成ID时的时间戳，说明系统时钟回退过，此时无法保证ID的唯一性，算法抛异常退出
        if (timestamp < lastTimestamp) {
            throw new RuntimeException(String.format("Clock moved backwards.  Refusing to generate id for %d milliseconds", lastTimestamp - timestamp));
        }

        // 若当前时间戳等于最后一次生成ID时的时间戳（同一毫秒内），则进行序列号累加
        if (timestamp == lastTimestamp) {
            // 此操作可获得的最大值是 4095, 最小值是 0, 在溢出时为 0
            sequence = (sequence + 1) & sequenceMask;

            // 毫秒内序列号溢出
            if (sequence == 0) {
                // 阻塞到下一个毫秒，获得新的时间戳
                timestamp = tillNextMills(lastTimestamp);
            }
        } else {
            // 若当前时间戳大于最后一次生成ID时的时间戳，则序列号需要重置到0
            sequence = 0L;
        }

        // 更新并记录本次时间戳
        lastTimestamp = timestamp;

        // 位运算拼接出最终的ID
        return ((timestamp - beginTimestamp) << timestampLeftShift)
            | (datacenterId << datacenterIdShift)
            | (workerId << workerIdShift)
            | sequence;

    }

    /**
     * 阻塞到下一个毫秒，直到获得新的时间戳
     *
     * @param lastTimestamp 上次生成ID的时间截
     * @return 当前时间戳
     */
    protected long tillNextMills(long lastTimestamp) {
        long timestamp = timeGen();
        while (timestamp <= this.lastTimestamp) {
            timestamp = timeGen();
        }
        return timestamp;
    }

    /**
     * 返回以毫秒为单位的当前时间戳
     *
     * @return 当前时间(毫秒)
     */
    protected long timeGen() {
        return System.currentTimeMillis();
    }


    /**
     * 测试
     */
    public static void main(String[] args) {
        long start = System.currentTimeMillis();
        SnowFlakeWorker idWorker = new SnowFlakeWorker(1, 3);
        for (int i = 0; i < 50; i++) {
            long id = idWorker.nextId();
            //            System.out.println(Long.toBinaryString(id));
            System.out.println(id);
        }
        long end = System.currentTimeMillis();
        System.out.println(end - start);

    }

}
```





















