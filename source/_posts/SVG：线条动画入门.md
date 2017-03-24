---
title: SVG：线条动画入门
date: 2017-03-24 18:38:45
tags: 
- SVG
- 前端
---

本文讨论的主题是 SVG Path 动画(路径动画)。之所以要讨论这个话题，是因为在项目中有要求用到它。所谓 SVG Path 动画，就是让图形有像人实时绘制一样的动画效果

<!-- more -->

## 1 基础知识

开始 SVG Path 动画之前，你需要先准备一些基础知识，主要是SVG是什么，以及 Path（路径） 和 Stroke （描边）这两个概念。 

### 1.1 SVG

SVG 指可伸缩矢量图形 (Scalable Vector Graphics)，因此，SVG 图像在放大或改变尺寸的情况下其图形质量不会有所损失。SVG 除了制作图像之外，还有各种用途，比如动画、 ICONFONT等。

兼容性
![](/images/svg/jianrongxing@2x.png)

### 1.2 path(路径)

`path` 元素是 SVG 基本形状中最强大的一个，它不仅能创建其他基本形状，还能创建更多其他形状。另外，path 只需要设定很少的点，就可以创建平滑流畅的线条（比如曲线）。

![](/images/svg/line.png)

``` html
<svg>
 <path d="M100 100, A120 120, -45 0 1, 300 300 A120 120, -45 0 1, 100 100"
  stroke="#05D380" stroke-width="2"
  fill="none"/>
</svg>
```

### 1.3 stroke(描边)

要实现绘制动画效果，除了 `path` 外，还要依靠 `stroke` 的两个重要属性来完成，即 `stroke-dasharray` 和 `stroke-dashoffset`。
- 属性 `stroke-dasharray`：该值可能由两个值合写，使用英文逗号(`,`)分隔，第一个值是画出的每段实线线段的长度，第二个值是各段之间空隙的长度。如果无分隔，则说明两个值都是一样大小的。
- 属性 `stroke-dashoffset`：指定每个实线线段的起始偏移量。正数从路径起始点向前偏移，负数则向后。
举例而言，如果要实现类似 CSS 中 `border-style: dotted`; 这样的虚线效果，则可以设置 `stroke-dasharray:5,10`，第一个数字表示每一段实线长度为 `5`，第二个表示实线直接间隔长度为 `10`。

### 1.4 CSS 控制

我们将 SVG 代码插入到 HTML 文件中，SVG本身也是一种DOM节点，能使用CSS属性控制。例如上例也可以改成这样。我们为 `path` 定义了一个样式类 `mypath`，并在 `<style>` 中进行定义：

``` html
<style>
.mypath {
    stroke: #05D380;
    stroke-width: 2;
    stroke-dasharray: 5, 10;
    fill: none;
}
</style>

<svg>
    <path d="M100 100, A120 120, -45 0 1, 300 300 A120 120, -45 0 1, 100 100" class="mypath" />
</svg>
```

### 1.5 CSS3 的 keyframes 和 animation

要动画，就需要借助 CSS3 的 `keyframes` 和 `animation` 此处知识略。

## 2 实践

好了废话不多少，现在就讲解实际的操作

### 2.1 你有一个SVG图形

<!-- ![](/images/svg/sharp.png) -->
<img src="/images/svg/sharp.png" width="300">

### 2.2 这个图形必须要有一个线条`stroke`属性

<!-- ![](/images/svg/stroke.png) -->
<img src="/images/svg/stroke.png" width="500">

### 2.3 线条可以是虚线

我们可以用Illustrator制作，也可以用编程实现。我们用CSS来设置这些路径的样式(假定我们这里是inline SVG，或通过一个`<object>`)，把它们变成虚线形式。

``` html
<svg ...>    <path class="path" stroke="#000000" ... >  </svg>

```
``` html
<svg ...>    <path class="path" stroke="#000000" ... >  </svg>
```

这是让虚线里的每个小线段长度为20px。

<!-- ![](/images/svg/dash.png) -->
<img src="/images/svg/dash.png" width="300">

### 2.4 可以让虚线小段的长度变得更长…

``` html
.path {
  stroke-dasharray: 100;
```
![](/images/svg/long-dashes.png)

### 2.5 我们还可以给我们的线条设置”offset”偏移量，这样会导致虚线里的小线段的位置发生移动。

当我们动态设置图形中线条的“offset”值时，可以看到这个效果：

![](/images/svg/animate-stroke.gif)

``` css
.path {
  stroke-dasharray: 100;
  animation: dash 5s linear;
}

@keyframes dash {
  to {
    stroke-dashoffset: 1000;
  }
}
```

### 2.6 想象，当虚线的小线条足够长，超过图形的整个线条长度时

没有什么变化，整个图像看起来完全不是虚线。你只需要将`stroke-dasharray`属性设置的足够长，超过整个线条的长度。

### 2.7 现在给线条设置偏移量，让它不再覆盖整个图形。

这样你就看不见图形了。

### 2.8 现在动态的慢慢将线条的偏移量设置回归到0

![](/images/svg/animate-stroke-full.gif)

如果通过CSS，你需要将`animation`属性设置成`forwards`，这样整个动画就会停止在它的最终状态。

``` css
.path {
  stroke-dasharray: 1000;
  stroke-dashoffset: 1000;
  animation: dash 5s linear forwards;
}

@keyframes dash {
  to {
    stroke-dashoffset: 0;
  }
}
```

### 2.9 为什么需要JavaScript

部分你看到的SVG线条动画都使用了JavaScript。这是因为在现实情况中你很难知道线条有多长。我们这里设置的是1000，是因为它碰巧是1000。

用JavaScript获取长度值的写法是这样的：

``` js
var path = document.querySelector('.path');
var length = path.getTotalLength();
```

然后你就可以随便使用这个值了。




