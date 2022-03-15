# [470. 用 Rand7() 实现 Rand10()](https://leetcode-cn.com/problems/implement-rand10-using-rand7/)

难度中等

已有方法 `rand7` 可生成 1 到 7 范围内的均匀随机整数，试写一个方法 `rand10` 生成 1 到 10 范围内的均匀随机整数。

不要使用系统的 `Math.random()` 方法。



 

**示例 1:**

```
输入: 1
输出: [7]
```

**示例 2:**

```
输入: 2
输出: [8,4]
```

**示例 3:**

```
输入: 3
输出: [8,1,10]
```

 

**提示:**

1. `rand7` 已定义。
2. 传入参数: `n` 表示 `rand10` 的调用次数。

 

**进阶:**

1. `rand7()`调用次数的 [期望值](https://en.wikipedia.org/wiki/Expected_value) 是多少 ?
2. 你能否尽量少调用 `rand7()` ?

## 思路

### 情况1

由大的随机数 生成小的随机数是方便的，如 rand10 -> rand7，只需要用 rand10 生成等概率的 1 ~ 10 ，然后判断生成的随机数 num ，如果 num <= 7 ，则返回即可

## 情况2

如何由小的随机数生成大的随机数呢？

- 考虑这样一个事实：
    randX() 生成的随机数范围是 [1...X]，(randX - 1) * Y + randY() 可以等概率的生成的随机数范围是 [1, X*Y]。因此， 可以通过 (rand7 - 1) * 7 + rand7() 等概率的生成 [1...49]的随机数，我们可以选择在 [1...10] 范围内的随机数返回。

## 情况3

上面生成 [1...49] 而 我们需要 [1...10]，那么[11...49]都要被过滤掉，效率有些低，可以通过减小过滤掉数的范围来提高效率。比如我们保留 [1...40]， 剩下 [41...49]。为什么保留 [1...40] 呢？ 因为对于要生成 [1...10]的随机数，那么可以等概率的转换为

```java
num  = (rand7 - 1) * 7 + rand7();
if(num <= 40) return num % 10 + 1;
```

因为 1 ... 40 可以等概率的映射到 [1...10]那么如果生成的数在 41...49 怎么办呢？，这些数因为也是等概率的。我们可以重新把 41 ... 49 通过 num - 40 映射到 1 ... 9，可以把 1...9 重新看成一个，通过 rand9 生成 rand10 的过程。

```java
num = (num - 40 - 1) * 7 + rand7()  => [1 ... 63]
 if(num <= 60) return num % 10 + 1;
```

类似的，[1...63] 可以 划分为 [1....60] and [61...63]，[[1...60] 可以通过 1 + num % 10 等概率映射到 [1...10]，而 [61...63] 又可以重新重复上述过程，先映射到 [1...3]，然后看作 rand3 生成 rand10，

```java
num = (num - 60 - 1) * 7 + rand7() -> [1 ... 21]
if( num <= 20) return num % 10 + 1;
```

注意：这个映射的范围需要根据 待生成随机数的大小而定的。比如我要用 rand7 生成 rand9，(rand7() - 1) * 7 + rand7() -> [1...49]，则等概率映射范围调整为 [1...45]， 

```java
num = (rand7() - 1) * 7 + rand7();
if(num <= 45) return num % 9 + 1;
```

## 代码实现

```java
/**
 * The rand7() API is already defined in the parent class SolBase.
 * public int rand7();
 * @return a random integer in the range 1 to 7
 */
class Solution extends SolBase {
    public int rand10() {
        while(true){
            int num1 = (rand7()-1) * 7 + rand7();
            if(num1 <= 40) return num1 % 10 + 1;
            int num2 = (num1-40-1) * 7 + rand7();
            if(num2 <= 60) return num2 % 10 + 1;
            int num3 = (num2-60-1) * 7 + rand7();
            if(num3 <= 21) return num3 % 10 + 1;
        }
    }
}
```

