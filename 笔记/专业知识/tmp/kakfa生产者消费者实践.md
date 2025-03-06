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
- 多个消费者实例
``` go
package main  
  
import (  
   "context"  
   "log"   "os"   "os/signal"   "syscall"      "github.com/IBM/sarama"  
  
   "HelloGo/Kafka")  
  
type ConsumerHandler struct{}  
  
func (h *ConsumerHandler) Setup(sess sarama.ConsumerGroupSession) error {  
   log.Printf("[协程-%d] 分配到分区: %v\n", sess.MemberID(), sess.Claims()[Kafka.HappyChanTopic])  
   return nil  
}  
  
func (h *ConsumerHandler) Cleanup(sess sarama.ConsumerGroupSession) error {  
   log.Println("消费者组会话已结束")  
   return nil  
}  
  
func (h *ConsumerHandler) ConsumeClaim(sess sarama.ConsumerGroupSession, claim sarama.ConsumerGroupClaim) error {  
   log.Printf("开始消费分区范围: %+v", claim)  
   for msg := range claim.Messages() {  
      log.Printf("处理分区 %d 的消息: msg.key: %+v, msg.value: %s \n", msg.Partition, string(msg.Key), string(msg.Value))  
      sess.MarkMessage(msg, "")  
   }  
   log.Print("分区消费结束 ===== ")  
   return nil  
}  
  
func main() {  
   config := sarama.NewConfig()  
   config.Version = sarama.V2_8_0_0  
   config.Consumer.Offsets.AutoCommit.Enable = true      // 启用自动提交（默认true）  
   config.Consumer.Offsets.Initial = sarama.OffsetOldest // 从最早Offset开始消费（默认最新）  
   // 同一消费者组  
   groupID := "multi-consumer-group"  
   topics := []string{Kafka.HappyChanTopic}  
   brokers := []string{Kafka.Brokers}  
  
   // 创建多个消费者协程  
   consumerCount := 4 // 与目标实例数一致  
   for i := 0; i < consumerCount; i++ {  
      go func(id int) {  
         consumer, err := sarama.NewConsumerGroup(brokers, groupID, config)  
         if err != nil {  
            panic(err)  
         }  
         defer consumer.Close()  
  
         handler := &ConsumerHandler{}  
         ctx := context.Background()  
         for {  
            select {  
            case <-ctx.Done():  
               log.Printf("消费者 %d 退出", id)  
               return  
            default:  
               if err := consumer.Consume(ctx, topics, handler); err != nil {  
                  log.Printf("消费者 %d 错误: %v", id, err)  
               }  
            }  
         }  
      }(i)  
   }  
  
   // 阻塞主协程  
   sigchan := make(chan os.Signal, 1)  
   signal.Notify(sigchan, syscall.SIGINT, syscall.SIGTERM)  
   <-sigchan  
}
```