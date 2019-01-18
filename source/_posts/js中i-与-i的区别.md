---
title: js中i++与++i的区别
date: 2019-01-18 11:13:25
tags: 
- javascript
- 前端
---

在javascript中，我们常常搞不懂i++与++i的区别，今天我们就来简单说一下。
<!-- more -->

i++的例子:
``` javascript
var i=1;
console.log(i); // 输出1

var a=i++;
console.log(i); //输出2
console.log(a); //输出1
```

++i的例子:
``` javascript
var i=1;
console.log(i);// 输出1

var a=++i;
console.log(i); //输出2
console.log(a); //输出2
```

## 解释：
我们通过两个例子，可以看出其中不同，当使用i++赋值给a后，a的值为1，而使用++i赋值给a后，a的值为2，而两例中i最终都为2

## 结论：
1. 使用i++时，i先将自身的值赋值给变量a，然后再自增1
2. 使用++i时，i先将自身的值自增1,再将自增后的值赋值给变量a

## 原理：
运算符优先级
1. 我们知道，++作为后置递增时，优先级为16，而作为前置递增时，优先级为15
2. =作为赋值运算符时，优先级为3
3. 所以，++会优先于=而执行