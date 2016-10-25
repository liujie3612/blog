---
title: javascript中的this
date: 2016-10-25 11:03:01
tags: javascript
---

js中的this已经有千千万万的文章写过这部分内容了，这里的文章是自己对this的一点总结，在js中，this这个上下文对于新手来说开始接触时会感觉一头雾水，其实，只要分清楚不同的情况下如何执行就 ok 了。

<!-- more -->

# 全局执行
1. 浏览器 ![](/images/this/window.png) window对象
2. node环境 ![](/images/this/node.png) global对象 
**总结**：在全局作用域中它的 this 执行当前的全局对象（浏览器端是 Window，node 中是 global）。

---

# 函数中执行

## 1.纯粹的函数调用
最普通的用法
``` javascript
function test() {
  console.log(this);
}
test()

//Window {speechSynthesis: SpeechSynthesis,...}
```
一个函数被直接调用的时候，属于全局调用，这时候它的 this 指向 全局对象；

## 2.严格模式 ‘use strict’;
如果在严格模式的情况下执行纯粹的函数调用，那么这里的的 this 并不会指向全局，而是 undefined，这样的做法是为了消除 js 中一些不严谨的行为：

``` javascript
'use strict';
function test() {
  console.log(this);
};

test();

// undefined
```

当然，把它放在一个立即执行函数中会更好，避免了污染全局：

```
(function (){
  "use strict";
　console.log(this);
})();

// undefined
```

## 2.作为对象的方法调用
当一个函数被当作一个对象的方法调用的时候：
```
var obj = {
  name: 'liujie',
  foo: function() {
    console.log(this.name);
  }
}
obj.foo();
// 'liujie'
```

这时候，this 指向当前的这个对象；当然，我们还可以这么做：
```
function test() {
  console.log(this.name);
}

var obj = {
  name: 'liujie',
  foo: test
}

obj.foo();

// 'liujie'
```

同样不变，因为在 js 中一切都是对象，函数也是一个对象，对于 test ，它只是一个函数名，函数的引用，它指向这个函数，当 foo = test，foo 同样也指向了这个函数。

如果把对象的方法赋值给一个变量，然后直接调用这个变量呢： 
```
var obj = {
  name: 'liujie',
  foo: function() {
    console.log(this);
  }
}

var test = obj.foo;
test();

// Window
```
可以看到，这时候 this 执行了全局，当我们把 test = obj.foo ，test 直接指向了一个函数的引用，这时候，其实和 obj这个对象没有关系了，所以，它是被当作一个普通函数来直接调用，因此，this 指向全局对象。

## 3.回调函数里的一些坑
```
var obj = {
  name: 'liujie',
  foo: function() {
    console.log(this);
  },
  foo2: function() {
    console.log(this);
    setTimeout(this.foo, 1000);
  }
}

obj.foo2();
// Object {name: "liujie"}
// Window
```
执行这段代码我们会发现两次打印出来的 this 是不一样的：<br>第一次是 foo2 中直接打印 this，这里指向 obj 这个对象，我们毋庸置疑;
但是在 setTimeout 中执行的 this.foo ，却指向了全局对象，这里不是把它当作函数的方法使用吗？这一点经常让很多初学者疑惑;其实，setTimeout 也只是一个函数而已，函数必然有可能需要参数，我们把 this.foo 当作一个参数传给 setTimeout 这个函数，就像它需要一个 fun参数，在传入参数的时候，其实做了个这样的操作 fun = this.foo，看到没有，这里我们直接把 fun 指向 this.foo 的引用；执行的时候其实是执行了 fun() 所以已经和 obj 无关了，它是被当作普通函数直接调用的，因此 this 指向全局对象。
这个问题是很多异步回调函数中普遍会碰到的；

### 3.1 解决办法
为了解决这个问题，我们可以利用 闭包 的特性来处理：
```
var obj = {
  name: 'liujie',
  foo: function() {
    console.log(this);
  },
  foo2: function() {
    console.log(this);
    var _self = this;
    setTimeout(function() {
      console.log(this);  // Window

      console.log(_self);  // Object {name: "liujie"}
    }, 1000);
  }
}
obj.foo2();
```
可以看到直接用 this 仍然是 Window；因为 foo2 中的 this 是指向 obj，我们可以先用一个变量 _self 来储存，然后在回调函数中使用 _self，就可以指向当前的这个对象了；

### 3.2 setTimeout 的另一个坑
之前说过，如果直接执行回调函数而没有绑定作用域，那么它的 this 是指向全局对象(window)，在严格模式下会指向 undefined，然而在setTimeout 中的回调函数在严格模式下却表现出不同：

```
'use strict';
function foo() {
  console.log(this);
}
setTimeout(foo, 1);
// window
```
按理说我们加了严格模式，foo 调用也没有指定 this，应该是出来 undefined，但是这里仍然出现了全局对象，难道是严格模式失效了吗？

并不，即使在严格模式下，setTimeout 方法在调用传入函数的时候，如果这个函数没有指定了的 this，那么它会做一个隐式的操作—-自动地注入全局上下文，等同于调用 foo.apply(window) 而非 foo()；

当然，如果我们在传入函数的时候已经指定 this，那么就不会被注入全局对象，比如： setTimeout(foo.bind(obj), 1);

---

# 作为构造函数使用

在 js 中，为了实现类，我们需要定义一些构造函数，在调用一个构造函数的时候需要加上 new 这个关键字：
```
function Person(name) {
  this.name = name;
  console.log(this);
}

var p = new Person('liujie');

// Person {name: "liujie"}
```
可以看到当作构造函数调用时，this 指向了这个构造函数调用时候实例化出来的对象;

当然，构造函数其实也是一个函数，如果我们把它当作一个普通函数执行，这个 this 仍然执行全局：
```
function Person(name) {
  this.name = name;
  console.log(this);
}
var p = Person('liujie');
// Window
```

其区别在于，如何调用函数（new）。

---

# 箭头函数

在 ES6 的新规范中，加入了箭头函数，它和普通函数最不一样的一点就是 this 的指向了，还记得在[上文](#3-1-解决办法)中我们使用闭包来解决 this 的指向问题吗，如果用上了箭头函数就可以更完美的解决了：
```
var obj = {
  name: 'liujie',
  foo: function() {
    console.log(this);
  },
  foo2: function() {
    console.log(this);
    setTimeout(() => {
      console.log(this);  // Object {name: "liujie"}
    }, 1000);
  }
}

obj.foo2();
```
可以看到，在 setTimeout 执行的函数中，本应该打印出在 Window，但是在这里 this 却指向了 obj，原因就在于，给 setTimeout 传入的函数（参数）是一个箭头函数：

> 函数体内的this对象，就是定义时所在的对象，而不是使用时所在的对象。

根据例子我们理解一下这句话：
在 obj.foo2() 执行的时候，当前的 this 指向 obj；在执行 setTimeout 时候，我们先是定义了一个匿名的箭头函数，关键点就在这，箭头函数内的this 执行定义时所在的对象，就是指向定义这个箭头函数时作用域内的 this，也就是 obj.foo2 中的 this，即 obj；所以在执行箭头函数的时候，它的 this -> obj.foo2 中的 this -> obj；

简单来说， ** 箭头函数中的 this 只和定义它时候的作用域的 this 有关，而与在哪里以及如何调用它无关，同时它的 this 指向是不可改变的。 **

---

# call, apply, bind
在 js 中，函数也是对象，同样也有一些方法，这里我们介绍三个方法，他们可以更改函数中的 this 指向：

- call
> ```
fun.call(thisArg[, arg1[, arg2[, ...]]])
```
它会立即执行函数，第一个参数是指定执行函数中 this 的上下文，后面的参数是执行函数需要传入的参数；
- apply
> ```
fun.apply(thisArg[, [arg1, arg2, ...]])
```
它会立即执行函数，第一个参数是指定执行函数中 this 的上下文，第二个参数是一个数组，是传给执行函数的参数（与 call 的区别）；
- bind
> ```
var foo = fun.bind(thisArg[, arg1[, arg2[, ...]]]);
```
它不会执行函数，而是返回一个新的函数，这个新的函数被指定了 this 的上下文，后面的参数是执行函数需要传入的参数；

** 这三个函数其实大同小异，总的目的就是去指定一个函数的上下文（this），我们以 call 函数为例； **

## 为一个普通函数指定 this
```
var obj = {
  name: 'liujie'
};

function foo() {
  console.log(this);
}

foo.call(obj);

// Object {name: "liujie"}
```
可以看到，在执行 foo.call(obj) 的时候，函数内的 this 指向了 obj 这个对象，成功；

## 为对象中的方法指定一个 this
```
var obj = {
  name: 'liujie',
  foo: function () {
    console.log(this);
  }
}

var obj2 = {
  name: 'liujie222',
};

obj.foo.call(obj2);

// Object {name: "liujie222"}
```
可以看到，执行函数的时候这里的 this 指向了 obj2，成功；

## 为构造函数指定 this
```
function Person(name) {
  this.name = name;
  console.log(this);
}

var obj = {
  name: 'liujie222'
};

var p = new Person.call(obj, 'liujie');

// Uncaught TypeError: Person.call is not a constructor(…)
```
这里报了个错，原因是我们去 new 了 Person.call 函数，而非 Person ，这里的函数不是一个构造函数；

换成 bind 试试：
```
function Person(name) {
  this.name = name;
  console.log(this);
}

var obj = {
  name: 'liujie222'
};

var Person2 = Person.bind(obj);

var p = new Person2('liujie');

// Person {name: "liujie"}

console.log(obj);

// Object {name: "liujie222"}
```
打印出来的是 Person 实例化出来的对象，而和 obj 没有关系，而 obj 也没有发生变化，说明，我们给 Person 指定 this 上下文并没有生效；

因此可以得出： 使用 bind 给一个构造函数指定 this，在 new 这个构造函数的时候，bind 函数所指定的 this 并不会生效；

当然 bind 不仅可以指定 this ，还能传入参数，我们来试试这个操作：
```
function Person(name) {
  this.name = name;
  console.log(this);
}

var obj = {
  name: 'liujie222'
};

var Person2 = Person.bind(obj, 'liujie111');

var p = new Person2('liujie');

// Person {name: "liujie111"}
```
可以看到，虽然指定 this 不起作用，但是传入参数还是起作用了；

## 为箭头函数指定 this
我们来定义一个全局下的箭头函数，因此这个箭头函数中的 this 必然会指向全局对象，如果用 call 方法改变 this 呢：
```
var afoo = (a) => {
  console.log(a);
  console.log(this);
}

var bfoo = function(b) {
  console.log(b);
  console.log(this);
}

var obj = {
  name: 'liujie'
};

afoo.call(obj, 1);
bfoo.call(obj, 1);

// 1
// Window

// 1
// Object {name: "liujie"}
```
可以看到，使用箭头函数的call指向this的操作没有成功，而没有使用箭头函数的call成功了,所以可以得出：**  箭头函数中的 this 在定义它的时候已经决定了（执行定义它的作用域中的 this），与如何调用以及在哪里调用它无关，包括 (call, apply, bind) 等操作都无法改变它的 this。** 








