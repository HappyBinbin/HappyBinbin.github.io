## Defer Rules

1. A deferred function’s arguments are evaluated when the defer statement is evaluated.*

```go
func a() {
    i := 0
    defer fmt.Println(i)
    i++
    return
}

// output: 0

func test2() (v int) {  
   defer func() {  
      fmt.Println(v)  
   }()  
   return 3  
}

// output : 3
// `return 3` 的底层操作是：`v = 3` → 执行 `defer` 函数 → 返回 `v` 的值

```

2. *Deferred function calls are executed in Last In First Out order after the surrounding function returns.*

```go
func b() {
    for i := 0; i < 4; i++ {
        defer fmt.Print(i)
    }
}

// output: 3210
```

3. *Deferred functions may read and assign to the returning function’s named return values.*

翻译：延迟函数，可以访问并修改函数的命名返回值；

这是因为defer 语句在函数返回之前执行，而在执行 return 语句时，命名返回值已经被赋值并且仍然在作用域内。

```go
func c() (i int) {
    defer func() { i++ }()
    return 1
}

// output: 2
```

## Panic & Recover

**Panic**是一个内置函数，当 panic 发生时:

- 触发 panic 的函数：
  - Go 会立即停止当前函数的正常执行流程。
  - 然后，Go 会执行该函数中所有已注册的 defer 语句，按照后进先出的顺序。
- 展开调用栈：
  - 在执行完当前函数的所有 defer 语句后，Go 会将控制权交回到调用该函数的上层函数。
  - 上层函数会执行它自己的 defer 语句，依然是后进先出的顺序。
- 继续向上展开：
  - 这个过程会一直向上展开，直到找到一个包含 recover 调用的 defer 函数，或者直到程序的最顶层（即 main 函数）都没有 recover，导致程序崩溃并打印错误信息。

recover :

- **Recover**是一个内置函数，用于重新获得对 panic goroutine 的控制权，并且只在 defer 函数中起作用
- 如果在某个 defer 函数中调用了 recover，并且成功捕获了 panic，则程序会停止展开调用栈。

- recover 返回 panic 的值，并且程序可以从 panic 中恢复，继续执行 recover 所在函数之后的代码。

example

```go
package main

import "fmt"

func main() {
    f()
    fmt.Println("Returned normally from f.")
}

func f() {
    defer func() {
        if r := recover(); r != nil {
            fmt.Println("Recovered in f", r)
        }
    }()
    fmt.Println("Calling g.")
    g(0)
    fmt.Println("Returned normally from g.")
}

func g(i int) {
    if i > 3 {
        fmt.Println("Panicking!")
        panic(fmt.Sprintf("%v", i))
    }
    defer fmt.Println("Defer in g", i)
    fmt.Println("Printing in g", i)
    g(i + 1)
}

// output:
Calling g.
Printing in g 0
Printing in g 1
Printing in g 2
Printing in g 3
Panicking!
Defer in g 4
Defer in g 3
Defer in g 2
Defer in g 1
Defer in g 0
Recovered in f 4
Returned normally from f.
```

