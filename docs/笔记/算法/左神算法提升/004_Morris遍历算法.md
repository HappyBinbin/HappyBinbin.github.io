# Morris遍历算法

关于二叉树先序、中序、后序遍历的递归和非递归版本在【直通BAT算法（基础篇）】中有讲到，但这6种遍历算法的时间复杂度都需要O(H)（其中H为树高）的额外空间复杂度，因为二叉树遍历过程中只能向下查找孩子节点而无法回溯父节点，因此这些算法借助栈来保存要回溯的父节点（递归的实质是系统帮我们压栈），并且栈要保证至少能容纳下H个元素（比如遍历到叶子节点时回溯父节点，要保证其所有父节点在栈中）。**而morris遍历则能做到时间复杂度仍为O(N)的情况下额外空间复杂度只需O(1)**

## 遍历规则

首先在介绍morris遍历之前，我们先把先序、中序、后序定义的规则抛之脑后，比如先序遍历在拿到一棵树之后先遍历头节点然后是左子树最后是右子树，并且在遍历过程中对于子树的遍历仍是这样。

忘掉这些遍历规则之后，我们来看一下morris遍历定义的标准：

1. 定义一个遍历指针cur，该指针首先指向头节点
2. 判断cur的左子树是否存在
    - 如果cur的左孩子为空，说明cur的左子树不存在，那么cur右移来到cur.right
    - 如果cur的左孩子不为空，说明cur的左子树存在，找出该左子树的最右节点，记为mostRight
        - 如果，mostRight的右孩子为空，那就让其指向cur（mostRight.right=cur），并左移cur（cur=cur.left）
        - 如果mostRight的右孩子不空，那么让cur右移（cur=cur.right），并将mostRight的右孩子置空
3. 经过步骤2之后，如果cur不为空，那么继续对cur进行步骤2，否则遍历结束。

下图所示举例演示morris遍历的整个过程：

![img](https://pic2.zhimg.com/80/v2-1668c70bcb6e3cd41fbcfe00e4820ded_720w.png)

## 先序、中序序列

遍历完成后对cur进过的节点序列稍作处理就很容易得到该二叉树的先序、中序序列：

![img](https://pic4.zhimg.com/80/v2-1a00cb2a67b56cbfa46e16c85d66b35f_720w.png)

示例代码：

```java
public static class Node {
    int data;
    Node left;
    Node right;
    public Node(int data) {
        this.data = data;
    }
}

public static void preOrderByMorris(Node root) {
    if (root == null) {
        return;
    }
    Node cur = root;
    while (cur != null) {
        if (cur.left == null) {
            System.out.print(cur.data+" ");
            cur = cur.right;
        } else {
            Node mostRight = cur.left;
            while (mostRight.right != null && mostRight.right != cur) {
                mostRight = mostRight.right;
            }
            if (mostRight.right == null) {
                System.out.print(cur.data+" ");
                mostRight.right = cur;
                cur = cur.left;
            } else {
                cur = cur.right;
                mostRight.right = null;
            }
        }
    }
    System.out.println();
}

public static void mediumOrderByMorris(Node root) {
    if (root == null) {
        return;
    }
    Node cur = root;
    while (cur != null) {
        if (cur.left == null) {
            System.out.print(cur.data+" ");
            cur = cur.right;
        } else {
            Node mostRight = cur.left;
            while (mostRight.right != null && mostRight.right != cur) {
                mostRight = mostRight.right;
            }
            if (mostRight.right == null) {
                mostRight.right = cur;
                cur = cur.left;
            } else {
                System.out.print(cur.data+" ");
                cur = cur.right;
                mostRight.right = null;
            }
        }
    }
    System.out.println();
}

public static void main(String[] args) {
    Node root = new Node(1);
    root.left = new Node(2);
    root.right = new Node(3);
    root.left.left = new Node(4);
    root.left.right = new Node(5);
    root.right.left = new Node(6);
    root.right.right = new Node(7);
    preOrderByMorris(root);
    mediumOrderByMorris(root);

}
```

这里值得注意的是：**morris遍历会来到一个左孩子不为空的节点两次，**而其它节点只会经过一次。

- 因此使用morris遍历打印先序序列时，如果来到的节点无左孩子，那么直接打印即可（这种节点只会经过一次），否则如果来到的节点的左子树的最右节点的右孩子为空才打印（这是第一次来到该节点的时机），这样也就忽略了cur经过的节点序列中第二次出现的节点；
- 而使用morris遍历打印中序序列时，如果来到的节点无左孩子，那么直接打印（这种节点只会经过一次，左中右，没了左，直接打印中），否则如果来到的节点的左子树的最右节点不为空时才打印（这是第二次来到该节点的时机），这样也就忽略了cur经过的节点序列中第一次出现的重复节点。

## 后序遍历

使用morris遍历得到二叉树的后序序列就没那么容易了，因为对于树种的非叶节点，morris遍历最多会经过它两次，而我们后序遍历是在第三次来到该节点时打印该节点的。因此要想得到后序序列，仅仅改变在morris遍历时打印节点的时机是无法做到的。

但其实，在morris遍历过程中，如果在每次遇到第二次经过的节点时，将该节点的左子树的右边界上的节点从下到上打印，最后再将整个树的右边界从下到上打印，最终就是这个数的后序序列：


![img](https://pic1.zhimg.com/80/v2-c9a88e4c3bf923804b39ad47faa85e40_720w.png)

![img](https://pic3.zhimg.com/80/v2-562b08b644e57ada078e4fe823b119be_720w.png)

![img](https://pic3.zhimg.com/80/v2-06b3d3b2cd6de210ebc8f163d29bf6fe_720w.png)

![img](https://pic2.zhimg.com/80/v2-180a0cacc31482e346f4b0b1259db1ad_720w.png)

其中无非就是在morris遍历中在第二次经过的结点的时机执行一下打印操作。而从下到上打印一棵树的右边界，可以将该右边界上的结点看做以right指针为后继指针的链表，将其反转reverse然后打印，最后恢复成原始结构即可。示例代码如下（其中容易犯错的地方是18行和19行的代码不能调换）：

```java
public static void posOrderByMorris(Node root) {
    if (root == null) {
        return;
    }
    Node cur = root;
    while (cur != null) {
        if (cur.left == null) {
            cur = cur.right;
        } else {
            Node mostRight = cur.left;
            while (mostRight.right != null && mostRight.right != cur) {
                mostRight = mostRight.right;
            }
            if (mostRight.right == null) {
                mostRight.right = cur;
                cur = cur.left;
            } else {
                mostRight.right = null;
                printRightEdge(cur.left);
                cur = cur.right;
            }
        }
    }
    printRightEdge(root);
}

private static void printRightEdge(Node root) {
    if (root == null) {
        return;
    }
    //reverse the right edge
    Node cur = root;
    Node pre = null;
    while (cur != null) {
        Node next = cur.right;
        cur.right = pre;
        pre = cur;
        cur = next;
    }
    //print 
    cur = pre;
    while (cur != null) {
        System.out.print(cur.data + " ");
        cur = cur.right;
    }
    //recover
    cur = pre;
    pre = null;
    while (cur != null) {
        Node next = cur.right;
        cur.right = pre;
        pre = cur;
        cur = next;
    }
}

public static void main(String[] args) {
    Node root = new Node(1);
    root.left = new Node(2);
    root.right = new Node(3);
    root.left.left = new Node(4);
    root.left.right = new Node(5);
    root.right.left = new Node(6);
    root.right.right = new Node(7);
    posOrderByMorris(root);
}
```

## 时间复杂度分析

因为morris遍历中，只有左孩子非空的结点才会经过两次而其它结点只会经过一次，也就是说遍历的次数小于2N

因此使用morris遍历得到先序、中序序列的时间复杂度自然也是O(1)；但产生后序序列的时间复杂度还要算上printRightEdge的时间复杂度，但是你会发现整个遍历的过程中，所有的printRightEdge加起来也只是遍历并打印了N个结点：

![img](https://pic4.zhimg.com/80/v2-72745692f3d0a96500cb793551696bb3_720w.png)

因此时间复杂度仍然为O(N)。

> morris遍历结点的顺序不是先序、中序、后序，而是按照自己的一套标准来决定接下来要遍历哪个结点。
> morris遍历的独特之处就是充分利用了叶子结点的无效引用（引用指向的是空，但该引用变量仍然占内存），从而实现了O(1)的时间复杂度。