## SpringBoot 读取环境变量

凡是被 `spring` 管理的类，实现接口 EnvironmentAware 重写方法 setEnvironment 可以在工程启动时，获取到系统环境变量和application配置文件中的变量。

```java
@Configuration
public class DataSourceAutoConfig implements EnvironmentAware{

    @Override
    public void setEnvironment(Environment environment) {

        // application.yml 里的多数据源路由配置
        String prefix = "mini-db-router.jdbc.datasource.";

        dbCount = Integer.valueOf(environment.getProperty(prefix + "dbCount"));
        tbCount = Integer.valueOf(environment.getProperty(prefix + "tbCount"));
        routerKey = environment.getProperty(prefix + "routerKey");

        // db01,db02 是分库分表的数据源
        String dataSources = environment.getProperty(prefix + "list");
        assert dataSources != null;
        for (String dbInfo : dataSources.split(",")) {
            Map<String, Object> dataSourceProps = PropertyUtil.handle(environment, prefix + dbInfo, Map.class);
            dataSourceMap.put(dbInfo, dataSourceProps);
        }

        // 默认数据源
        String defaultData = environment.getProperty(prefix + "default");
        defaultDataSourceConfig = PropertyUtil.handle(environment, prefix + defaultData, Map.class);
    }
}
```

application.yml 里的配置

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
        driver-class-name: com.mysql.jdbc.Driver
        url: jdbc:mysql://127.0.0.1:3306/lottery?useUnicode=true
        username: root
        password: root
      db01:
        driver-class-name: com.mysql.jdbc.Driver
        url: jdbc:mysql://127.0.0.1:3306/lottery_01?useUnicode=true
        username: root
        password: root
      db02:
        driver-class-name: com.mysql.jdbc.Driver
        url: jdbc:mysql://127.0.0.1:3306/lottery_02?useUnicode=true
        username: root
        password: root
```

@Controller @Service 等被Spring管理的类都支持，注意重写的方法 setEnvironment 是在系统启动的时候被执行。 

> @ConditionOnClass 表明该 @Configuration 仅仅在一定条件下才会被加载，这里的条件是Mongo.class位于类路径上

> `@EnableConfigurationProperties` 将 Spring Boot 的配置文件（application.yml）中的spring.data.mongodb.* 属性映射为 MongoProperties 并注入到 MongoAutoConfiguration中
>
> 这个属性也可以通过 spring.factories 进行配置，springboot 在启动的时候会加载类路径下的 META-INF/spring.factories 下配置的 EnableAutoConfiguration 对应的值
>
> 配置例子：org.springframework.boot.autoconfigure.EnableAutoConfiguration=cn.happy.middleware.db.router.config.DataSourceAutoConfig

```java
@Configuration
@ConditionalOnClass (Mongo. class )
@EnableConfigurationProperties (MongoProperties. class )
public class MongoAutoConfiguration {

    @Autowired
    private  MongoProperties properties;
}
```

我们还可以通过@ConfigurationProperties 读取application属性配置文件中的属性。

```java
@ConfigurationProperties (prefix =  "spring.data.mongodb" )
public class MongoProperties {

    private  String host;
    privateint port = DBPort.PORT;
    private  String uri =  "mongodb://localhost/test" ;
    private  String database;

    // ... getters/ setters omitted
}
```

> @ConditionalOnMissingBean 说明 Spring Boot 仅仅在当前上下文中不存在 DBRouterJoinPoint 对象时，才会实例化一个Bean，并且重新命名为 `db-router-point`。这个逻辑也体现了Spring Boot的另外一个特性——自定义的Bean优先于框架的默认配置，我们如果显式的在业务代码中定义了一个Mongo对象，那么Spring Boot就不再创建

```java
@Bean(name = "db-router-point")
@ConditionalOnMissingBean
public DBRouterJoinPoint point(DBRouterConfig dbRouterConfig, IDBRouterStrategy dbRouterStrategy) {
    return new DBRouterJoinPoint(dbRouterConfig, dbRouterStrategy);
}
```

以上这个配置需要加入依赖：

```xml
<!--spring-boot-configuration:spring boot 配置处理器; -->
<dependency>
    < groupId >org.springframework.boot</ groupId >
    < artifactId >spring-boot-configuration-processor</ artifactId >
    < optional >true</ optional >
</ dependency >
```