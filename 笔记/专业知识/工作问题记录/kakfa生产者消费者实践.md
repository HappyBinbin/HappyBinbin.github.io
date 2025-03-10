## 背景介绍
最近在工作中项目使用了新的一些开发思路，利用mq来解耦耗时较长的业务流程；
例如以下的场景：
- 删除某些资源的操作，可能是 服务A => 服务B => xxx 中间的过程是同步的，但可能某一步的业务逻辑需要删除的资源很多，如果是同步操作，给用于的体验就是一直等待，直到删除完毕，交互效果很不友好；
- 创建/更新资源的联动，用户可能创建一条资源，但是要满足整体的资源联动，则可能需要创建和更新其他的资源，也直接影响了用户的体验性；
- 每个模块进行完全独立的业务逻辑处理

有个很有意思的想法，就是利用mq的持久性，进行消息传播，让每个业务服务专注于处理自己的业务逻辑，不过这个想法也有一些很明显的优缺点：
- 优点
	- 每个服务接收到mq后，直接进行最原始的CRUD操作，不需要进行考虑其他问题
	- 可以隐藏后台的耗时操作，让用户无感知
	- 不用考虑跨服务调用失败，mq失败了不会提交offset
- 缺点
	- 可能存在循环调用的问题，导致msg永久存在，可能需要在业务上考虑如何避免
	- 每个服务都需要有一个模块专门接受和处理消息，消息是否本服务处理、处理完是否需要notify其他服务
	- 不好排查错误，每个服务都是独立的处理逻辑

![image.png](https://happychan.oss-cn-shenzhen.aliyuncs.com/picgo/20250308115601.png)

## 生产者

- 自定义分区器
	- 模拟业务key进行分区
- 同步生产者

``` go
package main  
  
import (  
   "fmt"  
   "hash/crc32"   "log"  
   "github.com/IBM/sarama"      "HelloGo/Kafka"  
)  
  
type CustomPartitioner struct{}  
  
func (p *CustomPartitioner) Partition(msg *sarama.ProducerMessage, numPartitions int32) (int32, error) {  
   keyBytes, _ := msg.Key.Encode()  
   hash := crc32.ChecksumIEEE(keyBytes)  
   return int32(hash % uint32(numPartitions)), nil  
}  
  
func (p *CustomPartitioner) RequiresConsistency() bool {  
   return true  
}  
  
func NewMyPartitioner(topic string) sarama.Partitioner {  
   return &CustomPartitioner{}  
}  
  
type BusinessKey struct {  
   UserID string  
}  
  
func (b BusinessKey) Encode() ([]byte, error) {  
   return []byte(b.UserID), nil  
}  
  
func (b BusinessKey) Length() int {  
   return len(b.UserID)  
}  
  
func main() {  
   Producer(Kafka.HappyChanTopic, 60000)  
}  
  
func Producer(topic string, limit int) {  
   config := sarama.NewConfig()  
   //config.Producer.Compression = sarama.CompressionGZIP  
   //config.Producer.CompressionLevel = gzip.BestCompression   config.Producer.Return.Successes = true  
   config.Producer.Return.Errors = true // 这个默认值就是 true 可以不用手动 赋值  
   config.Producer.Partitioner = NewMyPartitioner  
  
   producer, err := sarama.NewSyncProducer([]string{Kafka.Brokers}, config)  
   if err != nil {  
      log.Fatal("NewSyncProducer err:", err)  
   }  
   defer producer.Close()  
   userIds := []string{"user1", "user2", "user3", "user4"}  
   for i := 0; i < limit; i++ {  
      // 生成不同的UserID（示例：时间戳+随机数）  
      bs := BusinessKey{  
         UserID: userIds[i%4],  
      }  
      // 自定义Value（示例：添加时间戳）  
      value := fmt.Sprintf("data_%d", i)  
      msg := &sarama.ProducerMessage{Topic: topic, Key: bs, Value: sarama.StringEncoder(value)}  
      partition, offset, err := producer.SendMessage(msg)  
      if err != nil {  
         log.Println("SendMessage err: ", err)  
         return  
      }  
      log.Printf("[Producer] partitionid: %d; offset:%d\n", partition, offset)  
   }  
}
```

## 消费者
实现的功能：
- 消费者抽象
	- 工厂模式管理不同Topic的处理器
	- 统一接口实现业务逻辑解耦
	- 自动化的消费者生命周期管理
- 重试机制
- 死信队列
- 监控建议
	- 消息处理成功率
	- 重试队列堆积情况
	- 死信队列数量
	- 消费者组延迟
还可以再优化的地方：
- 分优先级处理不同消息的重试次数
- 消费者的config可以通过配置文件、k8s 的 configmap 资源、或者配置中心拉取，进行热加载 等其他方式进行初始化

``` go
package main  
  
import (  
   "context"  
   "fmt"   "log"   "os"   "os/signal"   "syscall"   "time"  
   "github.com/IBM/sarama"   "github.com/jinzhu/copier")  
  
// 配置常量  
const (  
   Brokers            = "localhost:9092"  
   MaxRetries         = 3  
   RetryHeaderKey     = "retry_count"  
   DLQTopicSuffix     = "_dlq"  
   SessionTimeout     = 30 * time.Second  
   HeartbeatInterval  = 3 * time.Second  
   MaxProcessingTime  = 2 * time.Minute  
   AutoCommitInterval = 1 * time.Second  
)  
  
// 扩展MessageHandler接口  
type MessageHandler interface {  
   Handle(ctx context.Context, msg *sarama.ConsumerMessage) error  
   Topic() string  
   ConsumerGroup() string    // 新增：消费者组ID  
   Concurrency() int         // 新增：消费者并发数  
   RetryPolicy() RetryConfig // 新增：重试策略  
}  
  
type RetryConfig struct {  
   MaxAttempts int  
   Backoff     time.Duration  
}  
  
// 示例处理器改造  
type SampleHandler struct {  
   topic       string  
   group       string  
   concurrency int  
   retryConfig RetryConfig  
}  
  
func NewSampleHandler(topic, group string, concurrency int) *SampleHandler {  
   return &SampleHandler{  
      topic:       topic,  
      group:       group,  
      concurrency: concurrency,  
      retryConfig: RetryConfig{MaxAttempts: 3, Backoff: 1 * time.Second},  
   }  
}  
  
// 实现新增方法  
func (h *SampleHandler) ConsumerGroup() string    { return h.group }  
func (h *SampleHandler) Concurrency() int         { return h.concurrency }  
func (h *SampleHandler) RetryPolicy() RetryConfig { return h.retryConfig }  
  
type ConsumerFactory struct {  
   producer  sarama.SyncProducer  
   consumers map[string][]sarama.ConsumerGroup // Key格式：group+topic  
   configs   map[string]*sarama.Config         // 不同消费者组的配置  
   handlers  map[string]MessageHandler         // 不同消费者组的处理器  
}  
  
func NewConsumerFactory() *ConsumerFactory {  
   return &ConsumerFactory{  
      consumers: make(map[string][]sarama.ConsumerGroup),  
      configs:   make(map[string]*sarama.Config),  
      handlers:  make(map[string]MessageHandler),  
   }  
}  
  
// 获取处理器实例  
func (f *ConsumerFactory) getHandlerByKey(groupKey string) MessageHandler {  
   return f.handlers[groupKey] // 从映射表中直接查找  
}  
  
// 注册处理器时创建多个消费者实例  
func (f *ConsumerFactory) RegisterHandler(handler MessageHandler, baseConfig *sarama.Config) error {  
   // 生成消费者组唯一标识  
   groupKey := fmt.Sprintf("%s-%s", handler.ConsumerGroup(), handler.Topic())  
   f.handlers[groupKey] = handler  
  
   // 克隆基础配置并设置组参数  
   config := sarama.Config{}  
   err := copier.Copy(&config, &baseConfig)  
   if err != nil {  
      return err  
   }  
   config.Consumer.Group.Session.Timeout = SessionTimeout  
   config.Consumer.Group.Rebalance.Timeout = 60 * time.Second  
  
   client, err := sarama.NewClient([]string{Brokers}, &config)  
   if err != nil {  
      return fmt.Errorf("failed to create client: %v", err)  
   }  
  
   // 创建指定数量的消费者实例  
   var consumers []sarama.ConsumerGroup  
   for i := 0; i < handler.Concurrency(); i++ {  
      consumer, err := sarama.NewConsumerGroupFromClient(handler.ConsumerGroup(), client)  
      if err != nil {  
         return fmt.Errorf("failed to create consumer: %v", err)  
      }  
      consumers = append(consumers, consumer)  
   }  
  
   f.consumers[groupKey] = consumers  
   f.configs[groupKey] = &config  
   return nil  
}  
  
// 消费者处理器  
type ConsumerHandler struct {  
   handler    MessageHandler  
   producer   sarama.SyncProducer  
   dlqTopic   string  
   retryTopic string  
}  
  
func (h *ConsumerHandler) Setup(sess sarama.ConsumerGroupSession) error {  
   log.Printf("Consumer setup for topic %s", h.handler.Topic())  
   return nil  
}  
  
func (h *ConsumerHandler) Cleanup(sess sarama.ConsumerGroupSession) error {  
   log.Printf("Consumer cleanup for topic %s", h.handler.Topic())  
   return nil  
}  
  
func (h *ConsumerHandler) ConsumeClaim(sess sarama.ConsumerGroupSession, claim sarama.ConsumerGroupClaim) error {  
   for msg := range claim.Messages() {  
      ctx, cancel := context.WithTimeout(context.Background(), MaxProcessingTime)  
  
      retryCount := getRetryCount(msg)  
      if retryCount >= h.handler.RetryPolicy().MaxAttempts {  
         h.sendToDLQ(msg)  
         sess.MarkMessage(msg, "")  
         cancel()  
         continue  
      }  
  
      if err := h.handler.Handle(ctx, msg); err != nil {  
         h.retryWithBackoff(msg, retryCount, h.handler.RetryPolicy().Backoff)  
      }  
      sess.MarkMessage(msg, "")  
      cancel()  
   }  
   return nil  
}  
  
func (h *ConsumerHandler) retryWithBackoff(msg *sarama.ConsumerMessage, attempt int, backoff time.Duration) {  
   select {  
   case <-time.After(backoff * time.Duration(attempt)):  
      h.retryMessage(msg, attempt)  
   case <-context.Background().Done():  
      return  
   }  
}  
  
// 重试逻辑  
func (h *ConsumerHandler) retryMessage(msg *sarama.ConsumerMessage, currentRetry int) {  
   var headers []sarama.RecordHeader  
   for _, h := range msg.Headers {  
      headers = append(headers, *h)  
   }  
   newMsg := &sarama.ProducerMessage{  
      Topic: msg.Topic,  
      Key:   sarama.ByteEncoder(msg.Key),  
      Value: sarama.ByteEncoder(msg.Value),  
      Headers: append(headers, sarama.RecordHeader{  
         Key:   []byte(RetryHeaderKey),  
         Value: []byte{byte(currentRetry + 1)},  
      }),  
   }  
  
   if _, _, err := h.producer.SendMessage(newMsg); err != nil {  
      log.Printf("Failed to retry message: %v", err)  
   }  
}  
  
// 死信队列处理  
func (h *ConsumerHandler) sendToDLQ(msg *sarama.ConsumerMessage) error {  
   var headers []sarama.RecordHeader  
   for _, h := range msg.Headers {  
      headers = append(headers, *h)  
   }  
   dlqMsg := &sarama.ProducerMessage{  
      Topic: h.dlqTopic,  
      Key:   sarama.ByteEncoder(msg.Key),  
      Value: sarama.ByteEncoder(msg.Value),  
      Headers: append(headers, sarama.RecordHeader{  
         Key:   []byte("original_topic"),  
         Value: []byte(msg.Topic),  
      }),  
   }  
  
   _, _, err := h.producer.SendMessage(dlqMsg)  
   return err  
}  
  
// 获取重试次数  
func getRetryCount(msg *sarama.ConsumerMessage) int {  
   for _, hdr := range msg.Headers {  
      if string(hdr.Key) == RetryHeaderKey {  
         return int(hdr.Value[0])  
      }  
   }  
   return 0  
}  
  
func (h *SampleHandler) Handle(ctx context.Context, msg *sarama.ConsumerMessage) error {  
   log.Printf("开始消费分区范围: %+v", msg)  
   log.Printf("处理分区 %d 的消息: msg.key: %+v, msg.value: %s \n", msg.Partition, string(msg.Key), string(msg.Value))  
   log.Print("分区消费结束 ===== ")  
   return nil  
}  
  
func (h *SampleHandler) Topic() string {  
   return h.topic  
}  
  
func main() {  
   // 初始化配置  
   config := sarama.NewConfig()  
   config.Version = sarama.V2_8_0_0  
   config.Consumer.Offsets.Initial = sarama.OffsetOldest  
   config.Producer.Return.Successes = true  
  
   // 初始化生产者  
   producer, err := sarama.NewSyncProducer([]string{Brokers}, config)  
   if err != nil {  
      log.Fatalf("Failed to create producer: %v", err)  
   }  
   defer producer.Close()  
  
   // 创建多个独立消费者组  
   handlers := []MessageHandler{  
      NewSampleHandler("orders", "order-group", 3),     // 订单Topic，3个消费者  
      NewSampleHandler("payments", "payment-group", 2), // 支付Topic，2个消费者  
   }  
  
   // 创建消费者工厂  
   factory := NewConsumerFactory()  
   for _, handler := range handlers {  
      if err := factory.RegisterHandler(handler, config); err != nil {  
         log.Fatal(err)  
      }  
   }  
  
   // 启动所有消费者组  
   for groupKey, consumers := range factory.consumers {  
      for _, consumer := range consumers {  
         go func(c sarama.ConsumerGroup, h MessageHandler) {  
            handler := &ConsumerHandler{  
               handler:    h,  
               producer:   factory.producer,  
               dlqTopic:   h.Topic() + DLQTopicSuffix,  
               retryTopic: h.Topic(),  
            }  
            for {  
               if err := c.Consume(context.Background(), []string{h.Topic()}, handler); err != nil {  
                  log.Printf("[%s] 消费者异常: %v", h.ConsumerGroup(), err)  
               }  
            }  
         }(consumer, factory.getHandlerByKey(groupKey))  
      }  
   }  
  
   // 信号处理  
   sigchan := make(chan os.Signal, 1)  
   signal.Notify(sigchan, syscall.SIGINT, syscall.SIGTERM)  
   <-sigchan  
   log.Println("Shutting down consumers...")  
}
```