## Reference

- https://go.cyub.vip/concurrency/sync-map/
- https://developer.aliyun.com/article/1172753

## 数据结构

```go
type Map struct {
    mu      Mutex     // 保护dirty map的互斥锁
    read    atomic.Value // 原子化只读map（底层是readOnly结构）
    dirty   map[interface{}]*entry // 写操作专用map
    misses  int        // read未命中次数统计
}

type readOnly struct {
    m       map[interface{}]*entry // 实际存储数据的只读map
    amended bool      // 标记dirty是否包含read未同步的新数据
}

type entry struct {
    p unsafe.Pointer // 指向值的指针（nil：已删除；expunged：已标记删除但存在于dirty）
}

var expunged = new(any)
```

## 核心原理

1. **读写分离**
   - **read map**：只读，支持原子操作，无锁读取
   - **dirty map**：写操作专用，需加锁，保存最新数据
2. **两级缓存机制**
   - 优先从`read`读取，未命中且`amended=true`时加锁读取`dirty`
   - `amended`标记`read`与`dirty`数据不一致
3. **延迟删除**
   - 删除操作仅标记`entry.p=nil`或`expunged`
   - 实际删除在`dirty`提升为`read`时批量清理
4. **动态升级机制**
   - 当`misses == len(dirty)`时，将`dirty`整体升级为`read`，重置`misses`和`amended`

## 关键结构

amended 的作用：

- 标记 dirty map 是否包含 read map 中没有的键
- 当它为 true 时，查找操作需要检查 dirty map

expunged 的作用和生命周期：

- 特殊标记，表示条目已从 dirty map 中删除但仍在 read 中
- 生命周期： 
  - 第一次删除：将 p 置为 nil 
  - 创建新 dirty 时：将 nil 变为 expunged
  - 再次存储时：需要先将 expunged 恢复为 nil

entry 是 sync.Map 的核心数据结构，包含三种状态：

- p = nil: 条目已被删除
- p = expunged: 条目已从 dirty map 删除
- p = 正常值: 条目有效

## 核心特点

|      特性      |                描述                 |
| :------------: | :---------------------------------: |
|  **适用场景**  |   读多写少（官方推荐读写比>1:1）    |
|   **锁粒度**   |       写操作加锁，读操作无锁        |
| **空间换时间** |  维护两个map，牺牲内存换取并发性能  |
| **原子性操作** |       读操作通过CAS保证原子性       |
|  **延迟回收**  | 删除操作延迟到`dirty`提升时批量处理 |

## 关键优化点

1. **原子性更新**
   - `tryStore()`通过CAS保证更新原子性
   - `unexpungeLocked()`清理expunged标记
2. **惰性删除**
   - 删除操作仅标记，避免频繁map操作
   - 实际删除在`dirty`→`read`升级时批量处理
3. **读优化**
   - `read` map始终保存有效数据（除已标记删除）
   - `misses`阈值触发自动升级，减少后续锁竞争

## 总结

- sync.Map是不能值传递（狭义的）的
- sync.Map采用空间换时间策略。其底层结构存在两个map，分别是read map和dirty map。当读取操作时候，优先从read map中读取，是不需要加锁的，若key不存在read map中时候，再从dirty map中读取，这个过程是加锁的。当新增key操作时候，只会将新增key添加到dirty map中，此操作是加锁的，但不会影响read map的读操作。当更新key操作时候，如果key已存在read map中时候，只需无锁更新更新read map就行，负责加锁处理在dirty map中情况了。总之sync.Map会优先从read map中读取、更新、删除，因为对read map的读取不需要锁
- 当sync.Map读取key操作时候，若从read map中一直未读到，若dirty map中存在read map中不存在的keys时，则会把dirty map升级为read map，这个过程是加锁的。这样下次读取时候只需要考虑从read map读取，且读取过程是无锁的
- 延迟删除机制，删除一个键值时只是打上删除标记，只有在提升dirty map为read map的时候才清理删除的数据
- sync.Map中的dirty map要么是nil，要么包含read map中所有未删除的key-value。
- sync.Map适用于读多写少场景。根据 [包官方文档介绍](https://golang.org/pkg/sync/#Map)，它特别适合这两个场景：1. 一个key只写入一次但读取多次时，比如在只会增长的缓存中；2. 当多个goroutine读取、写入和更新不相交的键值对时。