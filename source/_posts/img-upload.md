---
title: 图片上传组件开发
date: 2018-02-05 14:20:12
tags:
- canvas
- 前端
---

图片上传，作为web端一个常用的功能，在不同的项目中有不同的需求，在这里实现一个比价基本的上传图片插件，主要能实现图片的浏览，剪裁，上传这三个功能，同时也是为了让自己对图片／文件上传和HTML5中名声在外的 canvas相关能够有一些了解。一般的图片上传模块，主要就是实现了三个功能，图片的预览，图片的剪裁及预览。

<!--more-->

## 预览图片

用户使用：用户点击“选择图片”，弹出文件浏览器，可以选择本地的图片，点击确认后，所选图片会按照原始比例出现在页面的浏览区域中。

组件调用：开发者可以自己定义图片预览区域的大小，并限定所传图片的文件大小和尺寸大小。

## 剪裁图片

用户使用：用户根据提示，在预览区域的图片上拖动鼠标框出想要上传的图片区域，并且能在结果预览区域看到自己的剪裁结果。

组件调用：开发者可以自定义是否剪裁图片，并可以定义是否限定剪裁图片的大小及比例，并且设定具体大小及比例。

## 上传图片

用户使用：用户点击“图片上传”，图片开始上传，现实“上传中…”，完成后显示“上传完成”。

组件调用：开发者得到base64格式的urlData图片，自己编写调用Ajax的函数及其回调函数。

## 原型图

### state-1 初始状态

![](https://cdn.liujiefront.com/images/img-upload/640.webp)

### state-2:点击”选择图片”，浏览本地后载入图片

![](https://cdn.liujiefront.com/images/img-upload/1.webp)

### state-3:剪裁，在图片区域上拖动鼠标选择要剪裁的部分，确认要上传的部分

![](https://cdn.liujiefront.com/images/img-upload/2.webp)

## 读取本地图片

### 图片的选择

```
<input id="inputArea" type="file"/>
```

那么问题来了：
1. 默认的输入框的样式很难看，而且不好用css修改
2. 怎么上传数据

问题一的解决办法一般是让这个控件的透明度为0，再用一个好看的div盖在上面，实际点击的时候还是点击的这个控件。
问题二就要介绍下FormData对象了

> XMLHttpRequest Level 2添加了一个新的接口FormData.利用FormData对象,我们可以通过JavaScript用一些键值对来模拟一系列表单控件,我们还可以使用XMLHttpRequest的send()方法来异步的提交这个”表单”.比起普通的ajax,使用FormData的最大优点就是我们可以异步上传一个二进制文件.

正如上面的文档所说FormData对象可以干的事无非就是用javascript模拟表单控件，也正因为如此所以可以在模拟的表单中放入一个文件

``` js
var myFrom = new FormData();
var imageData = imgFrom.files[0];//获取表单中第一个文件
myFrom.append("image",imageDate);//向表单中添加一个键值对
console.log(myFrom.getAll("image"));//获取表单中image字段对应的值，结果见下图
```

![](https://cdn.liujiefront.com/images/img-upload/file.png)
正如我们所见，文件我们已经通过Web拿到手了

### 图片的预览

既然是要上传图片，我们肯定得知道自己传的是啥图片啊，所以下一步就是如何把读取的图片展现在页面上了，正如上图中的显示，我的得到的图片是一个File对象，而File对象是特殊的Blob对象，那Blob对象又是个啥呢…

> Blob 对象表示不可变的类似文件对象的原始数据。Blob表示不一定是JavaScript原生形式的数据。File 接口基于Blob，继承了 blob的功能并将其扩展使其支持用户系统上的文件。

Blob对象是用来表示／承载文件对象的原始数据（二进制）的,了解一下有个概念即可，重点在于我们怎么展示这个File对象。这就要请出FileReader对象了

> FileReader 对象允许Web应用程序异步读取存储在用户计算机上的文件（或原始数据缓冲区）的内容，使用 File 或 Blob 对象指定要读取的文件或数据。

不难看出，FileReader对象就是用来读取本地文件的，而这其方法`readAsDataURL()`就是我们要用的东西啦

> 该方法会读取指定的 Blob 或 File 对象。读取操作完成的时候，readyState 会变成已完成（DONE），并触发 loadend 事件，同时 result 属性将包含一个data:URL格式的字符串（base64编码）以表示所读取文件的内容。

这里面又提到一个新名词`data:URL`，也就是说readAsDataURL()的作用就是能把文件转换为data:URL，不过这个data:URL又是什么呢，执行来看看

``` js
var reader = new FileReader(); //调用FileReader对象
reader.readAsDataURL(imgData); //通过DataURL的方式返回图像
reader.onload = function(e) {
    console.log(e.target.result);//看看你是个啥
}
```
![](https://cdn.liujiefront.com/images/img-upload/console.png)

说到底这dataURL我就粗略的理解它为URL形式的data，也就是说这段URL并不是与普通的URL一样指向某个地址，而是它本身就是数据，我们试着把这一堆字符粘到一个`<img>`的src属性中
![](https://cdn.liujiefront.com/images/img-upload/3.webp)

终于看到了，结果正如所料，将这段包含了数据的URL赋给一个`<img>`确实可以让数据被展现为图片
至此，我们实现了本地文件的读取及展现

## 利用canvas截取图片

在Web上对图像进行操作，没有比canvas相关技术更合适的了，所以本文用canvas技术来实现对图片的截取

### canvas中的图片展现

在上文中，我们利用`<img>`展现出了我们选择的图片，但是我们的图片截取功能可是要利用来实现的，所以怎么在中展现我们刚才获取的图片就是下一步要干的事情了
canvas的API中自带drawImage()函数，其作用就是在中渲染一张图片出来，其可以支持多种图片

最简单的，我们直接把刚刚显示图片的那个`<img>`传入是不是就可以呢

``` js
var theCanvas = document.getElementById("imgCanvas");
var canvasImg = theCanvas.getContext("2d");//获取2D渲染背景
var img = document.getElementById("image");
img.onload = function(){//确认图片已载入
    canvasImg.drawImage(img,0,0);
}
```

结果如下
![](https://cdn.liujiefront.com/images/img-upload/4.webp)

从图中看，左侧是之前的`<img>`，右侧是渲染了图片信息的`<canvas>`
这么看来虽然成功？在`<canvas>`中渲染出了图片但是有两个明显的问题

1. 左边的`<img>`留着干啥？
2. 右边看上去是不是有点不一样？

这俩问题其实都好办，针对第一个问题，我们其实可以根本不用实体的`<img>`直接利用`Image`对象即可，第二个问题明显是因为的大小与获取到的图片大小不一致所产生的，综合这两点，对代码进行进化！

``` js
var theCanvas = document.getElementById("imgCanvas");
var canvasImg = theCanvas.getContext("2d");
var img = new Image();//创建img对象

reader.onload = function(e) {
    img.src = e.target.result;
}

img.onload = function(){
    theCanvas.Width = img.width;//将img对象的长款赋给canvas标签
    theCanvas.height = img.height;
    canvasImg.drawImage(img,0,0);
}
```

![](https://cdn.liujiefront.com/images/img-upload/5.webp)

结果与我们所期待的一样，至此我们成功的在`<canvas>`中展现了从本地获取的图片

## 截取canvas中的图片

其实截图，说白了就是在一个图像上，获取某个区域中的图像信息
canvas作为专门用来处理图像及像素相关的一套API，获取区域中的相关图像信息可以说是再简单不过的事情，利用getImageData()函数即可 [//详情](https://developer.mozilla.org/en-US/docs/Web/API/CanvasRenderingContext2D/getImageData)， 当然我们不光要把图像信息获取到，最好还能展现出来我们的截图结果，这里就要用到与之相对的putImageData()函数 [//详情](https://developer.mozilla.org/en-US/docs/Web/API/CanvasRenderingContext2D/putImageData)

``` js
var resultCanvas = document.getElementById("resultCanvas");
var resultImg = resultCanvas.getContext("2d");
var cutData = canvasImg.getImageData(100,100,200,200);
resultImg.putImageData(cutData,0,0);
```

![](https://cdn.liujiefront.com/images/img-upload/6.webp)

### 区域截取

既然这个工具是面向用户的，截图的过程肯定是要所见即所得的，在函数getImageData()中有4个参数，分别是截图起点的两个坐标和区域的宽度及高度，所以问题就变成了如何更合理的让用户输入这4个值。
其实现存的主流解决方案就做的非常好了：在图上拖动鼠标，拉出一个框，这个框内就是用户希望截取的区域。

在画布上画出一个框很简单，只需用到strokeRect()函数 [//详情](https://developer.mozilla.org/en-US/docs/Web/API/CanvasRenderingContext2D/strokeRect)
但是让用户自己拖出一个框就比较复杂了，先分析一下用户的一套动作都有什么

1. 用户选定起始点，点下鼠标左键
2. 用户选定截图区域的大小，保持鼠标左键不抬起，同时移动鼠标选择
3. 用户完成选择，抬起鼠标左键

回过头再来看程序需要干什么

1. 获取起始点的坐标，并记录为已点击状态
2. 判断一下如果为已点击状态那么，获取每一次移动／帧的鼠标坐标，并计算出与起始点之间的横纵坐标距离，而这距离就是所画框的长度和宽度，清除上一帧的整个画面，再绘制一个新的图片再画一个新的框，同时按照框的起始坐标及宽高，截取图像信息，再清除预览区域的上一帧的画布，再将这一帧的图像信息载入
3.

在这里，要说明一下，为什么非要清除整个画面不可，其实可以把通过canvas.getContext("2d")获取到的[2D 画布的渲染上下文](https://developer.mozilla.org/zh-CN/docs/Web/API/HTMLCanvasElement/getContext)就当作一块画布，已经渲染出来的东西就已经留在了上面，无法再修改，如果想要更改画面上已经存在的元素的大小位置形状等等属性，那么在程序层面，就只能（个人理解，不一定对，如果有问题请一定跟我唠唠）把之前的画布清空再重新渲染。

这个思路与我们之前端开发中动画相关的开发思路不同，并不是像之前那样直接操作现有元素属性就可以改变该元素在画面上的呈现结果的，而在这里其实更像是在现实生活中的动画制作原理就是

#### 每一帧都需要重新绘制整张画面

而其实这是任何动画渲染方式的最底层思路与行为

话说回来按照上文相关的开发思路，实现这个功能的代码如下

``` js
var flag = false;//记录是否为点击状态的标记
var W = img.width;
var H = img.height;
var startX = 0;
var startY = 0;

//当鼠标被按下
theCanvas.addEventListener("mousedown", e => {
    flag = true;//改变标记状态，置为点击状态
    startX = e.clientX;//获得起始点横坐标
    startY = e.clientY;//获得起始点纵坐标
})

//当鼠标在移动
theCanvas.addEventListener("mousemove", e => {
    if(flag){//判断鼠标是否被拖动
        canvasImg.clearRect(0,0,W,H);//清空整个画面
        canvasImg.drawImage(img,0,0);//重新绘制图片
        canvasImg.strokeRect(startX, startY, e.clientX - startX, e.clientY - startY);//绘制黑框
        resultImg.clearRect(0,0,cutData.width,cutData.height);//清空预览区域
        cutData = canvasImg.getImageData(startX, startY, e.clientX - startX, e.clientY - startY);//截取黑框区域图片信息
        resultImg.putImageData(cutData,0,0);//将图片信息赋给预览区域
    }
})

//当鼠标左键抬起
theCanvas.addEventListener("mouseup", e => {
    flag = false;//将标志置为已抬起状态
})
```
结果如图

![](https://cdn.liujiefront.com/images/img-upload/7.webp)

### 优化

主要吧，这个黑框太丑了，透露着一种原始和狂野，以及来自工科男审美的粗糙感…
能不能弄的好看点，起码让它看上去是一个工具不是一个实验

我的想法是这样的，待被截取的图片上应该蒙上一层半透明白色遮罩，用户框选出的部分是没有遮罩的，这样效果可以为功能增加视觉上的材质感及舒适感，同时显得高端

具体效果是这样的-下图来自ps

![](https://cdn.liujiefront.com/images/img-upload/8.webp)

是不是稍微好些了

可是，怎么实现？
简单来说，就是在原有的画布上再蒙半透明的一层画布，然后让这一层有一部分是没有的就可以实现了，总的来说就是蒙版和遮罩的思路，在canvas中也有[相关的api](https://developer.mozilla.org/en-US/docs/Web/API/Canvas_API/Tutorial/Compositing)

见下图
![](https://cdn.liujiefront.com/images/img-upload/9.webp)

mask层可以分为A，B，C，D四个矩形区域，在图中两个蓝色的点是已知的（用户自己画出来的），在下层图片大小已知的前提下，这四个矩形区域的四个点都是可以计算出来的，从而其高度和宽度也可以计算出来，这样就可以利用这些数据画出一个半透明的矩形，将四个半透明矩形都画出来后，就能够实现之前设计出的效果了，具体代码如下

``` js
theCanvas.addEventListener("mousemove", e => {
    if(flag){
        canvasImg.clearRect(0,0,W,H);
        resultImg.clearRect(0,0,cutData.width,cutData.height);
        canvasImg.drawImage(img,0,0);
        canvasImg.fillStyle = 'rgba(255,255,255,0.6)';//设定为半透明的白色
        canvasImg.fillRect(0, 0, e.clientX, startY);//矩形A
        canvasImg.fillRect(e.clientX, 0, W, e.clientY);//矩形B
canvasImg.fillRect(startX, e.clientY, W-startX, H-e.clientY);//矩形C
        canvasImg.fillRect(0, startY, startX, H-startY);//矩形D
        cutData = canvasImg.getImageData(startX, startY, e.clientX - startX, e.clientY - startY);
        resultImg.putImageData(cutData,0,0);
    }
})
```

效果如图
![](https://cdn.liujiefront.com/images/img-upload/10.webp)

至此，截图的基本功能都实现了，但还差最后一步

## 图片上传

图片已经截出来了，下一步就是怎么上传了，通过Ajax上传，需要将图像数据转化为File，而在canvas的API中自带[toBlob()函数](https://developer.mozilla.org/zh-CN/docs/Web/API/HTMLCanvasElement/toBlob)

``` js
var resultFile = {}
theCanvas.addEventListener("mouseup", e => {
    resultCanvas.toBlob(blob => {
            resultFile = blob;
            console.log(blob);//Blob(1797) {size: 1797, type: "image/png"}
        }
    })
    flag = false;
})
```

然后就可以用Ajax上传拉，具体怎么上传就需要具体问题具体分析了。

原文出自：[实战：图片上传组件开发](http://web.jobbole.com/93946/)



















