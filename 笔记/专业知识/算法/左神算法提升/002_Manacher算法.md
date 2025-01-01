# Manacher算法

Manacher算法是由题目“求字符串中最长回文子串的长度”而来。比如abcdcb的最长回文子串为bcdcb，其长度为5。

我们可以遍历字符串中的每个字符，当遍历到某个字符时就比较一下其左边相邻的字符和其右边相邻的字符是否相同，如果相同则继续比较其右边的右边和其左边的左边是否相同，如果相同则继续比较……，我们暂且称这个过程为向外“扩”。当“扩”不动时，经过的所有字符组成的子串就是以当前遍历字符为中心的最长回文子串。

我们每次遍历都能得到一个最长回文子串的长度，使用一个全局变量保存最大的那个，遍历完后就能得到此题的解。但分析这种方法的时间复杂度：当来到第一个字符时，只能扩其本身即1个；来到第二个字符时，最多扩两个；……；来到字符串中间那个字符时，最多扩(n-1)/2+1个；因此时间复杂度为1+2+……+(n-1)/2+1即O(N^2)。**但Manacher算法却能做到O(N)。**

注意：在找回文的过程中，一般要在每个字符中间插入#之类的间隔符，来避免奇数和偶数的差别回文

## 概念补充

- 回文半径：串中某个字符最多能向外扩的字符个数称为该字符的回文半径。比如abcdcb中字符d，能扩一个c，还能再扩一个b，再扩就到字符串右边界了，再算上字符本身，字符d的回文半径是3。
- 回文半径数组pArr：长度和字符串长度一样，保存串中每个字符的回文半径。比如charArr="abcdcb"，其中charArr[0]='a'一个都扩不了，但算上其本身有pArr[0]=1；而charArr[3]='d'最多扩2个，算上其本身有pArr[3]=3。
- 最右回文右边界R：遍历过程中，“扩”这一操作扩到的最右的字符的下标。比如charArr=“abcdcb”，当遍历到a时，只能扩a本身，向外扩不动，所以R=0；当遍历到b时，也只能扩b本身，所以更新R=1；但当遍历到d时，能向外扩两个字符到charArr[5]=b，所以R更新为5。
- 最右回文右边界对应的回文中心C：C与R是对应的、同时更新的。比如abcdcb遍历到d时，R=5，C就是charArr[3]='d'的下标3。

处理回文子串长度为偶数的问题：上面拿abcdcb来举例，其中bcdcb属于一个回文子串，但如果回文子串长度为偶数呢？像cabbac，按照上面定义的“扩”的逻辑岂不是每个字符的回文半径都是0，但事实上cabbac的最长回文子串的长度是6。因为我们上面“扩”的逻辑默认是将回文子串当做奇数长度的串来看的，因此我们在使用Manacher算法之前还需要将字符串处理一下，这里有一个小技巧，那就是将字符串的首尾和每个字符之间加上一个特殊符号，这样就能将输入的串统一转为奇数长度的串了。比如abba处理过后为#a#b#b#a，这样的话就有charArr[4]='#'的回文半径为4，也即原串的最大回文子串长度为4。相应代码如下：

```java
public static char[] manacherString(String str){
    char[] source = str.toCharArray();
    char chs[] = new char[str.length() * 2 + 1];
    for (int i = 0; i < chs.length; i++) {
        chs[i] = i % 2 == 0 ? '#' : source[i / 2];
    }
    return chs;
}
```

接下来分析，Manacher算法是如何利用遍历过程中计算的pArr(回文半径数组)、R、C 来为后续字符的回文半径的求解加速的。

## 分情况讨论

### 情况1

遍历到的字符下标cur在R的右边（起初令R=-1），这种情况下该字符的最大回文半径pArr[cur]的求解无法加速，只能一步步向外扩来求解。

![img](https://pic1.zhimg.com/80/v2-6b61f73e3efc0ac5a7ba56c6c34c54c8_720w.png)

### 情况2

遍历到的字符下标cur在R的左边，这时pArr[cur]的求解过程可以利用之前遍历的字符回文半径信息来加速。分别做cur、R关于C的对称点cur'和L：

#### 情况2-1

如果从cur'向外扩的最大范围的左边界没有超过L，那么pArr[cur]=pArr[cur']。

![img](https://pic3.zhimg.com/80/v2-168ef8b188b50a994d852cb73c67a2e6_720w.png)

证明如下：

![img](https://pic4.zhimg.com/80/v2-143b28d5e5c02a584d888bf48597cf9b_720w.png)


根据R和C的定义，整个L到R范围的字符是关于C对称的，L到C 与 R到C 是对称的，也就是说cur能扩出的最大回文子串和cur'能扩出的最大回文子串相同。如果cur能的回文串能更大， 那么必有 y=x =>x' = y'，那么pArr[cur']的回文子串就会更大，由于之前遍历过cur'位置上的字符，所以该位置上能扩的步数我们是有记录的（pArr[cur']），因此可以直接得出pArr[cur]=pArr[cur']。

#### 情况2-2

如果从cur'向外扩的最大范围的左边界超过了L，那么pArr[cur]=R-cur+1。

![img](https://pic2.zhimg.com/80/v2-8928e4ff0a930a283c5dbf4b7fc8b6fd_720w.png)

证明如下：

![img](https://pic3.zhimg.com/80/v2-aaf3cf324671b0fb4ea8f61fc90eb39e_720w.png)

R右边一个字符x，x关于cur对称的字符y，x,y关于C对称的字符x',y'。根据C,R的定义有x!=x'；由于x',y'在以cur'为中心的回文子串内且关于cur'对称，所以有x'=y'，可推出x!=y'；又y,y'关于C对称，且在L,R内，所以有y=y'。综上所述，有x!=y，因此cur的回文半径为R-cur+1。

#### 情况2-3

以cur'为中心向外扩的最大范围的左边界正好是L，那么pArr[cur] >= （R-cur+1）

![img](https://pic3.zhimg.com/80/v2-b5e6b76542bbb0af19bfecc3e0f76242_720w.png)

这种情况下，cur'能扩的范围是cur'-L，因此对应有cur能扩的范围是R-cur。但cur能否扩的更大则取决于x和y是否相等。而我们所能得到的前提条件只有x!=x'、y=y'、x'!=y'，无法推导出x,y的关系，只知道cur的回文半径最小为R-cur+1（算上其本身），需要继续尝试向外扩以求解pArr[cur]。

## 总结

综上所述，pArr[cur]的计算有四种情况：

1. 暴力扩
2. 等于pArr[cur']
3. 等于R-cur+1
4. 从R-cur+1继续向外扩

使用此算法求解原始问题的过程就是遍历串中的每个字符，每个字符都尝试向外扩到最大并更新R（只增不减），每次R增加的量就是此次能扩的字符个数，而R到达串尾时问题的解就能确定了，因此时间复杂度就是每次扩操作检查的次数总和，也就是R的变化范围（-1~2N，因为处理串时向串中添加了N+1个#字符），即O(1+2N)=O(N)。

```java
public static int maxLcpsLength(String str){
    //if(str == null || str.length() == 0){
    //    return 0;
    // }
    char[] charArr = manacherString(str); //处理原始字符串
    int[] pArr = new int[charArr.length]; //回文半径数组
    int C = -1;
    int R = -1;
    int max = Integer.MIN_VALUE;
    for(int i = 0;i != charArr.length;i++){ //求i位置的回文中心
        //R>i就是当前i在回文右边界内，pArr[2*c-i]代表i`的回文半径
        pArr[i] =R > i ? Math.min(pArr[2*c-i],R-i):1;
        while(i+pArr[i]<charArr.length && i-pArr[i]> -1 ){ //都扩一次
            if(charArr[i +pArr[i]] == charArr[i-pArr[i]])
                pArr[i]++;
            else{
                break;
            }
        }
        if(i + pArr[i]>R){  
            R = i+pArr[i];   //更新回文右边界
            c = i;			//更新回文中心
        }
        
        max = Math.max(max,pArr[i]);
    }
    return max-1;
}
```

上述代码将四种情况的分支处理浓缩到了7~14行。其中第7行是确定加速信息：如果当前遍历字符在R右边，先算上其本身有pArr[i]=1，后面检查如果能扩再直接pArr[i]++即可；否则，当前字符的pArr[i]要么是pArr[i']（i关于C对称的下标i'的推导公式为2*C-i），要么是R-i+1，要么是>=R-i+1，可以先将pArr[i]的值置为这三种情况中最小的那一个，后面再检查如果能扩再直接pArr[i]++即可。

最后得到的max是处理之后的串（length=2N+1）的最长回文子串的半径，max-1刚好为原串中最长回文子串的长度。

## 进阶问题

导航：LeetCode -> 字符串 -> 最短回文串

214题：最短回文串

#### 第一种，在前面添加

给定一个字符串 s，你可以通过在字符串前面添加字符将其转换为回文串。找到并返回可以用这种方式转换的最短回文串。

https://leetcode-cn.com/problems/shortest-palindrome/

#### 第二种，在后面添加

在给定字符串末尾添加一个字符串，生成回文串，且回文串长度最短