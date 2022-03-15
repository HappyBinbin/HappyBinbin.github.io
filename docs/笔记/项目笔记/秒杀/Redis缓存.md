## Redis 缓存

### 如何集成 Jedis ？

1. 添加 Jedis 依赖，FastJson 依赖（Fastjson速度慢一点， -但是序列化之后可读）

2. 在 application.xml 配置 Redis 服务器的信息（redis.post、redis.host、redis.timeout、redis.password、redis.poolMaxTotal……）

3. RedisConfig 类，加注解@Component & @ ConfigurationProperties(Prefix = "redis")

4. RedisService类，提供redis服务，从 RedisConfig 读取配置，编写方法： JedisPoolFacotry ，封装JedisPoolConfig，返回一个 jedis 客户端对象

    ```java
    JedisPoolConfig poolConfig = new JedisPoolConfig();
    set;
    ...;
    JedisPool jp = new JedisPool(poolConfig, redisConfig.getHsot(), ....);
    return jp;
    ```

5. 编写通用的 public < T >  T get(String key, Class< T > class) 方法 

6. 第四步会导致循环依赖，所以将 JedisPoolFactory 抽取成一个类，单独获取 PoolConfig 

7. set进入Redis时，为了使前缀不回重复，以及拓展多个服务Key，采用模版设计模式

    ```java
    public interface KeyPrefix {
    		
    	public int expireSeconds();
    	
    	public String getPrefix();
    	
    }
    
    public abstract class BasePrefix implements KeyPrefix{
    	
    	private int expireSeconds;
    	
    	private String prefix;
    	
    	public BasePrefix(String prefix) {//0代表永不过期
    		this(0, prefix);
    	}
    	
    	public BasePrefix( int expireSeconds, String prefix) {
    		this.expireSeconds = expireSeconds;
    		this.prefix = prefix;
    	}
    	
    	@Override
    	public int expireSeconds() {//默认0代表永不过期
    		return expireSeconds;
    	}
    
    	@Override
    	public String getPrefix() {
    		String className = getClass().getSimpleName();
    		return className+":" + prefix;
    	}
    
    }
    
    // 其他的具体是什么业务的类，只需要去继承 BasePrefix 即可
    public class MiaoshaUserKey extends BasePrefix{
    
    	public static final int TOKEN_EXPIRE = 3600*24 * 2;
    	private MiaoshaUserKey(int expireSeconds, String prefix) {
    		super(expireSeconds, prefix);
    	}
    	public static MiaoshaUserKey token = new MiaoshaUserKey(TOKEN_EXPIRE, "tk");
    }
    public class OrderKey extends BasePrefix {
    
    	public OrderKey(int expireSeconds, String prefix) {
    		super(expireSeconds, prefix);
    	}
    
    }
    ```

    