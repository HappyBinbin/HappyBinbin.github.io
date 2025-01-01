# BFPRT算法

题目：给你一个无序的整型数组，返回其中第K小的数。

[215. 数组中的第K个最大元素](https://leetcode-cn.com/problems/kth-largest-element-in-an-array/)

这道题可以利用荷兰国旗改进的partition和随机快排的思想：随机选出一个数，将数组以该数作比较划分为三个部分，则`=`部分的数是数组中第几小的数不难得知，接着对（如果第K小的数在>部分）部分的数递归该过程，直到=部分的数正好是整个数组中第K小的数。这种做法不难求得时间复杂度的数学期望为O(NlogN)（以2为底）。但这毕竟是数学期望，在实际工程中的表现可能会有偏差，而BFPRT算法能够做到时间复杂度就是O(NlogN)。

BFPRT算法首先将数组按5个元素一组划分成N/5个小部分（最后不足5个元素自成一个部分），再这些小部分的内部进行排序，然后将每个小部分的中位数取出来再排序得到中位数：

![img](https://pic4.zhimg.com/80/v2-d99a7223264be6ae816eedb0a19b9713_720w.png)

BFPRT求解此题的步骤和开头所说的步骤大体类似，唯一不同的是将“随机选出一个的作为比较的那个数”这一步替换为上图所示最终选出来的那个数。

O(NlogN)的证明，为什么每一轮partition中的随机选数改为BFPRT定义的选数逻辑之后，此题的时间复杂度就彻底变为O(NlogN)了呢？下面分析一下这个算法的步骤：

**BFPRT算法的功能：**接收一个数组和一个K值，返回数组中的一个数

1. 数组被划分为了N/5个小部分，每个部分的5个数排序需要O(1)，所有部分排完需要O(N/5)=O(N)
2. 取出每个小部分的中位数，一共有N/5个，递归调用BFPRT算法本身，得到这些数中第(N/5)/2小的数（即这些数的中位数），记为pivot
3. 以pivot作为比较，将整个数组划分为pivot三个区域
4. 判断第K小的数在哪个区域，如果在=区域则直接返回pivot，**如果在区域，则将这个区域的数递归调用BFPRT算法**
5. `base case`：在某次递归调用BFPRT算法时发现这个区域只有一个数，那么这个数就是我们要找的数

## 代码示例：

```java
public static int getMinKthNum(int[] arr, int K) {
    if (arr == null || K > arr.length) {
        return Integer.MIN_VALUE;
    }
    int[] copyArr = Arrays.copyOf(arr, arr.length);
    return bfprt(copyArr, 0, arr.length - 1, K - 1);
}

public static int bfprt(int[] arr, int begin, int end, int i) {
    if (begin == end) {
        return arr[begin];
    }
    int pivot = medianOfMedians(arr, begin, end);
    int[] pivotRange = partition(arr, begin, end, pivot);
    if (i >= pivotRange[0] && i <= pivotRange[1]) {
        return arr[i];
    } else if (i < pivotRange[0]) {
        return bfprt(arr, begin, pivotRange[0] - 1, i);
    } else {
        return bfprt(arr, pivotRange[1] + 1, end, i);
    }
}

public static int medianOfMedians(int[] arr, int begin, int end) {
    int num = end - begin + 1;
    int offset = num % 5 == 0 ? 0 : 1;
    int[] medians = new int[num / 5 + offset];
    for (int i = 0; i < medians.length; i++) {
        int beginI = begin + i * 5;
        int endI = beginI + 4;
        medians[i] = getMedian(arr, beginI, Math.min(endI, end));
    }
    return bfprt(medians, 0, medians.length - 1, medians.length / 2);
}

public static int getMedian(int[] arr, int begin, int end) {
    insertionSort(arr, begin, end);
    int sum = end + begin;
    int mid = (sum / 2) + (sum % 2);
    return arr[mid];
}

public static void insertionSort(int[] arr, int begin, int end) {
    if (begin >= end) {
        return;
    }
    for (int i = begin + 1; i <= end; i++) {
        for (int j = i; j > begin; j--) {
            if (arr[j] < arr[j - 1]) {
                swap(arr, j, j - 1);
            } else {
                break;
            }
        }
    }
}

public static int[] partition(int[] arr, int begin, int end, int pivot) {
    int L = begin - 1;
    int R = end + 1;
    int cur = begin;
    while (cur != R) {
        if (arr[cur] > pivot) {
            swap(arr, cur, --R);
        } else if (arr[cur] < pivot) {
            swap(arr, cur++, ++L);
        } else {
            cur++;
        }
    }
    return new int[]{L + 1, R - 1};
}

public static void swap(int[] arr, int i, int j) {
    int tmp = arr[i];
    arr[i] = arr[j];
    arr[j] = tmp;
}

public static void main(String[] args) {
    int[] arr = {6, 9, 1, 3, 1, 2, 2, 5, 6, 1, 3, 5, 9, 7, 2, 5, 6, 1, 9};
    System.out.println(getMinKthNum(arr,13));
}
```

时间复杂度为O(NlogN)（底数为2）的证明，分析bfprt的执行步骤（假设bfprt的时间复杂度为T(N)）：

1. 首先数组5个5个一小组并内部排序，对5个数排序为O(1)，所有小组排好序为O(N/5)=O(N)
2. 由步骤1的每个小组抽出中位数组成一个中位数小组，共有N/5个数，递归调用bfprt求出这N/5个数中第(N/5)/2小的数（即中位数）为T(N/5)，记为pivot
3. 对步骤2求出的pivot作为比较将数组分为小于、等于、大于三个区域，由于pivot是中位数小组中的中位数，所以中位数小组中有N/5/2=N/10个数比pivot小，这N/10个数分别又是步骤1中某小组的中位数，可推导出**至少有3N/10个数比pivot小，也即最多有7N/10个数比pivot大。**也就是说，大于区域（或小于）最大包含7N/10个数、最少包含3N/10个数，那么如果第i大的数不在等于区域时，无论是递归bfprt处理小于区域还是大于区域，最坏情况下子过程的规模最大为7N/10，即T(7N/10)

综上所述，bfprt的T(N)存在推导公式：T(N/5)+T(7N/10)+O(N)。根据 **基础篇** 中所介绍的Master公式可以求得bfprt的时间复杂度就是O(NlogN)（以2为底）。















