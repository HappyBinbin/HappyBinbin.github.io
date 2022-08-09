# Typora+Picgo+gitee实现图片自动上传配置

用Typora做笔记是真滴方便，很多地方都是支持md格式的文件，但是在笔记本上做的笔记，想在ipad或者手机上看就很困难，发送给别人只能转pdf之后再发，不然别人只能看到文字，而图片会失效。

究其原因，因为Typora的图片保存方法问题，它不像word一样把图片写进去，而是另外保存在你电脑的磁盘上，所以md格式文件上的图片发给别人，别人是看不到的。

所以就有了解决方案，把保存在本地的图片传到网络上，就是服务器上，这样就能通过url直接访问。下面讲一下我的配置过程



## 1. 下载软件

Typora 官网就能下，bing搜一下就可以了。

Picgo github有时候上不去，我是通过软件园下的，找不到的兄弟可以用百度网盘来下

链接：https://pan.baidu.com/s/1fzvtKKvWgi_IZa_thc1RvQ 
提取码：eavd 

## 2. 配置Typora

打开Typora，点击 文件 -> 偏好设置

插入图片时的动作设置为“**上传图片**”，开启“**对本地为止的图片应用上述规则**”

上传服务设定打开之后，服务我选的是PicGo，这个支持多平台的，大家下载PicGo的时候尽量别选beta版本，待测试的版本总会出点bug，然后选择PicGo的启动路径，也就是exe文件

![image-20210319225210998](https://gitee.com/HappyBinbin/pcigo/raw/master/pic/20210319225211.png)

## 3. 配置PicGo

首先，安装好PicGo之后，我们需要给PicGo配置插件以支持Gitee图床

**注意**：你必须安装[Node.js](https://link.zhihu.com/?target=https%3A//nodejs.org/en/)之后才能安装PicGo的插件，因为PicGo要使用`npm`来安装插件。

非程序员可能不会用到 Node.js ，不过装一个也不难，要是觉得不好找，我这里也给个链接

http://nodejs.cn/download/ 这个是中文网，根据自己的OS来选，Windows选64位的就好了

### 3.1 安装github-plus

安装好Nodejs后，继续打开Picgo，点开左边的**插件设置**一栏，在输入框内输入“github plus”，如下

双击Picgo.exe 可能不会直接弹出来，要在右下角窗口栏里面双击打开它

![image-20210320001017922](https://gitee.com/HappyBinbin/pcigo/raw/master/pic/20210320001017.png)

然后选择插件设置，搜索 github-plus，点击安装

![img](https://pic1.zhimg.com/80/v2-270b499aeadae15d014215b32b1204c8_720w.jpg)

点击安装，然后等待它安装完成，点开图床设置，就会发现多了一个githubPlus的图床。

如果能正常安装github-plus，则直接看 4

### 3.2 安装另一个插件 gitee

有些小伙伴可能在安装完node.js后，还是无法下载github-plus，可以换一个插件，比如 gitee

![image-20210320213335011](https://gitee.com/HappyBinbin/pcigo/raw/master/pic/20210320213335.png)



### 3.3 配置插件

安装好gitee插件后，就是配置gitee插件

owner：就是你的名字（参考下面的UserName）

repo：为 **UserName/仓库名称** 格式

token：第四步有讲令牌的问题

这个UserName是下面这个，也就是个人主页头像下的@后面那段名字

![image-20210319233115993](https://gitee.com/HappyBinbin/pcigo/raw/master/pic/20210319233116.png)

![image-20210320213605803](https://gitee.com/HappyBinbin/pcigo/raw/master/pic/20210320213605.png)

## 4. 配置好 token 令牌

1. 进入[https://gitee.com/](https://link.zhihu.com/?target=https%3A//gitee.com/)，没有账号的话，先注册账号，注册以后登录，新建一个**公开仓库**，名字为picgo（可以自己起其他名字）重点：</新建的<font color='red'>仓库名不要有空格，</font>不然可能一些奇怪的错误报错（例如：找不到地址）

2. 点击右上角，进入**设置**，在左侧的**安全设置-私人令牌**处生成新令牌。（注意：<font color='red'>生成的新令牌只会显示一次，</font>一定要保存好！！！）

## 5. 回到PicGO

1）回到picgo，按照如下进行设置

![image-20210319230406702](https://gitee.com/HappyBinbin/pcigo/raw/master/pic/20210319230406.png)

其中的repo为 **UserName/仓库名称** 格式

这个UserName是下面这个，也就是个人主页头像下的@后面那段名字

![image-20210319233115993](https://gitee.com/HappyBinbin/pcigo/raw/master/pic/20210319233116.png)

branch填入master

Token为刚才在Gitee生成的私人令牌，粘贴到这里就行

path为仓库下用于存储图片的路径，这个可以自行选择

最下边的origin部分选择gitee（默认是github）



### 一些问题

可能会在Typora + Picgo验证图片时出现问题，可以去查看它的日志文件来康康是什么问题

![image-20210319230637417](https://gitee.com/HappyBinbin/pcigo/raw/master/pic/20210319230637.png)

例如：

![image-20210319230733736](https://gitee.com/HappyBinbin/pcigo/raw/master/pic/20210319230733.png)