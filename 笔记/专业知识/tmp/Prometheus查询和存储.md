## Reference

- https://mp.weixin.qq.com/s?__biz=MzkxMDUzMzI5Mg==&mid=2247483716&idx=1&sn=83fbb4395ac6898ca813c9b2966291f3&chksm=c0331582fd851b09ba2f19c048b0c8d0bb7231af2ffe12b796da3a031b306dcd5170300c1732#rd
- https://www.timescale.com/blog/how-prometheus-querying-works-and-why-you-should-care

不同开源项目的存储架构：

- https://blog.csdn.net/qq_33589510/article/details/130455868
- https://github.com/VictoriaMetrics/VictoriaMetrics/issues/3268
- star !!! https://blog.51cto.com/u_16213702/10533915
- https://docs.google.com/presentation/d/13kZ3W4CMz5WOuziNMGJ8okzPU6OHisqD4_pKXIcF5Z8/edit#slide=id.geadb6e000c_0_919
- https://www.cnblogs.com/alchemystar/p/14462052.html

## Question

1. 数据存储结构是怎样的？
2. block、series、chunk、样本数据（sample） 分别是什么，存储结构是怎样的？
3. block、series、chunk 之间的关系是怎样的？
4. 查询指标的过程是怎样的？
5. 一个block包含多少series？
6. 一个series包含多少chunk？
7. 一个chunk 包含多少 series？
8. series 如何确定唯一性？
9. 查询过程如何体现在源码中？
10. block 的 index 结构是怎样的？

## 定义

- WAL：Write-Ahead-Log，预写日志，数据库系统中常见的一种手段，用于保证数据操作的原子性和持久性
- 倒排索引：倒排索引是实现“单词-文档矩阵”的一种具体存储形式，通过倒排索引，可以根据单词快速获取包含这个单词的文档列表。**倒排索引主要由两个部分组成：“单词词典”和“倒排文件”** https://blog.csdn.net/qq_43403025/article/details/114779166


## 查询流程图

目的：分析一个query请求的整个流程

前置知识：
- 建议先讲prometheus的存储结构[[Prometheus查询和存储#存储结构]]了解之后，再去理解代码，会易懂很多，按照存储的设计原理，对照代码逻辑看； 

流程大体逻辑：
- 
从 query 或 query_range 接口分析

``` go
// web/api/v1/api.go
r.Get("/query_range", wrapAgent(api.queryRange))


```

## 存储结构

查看prometheus 存储路径下的文件结构；如果你是手动编译的prometheus，并且没有制定存储路径，则默认存储在当前可执行文件下的 data 目录中

``` bash
tree .
.
├── 01JNZ7Q3HVHAJMXQK923KMFTFY
│   ├── chunks
│   │   └── 000001
│   ├── index
│   ├── meta.json
│   └── tombstones
├── chunks_head
│   ├── 000037
│   └── 000038
├── lock
├── queries.active
└── wal
    ├── 00000036
    ├── 00000037
    ├── 00000038
    └── checkpoint.00000035
        └── 00000000
```

可以看到，其文件结构大致分为两个层级，先对上述的层级有一个概念：
- Block 块：
	- Block 块 ID：01JNZ7Q3HVHAJMXQK923KMFTFY（ULID[[分布式ID#ULID]]）
	- **Block 作用**：存储历史时间序列数据，按时间（每两小时）分割的独立存储单元。
	- ​**chunks**：存放实际采样数据的块文件（如`000001`），每个块包含连续时间戳的数据，也就是一系列的 series
		- chunk 结构：
			- **series ref**：唯一标识时间线，由文件series ID 和偏移量组成，用于区分不同的 series和快速索引样本数据的位置
			- ​**mintime/maxtime**：记录该 chunk 的时间范围
			- ​**data**：存储压缩后的样本数据（如 `[(t1, v1), (t2, v2), ...]`）
	- ​**index**：索引文件，记录标签到数据块的反向映射，支持快速查询
	- ​**meta.json**：元数据文件，包含块的时间范围、校验和等信息
	- ​**tombstones**：墓碑文件，标记已删除的时间序列，用于数据清理
- Head Block（chunks_head）：
	- 存储内存中尚未持久化的最新数据块，采用LRU策略定期刷盘
- Lock：文件锁
- WAL：
	- 预写日志，记录内存中待持久化的数据变更，防止进程崩溃导致数据丢失
	- **检查点（Checkpoint）​**：`checkpoint.00000035`文件，定期生成内存数据的快照，加速恢复
- queries.active：
	- 活跃查询管理，记录当前正在执行的PromQL查询，用于资源管理和超时控制

总结一下：
- prometheus使用分块存储，每两小时一个Block，目录名为block id（ULID，有序），Block 有多个文件，用于索引index、记录块信息 meta、存放实际的时序数据 chunks、WAL；
- chunks 也是由多个chunk文件组成，每个文件默认为 512MB 大小，超过则切分；
- WAL 则是写入chunk之前需要做的预写日志操作；
- 其他的文件格式，在下面的查询流程中详细介绍

![image.png](https://happychan.oss-cn-shenzhen.aliyuncs.com/picgo/20250312202727.png)


## 查询流程
### 定位 block
在大概认识了prometheus的存储结构后，下面从一个PromQL的例子讲解，Prometheus是如何查询指标数据的；

PromQL `(http_requests{job=api-server,instance=0}) 时间范围 [start, end]`
根据上面介绍的存储文件结构，可以知道，我们要查询这个PromQL 满足的所有数据，需要分层级查找，block => chunk = > series => sample，首先根据时间范围查询对应的block，block块的meta.json文件存储了每个块中数据的时间范围，遍历即可找到对应的block

![image.png](https://happychan.oss-cn-shenzhen.aliyuncs.com/picgo/20250312203458.png)

然后，根据 block 的索引文件（index），判断数据存在哪些chunk中
### index 文件结构
``` bash
+------------+--------------+
| magic (4B) | version (1B) |
+------------+--------------+
|          Symbols          |
+---------------------------+
|           Series          |
+---------------------------+
|        LabelIndices       |
+---------------------------+
|          Postings         |
+---------------------------+
|     LabelIndicesTable     |
+---------------------------+
|       PostingsTable       |
+---------------------------+
|            TOC            |
+---------------------------+
```
``
字段含义：
1、​Symbol Tables

> 符号表，用于优化标签存储和索引效率的核心结构；将 lable 的 key 和 value 等字符串按照字典序排序，然后映射为唯一的数字标识符ID（以Block块为单位）

结构：
- `len`：符号总数
- `#symbols`：符号数量
- 后续为每个符号的`len`（长度）和`str`（字节数据），最后通过CRC32校验完整性

例如：`job`、`prometheus`、`node-exporter` 等字符串分配唯一 ID，`job` → 1，`prometheus` → 2，`node-exporter` → 3，然后查询和存储时，都使用ID来进行代替
具体作用：
- 字符串符号化，减少存储冗余
- ​加速查询时的字符串匹配，不需要比较字符串，只需判断ID是否相等
- 支持索引结构的紧凑存储，将长字符串转为ID，可以压缩存储体积

2、Series

> 记录每个时间序列的元数据，包括标签、时间范围（`mint`/`maxt`）及对应的chunk文件引用信息

结构：
- `len`：序列总长度
- `labels count`：标签对数量
- 后续为每个标签对的`ref`（符号表索引），标签名和标签值通过符号表索引定位
- `chunks count`：所属chunk文件数量
- 每个chunk的元数据包括：
    - `mint`（起始时间戳）、`maxt`（结束时间戳）、`chunk size`
    - `ref`（chunk文件在磁盘中的偏移量）

3、LabelIndices

> 标签名到其唯一值的映射关系，支持按标签名快速查找所有可能的标签值；主要用于标签合法性校验

为方便理解，后面介绍的索引中存储的标签名和值的表现形式字符串，但实际都是存储的符号表的索引ID

**结构**：
- `name`：标签名
- `values`：该标签名下所有可能的标签值列表
例子：
``` bash
Label Key: "job"  
Label Values: ["prometheus", "node-exporter", "k8s"]  
```

4、Postings（倒排索引）

> 记录标签值组合到时间序列series的映射，支持高效查询特定标签组合下的所有时间序列

**结构**：
- `name`：标签名
- `value`：标签值
- `offset`：指向具体倒排列表的偏移量

``` bash
Label Pair: "job=prometheus AND status=200"  
Postings List: [ref(series1), ref(series2)] 
```

​5、LabelIndicesTable & PostingsTable

- ​**LabelIndicesOffsetTable**：将标签名映射到其在`LabelIndices`中的偏移量，加速标签名到索引的查找
- ​**PostingsOffsetTable**：将`(name, value)`标签组合映射到其在`Postings`中的偏移量，支持快速定位倒排列表

6、TOC 

> 目录表，存储索引文件各部分的偏移量，包括Symbol Table、Series、LabelIndices等，用于快速定位文件内容

结构：
- 固定52字节，包含各部分的偏移量（如`refSymbols`、`refSeries`等）

![image.png](https://happychan.oss-cn-shenzhen.aliyuncs.com/picgo/20250312212708.png)

### 定位 chunk和series

在了解了 index 文件的结构后，我们对其每个作用有了大体的认识，下面继续回到如何查询数据上；我们已经找到了数据所在的block，然后通过读取其 index 文件来定位 chunk；
具体流程：
1. 我们要找到 `job =～ api-server.*`的数据，会先访问TOC， 通过LabelOffsetTable 定位到 `job` 对应的值在 `labelIndies` 中的 `offset`
2. 然后根据 `labelIndies` 找到所有满足的值， 根据这些值，到 `PostingOffsetTable` 中找到这些值对应在 `Postings` 中的 `offset`，从而找到所有的满足的 series ID，取并集
3. Postings 中存储的是 `seriesid`，根据这个 `id`，遍历chunk文件，匹配 `Series Ref` 中的ID，然后根据 `Series Ref` 的偏移量，进行数据的读取

### 结合源码分析

| **概念**     | **逻辑层级** | **唯一标识**                                                                        | **数据范围**             | **存储内容**                                                               |
| ---------- | -------- | ------------------------------------------------------------------------------- | -------------------- | :--------------------------------------------------------------------- |
| **Block**  | 物理存储单元   | ULID（Universally Unique Lexicographically Sortable Identifier）                  | 固定时间段（默认2小时）         | 包含 `chunks/`（数据文件）、`index`（倒排索引）、`meta.json`（元数据）、`tombstones`（逻辑删除标记） |
| **Series** | 逻辑时间序列单元 | Metric名称 + 标签键值对集合（如 `http_requests_total{method="GET", instance="localhost"}`） | 所有时间（动态增长）           | 属于同一逻辑序列的所有样本数据（可能分散在多个 Block 的 Chunk 中）                               |
| **Chunk**  | 物理数据片段   | Series 标识 + 时间范围（如 `01G7Z74ZPB79Z5Z1D234567890_000001`）                         | 固定时间段（默认2小时，可通过配置调整） | 单个 Series 的连续时间样本数据（压缩格式，如Snappy）                                      |
| **Sample** | 样本数据     | value 某个具体的值                                                                    | 根据值类型来定义范围           | 指标在这个时间点的具体值                                                           |










