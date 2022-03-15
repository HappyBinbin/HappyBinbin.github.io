# ID生成策略领域开发

## 学习目的

- 了解不同的ID生成策略，根据不同场景分析不同ID策略的应用方式
- 掌握ID生成策略，使用几种生成手段实践
- 拓展了解其他的ID生成策略

## 开发日志

- 【说明】从本章节开始，我们会陆续的引入一些基础内容的搭建，包括本章节关于ID的生成、以及后续章节需要引入分库分表、vo2dto方法、Redis等，这些会支撑我们继续开发业务领域中一些需要用到的订单号、活动号生成以及个人用户参与到的抽奖信息落库。
- 使用策略模式把三种生成ID的算法进行统一包装，由调用方决定使用哪种生成ID的策略。*策略模式属于行为模式的一种，一个类的行为或算法可以在运行时进行更改*
- 雪花算法本章节使用的是工具包 hutool 包装好的工具类，一般在实际使用雪花算法时需要做一些优化处理，比如支持时间回拨、支持手工插入、简短生成长度、提升生成速度等。
- 而日期拼接和随机数工具包生成方式，都需要自己保证唯一性，一般使用此方式生成的ID，都用在单表中，本身可以在数据库配置唯一ID。*那为什么不用自增ID，因为自增ID通常容易被外界知晓你的运营数据，以及后续需要做数据迁移到分库分表中都会有些麻烦*

## 支撑领域

在 domain 领域包下新增支撑领域，ID 的生成服务就放到这个领域下实现。

关于 ID 的生成因为有三种不同 ID 用于在不同的场景下；

- 订单号：唯一、大量、订单创建时使用、分库分表
- 活动号：唯一、少量、活动创建时使用、单库单表
- 策略号：唯一、少量、活动创建时使用、单库单表

## 工程结构

```basic
lottery-domain
└── src
    └── main
        └── java
            └── cn.happy.lottery.domain.support.ids
                ├── policy
                │     ├── RandomNumeric.java
                │     ├── ShortCode.java
                │     └── SnowFlake.java
                ├── IdContext.java
                └── IIdGenerator.java
```

- IIdGenerator，定义生成ID的策略接口。RandomNumeric、ShortCode、SnowFlake，是三种生成ID的策略。
- IdContext，ID生成上下文，也就是从这里提供策略配置服务。

## IIdGenerator 策略接口

```java
public interface IIdGenerator {

    /**
     * 获取ID，目前有两种实现方式
     * 1. 雪花算法，用于生成单号
     * 2. 日期算法，用于生成活动编号类，特性是生成数字串较短，但指定时间内不能生成太多
     * 3. 随机算法，用于生成策略ID
     *
     * @return ID
     */
    long nextId();

}
```

## 策略ID实现

```java
@Component
public class SnowFlake implements IIdGenerator {

    private Snowflake snowflake;

    @PostConstruct
    public void init() {
        // 0 ~ 31 位，可以采用配置的方式使用
        long workerId;
        try {
            workerId = NetUtil.ipv4ToLong(NetUtil.getLocalhostStr());
        } catch (Exception e) {
            workerId = NetUtil.getLocalhostStr().hashCode();
        }

        workerId = workerId >> 16 & 31;

        long dataCenterId = 1L;
        snowflake = IdUtil.createSnowflake(workerId, dataCenterId);
    }

    @Override
    public synchronized long nextId() {
        return snowflake.nextId();
    }

}
```

## 策略服务上下文

```java
@Configuration
public class IdContext {

    /**
     * 创建 ID 生成策略对象，属于策略设计模式的使用方式
     *
     * @param snowFlake 雪花算法，长码，大量
     * @param shortCode 日期算法，短码，少量，全局唯一需要自己保证
     * @param randomNumeric 随机算法，短码，大量，全局唯一需要自己保证
     * @return IIdGenerator 实现类
     */
    @Bean
    public Map<Constants.Ids, IIdGenerator> idGenerator(SnowFlake snowFlake, ShortCode shortCode, RandomNumeric randomNumeric) {
        Map<Constants.Ids, IIdGenerator> idGeneratorMap = new HashMap<>(8);
        idGeneratorMap.put(Constants.Ids.SnowFlake, snowFlake);
        idGeneratorMap.put(Constants.Ids.ShortCode, shortCode);
        idGeneratorMap.put(Constants.Ids.RandomNumeric, randomNumeric);
        return idGeneratorMap;
    }

}
```

通过配置注解 `@Configuration` 和 Bean 对象的生成 `@Bean`，来把策略生成ID服务包装到 `Map<Constants.Ids, IIdGenerator>` 对象中



## 思考

1、几个策略的 nextID 是否需要加 synchronized 的问题？

- RandomNumeric 的 nextId 方法不需要加 synchronized
- ShortCode 的 nextId 方法需要加 synchronized
- SnowFlake 的 nextId 方法是否需要加 synchronized





2、对比原有抽奖活动策略实现，ID生成策略实现借助@Configuration、@Bean注入

> 原有思路

```java
@Component
public class IdsConfig {
    @Resource
    private SnowFlake snowFlake;
    @Resource
    private ShortCode shortCode;
    @Resource
    private RandomNumeric randomNumeric;
    static Map<Constants.Ids, IIdGenerator> idGeneratorMap =  new
        ConcurrentHashMap<>();
    @PostConstruct
    public void init() {
        idGeneratorMap.put(Constants.Ids.SnowFlake, snowFlake);
        idGeneratorMap.put(Constants.Ids.ShortCode, shortCode);
        idGeneratorMap.put(Constants.Ids.RandomNumeric, randomNumeric);
    }
    public static Map<Constants.Ids, IIdGenerator> getIds() {
        return idGeneratorMap;
    }
}
```

> 借助@Configuration、@Bean注入

下述实现等价于"注入一个idGenerator对象，类型为Map<Constants.Ids, IIdGenerator>"

```java
@Configuration
public class IdContext {

    /**
     * 创建 ID 生成策略对象，属于策略设计模式的使用方式
     *
     * @param snowFlake 雪花算法，长码，大量
     * @param shortCode 日期算法，短码，少量，全局唯一需要自己保证
     * @param randomNumeric 随机算法，短码，大量，全局唯一需要自己保证
     * @return IIdGenerator 实现类
     */
    @Bean
    public Map<Constants.Ids, IIdGenerator> idGenerator(SnowFlake snowFlake, ShortCode shortCode, RandomNumeric randomNumeric) {
        Map<Constants.Ids, IIdGenerator> idGeneratorMap = new HashMap<>(8);
        idGeneratorMap.put(Constants.Ids.SnowFlake, snowFlake);
        idGeneratorMap.put(Constants.Ids.ShortCode, shortCode);
        idGeneratorMap.put(Constants.Ids.RandomNumeric, randomNumeric);
        return idGeneratorMap;
    }

}
```



## TODO

了解 @Configuration 和 @Bean 两个注解的 使用方法 和 原理













