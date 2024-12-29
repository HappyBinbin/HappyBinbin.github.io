## Reference

- https://stackoverflow.com/questions/51399407/watch-in-k8s-golang-api-watches-and-get-events-but-after-sometime-doesnt-get-an



## 问题描述

最近在使用 client-go 的 watch 机制监听 k8s 中的 deployment 资源时，发现一个奇怪的现象

先看下代码：

- 服务启动时调用 watchDeployment 新建一个 watcher 监听对应的资源
- for 循环，select 处理  watcher.ResultChan 返回的事件

```go
func WatchDeployment(ctx context.Context, namespace string, options metav1.ListOptions, handler EventHandler) error {
	watcher, err := KubeCli.AppsV1().Deployments(namespace).Watch(ctx, options)
	if err != nil {
		log.Errorf("watching deployments err: %+v", err)
		return err
	}

	defer watcher.Stop()

	// 处理事件
	for {
		select {
		case event, ok := <-watcher.ResultChan():
			if !ok {
				log.Errorf("Watcher channel closed")
				return nil
			}

			deployment, ok := event.Object.(*appsv1.Deployment)
			if !ok {
				log.Errorf("Error casting to Deployment")
				continue
			}

			switch event.Type {
			case watch.Added:
				if handler.OnAdd != nil {
					handler.OnAdd(ctx, deployment)
				}
			case watch.Modified:
				if handler.OnModify != nil {
					handler.OnModify(ctx, deployment)
				}
			case watch.Deleted:
				if handler.OnDelete != nil {
					handler.OnDelete(ctx, deployment)
				}
			}
		}
	}
}
```

在运行了一段时间后，watch 监听的通道会自动关闭，日志："ERROR	[trace-] Watcher channel closed" 

检视完代码，唯一存在问题的就是  watcher.ResultCha( ) 如果出问题，则会直接 return 导致 for 循环退出了，所以我改了第二版的代码，将 return 替换为了 continue

```go
if !ok {
    log.Errorf("Watcher channel closed")
    continue
}
```

再运行一段时间，日志疯狂报错 "ERROR	[trace-] Watcher channel closed" ；

**疑问：为什么错误已经continue了，为什么无法再继续监听了？**

## 排查过程

具体debug看下 watch 机制的源码，只展示重要流程代码，细节忽略：

```go
// watch 其实是可以设置 timeout 时间，具体用在哪，继续往下看看
func (c *deployments) Watch(ctx context.Context, opts metav1.ListOptions) (watch.Interface, error) {
	var timeout time.Duration
	if opts.TimeoutSeconds != nil {
		timeout = time.Duration(*opts.TimeoutSeconds) * time.Second
	}
	opts.Watch = true
	return c.client.Get().
		Namespace(c.ns).
		Resource("deployments").
		VersionedParams(&opts, scheme.ParameterCodec).
		Timeout(timeout).
		Watch(ctx)
}

// Timeout makes the request use the given duration as an overall timeout for the
// request. Additionally, if set passes the value as "timeout" parameter in URL.
// 这里就将timeout 设置为了 rquest 请求的超时时间
func (r *Request) Timeout(d time.Duration) *Request {
	if r.err != nil {
		return r
	}
	r.timeout = d
	return r
}
```

从 watch 可以看到，client-go 提供的 watch 方法，就是使用 net/http 发起一个 http 请求 `https://10.96.0.1:443/apis/apps/v1/namespaces/xxx/deployments?fieldSelector=metadata.name%3Dabc&watch=true`，并启用 watch 机制，成功后则返回一个  实现了 watch.Interface 这个接口的 StreamWatcher 的结构体

```go
// Watch attempts to begin watching the requested location.
// Returns a watch.Interface, or an error.
func (r *Request) Watch(ctx context.Context) (watch.Interface, error) {
	// We specifically don't want to rate limit watches, so we
	// don't use r.rateLimiter here.
	if r.err != nil {
		return nil, r.err
	}

	client := r.c.Client
	if client == nil {
		client = http.DefaultClient
	}

	isErrRetryableFunc := func(request *http.Request, err error) bool {
		// The watch stream mechanism handles many common partial data errors, so closed
		// connections can be retried in many cases.
		if net.IsProbableEOF(err) || net.IsTimeout(err) {
			return true
		}
		return false
	}
	retry := r.retryFn(r.maxRetries)
	url := r.URL().String()
	for {
		if err := retry.Before(ctx, r); err != nil {
			return nil, retry.WrapPreviousError(err)
		}

		req, err := r.newHTTPRequest(ctx)
		if err != nil {
			return nil, err
		}

		resp, err := client.Do(req)
		updateURLMetrics(ctx, r, resp, err)
		retry.After(ctx, r, resp, err)
		if err == nil && resp.StatusCode == http.StatusOK {
			return r.newStreamWatcher(resp)
		}

		// 重试机制...
	}
}

```

StreamWatcher  就是启了一个协程接受 wacth 中的事件变化，进行处理

```go
func (r *Request) newStreamWatcher(resp *http.Response) (watch.Interface, error) {
	contentType := resp.Header.Get("Content-Type")
	mediaType, params, err := mime.ParseMediaType(contentType)
	if err != nil {
		klog.V(4).Infof("Unexpected content type from the server: %q: %v", contentType, err)
	}
	objectDecoder, streamingSerializer, framer, err := r.c.content.Negotiator.StreamDecoder(mediaType, params)
	if err != nil {
		return nil, err
	}

	handleWarnings(resp.Header, r.warningHandler)

	frameReader := framer.NewFrameReader(resp.Body)
	watchEventDecoder := streaming.NewDecoder(frameReader, streamingSerializer)

	return watch.NewStreamWatcher(
		restclientwatch.NewDecoder(watchEventDecoder, objectDecoder),
		// use 500 to indicate that the cause of the error is unknown - other error codes
		// are more specific to HTTP interactions, and set a reason
		errors.NewClientErrorReporter(http.StatusInternalServerError, r.verb, "ClientWatchDecoding"),
	), nil
}
// NewStreamWatcher creates a StreamWatcher from the given decoder.
func NewStreamWatcher(d Decoder, r Reporter) *StreamWatcher {
	sw := &StreamWatcher{
		source:   d,
		reporter: r,
		// It's easy for a consumer to add buffering via an extra
		// goroutine/channel, but impossible for them to remove it,
		// so nonbuffered is better.
		result: make(chan Event),
		// If the watcher is externally stopped there is no receiver anymore
		// and the send operations on the result channel, especially the
		// error reporting might block forever.
		// Therefore a dedicated stop channel is used to resolve this blocking.
		done: make(chan struct{}),
	}
	go sw.receive()
	return sw
}

// StreamWatcher turns any stream for which you can write a Decoder interface
// into a watch.Interface.
type StreamWatcher struct {
	sync.Mutex
	source   Decoder
	reporter Reporter
	result   chan Event
	done     chan struct{}
}

// Interface can be implemented by anything that knows how to watch and report changes.
type Interface interface {
	// Stop stops watching. Will close the channel returned by ResultChan(). Releases
	// any resources used by the watch.
	Stop()

	// ResultChan returns a chan which will receive all the events. If an error occurs
	// or Stop() is called, the implementation will close this channel and
	// release any resources used by the watch.
	ResultChan() <-chan Event
}
```

看下具体是怎么进行处理的

1. 从 source 中解码得到k8s中监听到的事件变化的action（动作）
2. 将结果写入 result 这个 channel 中
3. result 这个channel 就是我们最开始 watch.ResultChan 函数的返回结果

```go
// receive reads result from the decoder in a loop and sends down the result channel.
func (sw *StreamWatcher) receive() {
	defer utilruntime.HandleCrash()
	defer close(sw.result)
	defer sw.Stop()
	for {
		action, obj, err := sw.source.Decode()
		if err != nil {
			switch err {
			case io.EOF:
				// watch closed normally
			case io.ErrUnexpectedEOF:
				klog.V(1).Infof("Unexpected EOF during watch stream event decoding: %v", err)
			default:
				if net.IsProbableEOF(err) || net.IsTimeout(err) {
					klog.V(5).Infof("Unable to decode an event from the watch stream: %v", err)
				} else {
					select {
					case <-sw.done:
					case sw.result <- Event{
						Type:   Error,
						Object: sw.reporter.AsObject(fmt.Errorf("unable to decode an event from the watch stream: %v", err)),
					}:
					}
				}
			}
			return
		}
		select {
		case <-sw.done:
			return
		case sw.result <- Event{
			Type:   action,
			Object: obj,
		}:
		}
	}
}

// ResultChan implements Interface.
func (sw *StreamWatcher) ResultChan() <-chan Event {
	return sw.result
}
```

回顾一下我们接受channel的写法，我们拿到channel后，从里面读取数据，会根据bool值来判断channel是否已经关闭，关闭则不处理；

```go
ch := watcher.ResultChan()
event, ok := <-ch:
```

那为什么channel会关闭呢，猜测一下？

- 客户端超时断开了？但是我们没设置timeout，则默认为0，就是无限制时间，不会主动断开
- 服务端主动断开了？有可能

在watcher建立后，我们通过 lsof -p 查看对应进程打开的连接，可以看到与 k8s 建立的 https 的连接，就是对应的 watcher 发起的http请求建立的 tcp 长链接；net/http 发起的 http 请求，是使用了 transport 连接池进行管理的，所以会默认维持长链接，感兴趣可以看下这篇文章 [[net-http]]

`xxx-75df5b458c-hj6qr:45006->kubernetes.default.svc.cluster.local:https (ESTABLISHED)`

知道了对端域名和端口后，就能通过 `tcpkill -i eth0 host kubernetes.default.svc.cluster.local and port 443`  命令，来手动中断这个连接，看下 streamWatch 是怎么处理的；

在 streamWatcher 的 receive 函数 select 中打断点调试，最后发现是在 net.IsProbableEOF 函数中命中了 "connection reset by peer" 

```go
// IsProbableEOF returns true if the given error resembles a connection termination
// scenario that would justify assuming that the watch is empty.
// These errors are what the Go http stack returns back to us which are general
// connection closure errors (strongly correlated) and callers that need to
// differentiate probable errors in connection behavior between normal "this is
// disconnected" should use the method.
func IsProbableEOF(err error) bool {
	if err == nil {
		return false
	}
	var uerr *url.Error
	if errors.As(err, &uerr) {
		err = uerr.Err
	}
	msg := err.Error()
	switch {
	case err == io.EOF:
		return true
	case err == io.ErrUnexpectedEOF:
		return true
	case msg == "http: can't write HTTP request on broken connection":
		return true
	case strings.Contains(msg, "http2: server sent GOAWAY and closed the connection"):
		return true
	case strings.Contains(msg, "connection reset by peer"):
		return true
	case strings.Contains(strings.ToLower(msg), "use of closed network connection"):
		return true
	}
	return false
}
```

并且我们将日志级别设置为0，就能直接打印对应的infof日志：

> I1226 09:38:19.316831   16623 streamwatcher.go:114] Unable to decode an event from the watch stream: read tcp 10.244.1.96:33006->10.96.0.1:443: read: connection reset by peer

ok，连接被对端关闭了，然后按照代码逻，就会直接return，在返回之前，会执行 defer 进行一些操作，receive 在方法开始就定义了 defer 资源回收

- 明确声明了会关闭 sw.result 这个channel
- stop 中则是将 source 这个 streamDecoder 关闭，最后调用到 http.transportResponseBody 进行关闭，这也是 net-http 源码 transport 的设计，不过k8s-apiserver 貌似用的http2的协议；

```go
defer close(sw.result)
defer sw.Stop()
// Stop implements Interface.
func (sw *StreamWatcher) Stop() {
	// Call Close() exactly once by locking and setting a flag.
	sw.Lock()
	defer sw.Unlock()
	// closing a closed channel always panics, therefore check before closing
	select {
	case <-sw.done:
	default:
		close(sw.done)
		sw.source.Close()
	}
}

// 最终的close函数，会把未读的数据都flush出来再关闭
func (b transportResponseBody) Close() error {
	cs := b.cs
	cc := cs.cc

	cs.bufPipe.BreakWithError(errClosedResponseBody)
	cs.abortStream(errClosedResponseBody)

	unread := cs.bufPipe.Len()
	if unread > 0 {
		cc.mu.Lock()
		// Return connection-level flow control.
		connAdd := cc.inflow.add(unread)
		cc.mu.Unlock()

		// TODO(dneil): Acquiring this mutex can block indefinitely.
		// Move flow control return to a goroutine?
		cc.wmu.Lock()
		// Return connection-level flow control.
		if connAdd > 0 {
			cc.fr.WriteWindowUpdate(0, uint32(connAdd))
		}
		cc.bw.Flush()
		cc.wmu.Unlock()
	}

	select {
	case <-cs.donec:
	case <-cs.ctx.Done():
		// See golang/go#49366: The net/http package can cancel the
		// request context after the response body is fully read.
		// Don't treat this as an error.
		return nil
	case <-cs.reqCancel:
		return errRequestCanceled
	}
	return nil
}
```



再梳理一下整个流程：

- 我们通过client-go提供的方法创建一个watcher，监听对应的资源
- watcher 会先向 kube-apiserver 发起一个 http 请求，告知 apiserver 启用  watch 机制监听某类型的资源
- 服务与apiserver建立了连接后，就通过FD进行读写传输
- 最终变更的事件，是通过 channel 与我们的服务进行通信
- 当apiserver关闭了连接，streamwatcher就会return并进行资源回收，从而关闭 channel

## 问题原因

-  apiserver 主动关闭了 TCP 连接，客户端 streamWatcher 将channel回收关闭了，所以，我们通过 watcher.ResultChan 获取到的 channel 永远都是关闭的
- apiserver 主动关闭连接有几个可能原因
  - 监听的资源被删除了，尝试了手动删除，发现watcher还是存在不会关闭
  - 长时间没有事件变更，TCP连接会自动断开（大概在30min左右）（事实证明就是这个原因）
  - 其他xxx

## 解决办法

- 如果发现 channel 被关闭了，则重新建立一个 watcher 进行监听即可

改进后的代码：

```go
func WatchDeployment(ctx context.Context, namespace string, options metav1.ListOptions, handler EventHandler) {
	log.Infof("start watch deployment: %+v", options)
	for {
		func() {
			defer func() {
				if r := recover(); r != nil {
					log.Warnf("The Kubernetes deployment watcher is attempting to restart for recovery. err: %v", r)
				}
			}()
			if err := runLoop(ctx, namespace, options, handler); err != nil {
				log.Errorf("Kubernetes deployment watcher has exited in runLoop: %v", err)
			}
		}()
		time.Sleep(5 * time.Second) // 等待一段时间后重试
	}
}

func runLoop(ctx context.Context, namespace string, options metav1.ListOptions, handler EventHandler) error {
	watcher, err := KubeCli.AppsV1().Deployments(namespace).Watch(ctx, options)
	if err != nil {
		return err
	}
	ch := watcher.ResultChan()

	for {
		select {
		case event, ok := <-ch:
			if !ok {
				// channel 关闭，重启 watcher
				log.Infof("Kubernetes hung up on us, restarting deployment watcher")
				return nil
			}

			deployment, ok := event.Object.(*appsv1.Deployment)
			if !ok {
				log.Errorf("Error casting to Deployment")
				continue
			}

			// 处理事件
			switch event.Type {
			case watch.Added:
				if handler.OnAdd != nil {
					handler.OnAdd(ctx, deployment)
				}
			case watch.Modified:
				if handler.OnModify != nil {
					handler.OnModify(ctx, deployment)
				}
			case watch.Deleted:
				if handler.OnDelete != nil {
					handler.OnDelete(ctx, deployment)
				}
			}
		case <-time.After(30 * time.Minute):
			// 超时，重启 watcher
			log.Infof("Timeout, restarting deployment watcher")
			return nil
		case <-ctx.Done():
			log.Info("Context done, stopping watch")
			return nil
		}
	}
}
```

## 其他疑问

1、为什么发起一个 http 请求，apiserver 就能与这个请求建立连接，进行 watch 并增量通知，apiserver 是怎么实现的？
- 推荐阅读：
	- https://cloud.tencent.com/developer/article/1991054
	- [etcd教程(五)---watch机制原理分析](https://www.lixueduan.com/posts/etcd/05-watch/)

2、为什么 list-watch 机制不会每隔一段时间就关闭连接？（貌似有探活？）

3、StreamWatcher 中包装的 Decoder 是怎么与TCP连接的描述符关联上的，读写是怎么传输的？





















