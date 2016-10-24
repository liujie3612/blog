layout: w
title: Canvas粒子动画
date: 2016-10-24 11:04:34
tags: Canvas
---

首先来看下我们准备要做的粒子动画效果是怎么样的~

![](/images/canvas_lizi/0.gif)

<!-- more -->

![](/images/canvas_lizi/1.gif)

![](/images/canvas_lizi/2.gif)

是不是很酷炫呢？那如何去实现类似上面的粒子动画甚至根据自己的喜好去做更多其他轨迹的动画呢~请看下面详细的讲解。

因为粒子数量很多，而且涉及到图像像素处理，所以这里使用Canvas是不二选择。（注意，以下演示的代码只是关键代码，重点在于解决思路。）

### 1.绘制粒子轮廓图

首先要在canvas画布上绘制一个由粒子组成的轮廓图，记录下每一个粒子的坐标，这样才能有后续的动画。

#### 1.创建一个canvas元素，并获取Canvas画布渲染上下文

``` html
<canvas id="canvas" width="600" height="400">你的的浏览器不支持Canvas</canvas>
<script>
    (function() {
        var canvas = document.getElementById('canvas')
        var ctx = null;
        if (canvas.getContext) {
            ctx = canvas.getContext('2d')
        }
    })()
</script>
```

&lt;canvas>是一个双标签元素，通过width和height的值来设置画布的大小。至于ctx（画布渲染上下文），可以理解为画布上的画笔，我们可以通过画笔在画布上随心所欲的绘制图案。如果浏览器不支持canvas会直接显示&lt;canvas>标签中间自己设定的文字。当然&lt;canvas>标签中间也可以是一张当不支持canvas时需要替换显示的图片。

#### 2. 使用canvas的图像操作API绘制图像

绘制图像的关键API及参数说明：

``` javascript
/*
  * 参数描述
  * image: image或者canvas对象
  * sx,sy 源对象的x，y坐标 可选
  * sWidth,sHeight 源对象的宽高，可选
  * dx,dy 画布上的x,y坐标
  * dWidth,dHeight 在画布上绘制的宽高 可选
*/

cxt.drawImage(image, sx, sy, sWidth, sHeight, dx, dy, dWidth, dHeight)
```

drawImage就是把一个image对象或者canvas上（甚至是video对象上的的每一帧）指定位置和尺寸的图像绘制到当前的画布上。而在我们的需求中，是要把整个图像绘制到画布中。

``` javascript
// 新建一个image对象
var image = new Image();
image.onload = function(argument) {
    //把加载完的图像绘制到画布上
    ctx.drawImage(image, 100, 100)
    //设置image的src
    image.src = 'http://liujiefront.com/images/canvas_lizi/lizi.png'
}
```

#### 3. 获取图像的像素信息，并根据像素信息重新绘制出粒子效果轮廓图
canvas有一个叫getImageData的接口，通过该接口可以获取到画布上指定位置的全部像素的数据：

``` javascript
/*
  * 参数描述
  * x,y画布上的x和y坐标
  * width,height 指定获取图像信息的区域宽高
*/

var imageData = ctx.getImageData(x,y,width,height)
```
把获取的imageData输出到控制台可以看到，imageData包含三个属性：

![](/images/canvas_lizi/console.png)

其中，width、height是读取图像像素信息完整区域的宽度和高度，data是一个Uint8ClampedArray类型的一维数组，包含了整个图片区域里每个像素点的RGBA的整型数据。这里必须要理解这个数组所保存像素信息的排序规则，请看下图描述的data数组：

![](/images/canvas_lizi/dataArr.png)

每一个色值占据data数组索引的一个位置，一个像素有个4个值（R、G、B、A）占据数组的4个索引位置。根据数列规则可以知道，要获取第n个位置（n从1开始）的R、G、B像素信息就是：Rn = (n-1)*4 ，Gn = (n-1)*4+1 ，Bn = (n-1)*4+2  ，so easy~  当然，实际上图像是一个包括image.height行，image.width列像素的矩形而不是单纯的一行到结束的，这个n值在矩形中要计算下：

![](/images/canvas_lizi/jisuan.png)

由于一个像素是带有4个索引值（rgba）的，所以拿到图像中第i行第j列的R、G、B、A像素信息就是 Rij = [(j-1)*imageData.width + (i-1)]*4 ，Gij = [(j-1)*imageData.width + (i-1)]*4 + 1，Bij = [(j-1)*imageData.width + (i-1)]*4 + 2，Aij = [(j-1)*imageData.width + (i-1)]*4 + 3 。每个像素值都可以拿到了!


接下来就要把图像的粒子化轮廓图画出来了。那么，怎么做这个轮廓图呢，我们先读取每个像素的信息(用到上面的计算公式)，如果这个像素的色值符合要求，就保存起来，用于绘制在画布上。另外，既然是做成粒子的效果，我们只需要把像素粒子保存一部分，展示在画布上。


具体做法是，设定每一行和每一列要显示的粒子数，分别是cols和rows，一个粒子代表一个单元格，那么每个单元格的的宽高就是imageWidth/cols和imageHeight/rows，然后循环的判断每个单元格的第一个像素是否满足像素值的条件，如果满足了，就把这个单元格的坐标保存到数组里，用作后续绘制图案用。


``` javascript
(function() {
  var particles = [];
  //计算并保存坐标
  function calculate() {
      var len = image.imageData.length;
      //只保存100行，100列的像素值
      var cols = 100,
          rows = 100;
      //设成150行，100列后每个单元的宽高
      var s_width = parseInt(image.w / cols),
          s_height = parseInt(image.h / rows);
      var pos = 0; //数组中的位置
      var par_x, par_y; //粒子的x,y坐标
      var data = image.imageData.data; //像素值数组
      for (var i = 0; i < cols; i++) {
          for (var j = 0; j < rows; j++) {
              //计算(i,j)在数组中的R的坐标值
              pos = (j * s_height * image.w + i * s_width) * 4;
              //判断像素透明度值是否符合要求
              if (data[pos + 3] > 100) {
                  var particle = {
                          //x,y值都随机一下
                          x: image.x + i * s_width + (Math.random() - 0.5) * 20,
                          y: image.y + j * s_height + (Math.random() - 0.5) * 20
                      }
                      // 根据图像不同的色值来设定粒子色值
                  if (data[pos + 1] < 175 && data[pos + 2] < 10) {
                      particle.fillStyle = '#ffa900';
                  } else if (data[pos + 1] < 75 && data[pos + 1] > 50) {
                      particle.fillStyle = '#ff4085';
                  } else if (data[pos + 1] < 220 && data[pos + 1] > 190) {
                      particle.fillStyle = '#00cfff';
                  } else if (data[pos + 1] < 195 && data[pos + 1] > 175) {
                      particle.fillStyle = '#9abc1c';
                  }
                  //符合要求的粒子保存到数组里
                  particles.push(particle);
              }
          }
      }
  }
  //绘图案
  function draw() {
      //清空画布					
      canvas.ctx.clearRect(0, 0, canvas.w, canvas.h);
      var len = particles.length;
      var curr_particle = null;
      for (var i = 0; i < len; i++) {
          curr_particle = particles[i];
          //设置填充颜色
          canvas.ctx.fillStyle = curr_particle.fillStyle;
          //绘粒子到画布上
          canvas.ctx.fillRect(curr_particle.x, curr_particle.y, 1, 1);
      }
  }
}())
```

用完整代码做出的demo及效果：

![](/images/canvas_lizi/demo)

至此，粒子轮廓图已经制作完成。

### 2. 制作粒子动画

制作粒子动画分两种：

一种是粒子漂浮类，这种比较简单，只需要随机的改变每个粒子的位置值，然后一直执行setInterval或者requestAnimationFrame重绘画布即可，具体的效果因人喜好而去设定，就不具体讲解了，做了个简单的粒子漂浮的例子。

另一种是粒子的轨迹动画，这个相对复杂一些。这里要介绍的是每个粒子按照指定的轨迹在指定的时间内做位移，最终汇聚成指定图案的动画效果（也就是文章一开始的动效），要做成这类动画效果需要解决两个问题：一个是动画轨迹，另外一个是每个粒子执行动画的时机。

#### 1. 粒子动画轨迹

动画位移的轨迹，最常见的就是单位时间内改变固定的位移值，从而达到动画效果。但要做到炫酷的效果依赖这种单调固定的位移肯定是不行的。所以位移可以依赖缓动函数去做到单位时间内改变不一样的位移值，从而达到特别的效果。

使用已有的缓动函数，不需要自己制定控制点，这里推荐出名的Tween算法的缓动函数，用其中一个缓动函数来介绍下参数值，其他缓动函数所传的参数值是一样的：


``` javascript
/*
  * 参数描述
  * t 动画执行到当前帧所经过的时间
  * b 起始的值
  * c 总的位移
  * d 持续时间
*/

function easeInOutExpo(t,b,c,d) {
  t /= d/2;
  if(t < 1) return c/2 * Math.pow(2, 10 * (t - 1) ) + b;
  t--;
  return c/2 * (-Math.pow( 2, -10 * t) + 2 ) + b;
}
```

是不是觉得很熟悉？对没错，jquery用的动画扩展插件easing.js就是Tween算法的缓动函数。有了这现成的缓动函数，就可以制定粒子的起始点、终点（终点就是图案本身的坐标位置）以及动画执行持续时间来做我们要的效果。

关键参考代码：

![](/images/canvas_lizi/code.png)

动画效果是有了，但总感觉不太对劲。。。唔，仔细观察一下，是图案动画执行太过整体了，没有明显的颗粒动画效果，这就引出粒子动画的另一个关键点，粒子执行动画的时机。

#### 2. 粒子执行动画的时机

要让粒子效果比较明显，那就不能让动画效果执行太过整体了，需要让图案上每个粒子有不同的时间间隔启动，根据一定的规律交错的执行动画。这里的粒子启动间隔有两种，一种是每一行粒子执行时间间隔，要让每一行的粒子启动时间有规律错开；另外一种是每一行粒子之间启动时间随机的错开，这样执行的粒子动画才会有一种层次感和每个粒子有独立动画的颗粒感。看下加了粒子启动时间间隔之后的效果对比：

![](/images/canvas_lizi/3.gif)

比上面不加粒子启动时间间隔的效果好多了。

ps:原文转自 [前端大全](http://mp.weixin.qq.com/s?__biz=MzAxODE2MjM1MA==&mid=2651551228&idx=1&sn=a36318b651dcd96ba47809884463dfc9&scene=0#wechat_redirect)



















