## Reference
- https://www.tubring.cn/articles/ulid-vs-uuid


## UUID & GUID

Universally Unique Identifier，通用唯一标识符
Globally Unique Identifier，全局唯一标识符

UUID 和 GUID 通常被认为是可以互换的，但 GUID 是 Microsoft 对 UUID 的实现。它们都遵循 128 位结构，并表示为 32 个十六进制字符（例如， 550e8400-e29b-41d4-a716-446655440000 ）

优缺点：
- 全局唯一、广泛支持、几乎不可能冲突
- 非时间排序、尺寸较大（128位）
## ULID

ULID（Universally Unique Lexicographically Sortable Identifier）是一种可排序、唯一的标识符，由 Alizain Feerasta 在 2016 年提出，它结合了时间戳和随机数生成器来生成一个 32 位的标识符，适用于分布式系统中标识数据实体和事件等场景

ULID 是一种较新的标识符。它采用 128 位格式，但使用 Base32 编码为 26 个字符的字符串（例如 01AN4Z07BY79KA1307SR9X4MV3 ）。ULID 更易于阅读和输入，这对于某些应用程序来说是一个优点

优缺点：
- 可排序、可读性更强、无需协调即可生成
- 长度更长，耗费存储空间、仅限于毫秒级别的精度

# Snowflake ID

基于时间的唯一标识符生成系，可以保证分布式唯一性
组成结构：
- 41 bits for the timestamp (milliseconds since a custom epoch)
- 10 bits for machine identification
- 12 bits for a per-machine sequence number

优缺点：
- 时间有序、高性能、可扩展
- 需要集中时钟同步，漂移的系统时钟可能导致 ID 冲突
