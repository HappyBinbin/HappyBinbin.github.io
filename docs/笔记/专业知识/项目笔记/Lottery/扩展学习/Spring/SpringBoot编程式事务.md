# TransactionTemplate的使用

总结：在类中注入TransactionTemplate，即可在springboot中使用编程式事务。

`spring` 支持编程式事务管理和声明式事务管理两种方式

编程式事务管理使用TransactionTemplate或者直接使用底层的PlatformTransactionManager。对于编程式事务管理，spring推荐使用TransactionTemplate。

声明式事务管理建立在AOP之上的。其本质是对方法前后进行拦截，然后在目标方法开始之前创建或者加入一个事务，在执行完目标方法之后根据执行情况提交或者回滚事务。对于声明式事务管理，springboot中推荐使用@Transactional注解。

## 1.为何用？

多数情况下，方法上声明@Transactional注解声明事务即可，简单、快捷、方便，但@Transactional声明式事务的可控性太弱了，只可在方法或类上声明，做不到细粒度的事务控制。如果一个方法前10条sql都是select查询语句，只有最后2条sql是update语句，那么只对最后2条sql做事务即可。

## 2.如何用

```xml
<dependency>
    <groupId>org.mybatis.spring.boot</groupId>
    <artifactId>mybatis-spring-boot-starter</artifactId>
    <version>2.2.0</version>
</dependency>
```

springboot中 引入mybatis-spring-boot-starter 依赖包即可。

mybatis-spring-boot-starter 依赖包中包含了spring-boot-starter-jdbc的依赖，spring-boot-starter-jdbc 中包含 DataSourceTransactionManager 事务管理器以及自动注入配置类DataSourceTransactionManagerAutoConfiguration

代码中使用，在使用bean中注入TransactionTemplate即可：

```java
@Service
public class TestServiceImpl {
    @Resource
    private TransactionTemplate transactionTemplate;

    public Object testTransaction() {
        //数据库查询
        dao.select(1);
        return transactionTemplate.execute(status -> {
            //数据库新增
            dao.insert(2);
            dao.insert(3);
            return new Object();
        });
    }
}
```

