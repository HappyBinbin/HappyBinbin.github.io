# 引入xxl-job处理活动状态扫描

- 分支：20220313_happy_xxl-job
- 描述：引入XXL-JOB，分布式任务调度平台，处理需要使用定时任务解决的场景。

## 开发日志

- 搭建 XXL-JOB 分布式任务调度环境，这里需要在官网：https://github.com/xuxueli/xxl-job/ 下载运行包，按照 Java SpringBoot 修改一些基本配置，项目启动即可。
- 配置 XXL-JOB 的基础使用环境，导入库表、配置文件、验证官网管理，测试任务启动运行
- 解决第一个分布式任务场景问题，扫描抽奖活动状态，把审核通过的活动扫描为活动中，把已过期活动中的状态扫描为关闭。后续章节我们还会使用分布式任务调度系统解决其他场景问题。

## 搭建分布式任务调度环境

https://www.xuxueli.com/xxl-job/ 

参考官网的教程即可

### 注意点

1. 启动前检查好 application.properties 中的端口号
2. 确保数据库表已经初始化完成，并修改 application.properties 中数据库链接信息
3. 修改 logback.xml 日志打印目录，否则日志找不到会报错

## 任务扫描活动状态

### 引入 POM

```xml
<!-- xxl-job-core https://github.com/xuxueli/xxl-job/-->
<dependency>
    <groupId>com.xuxueli</groupId>
    <artifactId>xxl-job-core</artifactId>
    <version>2.3.0</version>
</dependency>
```

- 把需要使用 xxl-job 的包，引入对应的 POM 配置

### 配置 application.yml

```yaml
# xxl-job
# 官网：https://github.com/xuxueli/xxl-job/
# 地址：http://localhost:7397/xxl-job-admin 【需要先启动 xxl-job】
# 账号：admin
# 密码：123456
xxl:
  job:
    admin:
      addresses: http://127.0.0.1:7397/xxl-job-admin
    executor:
      address:
      appname: lottery-job
      ip:
      port: 9999
      logpath: /data/applogs/xxl-job/jobhandler
      logretentiondays: 50
    accessToken:
```

### 任务初始类

```java
@Configuration
public class LotteryXxlJobConfig {

    private Logger logger = LoggerFactory.getLogger(LotteryXxlJobConfig.class);

    @Value("${xxl.job.admin.addresses}")
    private String adminAddresses;

    @Value("${xxl.job.accessToken}")
    private String accessToken;

    @Value("${xxl.job.executor.appname}")
    private String appname;

    @Value("${xxl.job.executor.address}")
    private String address;

    @Value("${xxl.job.executor.ip}")
    private String ip;

    @Value("${xxl.job.executor.port}")
    private int port;

    @Value("${xxl.job.executor.logpath}")
    private String logPath;

    @Value("${xxl.job.executor.logretentiondays}")
    private int logRetentionDays;

    @Bean
    public XxlJobSpringExecutor xxlJobExecutor() {
        logger.info(">>>>>>>>>>> xxl-job config init.");

        XxlJobSpringExecutor xxlJobSpringExecutor = new XxlJobSpringExecutor();
        xxlJobSpringExecutor.setAdminAddresses(adminAddresses);
        xxlJobSpringExecutor.setAppname(appname);
        xxlJobSpringExecutor.setAddress(address);
        xxlJobSpringExecutor.setIp(ip);
        xxlJobSpringExecutor.setPort(port);
        xxlJobSpringExecutor.setAccessToken(accessToken);
        xxlJobSpringExecutor.setLogPath(logPath);
        xxlJobSpringExecutor.setLogRetentionDays(logRetentionDays);

        return xxlJobSpringExecutor;
    }

    /**********************************************************************************************
     * 针对多网卡、容器内部署等情况，可借助 "spring-cloud-commons" 提供的 "InetUtils" 组件灵活定制注册IP；
     *
     *      1、引入依赖：
     *          <dependency>
     *             <groupId>org.springframework.cloud</groupId>
     *             <artifactId>spring-cloud-commons</artifactId>
     *             <version>${version}</version>
     *         </dependency>
     *
     *      2、配置文件，或者容器启动变量
     *          spring.cloud.inetutils.preferred-networks: 'xxx.xxx.xxx.'
     *
     *      3、获取IP
     *          String ip_ = inetUtils.findFirstNonLoopbackHostInfo().getIpAddress();
     **********************************************************************************************/

}
```

- 这里需要启动一个任务执行器，通过配置 @Bean 对象的方式交给 Spring 进行管理

### 开发任务扫描活动

```java
@Component
public class LotteryXxlJob {

    private Logger logger = LoggerFactory.getLogger(LotteryXxlJob.class);

    @Resource
    private IActivityDeploy activityDeploy;

    @Resource
    private IStateHandler stateHandler;

    @XxlJob("lotteryActivityStateJobHandler")
    public void lotteryActivityStateJobHandler() throws Exception {
        logger.info("扫描活动状态 Begin");

        List<ActivityVO> activityVOList = activityDeploy.scanToDoActivityList(0L);
        if (activityVOList.isEmpty()){
            logger.info("扫描活动状态 End 暂无符合需要扫描的活动列表");
            return;
        }

        while (!activityVOList.isEmpty()) {
            for (ActivityVO activityVO : activityVOList) {
                Integer state = activityVO.getState();
                switch (state) {
                        // 活动状态为审核通过，在临近活动开启时间前，审核活动为活动中。在使用活动的时候，需要依照活动状态核时间两个字段进行判断和使用。
                    case 4:
                        Result state4Result = stateHandler.doing(activityVO.getActivityId(), Constants.ActivityState.PASS);
                        logger.info("扫描活动状态为活动中 结果：{} activityId：{} activityName：{} creator：{}", JSON.toJSONString(state4Result), activityVO.getActivityId(), activityVO.getActivityName(), activityVO.getCreator());
                        break;
                        // 扫描时间已过期的活动，从活动中状态变更为关闭状态
                    case 5:
                        if (activityVO.getEndDateTime().before(new Date())){
                            Result state5Result = stateHandler.close(activityVO.getActivityId(), Constants.ActivityState.DOING);
                            logger.info("扫描活动状态为关闭 结果：{} activityId：{} activityName：{} creator：{}", JSON.toJSONString(state5Result), activityVO.getActivityId(), activityVO.getActivityName(), activityVO.getCreator());
                        }
                        break;
                    default:
                        break;
                }
            }

            // 获取集合中最后一条记录，继续扫描后面10条记录
            ActivityVO activityVO = activityVOList.get(activityVOList.size() - 1);
            activityVOList = activityDeploy.scanToDoActivityList(activityVO.getId());
        }

        logger.info("扫描活动状态 End");

    }

}
```

在任务扫描中，主要把已经审核通过的活动和已过期的活动中状态进行变更操作；

- 审核通过 -> 扫描为活动中
- 活动中已过期时间 -> 扫描为活动关闭

### 配置抽奖系统任务调度执行器

<img src="https://gitee.com/HappyBinbin/pcigo/raw/master/image-20220313144548401.png" alt="image-20220313144548401" style="zoom:67%;" />

- 只有配置了任务执行器，才能执行当前这个实例中的任务
- 另外在有些业务体量较大的场景中，需要把任务开发为新工程并单独部署

### 配置任务

这里我们把已经开发了的任务 `LotteryXxlJob#lotteryActivityStateJobHandler` 配置到任务调度中心，如下：

<img src="https://gitee.com/HappyBinbin/pcigo/raw/master/image-20220313144628233.png" alt="image-20220313144628233" style="zoom:67%;" />

配置完成后，就可以启动任务了

## 测试验证

**准备数据**

- 确保数据库中有可以扫描的活动数据，比如可以把活动数据从活动中扫描为结束，也就是把状态5变更为7

启动任务

```java
12:35:37.175  INFO 23141 --- [Pool-1090755084] c.xxl.job.core.executor.XxlJobExecutor   : >>>>>>>>>>> xxl-job regist JobThread success, jobId:2, handler:com.xxl.job.core.handler.impl.MethodJobHandler@19a20bb2[class cn.itedus.lottery.application.worker.LotteryXxlJob#lotteryActivityStateJobHandler]
12:35:37.180  INFO 23141 --- [      Thread-18] c.i.l.application.worker.LotteryXxlJob   : 扫描活动状态，把审核通过的活动，扫描成活动中
12:35:38.013  INFO 23141 --- [      Thread-18] c.i.l.application.worker.LotteryXxlJob   : 扫描活动状态，把审核通过的活动，扫描成活动中
12:35:39.012  INFO 23141 --- [      Thread-18] c.i.l.application.worker.LotteryXxlJob   : 扫描活动状态，把审核通过的活动，扫描成活动中
12:35:40.013  INFO 23141 --- [      Thread-18] c.i.l.application.worker.LotteryXxlJob   : 扫描活动状态，把审核通过的活动，扫描成活动中
12:35:41.009  INFO 23141 --- [      Thread-18] c.i.l.application.worker.LotteryXxlJob   : 扫描活动状态，把审核通过的活动，扫描成活动中
12:35:42.012  INFO 23141 --- [      Thread-18] c.i.l.application.worker.LotteryXxlJob   : 扫描活动状态，把审核通过的活动，扫描成活动中
12:35:43.014  INFO 23141 --- [      Thread-18] c.i.l.application.worker.LotteryXxlJob   : 扫描活动状态，把审核通过的活动，扫描成活动中
12:35:44.011  INFO 23141 --- [      Thread-18] c.i.l.application.worker.LotteryXxlJob   : 扫描活动状态，把审核通过的活动，扫描成活动中
12:35:45.016  INFO 23141 --- [      Thread-18] c.i.l.application.worker.LotteryXxlJob   : 扫描活动状态，把审核通过的活动，扫描成活动中
12:35:46.012  INFO 23141 --- [      Thread-18] c.i.l.application.worker.LotteryXxlJob   : 扫描活动状态，把审核通过的活动，扫描成活动中
12:35:47.008  INFO 23141 --- [      Thread-18] c.i.l.application.worker.LotteryXxlJob   : 扫描活动状态，把审核通过的活动，扫描成活动中
```

<img src="https://gitee.com/HappyBinbin/pcigo/raw/master/image-20220313144705590.png" alt="image-20220313144705590" style="zoom:67%;" />

- 此时就已经把活动状态为5的已过期的活动，扫描为关
- 下一节我们会继续开发分布式任务调度，完成发奖数据MQ补偿处理



## 问题与思考

1. 为什么要用 xxl-job 作为分布式任务处理中心？它的特性和功能？适合什么场景？
2. 知道 xxl-job 分布式任务调度的设计和实现的原理吗，，集群配置？了解一下？
3. 课外扩展 中间件设计和开发 技术，  [SpringBoot中间件的设计和开发](https://juejin.cn/book/6940996508632219689) 





## 总结

------

1. 学习 xxl-job 的使用，如果你对这类技术的源码感兴趣，也可以阅读小傅哥关于 [SpringBoot中间件的设计和开发](https://juejin.cn/book/6940996508632219689) 这里就包括了分布式任务调度的设计和实现
2. 如果你之前还没有接触过类似分布式任务的内容，可以好好使用下，补全这部分内容。