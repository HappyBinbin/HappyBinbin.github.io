# Redis生成流水号

Redis的 incr( ) 方法可以进行自增补零，结合时间、随机数、前缀组成唯一的流水号。

## 流水号结构

## 

![image-20220220080430080](https://gitee.com/HappyBinbin/pcigo/raw/master/image-20220220080430080.png)

## 实现步骤

1. 初始化流水号进入缓存
2. 生成流水号

### 初始化

```java

@Data
public class YuSnGenCode {
    // 流水号生成依赖的类，会使用类的名称作为redis的key 
    private Class entity;
    // 前缀
    private String prefix;
    // 自增数位数 自增数达不到此位数自动补零
    private Integer num;

    public YuSnGenCode(Class entity, String prefix, Integer num) {
        this.entity = entity;
        this.prefix = prefix;
        this.num = num;
    }
}

@Component
@Slf4j
public class YuSnGenStart implements ApplicationRunner {
    @Autowired
    YuSnGenUtil yuSnGenUtil;

    @Override
    public void run(ApplicationArguments args) throws Exception {
        log.info("=====开始初始化流水号=====");
        List<YuSnGenCode> yuSnGenCodeList = new ArrayList<>();
        yuSnGenCodeList.add(new YuSnGenCode(Account.class, "AC", 6));
        yuSnGenCodeList.add(new YuSnGenCode(Shop.class, "DP", 6));
        yuSnGenCodeList.add(new YuSnGenCode(Order.class, "OR", 6));
        yuSnGenCodeList.add(new YuSnGenCode(Dispatch.class, "DL", 6));
        yuSnGenCodeList.add(new YuSnGenCode(Refund.class, "RF", 6));
        yuSnGenCodeList.add(new YuSnGenCode(PayLog.class, "PL", 6));
        yuSnGenCodeList.add(new YuSnGenCode(Withdrawal.class, "WR", 6));
        yuSnGenCodeList.add(new YuSnGenCode(Aftermarket.class, "AS", 6));
        yuSnGenCodeList.add(new YuSnGenCode(Coupon.class, "CO", 6));
        yuSnGenCodeList.add(new YuSnGenCode(CouponGen.class, "CG", 10));
        yuSnGenCodeList.add(new YuSnGenCode(Draw.class, "DP", 6));
        yuSnGenUtil.init(yuSnGenCodeList);
        log.info("=====初始化流水号完毕=====");
    }
}

public void init(List<YuSnGenCode> yuSnGenCodes) {
    // 流水号初始化入缓存
    for (YuSnGenCode yuSnGenCode : yuSnGenCodes) {
        String redisKey = yuSnGenCode.getEntity().getName();
        // 存入缓存 key：key：实体类名称 value：流水号数据（前缀、自增数位数）
        redisTemplate.opsForValue().set(yuSnGenCode.getEntity().getName(), FastJsonUtils.toJsonStr(yuSnGenCode));
        log.info(yuSnGenCode.getEntity().getName() + "已初始化");

    }
}
```

### 生成流水号

```java
public Optional<String> gen(Class c) {
    // 获取实体类的名称
    String redisKey = c.getName();
    // 判断是不是有初始化此实体类
    if (null != redisTemplate.opsForValue().get(redisKey)) {
        // 从缓存获取流水号的生成信息
        YuSnGenCode yuSnGenCode = FastJsonUtils.toBean(redisTemplate.opsForValue().get(redisKey).toString(), YuSnGenCode.class);
        // 根据流水号的前缀判断今天是否有生成过流水号
        if (redisTemplate.opsForValue().get(yuSnGenCode.getPrefix()) == null) {
            // 没有则新建一个存入缓存 格式（key:OR  value:0）
            // 设置到第二天早上00：00：01过期
            Long todayTime = LocalDate.now().plusDays(1).atTime(0, 0, 0, 1).atOffset(ZoneOffset.ofHours(8)).toEpochSecond();
            Long nowTime = LocalDateTime.now().atOffset(ZoneOffset.ofHours(8)).toEpochSecond();
            Long expireTime = todayTime - nowTime;
            redisTemplate.opsForValue().set(yuSnGenCode.getPrefix(), 0, expireTime*1000, TimeUnit.MILLISECONDS);
        }
        // 进行自增操作
        StringBuffer sn = new StringBuffer();
        // 和前缀、时间、随机数进行组合
        sn.append(yuSnGenCode.getPrefix());
        String date = LocalDate.now().format(DateTimeFormatter.ofPattern("yyyyMMdd"));
        sn.append(date);
        Long num = redisTemplate.opsForValue().increment(yuSnGenCode.getPrefix());
        sn.append(addZero(String.valueOf(num), yuSnGenCode.getNum()));
        String random = String.valueOf(new Random().nextInt(1000));
        sn.append(random);
        // 生成最终的流水号返回
        return Optional.ofNullable(sn.toString());
    }
    return Optional.ofNullable(null);
}

// 自动补零
public String addZero(String numStr, Integer maxNum) {
    int addNum = maxNum - numStr.length();
    StringBuffer rStr = new StringBuffer();
    for (int i = 0; i < addNum; i++) {
        rStr.append("0");
    }
    rStr.append(numStr);
    return rStr.toString();
}
```

## Redis 持久化

redis持久化指redis意外退出之后重启仍然能够恢复之前数据。我们这里使用redis AOF 持久化防止redis意外退出重启导致流水号数据重置，从而导致我们的流水号生成重复。

