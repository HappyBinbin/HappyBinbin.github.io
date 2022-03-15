# 注解使用

## @Resources

**问题：**

@Resources 和 static 不能共用的问题，会出现  java.lang.IllegalStateException: @Resource annotation is not supported on static fields 异常

**解答：**

因为静态变量、类变量不是对象的属性，而是一个类的属性，所以静态方法是属于类（class）的；普通方法才是属于实体对象（也就是New出来的对象）的，spring注入是在容器中实例化对象，所以不能使用静态方法。而使用静态变量、类变量扩大了静态方法的使用范围。静态方法在spring是不推荐使用的，依赖注入的主要目的，是让容器去产生一个对象的实例，然后在整个生命周期中使用他们，同时也让testing工作更加容易。

一旦你使用静态方法，就不需要去产生这个类的实例，这会让testing变得更加困难，同时你也不能为一个给定的类，依靠注入方式去产生多个取优不同的依赖环境的实例，这种static field是隐含共享的，并且是一种global全局状态，spring同样不推荐这样去做。

## @PostConstruct

PostConstruct 的执行顺序问题

> Constructor（构造方法）—> @Autowired（依赖注入）—> @PostConstruct（注释的方法）

1. @PostConstruct 注解的方法在加载类的构造函数之后执行，也就是在加载了构造函数之后，为此，可以使用@PostConstruct注解一个方法来完成初始化，@PostConstruct 注解的方法将会在依赖注入完成后被自动调用。
2. 执行优先级高于非静态的初始化块，它会在类初始化（类加载的初始化阶段）的时候执行一次，执行完成便销毁，它仅能初始化类变量，即static修饰的数据成员。

## @Pointcut

```java
@Pointcut("@annotation(cn.happy.middleware.db.router.annotation.DBRouter)")
```

- @annotation：用于匹配当前执行方法持有指定注解的方法；

## @Confriguration

注解标识的类中声明了1个或者多个@Bean方法，Spring容器可以使用这些方法来注入Bean，比如：

```java
@Configuration
public class AppConfig {
    //这个方法就向Spring容器注入了一个类型是MyBean名字是myBean的Bean
    @Bean
    public MyBean myBean() {
        // instantiate, configure and return bean ...
    }
}
```

## @Bean

产生一个Bean对象，然后这个Bean对象交给Spring管理。产生这个Bean对象的方法Spring只会调用一次，随后这个Spring将会将这个Bean对象放在自己的IOC容器中。

SpringIOC 容器管理一个或者多个bean，这些bean都需要在@Configuration注解下进行创建，在一个方法上使用@Bean注解就表明这个方法需要交给Spring进行管理。



## AOP 注解

称为面向切面编程，在程序开发中主要用来解决一些系统层面上的问题，比如日志，事务，权限等待

**通知 Advice**

- @Before：前置通知，在目标方法被调用之前做增强处理
- @After：后置通知，在目标方法完成之后做增强，无论目标方法时候成功完成
- @AfterReturning：返回通知，在目标方法正常完成后做增强,@AfterReturning除了指定切入点表达式后，还可以指定一个返回值形参名returning,代表目标方法的返回值
- @AfterThrowing：异常通知，主要用来处理程序中未处理的异常,@AfterThrowing除了指定切入点表达式后，还可以指定一个throwing的返回值形参名,可以通过该形参名
- @Around：环绕通知，在目标方法完成前后做增强处理,环绕通知是最重要的通知类型,像事务,[日志](https://so.csdn.net/so/search?q=日志&spm=1001.2101.3001.7020)等都是环绕通知,注意编程中核心是一个ProceedingJoinPoint

**其他注解**

- @PointCut：就是带有通知的连接点，在程序中主要体现为书写切入点表达式
- JoinPoint：作为函数的参数传入切面方法，可以得到目标方法的相关信息
- @Aspect ： 指定切面类，里面可以定义切入点和通知
- @EnableAspectJAutoProxy ： 开启基于注解的AOP模式

## @annotation()的使用

### 一般的切面注解

```java
//切入点签名
@Pointcut("execution(* com.lxk.spring.aop.annotation.PersonDaoImpl.*(..))")
private void aa() {
}
```

切入点声明OK之后，就是在不同的 advice 里面使用啦。一般都是如下使用。
下面的 `暂时是不带注解的`

```java
//前置通知
@Before("aa()")

//后置通知
@AfterReturning(value = "aa()", returning = "val")
public void afterMethod(JoinPoint joinPoint, Object val) {}

//最终通知
@After("aa()")

//环绕通知
@Around("aa()")

//异常通知
@AfterThrowing(value = "aa()", throwing = "ex")
public void throwingMethod(Throwable ex) {}
```

这些切面方法里面的参数。JoinPoint joinPoint，这个是哪个都可以加的。加不加随意。需要的话就加。是可以用的。

### 带自定义注解的切面注解

@Pointcut 先说下这个显示声明的好处，就像声明变量一样，因为这个切入点表达式是可以用 && ||  !来组合条件的，这么声明的话，可以使得代码简洁。

直接在各类 advice 通知的参数上面，使用execution来声明。例如：

```java
@Around(value = "(execution(* com.lxk.service..*(..))) && @annotation(methodLog)", argNames = "joinPoint, methodLog")
public Object methodAround(ProceedingJoinPoint joinPoint, MethodLog methodLog) throws Throwable {}
```

其实，上面的value里面的意思，就是复合那个切入的点的条件， 以&&连接，也就是说2个都符合。

既然咱自定义了注解，就是来干这个切面的，为啥还要对他是哪个包，要限制一下呢，我

最终简化如下：

```java
@Around(value = "@annotation(methodLog)")
public Object methodAround(ProceedingJoinPoint joinPoint, MethodLog methodLog) throws Throwable {}
```

既然不用加那个包的限制，这切面还是OK的，为啥还要加呢？

自定义注解命名的时候，可能你取的名字很大众化，其他的jar包，也就是你项目引入的jar包，可能有重名的注解，如果要是不加包限制的话，那估计就会出现意想不到的效果。所以，我们就看到，那么多的切面代码，这地方的写法都是千篇一律 都是使用 && 符号。限制包，然后限制使用的是哪个注解。













