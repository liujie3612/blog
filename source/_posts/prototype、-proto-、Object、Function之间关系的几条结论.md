---
title: js的几条结论
date: 2017-04-02 11:01:04
tags:
- javascript
- 前端
---

`prototype`、`__proto__`、`Object`、`Function`之间关系的几条结论，记住后再在实际的工作中慢慢体会，真正理解后会对js底层理论有很大的帮助。
<!-- more -->

### 结论1：Object.prototype只是一个普通对象，它是js原型链的最顶端
``` js
(typeof Object.prototype) === object;//true  
Object.prototype.__proto__=== null;//true  
Object.prototype.prototype === undefied;//true  
```
Object.prototype只是一个普通对象(普通对象没有prototype属性，所以值是undefined)，Object.prototype是js原型链的最顶端，它的__proto__是null(有__proto__属性，但值是null，因为这是原型链的最顶端)。

### 结论2：在js中如果A对象是由B函数构造的，那么A.__proto__ === B.prototype
``` js
function Person() { }  
var obj = {};  
alert(obj.__proto__ === Object.prototype);//true  
alert(Person.__proto__ === Function.prototype);//true   
```
javascript中对象是由Object创建的，函数是由Function创建的

### 结论3：内置的Object是其实也是一个函数对象，它是由Function创建的
``` js
Object.__proto__ === Function.prototype;  
```

### 结论4：js中每一个对象或函数都有__proto__属性，但是只有函数对象才有prototype属性。
``` js
//函数对象  
function Person() { }  
  
// 普通对象  
var obj = {};  
  
obj.__proto__ === Object.prototype;//true  
obj.prototype === undefined;//true  
Person.__proto__ === Function.prototype;//true  
Person.prototype !== undefined;//true  
```
我们知道javascript正是通过prototype实现继承的。如果objA、objB都是由cFunction创建的，那么根据结论2，objA.__proto__ === objB.__proto__ === cFunction.prototype，也就是说objA和objB对象都继承了cFunction的prototype。原型链是基于__proto__形成的，继承是通过prototype实现的。

### 结论5：Function.prototype是个特例，它是函数对象，但是没有prototype属性。其他所有函数都有prototype属性。
``` js
(typeof Function.prototype) === function;//true  
Function.prototype.prototype === undefined;//true  
```

### 结论6：内置的Function也是一个函数对象，它是通过自己来创建自己的。
``` js
(typeof Function.__proto__) === function;//true  
Function.__proto__=== Function.prototype;//true  
```
Function这个函数对象,由其自身通过Function函数构造的。

### 结论7：函数也是对象，因为Function.prototype.__proto__指向Object.prototype。
``` js
(typeof Function.prototype.__proto__) === "object";//true  
Function.prototype.__proto__=== Object.prototype;//true
```
最后提一下：<span style="color: rgb(230,80,30)"> 原型链是基于`__proto__`形成的，继承是通过`prototype`实现的。 </span>

每个对象都有一个`__proto__`属性，原型链上的对象正是依靠这个`__proto__`属性连结在一起的!  对于原型链上的一个对象obj，那么访问obj.xxx属性(方法也是属性)的过程是: 如果自身有xxx属性，则访问它；如果没有，就通过`__proto__`属性找到其原型链的上一级原型对象，看它有没有xxx属性，如此递归查找，直至找到xxx属性或到了原型链顶端`Object.prototype`对象为止。

函数拥有`prototype`属性，该属性值是一个object类型。当函数A创建对象B的时候，B对象的`__proto__`会指向`A.prototype`，这就是javascript的继承。
