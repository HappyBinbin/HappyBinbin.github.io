# [剑指 Offer 51. 数组中的逆序对](https://leetcode-cn.com/problems/shu-zu-zhong-de-ni-xu-dui-lcof/)

难度困难

在数组中的两个数字，如果前面一个数字大于后面的数字，则这两个数字组成一个逆序对。输入一个数组，求出这个数组中的逆序对的总数。

 

**示例 1:**

```
输入: [7,5,6,4]
输出: 5
```

 

**限制：**

```
0 <= 数组长度 <= 50000
```



## 解法1

暴力法，不用看，超时

## 解法2

归并排序，在归并的时候比较，统计逆序对的个数

思想是「分治算法」，所有的「逆序对」来源于 3 个部分：

- 左边区间的逆序对；
- 右边区间的逆序对；
- 横跨两个区间的逆序对。

![image.png](https://pic.leetcode-cn.com/0adb9d76f0f2a8efccaa1c3d340003e91e2a9eb9dc490280460acae0c8850a24-image.png)

![image.png](https://pic.leetcode-cn.com/a13af31b7f9e12f6d8588d95dd71c94aa0117bc8c819899e7806a5695e237f78-image.png)

```java
class Solution {
    public int reversePairs(int[] nums) {
        if(nums == null || nums.length < 2){
            return 0;
        }
        return mergeSort(nums,0,nums.length-1);
    }

    public int mergeSort(int[] nums, int L, int R){
        if(L == R){
            return 0;
        }
        int mid = L + ((R-L) >> 1);
        return mergeSort(nums,L,mid) + mergeSort(nums,mid+1,R) + merge(nums,L,mid,R);
    }
    public int merge(int[] nums, int l, int m, int r){
        int res = 0;
        int[] help = new int[r-l+1];
        int p1 = l;
        int p2 = m + 1;
        int k = 0;
        while(p1 <= m && p2 <= r){
            if(nums[p1] > nums[p2]){
                help[k++] = nums[p2++];
                res += (m-p1+1);
            }else{
                help[k++] = nums[p1++];
            }
        }
        while(p1 <= m){
            help[k++] = nums[p1++]; 
        }
        while (p2 <= r) {
			help[k++] = nums[p2++];
		}
        for(int i = 0; i < help.length; i++){
            nums[l+i] = help[i];
        }
        return res;
    }
}
```

