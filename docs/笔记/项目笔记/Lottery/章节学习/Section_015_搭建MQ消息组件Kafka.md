# 搭建MQ消息组件Kafka服务环境

## Reference

[1] https://blog.csdn.net/xwj1992930/article/details/109333944



分支：20220304_happy_kafka

描述：搭建MQ消息组件Kafka服务环境，并整合到SpringBoot中，完成消息的生产和消费处理

## 开发日志

- 搭建 Kafka 环境，配置消息主题 *注意：MQ 消息的使用不非得局限于 Kafka，也可以使用 RocketMq*
- SpringBoot 整合 Kafka，验证消息的生产和消费

## Kafka 安装和配置

Apache Kafka是一个分布式发布 - 订阅消息系统和一个强大的队列，可以处理大量的数据，并使您能够将消息从一个端点传递到另一个端点。 Kafka适合离线和在线消息消费。 Kafka消息保留在磁盘上，并在群集内复制以防止数据丢失。 Kafka构建在ZooKeeper同步服务之上。 它与Apache Storm和Spark非常好地集成，用于实时流式数据分析。

以下是Kafka的几个好处：

- **可靠性** - Kafka是分布式，分区，复制和容错的。
- **可扩展性** - Kafka消息传递系统轻松缩放，无需停机。
- **耐用性** - Kafka使用分布式提交日志，这意味着消息会尽可能快地保留在磁盘上，因此它是持久的。
- **性能** - Kafka对于发布和订阅消息都具有高吞吐量。 即使存储了许多TB的消息，它也保持稳定的性能。

Kafka非常快，并保证零停机和零数据丢失

官网下载：https://kafka.apache.org/downloads



### windows 下

windows 的话，需要调用 .bat 后缀的文件操作

### 配置 Zookeeper

在高版本的 kafka 里已经内置了 Zookeeper，但是建议自己独立安装

进入到 kafka 文件 

启动 Zookeeper：

```bash
bin/zookeeper-server-start.sh -daemon config/zookeeper.properties
```

关闭Zookeeper：

```bash
 bin/zookeeper-server-stop.sh -daemon config/zookeeper.properties
```

### 配置 Kafka

进入到 kafka 文件，新增两个文件夹 data 和 log

打开 config 下的 server.properties 修改

```properties
broker.id = 1
log,dirs = F:\\kafka\\kafka_2.13-2.8.0\\log
```

打开 config 下的 zookeeper.properties  修改

```properties
dataDir=F:\kafka\kafka_2.13-2.8.0\data
```

启动 kafka

```bash
bin/kafka-server-start.sh -daemon config/server.properties
```

## SpringBoot 整合 kafka

### POM

```xml
<dependency>
    <groupId>org.springframework.kafka</groupId>
    <artifactId>spring-kafka</artifactId>
</dependency>
```

### application.yml 配置 kafka

```yaml
spring:
  kafka:
    bootstrap-servers: localhost:9092
    producer:
      # 发生错误后，消息重发的次数。
      retries: 1
      #当有多个消息需要被发送到同一个分区时，生产者会把它们放在同一个批次里。该参数指定了一个批次可以使用的内存大小，按照字节数计算。
      batch-size: 16384
      # 设置生产者内存缓冲区的大小。
      buffer-memory: 33554432
      # 键的序列化方式
      key-serializer: org.apache.kafka.common.serialization.StringSerializer
      # 值的序列化方式
      value-serializer: org.apache.kafka.common.serialization.StringSerializer
      # acks=0 ： 生产者在成功写入消息之前不会等待任何来自服务器的响应。
      # acks=1 ： 只要集群的首领节点收到消息，生产者就会收到一个来自服务器成功响应。
      # acks=all ：只有当所有参与复制的节点全部收到消息时，生产者才会收到一个来自服务器的成功响应。
      acks: 1
    consumer:
      # 自动提交的时间间隔 在spring boot 2.X 版本中这里采用的是值的类型为Duration 需要符合特定的格式，如1S,1M,2H,5D
      auto-commit-interval: 1S
      # 该属性指定了消费者在读取一个没有偏移量的分区或者偏移量无效的情况下该作何处理：
      # latest（默认值）在偏移量无效的情况下，消费者将从最新的记录开始读取数据（在消费者启动之后生成的记录）
      # earliest ：在偏移量无效的情况下，消费者将从起始位置读取分区的记录
      auto-offset-reset: earliest
      # 是否自动提交偏移量，默认值是true,为了避免出现重复数据和数据丢失，可以把它设置为false,然后手动提交偏移量
      enable-auto-commit: false
      # 键的反序列化方式
      key-deserializer: org.apache.kafka.common.serialization.StringDeserializer
      # 值的反序列化方式
      value-deserializer: org.apache.kafka.common.serialization.StringDeserializer
    listener:
      # 在侦听器容器中运行的线程数。
      concurrency: 5
      #listner负责ack，每调用一次，就立即commit
      ack-mode: manual_immediate
      missing-topics-fatal: false
```

### 生产者

```java
@Component
public class KafkaProducer {

    private Logger logger = LoggerFactory.getLogger(KafkaProducer.class);

    @Resource
    private KafkaTemplate<String, Object> kafkaTemplate;

    public static final String TOPIC_TEST = "Hello-Kafka";

    public static final String TOPIC_GROUP = "test-consumer-group";

    public void send(Object obj) {
        String obj2String = JSON.toJSONString(obj);
        logger.info("准备发送消息为：{}", obj2String);

        // 发送消息
        ListenableFuture<SendResult<String, Object>> future = kafkaTemplate.send(TOPIC_TEST, obj);
        future.addCallback(new ListenableFutureCallback<SendResult<String, Object>>() {
            @Override
            public void onFailure(Throwable throwable) {
                //发送失败的处理
                logger.info(TOPIC_TEST + " - 生产者 发送消息失败：" + throwable.getMessage());
            }

            @Override
            public void onSuccess(SendResult<String, Object> stringObjectSendResult) {
                //成功的处理
                logger.info(TOPIC_TEST + " - 生产者 发送消息成功：" + stringObjectSendResult.toString());
            }
        });
    }

}
```



### 消费者

```java
@Component
public class KafkaConsumer {

    private Logger logger = LoggerFactory.getLogger(KafkaConsumer.class);

    @KafkaListener(topics = KafkaProducer.TOPIC_TEST, groupId = KafkaProducer.TOPIC_GROUP)
    public void topicTest(ConsumerRecord<?, ?> record, Acknowledgment ack, @Header(KafkaHeaders.RECEIVED_TOPIC) String topic) {
        Optional<?> message = Optional.ofNullable(record.value());
        if (message.isPresent()) {
            Object msg = message.get();
            logger.info("topic_test 消费了： Topic:" + topic + ",Message:" + msg);
            ack.acknowledge();
        }
    }

}
```

## 测试验证

测试之前需要开启 Kafka 服务

- 启动 Zookeeper：`bin/zookeeper-server-start.sh -daemon config/zookeeper.properties`
- 启动 Kafka：`bin/kafka-server-start.sh -daemon config/server.properties`

**单元测试**

```java
@RunWith(SpringRunner.class)
@SpringBootTest
public class KafkaProducerTest {

    private Logger logger = LoggerFactory.getLogger(KafkaProducerTest.class);

    @Resource
    private KafkaProducer kafkaProducer;

    @Test
    public void test_send() throws InterruptedException {
        // 循环发送消息
        while (true) {
            kafkaProducer.send("你好，我是Lottery");
            Thread.sleep(3500);
        }
    }
}
```

- 在单元测试中，我们循环发送 MQ 消息，最后你会在控制台看到消费消息的结果

```java
2022-03-04 10:10:26.281  INFO 18552 --- [           main] c.h.l.a.process.mq.KafkaProducer         : 准备发送消息为："你好，我是HappyChan"
2022-03-04 10:10:31.808  INFO 18552 --- [ad | producer-1] c.h.l.a.process.mq.KafkaProducer         : Hello-Kafka - 生产者 发送消息成功：SendResult [producerRecord=ProducerRecord(topic=Hello-Kafka, partition=null, headers=RecordHeaders(headers = [], isReadOnly = true), key=null, value=你好，我是HappyChan, timestamp=null), recordMetadata=Hello-Kafka-0@0]
2022-03-04 10:10:32.278  INFO 18552 --- [ntainer#0-0-C-1] c.h.l.a.process.mq.KafkaConsumer         : topic_test 消费了： Topic:Hello-Kafka,Message:你好，我是HappyChan
```



## 问题与思考

1、Kafka 的原理是什么？ 为什么说它是专门处理大数据的消息队列？

2、SpingBoot 集成 MQ 的方式有哪些？xml 的配置方式怎么弄



3、端口启动被占用，但是 netstat 查不到？

有些端口是固定不开放的，被特殊使用的。请查询后进行更换



4、更换 mysql 8.0 版本后，有很多坑要填

当安装了Mysql8.0以上版本，搭建SpringBoot环境时启动项目时会遇到以下错误：

4.1 第一个坑

Caused by javax.net.ssl.SSLHandshakeException:java.security.cert.certificateException

jdbc 的驱动依赖升级

```xml
<dependency>
    <groupId>mysql</groupId>
    <artifactId>mysql-connector-java</artifactId>
    <version>8.0.11</version>
</dependency>
```

配置文件的 driverClassName 更换

```yaml
 com.mysql.cj.jdbc.Driver
```

4.2 第二个坑

java.sql.SQLException: The connection property 'zeroDateTimeBehavior' acceptable values are: 'CONVERT_TO_NULL', 'EXCEPTION' or 'ROUND'. The value 'convertToNull' is not acceptable

由于MySql废弃了convertToNull该写法，改为 CONVERT_TO_NULL

```yaml
url:  jdbc:mysql://xxx.xxx.xxx.xxx:3306/xxx?characterEncoding=utf8&useSSL=true&serverTimezone=UTC&zeroDateTimeBehavior=CONVERT_TO_NULL
```
4.3 第三个坑

DBRouter 的组件引用的依赖也要更换

4.4 第四个坑

java.sql.SQLNonTransientConnectionException: Could not create connection to database server. Attempted reconnect 3 times. Giving up.

```yaml
原先的 url

url: jdbc:mysql://localhost:3306/lottery_02？useUnicode=true&characterEncoding=utf8&autoReconnect=true&zeroDateTimeBehavior=CONVERT_TO_NULL&serverTimezone=UTC&allowPublicKeyRetrieval=true&useSSL=true

简化后的 url
url: jdbc:mysql://localhost:3306/lottery_02?serverTimezone=UTC&useSSL=false&allowPublicKeyRetrieval=true
```



## 总结

1. 学习 Kafka 环境配置搭建，也可以把 Kafka 配置到云服务中做集群配置
2. 学习 SpringBoot 与 Kafka 的整合使用，消息的发送和接收处理
