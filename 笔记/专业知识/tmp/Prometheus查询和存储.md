## Reference

- https://cloud.tencent.com/developer/article/2363771?areaId=106005
- https://mp.weixin.qq.com/s?__biz=MzkxMDUzMzI5Mg==&mid=2247483716&idx=1&sn=83fbb4395ac6898ca813c9b2966291f3&chksm=c0331582fd851b09ba2f19c048b0c8d0bb7231af2ffe12b796da3a031b306dcd5170300c1732#rd
- https://www.timescale.com/blog/how-prometheus-querying-works-and-why-you-should-care

不同开源项目的存储架构：

- https://blog.csdn.net/qq_33589510/article/details/130455868
- https://github.com/VictoriaMetrics/VictoriaMetrics/issues/3268

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

## 定义

- WAL：Write-Ahead-Log，预写日志，数据库系统中常见的一种手段，用于保证数据操作的原子性和持久性
- 倒排索引：倒排索引是实现“单词-文档矩阵”的一种具体存储形式，通过倒排索引，可以根据单词快速获取包含这个单词的文档列表。**倒排索引主要由两个部分组成：“单词词典”和“倒排文件”** https://blog.csdn.net/qq_43403025/article/details/114779166



## 存储结构

以下是按照 **“概念、逻辑层级、唯一标识、数据范围、存储内容”** 维度总结的 Prometheus 存储结构核心组件，以 Markdown 表格形式呈现：

| **概念**   | **逻辑层级**     | **唯一标识**                                                 | **数据范围**                            | **存储内容**                                                 |
| ---------- | ---------------- | ------------------------------------------------------------ | --------------------------------------- | :----------------------------------------------------------- |
| **Block**  | 物理存储单元     | ULID（Universally Unique Lexicographically Sortable Identifier） | 固定时间段（默认2小时）                 | 包含 `chunks/`（数据文件）、`index`（倒排索引）、`meta.json`（元数据）、`tombstones`（逻辑删除标记） |
| **Series** | 逻辑时间序列单元 | Metric名称 + 标签键值对集合（如 `http_requests_total{method="GET", instance="localhost"}`） | 所有时间（动态增长）                    | 属于同一逻辑序列的所有样本数据（可能分散在多个 Block 的 Chunk 中） |
| **Chunk**  | 物理数据片段     | Series + 时间范围（如 `01G7Z74ZPB79Z5Z1D234567890_000001`）  | 固定时间段（默认2小时，可通过配置调整） | 单个 Series 的连续时间样本数据（压缩格式，如Snappy）         |

---

### 关键说明

1. **Block**  
   • **唯一标识**：通过 ULID 命名，文件名前缀（如 `01G7Z74ZPB79Z5Z1D`）直接反映创建时间，便于排序和压缩。  
   • **数据范围**：默认2小时，超过则拆分，旧 Block 可通过压缩合并减少数量。  
   • **存储内容**：包含索引、元数据、逻辑删除标记等，支持高效查询和数据恢复。

2. **Series**  
   • **唯一标识**：由 Metric 名称和标签集合唯一确定，标签的任何差异均视为不同 Series。  
   • **数据范围**：动态增长，生命周期与数据保留策略（如 `retention.time`）相关。  
   • **存储内容**：逻辑上代表一个时间序列，实际数据通过 Block 的索引和 Chunk 存储。

3. **Chunk**  
   • **唯一标识**：通过 Series 标识 + 时间范围确定，文件名包含时间戳和序列号。  
   • **数据范围**：固定时间段（如2小时），超过则生成新 Chunk。  
   • **存储内容**：压缩后的样本数据（时间戳 + 值），采用可变长度编码减少存储空间。

---

### 总结

• **Block** 是物理存储单元，按时间切分数据，支持压缩和合并。  
• **Series** 是逻辑时间序列，通过标签唯一标识，数据动态增长。  
• **Chunk** 是压缩后的数据片段，属于单一 Series 的时间范围子集。  
此设计平衡了写入性能、查询效率与存储成本，适用于大规模时序数据场景。









