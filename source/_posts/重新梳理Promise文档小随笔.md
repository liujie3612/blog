---
title: 重新梳理Promise文档小随笔
date: 2020-04-02 16:37:04
tags: 
- Promise
- 前端进阶
---

Promise是大家都耳熟能详的一个知识点了，平时项目中也用的很多，总的来说Promise 是异步编程的一种解决方案，相当于一个容器，保存了同步或者异步（一般来说都是异步）的事件的执行结果，昨天看了一些关于Promise/A+的文章，想实现一下以便更深入的理解Promise的概念，所以基于这样的一个背景，这篇文章就先通篇梳理下Promise的知识体系,当然参考的文章主要还是阮老师的这[文章](https://es6.ruanyifeng.com/#docs/promise)

<!--more-->

## Promise：
1. Promise接受函数作为参数，函数的参数分别为resolve和reject，resolve和reject本身也是两个函数，js引擎提供，不需要单独部署；
2. then接受的参数分别为两个回调函数，两个函数都接受Promise对象传出的值作为参数
3. Promise里的resolve函数接受的值：正常值，Promise实例
4. 一般来讲调用了resolve和reject，Promise的使命就结束了，后续的操作都放到then进行
5. reject方法的作用，等同于抛出错误
6. Promise对象抛出的错误不会传递到外层代码，也就是说“Promise会吃掉错误”

## prototype.then、prototype.catch、prototype.finally：
1. then和catch返回的是一个新的Promise实例
2. catch是.then(null,rejection)或者.then(undefined,rejection)的别名
3. 一般来讲，不要在then里定义第二个回调函数，而总是用catch方法
4. finally不管promise对象最后的状态，都会执行的操作
5. 源代码：
   
``` javascript
Promise.prototype.finally = function (callback) {
  let P = this.constructor;
  return this.then(
    value  => P.resolve(callback()).then(() => value),
    reason => P.resolve(callback()).then(() => { throw reason })
  );
};
```
resolve接收callback函数，立即执行； 转化为promise对象都执行then方法；

## Promise.all:
1. 接收数组作为参数，都是Promise的实例，如果不是就调用resolve方法
2. 如果不是数组的话，就必须有Iterator接口，且返回成的成员都是Promise实例
3. 都成功才会resolved，返回值组成数组，给p的回调函数
4. 有一个失败，第一个失败的promise实例的返回值给p的回调函数

## Promise.race:

## Promise.allSettled:
1. 状态只可能是resolved，也就是then来接收
2. 不关心结果，只关心有没结束

## Promise.any
1. 有一个成功就成功，都失败就失败
2. 如果抛出错误，相当于一个数组

## Promise.resolve:
1. 将现有对象转化为promise对象
2. 四种情况：
  * Promise实例：不做修改，直接返回
  * thenable对象，有then方法的对象，转为Promise后立即执行thenable里的then的方法，返回一个promise对象
  * 普通对象，或者不是对象
  * 没有参数
  
## Promise.reject:
1. 也返回一个新的promise实例，但是状态是rejected，所以then不起作用

## Promise.try:
