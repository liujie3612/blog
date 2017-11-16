---
title: 如何理解和熟练运用js中的call及apply?
date: 2017-11-16 21:41:28
tags:
- javascript
---

在知乎上看到一个很好的例子，题目就是“如何理解和熟练运用js中的call及apply？”，所以记录下来：

1、Call和Apply的作用完全一样

2、Call传递的是单个参数，Apply传递的是一个数组参数

3、Call和Apply可理解为--被准许使用的意思

<!--more-->

```
//亲戚家
var otherHome = {
   tips: '我家有电筒',
   flashLight: function(meg){
      if(!meg) meg = '';
      console.log(this.tips + meg)
   }
}
//我的家
var myHome = {
   tips:'我的家穷啊，',
}
otherHome.flashLight();//我家里有电筒
otherHome.flashLight.call(myHome,'借你家电筒用一下');//我的家穷啊，借你家电筒用一下

//理解为亲戚允许我使用他家的电筒了
//现在我的家可以说是这个样子的
var myHome = {
   tips:'我的家穷啊，',
   //注意：下面的代码不是真的在myHome里了，只是在执行
   //otherHome.flashLight.call(myHome,'借你家电筒用一下')的时候类似于下面这种形式而已
   //你可以打印一下myHome其实还是没变的，
   //当然，手电筒怎么可能真给你，只是借你用一下而已
   flashLight: function(meg){
      if(!meg) meg = '';
      console.log(this.tips + meg)
   }
}
```


