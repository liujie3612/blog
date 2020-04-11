---
title: this、apply、call、bind
date: 2020-04-11 17:03:39
tags: 
- javascript
- this
- apply、call、bind
---

this指向问题应该是面试高频问题了，也确实是比较基础的一种问题，这两天在梳理PromiseA/+相关的东西，实现一个Promise类的时候，里面涉及到this指向问题，当时调试了几次才深刻感受到PromiseA/+的巧妙之处，再写实现PromiseA/+规范的Promise类之前，我们先再系统的了解下`this、apply、call、bind`这个基础概念的东西。

<!--more-->

## this指向

es5中就记住一句话：this 永远指向** 最后 **调用它的那个对象

看几个例子：

eg1：

``` js
 var name = "windowsName";
 function a() {
    var name = "Cherry";
    console.log(this.name);         
    console.log("inner:" + this);   
  }
  a();
  console.log("outer:" + this) 
```

结果大家肯定都知道了，分别是 `windowsName` ,`inner: Window`,`outer: Window`,`a()`其实是`window.a()`，谁调用我a，我this就指向谁，所以this指向的就是`window`

eg2：

``` js
var name = "windowsName";
var a = {
  name: "Cherry",
  fn: function () {
    console.log(this.name);      
  }
}
a.fn();
```

结果也是很明显的，函数fn是a调用的，所以this就是指向a，a有属性name，所以结果就是Cherry

eg3：

``` js
var name = "windowsName";
var a = {
    name: "Cherry",
    fn:function () {
      console.log(this.name);      // Cherry
    }
}
window.a.fn();
```

根据** “this 永远指向最后调用它的那个对象” ** 这句话，最后调用的是a，所以thi还是指向a；

eg4:

``` js
var name = "windowsName";
var a = {
  name : null,
  // name: "Cherry",
  fn : function () {
    console.log(this.name);     
  }
}
var f = a.fn;
f();
```

最后结果是`windowsName`,为什么呢？因为虽然将 a 对象的 fn 方法赋值给变量 f 了，但是没有调用，由于刚刚的 f 并没有调用，所以 fn() 最后仍然是被 window 调用的。所以 this 指向的也就是 window。

eg6：
再看一个例子：
``` js
 var name = "windowsName";
 function fn() {
   var name = 'Cherry';
   innerFunction();
   function innerFunction() {
      console.log(this.name);      
    }
  }
  fn()
```
答案是`windowsName`

到目前为止应该对this该指向谁有个初步的了解了吧；

## 怎么改变this指向

改变 this 的指向我总结有以下几种方法：

* 使用 ES6 的箭头函数
* 在函数内部使用 _this = this
* 使用 apply、call、bind
* new 实例化一个对象

### 箭头函数 =>

众所周知，ES6 的箭头函数是可以避免 ES5 中使用 this 的坑的。** 箭头函数的 this 始终指向函数定义时的 this，而非执行时 **。，箭头函数需要记着这句话：“箭头函数中没有 this 绑定，必须通过查找作用域链来决定其值，如果箭头函数被非箭头函数包含，则 this 绑定的是最近一层非箭头函数的 this，否则，this 为 undefined”。

``` js
  var name = "windowsName";

    var a = {
        name : "Cherry",

        func1: function () {
            console.log(this.name)     
        },

        func2: function () {
            setTimeout( () => {
                this.func1()
            },100);
        }

    };

    a.func2()     // Cherry
```

如果不写箭头函数是这样的，

``` js
func2: function () {
    setTimeout(  function () {
      this.func1()
    },100);
}
```
因为最后调用 setTimeout 的对象是 window，但是在 window 中并没有 func1 函数。所以最终的结果其实是`this.func1 is not a function`

补充下：** “匿名函数的 this 永远指向 window” ** 如果这个时候你要问，那匿名函数都是怎么定义的，首先，我们通常写的匿名函数都是自执行的，就是在匿名函数后面加 () 让其自执行。

### 在函数内部使用 _this = this

如果不使用 ES6，那么这种方式应该是最简单的不会出错的方式了，我们是先将调用这个函数的对象保存在变量 _this 中，然后在函数中都使用这个 _this，这样 _this 就不会改变了。

``` js
    var name = "windowsName";

    var a = {
        name : "Cherry",
        func1: function () {
            console.log(this.name)     
        },
        func2: function () {
            var _this = this;
            setTimeout( function() {
                _this.func1()
            },100);
        }
    };

    a.func2()       // Cherry
```
这个例子中，在 func2 中，首先设置 var _this = this;，这里的 this 是调用 func2 的对象 a，为了防止在 func2 中的 setTimeout 被 window 调用而导致的在 setTimeout 中的 this 为 window。我们将 this(指向变量 a) 赋值给一个变量 _this，这样，在 func2 中我们使用 _this 就是指向对象 a 了。

### apply、call、bind

#### 体验下使用上的差别：

``` js
 var a = {
        name : "Cherry",

        func1: function () {
            console.log(this.name)
        },

        func2: function () {
            setTimeout(  function () {
                this.func1()
            }.apply(a),100);
        }

    };

    a.func2()            // Cherry
```
``` js
    var a = {
        name : "Cherry",

        func1: function () {
            console.log(this.name)
        },

        func2: function () {
            setTimeout(  function () {
                this.func1()
            }.call(a),100);
        }

    };
    a.func2()            // Cherry
```
``` js
  var a = {
        name : "Cherry",

        func1: function () {
            console.log(this.name)
        },

        func2: function () {
            setTimeout(  function () {
                this.func1()
            }.bind(a)(),100);
        }

    };

    a.func2()            // Cherry
```

#### 语法上的差别

`fun.apply(thisArg, [argsArray])`

* thisArg：在 fun 函数运行时指定的 this 值。需要注意的是，指定的 this 值并不一定是该函数执行时真正的 this 值，如果这个函数处于非严格模式下，则指定为 null 或 undefined 时会自动指向全局对象（浏览器中就是window对象），同时值为原始值（数字，字符串，布尔值）的 this 会指向该原始值的自动包装对象。
* argsArray：一个数组或者类数组对象，其中的数组元素将作为单独的参数传给 fun 函数。如果该参数的值为null 或 undefined，则表示不需要传入任何参数。从ECMAScript 5 开始可以使用类数组对象。浏览器兼容性请参阅本文底部内容。

call和apply的区别就是传入的参数不同。

`fun.call(thisArg[, arg1[, arg2[, ...]]])`

所以 apply 和 call 的区别是 call 方法接受的是若干个参数列表，而 apply 接收的是一个包含多个参数的数组。

感受一下：
``` js
  var a ={
        name : "Cherry",
        fn : function (a,b) {
            console.log( a + b)
        }
    }

    var b = a.fn;
    b.apply(a,[1,2])     // 3
```

``` js
 var a ={
        name : "Cherry",
        fn : function (a,b) {
            console.log( a + b)
        }
    }

    var b = a.fn;
    b.call(a,1,2)       // 3
```

和bind的区别呢？
``` js
var a ={
  name : "Cherry",
  fn : function (a,b) {
    console.log( a + b)
  }
}
var b = a.fn;
b.bind(a,1,2)
```
发现并没有输出，这是为什么呢，

MDN说明：
> bind()方法创建一个新的函数, 当被调用时，将其this关键字设置为提供的值，在调用新函数时，在任何提供之前提供一个给定的参数序列。
所以我们可以看出，bind 是创建一个新的函数，我们必须要手动去调用：

``` js
var a ={
  name : "Cherry",
  fn : function (a,b) {
    console.log( a + b)
  }
}
var b = a.fn;
b.bind(a,1,2)()
```

### js的函数调用

* 作为一个函数调用
* 函数作为方法调用
* 使用构造函数调用函数
* 作为函数方法调用函数（call、apply）

> 文章参考https://juejin.im/post/59bfe84351882531b730bac2




