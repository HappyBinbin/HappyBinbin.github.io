# Redis 前缀Key设计

在Java web开发中，redis的使用已非常频繁了，大规模的使用也延伸了一些问题，例如：我定义了一个redis key name 存放的值为用户昵称，而这时同事定义一个key 也叫name,存放的是商品名字，那么冲突再所难免，为了解决这一问题,合理的设计redis key前缀 成为了迫切的需求。我们一起来看看优雅的设计吧！

## 采用模板方法模式进行设计前缀空间

接口------RedisPrefixKey
|
抽象类-----RedisBasePrefixKey
|
实现类 -----UserKey

## RedisPrefixKey 接口

```java
public interface RedisPrefixKey {
    /**
     * redis 过期时间
     * @return 过期时间
     */
    Long getExpireSeconds();

    /**
     * redis key
     * @return 键前缀
     */
    String getPrefix();
}
```

接口中定义了两个方法

- 获取redis key 的过期时间 `getExpireSeconds()`
- 获取redis 的key前缀`getPrefix()`

## RedisBasePrefixKey 抽象类

```java
@Setter
@AllArgsConstructor
public abstract class RedisBasePrefixKey implements RedisPrefixKey {
    /**
     * 过期时间
     */
    private Long expireSeconds;
    /**
     * redis key前缀
     */
    private String prefix;

    /**
     * 构造器
     * expireSeconds 为零默认为永不过期
     *
     * @param prefix 前缀
     */
    public RedisBasePrefixKey(String prefix) {
        this.prefix = prefix;
        this.expireSeconds = 0L;
    }

    /**
     * 获取过期时间
     *
     * @return
     */
    @Override
    public Long getExpireSeconds() {
        return expireSeconds;
    }

    /**
     * 获取Key前缀
     *
     * @return
     */
    @Override
    public String getPrefix() {
        String className = getClass().getSimpleName();
        return className.concat(":").concat(prefix).concat(":");
    }
}
```

## UserKey 实现类(自定义)

私有化构造器防止外面new创建

```java
public class UserKey extends RedisBasePrefixKey{

    private UserKey(Long expireSeconds, String prefix) {
        super(expireSeconds, prefix);
    }

    private UserKey(String prefix){
        super(prefix);
    }

    public static final String USER_KEY_ID = "uid";
    /**
     * 用户key
     */
    public static UserKey userId = new UserKey(USER_KEY_ID);

}
```

最后生成的key是 `UserKey:uid:1` 模块:属性:值 == value

## 改造RedisUtil工具类的方法

```java
/**
 *
 * @param prefix 键前缀
 * @param key 键
 * @param value 值
 * @return true成功 false 失败
 */
public boolean set(RedisPrefixKey prefix, String key, Object value) {
    try {
        long time = prefix.getExpireSeconds();
        if (time > 0) {
            redisTemplate.opsForValue().set(prefix.getPrefix().concat(key), value, time, TimeUnit.SECONDS);
        } else {
            set(prefix.getPrefix().concat(key), value);
        }
        return true;
    } catch (Exception e) {
        e.printStackTrace();
        return false;
    }
}

/**
 * 普通缓存放入
 *
 * @param key   键
 * @param value 值
 * @return true成功 false失败
 */
public boolean set(String key, Object value) {
    try {
        redisTemplate.opsForValue().set(key, value);
        return true;
    } catch (Exception e) {
        e.printStackTrace();
        return false;
    }
}

/**
 * 普通缓存获取
 *
 * @param key 键
 * @return 值
 */
public Object get(RedisPrefixKey prefix, String key) {
    return key == null ? null : redisTemplate.opsForValue().get(prefix.getPrefix().concat(key));
}
```

## 具体使用

```java
//设置用户缓存
User user = userService.queryById(1);
redisUtil.set(UserKey.userId,user.getId()+"",user);
User u = (User)redisUtil.get(UserKey.getUserId,user.getId()+"");
System.out.println(u.toString());
```