# 实现和使用分库分表

## 学习目的

描述：开发一个基于 HashMap 核心设计原理，使用哈希散列+扰动函数的方式，把数据散列到多个库表中的组件，并验证使用。

- 理清楚整个 router 的处理逻辑
- aop 切面怎么起效果的
- mybatis 拦截器如何配置，如何使用
- 动态切换数据源怎么实现的？
- 具体的分库操作在哪执行？
- 具体的分表操作在哪执行？
- 各种注解的使用方法和作用
- ThreadLocal 的原理
- HashMap 原理

## 开发日志

- 新增数据库路由组件开发工程 db-router-spring-boot-starter 这是一个自研的分库分表组件。主要用到的技术点包括：散列算法、数据源切换、AOP切面、SpringBoot Starter 开发等
- 完善分库中表信息，user_take_activity、user_take_activity_count、user_strategy_export_001~004，用于测试验证数据库路由组件
- 基于Mybatis拦截器对数据库路由分表使用方式进行优化，减少用户在使用过程中需要对数据库语句进行硬编码处理

## 需求分析

> 如果要做一个数据库路由，都需要做什么技术点？

首先我们要知道为什么要用分库分表，其实就是由于业务体量较大，数据增长较快，所以需要把用户数据拆分到不同的库表中去，减轻数据库压力

分库分表操作主要有垂直拆分和水平拆分：

- 垂直拆分：指按照业务将表进行分类，分布到不同的数据库上，这样也就将数据的压力分担到不同的库上面。最终一个数据库由很多表的构成，每个表对应着不同的业务，也就是专库专用。
- 水平拆分：如果垂直拆分后遇到单机瓶颈，可以使用水平拆分。相对于垂直拆分的区别是：垂直拆分是把不同的表拆到不同的数据库中，而本章节需要实现的水平拆分，是把同一个表拆到不同的数据库中。如：user_001、user_002

而本章节我们要实现的也是水平拆分的路由设计，如图：

<img src="https://gitee.com/HappyBinbin/pcigo/raw/master/image-20220224132519506.png" alt="image-20220224132519506" style="zoom:67%;" />

> 那么，这样的一个数据库路由设计要包括哪些技术知识点呢？

- AOP 切面拦截的使用。这是因为需要给使用数据库路由的方法做上标记，便于处理分库分表逻辑。
- 数据源的切换操作。既然有分库那么就会涉及在多个数据源间进行链接切换，以便把数据分配给不同的数据库。
- 数据库表寻址操作。一条数据分配到哪个数据库，哪张表，都需要进行索引计算。在方法调用的过程中最终通过 ThreadLocal 记录。
- 数据散列的操作。为了能让数据均匀的分配到不同的库表中去，还需要考虑如何进行数据散列的操作，不能分库分表后，让数据都集中在某个库的某个表，这样就失去了分库分表的意义。

需要用到的技术包括：`AOP`、`数据源切换`、`散列算法`、`哈希寻址`、`ThreadLocal` 以及`SpringBoot的Starter开发方式`

## 如何做一个组件starter

⾸先是⼀个 Jar 包，⼀个集合，它把需要用的其他功能组件囊括进来，放到自己的 pom 文件中。
然后它是⼀个连接，把它引入的组件和我们的项目做⼀个连接，并且在中间帮我们省去复杂的配置，力图做到使用最简单。

实现一个 starter 的四要素

- 以 starter 命名
- 自动配置类，用来初始化相关的 Bean
- 指明自动配置类的配置文件 spring.factories
- 自定义属性实体类，声明 starter 的应用配置属性

spring.factories 里面配置的属性就是指明自动配置类，这里是用到了 Java 的 SPI 机制

```properties
org.springframework.boot.autoconfigure.EnableAutoConfiguration=cn.happy.middleware.db.router.config.DataSourceAutoConfig
```

## 设计思路

![未命名绘图](https://gitee.com/HappyBinbin/pcigo/raw/master/未命名绘图.png)

## 结构分析图

![image-20220226134006305](https://gitee.com/HappyBinbin/pcigo/raw/master/image-20220226134006305.png)

## 类作用分析

DataSourceAutoConfig



## 设计实现

### 自定义路由注解

- 首先我们需要自定义一个注解，用于放置在需要被数据库路由的方法上。
- 它的使用方式是通过方法配置注解，就可以被我们指定的 AOP 切面进行拦截，拦截后进行相应的数据库路由计算和判断，并切换到相应的操作数据源上。

```java
@Documented
@Retention(RetentionPolicy.RUNTIME)
@Target({ElementType.TYPE, ElementType.METHOD})
public @interface DBRouter {

    String key() default "";

}

@Mapper
public interface IUserDao {

    @DBRouter(key = "userId")
    User queryUserInfoByUserId(User req);

    @DBRouter(key = "userId")
    void insertUser(User req);

}
```

### 数据准备

```yml
# 多数据源路由配置
mini-db-router:
  jdbc:
    datasource:
      dbCount: 2
      tbCount: 4
      default: db00
      routerKey: uId
      list: db01,db02
      db00:
        driver-class-name: com.my SQL .jdbc.Driver
        url: jdbc:my SQL ://127.0.0.1:3306/lottery?useUnicode=true
        username: root
        password: root
      db01:
        driver-class-name: com.my SQL .jdbc.Driver
        url: jdbc:my SQL ://127.0.0.1:3306/lottery_01?useUnicode=true
        username: root
        password: root
      db02:
        driver-class-name: com.my SQL .jdbc.Driver
        url: jdbc:my SQL ://127.0.0.1:3306/lottery_02?useUnicode=true
        username: root
        password: root
```

- 以上就是我们实现完数据库路由组件后的一个数据源配置，在分库分表下的数据源使用中，都需要支持多数据源的信息配置，这样才能满足不同需求的扩展。
- 对于这种自定义较大的信息配置，就需要使用到 `org.springframework.context.EnvironmentAware` 接口，来获取配置文件并提取需要的配置信息。

#### 数据源配置信息提取

```java
@Override
public void setEnvironment(Environment environment) {
    String prefix = "router.jdbc.datasource.";    

    dbCount = Integer.valueOf(environment.getProperty(prefix + "dbCount"));
    tbCount = Integer.valueOf(environment.getProperty(prefix + "tbCount"));    

    String dataSources = environment.getProperty(prefix + "list");
    for (String dbInfo : dataSources.split(",")) {
        Map<String, Object> dataSourceProps = PropertyUtil.handle(environment, prefix + dbInfo, Map.class);
        dataSourceMap.put(dbInfo, dataSourceProps);
    }
}
```

- refix，是数据源配置的开头信息，你可以自定义需要的开头内容。
- dbCount、tbCount、dataSources、dataSourceProps，都是对配置信息的提取，并存放到 dataSourceMap 中便于后续使用。

#### 创建数据源

```java
@Bean
public DataSource dataSource() {
    // 创建数据源
    Map<Object, Object> targetDataSources = new HashMap<>();
    for (String dbInfo : dataSourceMap.keySet()) {
        Map<String, Object> objMap = dataSourceMap.get(dbInfo);
        targetDataSources.put(dbInfo, new DriverManagerDataSource(objMap.get("url").toString(), objMap.get("username").toString(), objMap.get("password").toString()));
    }     

    // 设置数据源
    DynamicDataSource dynamicDataSource = new DynamicDataSource();
    dynamicDataSource.setTargetDataSources(targetDataSources);
    dynamicDataSource.setDefaultTargetDataSource(new DriverManagerDataSource(defaultDataSourceConfig.get("url").toString(), defaultDataSourceConfig.get("username").toString(), defaultDataSourceConfig.get("password").toString()));

    return dynamicDataSource;
}
```

- 这里是一个简化的创建案例，把基于从配置信息中读取到的数据源信息，进行实例化创建。
- 数据源创建完成后存放到 `DynamicDataSource` 中，它是一个继承了 AbstractRoutingDataSource 的实现类，这个类里可以存放和读取相应的具体调用的数据源信息。

### 路由策略

在 AOP 的切面拦截中需要完成；数据库路由计算、扰动函数加强散列、计算库表索引、设置到 ThreadLocal 传递数据源，整体案例代码如下：

```java
@Around("aopPoint() && @annotation(dbRouter)")
public Object doRouter(ProceedingJoinPoint jp, DBRouter dbRouter) throws Throwable {
    String dbKey = dbRouter.key();
    if (StringUtils.isBlank(dbKey)) throw new RuntimeException("annotation DBRouter key is null！");

    // 计算路由
    String dbKeyAttr = getAttrValue(dbKey, jp.getArgs());
    int size = dbRouterConfig.getDbCount() * dbRouterConfig.getTbCount();

    // 扰动函数
    int idx = (size - 1) & (dbKeyAttr.hashCode() ^ (dbKeyAttr.hashCode() >>> 16));

    // 库表索引
    int dbIdx = idx / dbRouterConfig.getTbCount() + 1;
    int tbIdx = idx - dbRouterConfig.getTbCount() * (dbIdx - 1);   

    // 设置到 ThreadLocal
    DBContextHolder.setDBKey(String.format("%02d", dbIdx));
    DBContextHolder.setTBKey(String.format("%02d", tbIdx));
    logger.info("数据库路由 method：{} dbIdx：{} tbIdx：{}", getMethod(jp).getName(), dbIdx, tbIdx);

    // 返回结果
    try {
        return jp.proceed();
    } finally {
        DBContextHolder.clearDBKey();
        DBContextHolder.clearTBKey();
    }
}
```

- 简化的核心逻辑实现代码如上，首先我们提取了库表乘积的数量，把它当成 HashMap 一样的长度进行使用。
- 接下来使用和 HashMap 一样的扰动函数逻辑，让数据分散的更加散列。
- 当计算完总长度上的一个索引位置后，还需要把这个位置折算到库表中，看看总体长度的索引因为落到哪个库哪个表。
- 最后是把这个计算的索引信息存放到 ThreadLocal 中，用于传递在方法调用过程中可以提取到索引信息。

### 数据库选择

```java
// AbstractRoutingDataSource 下的方法
@Override
public Connection getConnection() throws  SQL Exception {
    return determineTargetDataSource().getConnection();
}

// AbstractRoutingDataSource 下的方法
protected DataSource determineTargetDataSource() {
    Assert.notNull(this.resolvedDataSources, "DataSource router not initialized");
    Object lookupKey = determineCurrentLookupKey();
    DataSource dataSource = this.resolvedDataSources.get(lookupKey);
    if (dataSource == null && (this.lenientFallback || lookupKey == null)) {
        dataSource = this.resolvedDefaultDataSource;
    }
    if (dataSource == null) {
        throw new IllegalStateException("Cannot determine target DataSource for lookup key [" + lookupKey + "]");
    }
    return dataSource;
}

// 自定义动态数据源类
public class DynamicDataSource extends AbstractRoutingDataSource{

    @Override
    protected Object determineCurrentLookupKey() {
        return "db" + DBContextHolder.getDBKey();
    }
}
```

### 数据表选择

在 Mybatis 拦截器中进行  SQL  修改，选择数据表

- 最开始考虑直接在Mybatis对应的表 `INSERT INTO user_strategy_export`**_${tbIdx}** 添加字段的方式处理分表。但这样看上去并不优雅，不过也并不排除这种使用方式，仍然是可以使用的。
- 那么我们可以基于 Mybatis 拦截器进行处理，通过拦截  SQL  语句动态修改添加分表信息，再设置回 Mybatis 执行  SQL  中。
- 此外再完善一些分库分表路由的操作，比如配置默认的分库分表字段以及单字段入参时默认取此字段作为路由字段。

```java
@Intercepts({@Signature(type = StatementHandler.class, method = "prepare", args = {Connection.class, Integer.class})})
public class DynamicMybatisPlugin implements Interceptor {


    private Pattern pattern = Pattern.compile("(from|into|update)[\\s]{1,}(\\w{1,})", Pattern.CASE_INSENSITIVE);

    @Override
    public Object intercept(Invocation invocation) throws Throwable {
        // 获取StatementHandler
        StatementHandler statementHandler = (StatementHandler) invocation.getTarget();
        MetaObject metaObject = MetaObject.forObject(statementHandler, SystemMetaObject.DEFAULT_OBJECT_FACTORY, SystemMetaObject.DEFAULT_OBJECT_WRAPPER_FACTORY, new DefaultReflectorFactory());
        MappedStatement mappedStatement = (MappedStatement) metaObject.getValue("delegate.mappedStatement");

        // 获取自定义注解判断是否进行分表操作
        String id = mappedStatement.getId();
        String className = id.substring(0, id.lastIndexOf("."));
        Class<?> clazz = Class.forName(className);
        DBRouterStrategy dbRouterStrategy = clazz.getAnnotation(DBRouterStrategy.class);
        if (null == dbRouterStrategy || !dbRouterStrategy.splitTable()){
            return invocation.proceed();
        }

        // 获取 SQL 
        Bound SQL  bound SQL  = statementHandler.getBound SQL ();
        String  SQL  = bound SQL .get SQL ();

        // 替换 SQL 表名 USER 为 USER_03
        Matcher matcher = pattern.matcher( SQL );
        String tableName = null;
        if (matcher.find()) {
            tableName = matcher.group().trim();
        }
        assert null != tableName;
        String replace SQL  = matcher.replaceAll(tableName + "_" + DBContextHolder.getTBKey());

        // 通过反射修改 SQL 语句
        Field field = bound SQL .getClass().getDeclaredField(" SQL ");
        field.setAccessible(true);
        field.set(bound SQL , replace SQL );

        return invocation.proceed();
    }
}
```

- 实现 Interceptor 接口的 intercept 方法，获取 StatementHandler、通过自定义注解判断是否进行分表操作、获取 SQL 并替换 SQL 表名 USER 为 USER_03、最后通过反射修改 SQL 语句

- 此处会用到正则表达式拦截出匹配的 SQL ，`(from|into|update)[\\s]{1,}(\\w{1,})`

### 清除路由

```java
//返回结果
try {
    result = jp.proceed();
} finally {
    dbRouterStrategy.clear();
}
```

## 测试验证

### 分库验证

#### 接口

```java
@Mapper
public interface IUserTakeActivityDao {
    /**
     * 插入用于领取活动信息
     *
     * @param userTakeActivity 入参
     */
    @DBRouter(key = "uId")
    void insert(UserTakeActivity userTakeActivity);

}
```

- @DBRouter(key = "uId") key 是入参对象中的属性，用于提取作为分库分表路由字段使用

#### SQL 语句

```sql
<insert id="insert" parameterType="cn.happy.lottery.infrastructure.po.UserTakeActivity">
    INSERT INTO user_take_activity
    (u_id, take_id, activity_id, activity_name, take_date,
    take_count, uuid, create_time, update_time)
    VALUES
    (#{uId}, #{takeId}, #{activityId}, #{activityName}, #{takeDate},
    #{takeCount}, #{uuid}, now(), now())
</insert>
```

- 如果一个表只分库不分表，则它的 sql 语句并不会有什么差异
- 如果需要分表，那么则需要在表名后面加入 user_take_activity_${tbIdx} 同时入参对象需要继承 DBRouterBase 这样才可以拿到 tbIdx 分表信息 `这部分内容我们在后续开发中会有体现`

#### 单元测试

```java
@Test
public void test_insert() {
    UserTakeActivity userTakeActivity = new UserTakeActivity();
    userTakeActivity.setuId("Uhdgkw766120d"); // 1库：Ukdli109op89oi 2库：Ukdli109op811d
    userTakeActivity.setTakeId(121019889410L);
    userTakeActivity.setActivityId(100001L);
    userTakeActivity.setActivityName("测试活动");
    userTakeActivity.setTakeDate(new Date());
    userTakeActivity.setTakeCount(10);
    userTakeActivity.setUuid("Uhdgkw766120d");

    userTakeActivityDao.insert(userTakeActivity);
}
```

### 分表验证

#### 接口

```java
@Mapper
@DBRouterStrategy(splitTable = true)
public interface IUserStrategyExportDao {

    /**
     * 新增数据
     * @param userStrategyExport 用户策略
     */
    @DBRouter(key = "uId")
    void insert(UserStrategyExport userStrategyExport);

    /**
     * 查询用户
     *
     * @param uId 用户ID
     * @return 用户策略
     */
    @DBRouter
    UserStrategyExport queryUserStrategyExportByUId(String uId);

}
```

- @DBRouterStrategy(splitTable = true) 配置分表信息，配置后会通过数据库路由组件把sql语句添加上分表字段，比如表 user 修改为 user_003
- @DBRouter(key = "uId") 设置路由字段
- @DBRouter 未配置情况下走默认字段，routerKey: uId

#### SQL 语句

```sql
<insert id="insert" parameterType="cn.happy.lottery.infrastructure.po.UserStrategyExport">
    INSERT INTO user_strategy_export
    (u_id, activity_id, order_id, strategy_id, strategy_mode,
    grant_type, grant_date, grant_state, award_id, award_type,
    award_name, award_content, uuid, create_time, update_time)
    VALUES (#{uId}, #{activityId}, #{orderId}, #{strategyId}, #{strategyMode},
    #{grantType}, #{grantDate}, #{grantState}, #{awardId}, #{awardType},
    #{awardName}, #{awardContent}, #{uuid}, now(), now())
</insert>

<select id="queryUserStrategyExportByUId" parameterType="java.lang.String" resultMap="userStrategyExportMap">
    SELECT id, u_id, activity_id, order_id, strategy_id, strategy_mode,
    grant_type, grant_date, grant_state, award_id, award_type,
    award_name, award_content, uuid, create_time, update_time
    FROM user_strategy_export
    WHERE u_id = #{uId}
</select>
```

- 正常写 SQL 语句即可，如果你不使用注解 @DBRouterStrategy(splitTable = true) 也可以使用 user_strategy_export_003


#### 单元测试

```java
@Test
public void test_insert() {
    UserStrategyExport userStrategyExport = new UserStrategyExport();
    userStrategyExport.setuId("Uhdgkw766120d");
    userStrategyExport.setActivityId(idGeneratorMap.get(Constants.Ids.ShortCode).nextId());
    userStrategyExport.setOrderId(idGeneratorMap.get(Constants.Ids.SnowFlake).nextId());
    userStrategyExport.setStrategyId(idGeneratorMap.get(Constants.Ids.RandomNumeric).nextId());
    userStrategyExport.setStrategyMode(Constants.StrategyMode.SINGLE.getCode());
    userStrategyExport.setGrantType(1);
    userStrategyExport.setGrantDate(new Date());
    userStrategyExport.setAwardId("1");
    userStrategyExport.setAwardType(Constants.AwardType.DESC.getCode());
    userStrategyExport.setAwardName("IMac");
    userStrategyExport.setAwardContent("奖品描述");
    userStrategyExport.setUuid(String.valueOf(userStrategyExport.getOrderId()));

    userStrategyExportDao.insert(userStrategyExport);
}
```

## 问题与思考



## 总结

## 总结

