
本文档整理了关于 VictoriaMetrics 中 `downsampling.period` 的实现逻辑、Part Merge 流程以及底层 LSM Tree 存储结构的详细分析。

## 1. `downsampling.period` 实现���辑

`downsampling.period` 是 VictoriaMetrics 企业版用于配置多级降采样（Downsampling）的功能。虽然核心逻辑位于企业版代码中，但结合开源版本的架构与 `dedup`（去重）机制，其实现原理如下：

### 核心机制：寄生于 Merge 过程
降采样并非独立的后台进程，而是**寄生于 LSM Tree 的 Merge（合并）过程**中。当存储引擎将多个旧的 `part`（数据块）合并为一个新 `part` 时，系统会利用这一时机处理数据，从而避免了额外的读取开销。

### 具体执行流程
1.  **配置解析**：
    *   启动时解析参数（如 `-downsampling.period=30d:5m,180d:1h`）。
    *   生成规则链：`{Offset: 30d, Interval: 5m}`, `{Offset: 180d, Interval: 1h}`。

2.  **触发点**：
    *   位于 `lib/storage/block_stream_writer.go` 的 `WriteExternalBlock` 方法。
    *   在数据块（Block）写入磁盘前，调用 `b.deduplicateSamplesDuringMerge()`。

3.  **执行逻辑 (在 `deduplicateSamplesDuringMerge` 中)**：
    *   **时间窗口判断**：计算样本年龄（`Now - Timestamp`）。
    *   **规则匹配**：
        *   若 `年龄 > 180d`，采用 `1h` 间隔。
        *   若 `180d > 年龄 > 30d`，采用 `5m` 间隔。
        *   否则，使用默认去重配置或保持原样。
    *   **去重/降采样**：
        *   基于选定的 `Interval` 对时间戳进行对齐（`Timestamp -= Timestamp % Interval`）。
        *   采用 `Last-Write-Wins` 策略，保留同一时间窗口内的最后一个样本。

**总结**：`downsampling.period` 本质上是一种**分级、动态间隔的 Deduplication**，利用存储引擎必然发生的 Merge 操作实现零成本降采样。

---

## 2. Part Merge 逻辑

VictoriaMetrics 的存储引擎采用类似 LSM Tree 的结构，数据被组织为 `part`。Merge 逻辑负责维护这些文件，提升查询效率并执行数据清理。

### 代码位置
*   `lib/storage/partition.go`: 管理 Part 生命周期和 Merge 任务调度。
*   `lib/storage/merge.go`: 执行流式合并的核心算法。

### Merge 流程详解
1.  **后台 Worker**：
    *   系统启动三类 Merger 协程，分别处理：内存 Parts (`inmemoryPartsMerger`)、磁盘小 Parts (`smallPartsMerger`)、磁盘大 Parts (`bigPartsMerger`)。

2.  **Part 选择策略 (`getPartsToMerge`)**：
    *   **筛选**：排除正在合并中的 parts。
    *   **排序**：按大小和时间排序。
    *   **算法**：寻找一组连续的 parts，目标是使合并后的输出大小适中，且输入 parts 大小差异不大（减少写放大）。默认尝试一次合并 15 个 parts。

3.  **流式合并 (`mergeBlockStreams`)**：
    *   **多路归并**：同时打开所有源 parts 的读取流，按时间序（TSID + Timestamp）进行归并。
    *   **处理重叠**：若多个 parts 包含同一时间序列，调用 `mergeBlocks` 合并数据点，通常保留最新数据。
    *   **应用 Retention**：在此阶段直接丢弃超出 `-retentionPeriod` 的数据。

4.  **写入新 Part (`WriteExternalBlock`)**：
    *   合并后的数据通过 `blockStreamWriter` 写入。
    *   **关键点**：在此处调用 `deduplicateSamplesDuringMerge()` 执行去重和降采样。
    *   数据被压缩并写入新目录（包含 `values.bin`, `timestamps.bin`, `index.bin` 等）。

5.  **原子替换 (`swapSrcWithDstParts`)**：
    *   新 part 写入完成后，加锁更新 part 列表。
    *   移除旧的源 parts 并标记为 `mustDrop`，待查询引用计数归零后物理删除。

---

## 3. LSM Tree (Log-Structured Merge-tree) 概念解析

LSM Tree 是 VictoriaMetrics、RocksDB、HBase 等现代高吞吐数据库的核心存储结构。

### 核心理念：顺序写 vs 随机写
*   **传统 B+ 树**：像“图书馆归位”，新数据必须插入特定位置，导致大量随机 I/O，写入慢，读取快。
*   **LSM Tree**：像“记事本暂存”，新数据追加写入（Append-only），利用顺序 I/O 极大提升写入性能，通过后台合并整理数据。

### 三层结构
1.  **MemTable（内存表）**：
    *   内存中的有序结构（跳表/红黑树）。
    *   接收所有新写入，速度极快。
    *   配有 WAL (Write Ahead Log) 防止断电丢失。
2.  **Immutable MemTable（不可变内存表）**：
    *   MemTable 写满后转变为不可变状态，准备刷盘。
3.  **SSTable（Sorted String Table，磁盘文件）**：
    *   磁盘上的有序文件，不可变。
    *   分层存储（Leveling），层级越高数据越旧。

### Compaction（合并）
即 VictoriaMetrics 中的 **Merge** 过程。
*   **目的**：解决追加写导致的读放大（数据分散在多处）和空间浪费（重复/删除的数据）。
*   **过程**：读取多个 SSTable -> 归并排序 -> 去重/清理 -> 写入新 SSTable -> 删除旧文件。
*   **VM 的优化**：VictoriaMetrics 在此步骤中“夹带私货”，执行了降采样逻辑。

### 读写特性
*   **写入**：写 WAL -> 写 MemTable -> 结束。极快。
*   **读取**：查 MemTable -> 查 Immutable MemTable -> 一层层查 SSTable（配合 Bloom Filter 加速）。

**总结**：LSM Tree 是一种**用读取性能换取写入性能**的设计，特别适合监控、日志等���入量巨大的场景。
