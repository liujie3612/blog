---
title: 关于官网首页优化的建议
date: 2018-05-19 15:24:44
tags:
- 前端优化
---

## 背景目的
* 让官网首页加载速度更快，对用户的操作响应得更及时，给用户提供更为友好的体验。
* 减少页面请求数，减小请求所占带宽，节省资源。

## 优化手段
按粒度分为两类：
* 页面级别优化（HTTP请求数，资源合并压缩，资源加载时机等）
* 代码级别优化（DOM操作优化、CSS选择符优化、HTML结构优化）

<!--more-->

## 具体措施

### 页面级别优化

<!-- #### 减少HTTP请求数 -->
页面级别的优化目标基本就是如何减少HTTP请求数，减少请求资源的体积。每个请求都是有成本的，既包含时间成本也包含资源成本（一个完整的请求都需要经过DNS寻址、与服务器建立连接、发送数据、等待服务器响应、接收数据这样一个 “漫长” 而又复杂的过程）

#### 1. 静态资源的合并和压缩
根据静态文件的类型，可以借助gulp工具将js文件和css文件进行合并和压缩。
例如官网项目里css文件有七个，js文件有十几二十多个,合并压缩静态资源后可以减少http的开销。
![](https://cdn.liujiefront.com/images/web-optimization/1.png)
我们将不经常改变的资源(例如jquery、各种lib库、插件等)全部合并压缩成一个文件，命名为vender.css、vender.js。经常改变上线的文件合并压缩成一个文件，命名为index.css，index.js,并且加上hash戳，index等文件每次上线内容基本都是会改变的，那么gulp自动构建后加上的hash戳也是不一样的，而vender类型不变，这样我们就能合理利用浏览器的缓存机制了。

#### 2. 图片的处理
* 使用jq的`lazyload`插件实现图片懒加载。等滚动条滚动到对应的地方再加载所需要的图片资源。
* 不直接使用设计给的两倍图，用css的`devicePixelRatio`检查设备的像素比，辅助区分视网膜设备还是非视网膜设备来决定加载两倍图还是原始大小的图片。
* 图片上传到cdn之前在保证不失真的情况下，用`gulp-imagemin`工具压缩下大小。
* 将下图这样的小图片全部做成雪碧图，单色可以考虑用`icon-font`来实现。或者直接在页面写svg代码和转成base64写到页面也行，总之是要减少http的请求数。
![](https://cdn.liujiefront.com/images/web-optimization/2.png)

#### 3. 首屏加载
将首屏第一时间呈现给用户。
具体的做法是除了首屏dom元素之外,将所有的dom元素用一个`template`元素进行包裹，等window监听到load事件后，将剩余的dom部分全部插到页面中。（tips：为避免用户可能还没等到window的load事件就开始滚动页面，可以将首屏的范围扩大。）

#### 4. DNS预读取
DNS预读取是一项使浏览器主动去执行域名解析的功能。DNS请求需要的带宽非常小，但是延迟却有点高。
下面是引用MDN的一句话：
> 在某些浏览器中这个预读取的行为将会与页面实际内容并行发生（而不是串行）。正因如此，某些高延迟的域名的解析过程才不会卡住资源的加载。
> 这样可以极大的加速（尤其是移动网络环境下）页面的加载。在某些图片较多的页面中，在发起图片加载请求之前预先把域名解析好将会有至少 5% 的图片加载速度提升。

具体做法：
`head`标签里加上
```
<link rel="dns-prefetch" href="https://data.dadaabc.com/">
```
`data.dadaabc.com`为静态资源的域名，如还有其他链接的域名，都一起加进去。

#### 5. 多域名分发静态资源
同域下浏览器能并发的请求有限，为了增加并发，尤其是一些静态资源上，可以使用多个域名。但由于域名DNS解析本身也是耗时的，所以也不是越多越好，chrome最大支持6路并发，所以一般设置2-4个域名较为合适。
具体的做法是：再增加cdn域名来下载静态资源。比如图片全部用`img.dadaabc.com/`域名,css资源全部用`css.dadaabc.com/`域名，这些域名最终全部指向同样的cdn服务器。静态资源域名加前缀可以用`gulp-rev-replace`来实现。

#### 6. 统计代码
统计代码全部放到window的load事件之后执行。为了便于管理统计代码，例如页面加上一些埋点，增加删除统计产品，我们可以借助`Google Tag Manager`工具来统一管理。
具体做法是：页面只拉取`Google Tag Manager`提供的`gtm`代码，该js代码含有全部的统计产品，例如百度、Inspelect等， 这些统计产品也都是通过创建script标签来动态插入到页面中的。另外需要注意的是，google提供的`gtm`代码是在google服务器上的，为了让获取该代码的速度更快，我们可以在自己的服务器上执行`crontab`定时任务，每分钟获取一次，然后`gtm`代码直接从自己服务器上获取。

### 代码级别优化

#### 1. 合理的dom结构
css文件全部放到`head`里，script文件全部放到`body`的最底部。
原因：
把样式表移到`head`里允许页面逐步渲染。
浏览器负责渲染的GUI渲染线程与JS引擎线程是互斥的，当JS引擎执行时GUI线程会被挂起（相当于被冻结了），GUI更新会被保存在一个队列中等到JS引擎空闲时立即被执行。
![](https://cdn.liujiefront.com/images/web-optimization/3.png)
参考资料：[从浏览器多进程到JS单线程，JS运行机制最全面的一次梳理](https://mp.weixin.qq.com/s/GFUivceIlbjVDfcJibnVOg)

#### 2. 最小化重排和重绘

<h5 style="font-size: 14px;">多个属性改变一次性写：</h5>举个例子：
```
var ele = document.getElementById('myDiv');
ele.style.borderLeft = '1px';
ele.style.borderRight = '2px';
ele.style.padding = '5px';
```
三个样式属性被改变，每一个都会影响元素的几何结构，虽然大部分现代浏览器都做了优化，只会引起一次重排，但是像上文一样，如果一个及时的属性被请求，那么就会强制刷新队列，而且这段代码四次访问DOM，一个很显然的优化策略就是把它们的操作合成一次，这样只会修改DOM一次：
```
var ele = document.getElementById('myDiv');
ele.style.cssText = 'border-left: 1px; border-right: 2px; padding: 5px;';
```
总结：同一个DOM的多个属性改变可以写在一起（减少DOM访问，同时把强制渲染队列刷新的风险降为0）

<h5 style="font-size: 14px;">fragment元素的应用：</h5>fragment是个轻量级的document对象，它的设计初衷就是为了完成更新和移动节点这样的任务。fragment的一个便利的语法特性是当你附加一个片断到节点时，实际上被添加的是该片断的子节点，而不是片断本身。只触发了一次重排，而且只访问了一次实时的DOM。
例如：
``` js
var fragment = document.createDocumentFragment();

var li = document.createElement('li');
li.innerHTML = 'apple';
fragment.appendChild(li);

var li = document.createElement('li');
li.innerHTML = 'watermelon';
fragment.appendChild(li);

document.getElementById('fruit').appendChild(fragment);
```
参考资料：[重排和重绘](http://www.cnblogs.com/zichi/p/4720000.html)

#### 3. 函数防抖和函数节流
触发大量回调函数的事件，例如拖拽时的`mousemove`事件，window对象的`resize`、`scroll`事件，文字输入、自动完成的`keyup`事件等，需要合理使用函数防抖和函数节流机制。具体可以参考我的另外一篇文章[函数防抖和函数节流](https://blog.liujiefront.com/2018/04/27/throttle-debounce/)

#### 4. CSS选择器
CSS选择器的解析式其实是**从右到左**的，例如：
``` css
#div1 a {
    color: red
}
```
如上面的选择器，浏览器必须遍历查找所有的a元素，再去找ID为div1的元素，这样查找的方式显然很低效。















