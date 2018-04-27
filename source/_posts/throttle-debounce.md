---
title: 轻松理解JS函数防抖和函数节流
date: 2018-04-27 14:13:53
tags:
- 函数
---

## 问题引入：

**问题1：**实现拖拽时的mousemove事件，window对象的resize、scroll事件，文字输入、自动完成的keyup事件等情况时，触发了大量的回调函数，导致了浏览器卡死，这时要怎么办？

**问题2：**如果给一个按钮绑定了表单提交的post事件，但是用户有些时候在网络情况极差的情况下多次点击按钮造成表单重复提交，如何防止多次提交的发生？

<!-- more -->

>为了应对如上场景，便出现了`函数防抖`和`函数节流`两个概念，总的来说：
这两个方法是在时间轴上控制函数的执行次数。

## 概念

* 函数防抖: 当调用动作过n毫秒后，才会执行该动作，若在这n毫秒内又调用此动作则将重新计算执行时间
* 函数节流: 预先设定一个执行周期，当调用动作的时刻大于等于执行周期则执行该动作，然后进入下一个新周期

这么说好像有点晦涩，可以拿我们平时坐电梯为例来形象地表述二者的区别

>函数防抖：如果有人进电梯（触发事件），那电梯将在10秒钟后出发（执行事件监听器），这时如果又有人进电梯了（在10秒内再次触发该事件），我们又得等10秒再出发（重新计时）。
>
>函数节流 ：如果电梯第一个人进来后，10秒后准时运送一次，这个时间开始计时，不等待，如果没有人，则不运行。

## 实现

### 函数防抖（debounce）

``` js
function _debounce(fn,wait){
    var timer = null;
    return function () {
      var context = this
      var args = arguments
      if (timer) {
          clearTimeout(timer);
          timer = null;
      }
      timer = setTimeout(function () {
          fn.apply(context, args)
      }, wait)
  }
}

function _log(){
    console.log(1)
}
window.onscroll = _debounce(_log,500)
```
之所以返回一个函数，因为防抖本身更像是一个函数修饰，所以就做了一次函数柯里化。里面也用到了闭包，闭包的变量是timer。

但是，仔细想想，上面的实现方式还是有一定的缺点。如果页面很长，我们一直在滚动页面，那_log方法就一直不会被执行。所以我们可以升级一下上述的防抖方法。

``` js
function _debounce(fn,wait,time){
    var previous = null; //记录上一次运行的时间
    var timer = null;

    return function(){
        var now = +new Date();

        if(!previous) previous = now;
        //当上一次执行的时间与当前的时间差大于设置的执行间隔时长的话，就主动执行一次
        if(now - previous > time){
            clearTimeout(timer);
            fn();
            previous = now;// 执行函数后，马上记录当前时间
        }else{
            clearTimeout(timer);
            timer = setTimeout(function(){
                fn();
            },wait);
        }
    }
}
function _log(){
    console.log(1)
}
window.onscroll = _debounce(_log,500,2000)
```

### 函数节流（throttle）

``` js
function _throttle(fn, time) {

  let _self = fn,
      timer,
      firstTime = true //记录是否是第一次执行的flag

  return function() {
    let args = arguments, //解决闭包传参问题
        _me = this //解决上下文丢失问题

    if(firstTime) { //若是第一次，则直接执行
      _self.apply(_me, args)
      return firstTime = false
    }
    if(timer) { //定时器存在，说明有事件监听器在执行，直接返回
      return false
    }

    timer = setTimeout(function() {
      clearTimeout(timer)
      timer = null
      _self.apply(_me, args)
    }, time || 500)
  }
}

function _log(){
    console.log(1)
}
window.onscroll = _throttle(_log,500)
```

## 应用场景

### 函数防抖

* 给按钮加函数防抖防止表单多次提交。
* 对于输入框连续输入进行AJAX验证时，用函数防抖能有效减少请求次数。
* 判断scroll是否滑到底部，滚动事件+函数防抖

> 总的来说，适合多次事件一次响应的情况


### 函数节流

* 游戏中的刷新率
* DOM元素拖拽
* Canvas画笔功能

> 总的来说，适合大量事件按时间做平均分配触发。

## 小结

函数防抖和函数节流是在`时间轴上控制函数的执行次数`。防抖可以类比为电梯不断上乘客,节流可以看做幻灯片限制频率播放电影。




