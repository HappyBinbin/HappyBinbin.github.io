
## 概念
`context.Context` 是 Go 语言在 1.7 版本中引入标准库的接口，该接口定义了四个需要实现的方法，其中包括：

1. `Deadline` — 返回 `context.Context` 被取消的时间，也就是完成工作的截止日期；
2. `Done` — 返回一个 Channel，这个 Channel 会在当前工作完成或者上下文被取消后关闭，多次调用 `Done` 方法会返回同一个 Channel；
3. `Err` — 返回 `context.Context` 结束的原因，它只会在 `Done` 方法对应的 Channel 关闭时返回非空的值；
    1. 如果 `context.Context` 被取消，会返回 `Canceled` 错误；
    2. 如果 `context.Context` 超时，会返回 `DeadlineExceeded` 错误；
4. `Value` — 从 `context.Context` 中获取键对应的值，对于同一个上下文来说，多次调用 `Value` 并传入相同的 `Key` 会返回相同的结果，该方法可以用来传递请求特定的数据；
```go
type Context interface {
	Deadline() (deadline time.Time, ok bool)
	Done() <-chan struct{}
	Err() error
	Value(key interface{}) interface{}
}
```

## 设计目的

> 在 Goroutine 构成的树形结构中对信号进行同步以减少计算资源的浪费是 `context.Context`的最大作用

