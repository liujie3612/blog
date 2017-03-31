---
title: 详解call apply 与 bind
date: 2017-03-29 13:02:02
tags: javascript
---

在JavaScript中，`call`、 `apply` 和 `bind` 是 `Function` 对象自带的三个方法，本文将通过几个场景的应用，来详细理解三个方法。
<!-- more -->

## call()

`call()` 方法在使用一个指定的this值和若干个指定的参数值的前提下调用某个函数或方法。
当调用一个函数时，可以赋值一个不同的 `this` 对象。`this` 引用当前对象，即 `call` 方法的第一个参数。
通过`call`方法，你可以在一个对象上借用另一个对象上的方法，比如`Object.prototype.toString.call([])`，就是一个`Array`对象借用了`Object`对象上的方法。

```
语法 fun.call(thisArg[, arg1[, arg2[, ...]]])
```

### thisArg
在fun函数运行时指定的`this`值。需要注意的是下面几种情况
1. 不传，或者传`null`，`undefined`， 函数中的`this`指向window对象
2. 传递另一个函数的函数名，函数中的`this`指向这个函数的引用，并不一定是该函数执行时真正的`this`值 
3. 值为原始值(数字，字符串，布尔值)的`this`会指向该原始值的自动包装对象，如 `String`、`Number`、`Boolean`
4. 传递一个对象，函数中的`this`

### arg1, arg2, ...
指定的参数列表。

### 举个栗子

#### 初级应用的例子
``` js
function a(){
    //输出函数a中的this对象
    console.log(this); 
}
//定义函数b
function b(){} 

var obj = {name:'这是一个屌丝'}; //定义对象obj
a.call(); //window
a.call(null); //window
a.call(undefined);//window
a.call(1); //Number
a.call(''); //String
a.call(true); //Boolean
a.call(b);// function b(){}
a.call(obj); //Object
```
#### 使用call方法调用匿名函数并且指定上下文的this
在下面的例子中，当调用 `greet` 方法的时候，该方法的 `this` 值会绑定到 `i` 对象。

``` js
function greet() {
  var reply = [this.person, '是一个轻量的', this.role].join(' ');
  console.log(reply);
}

var i = {
  person: 'JSLite.io', role: 'Javascript 库。'
};

greet.call(i); 
// JSLite.io 是一个轻量的 Javascript 库。
```
#### 使用call方法调用匿名函数
在下例中的for循环体内，我们创建了一个匿名函数，然后通过调用该函数的call方法，将每个数组元素作为指定的this值执行了那个匿名函数。这个匿名函数的主要目的是给每个数组元素对象添加一个print方法，这个print方法可以打印出各元素在数组中的正确索引号。当然，这里不是必须得让数组元素作为this值传入那个匿名函数（普通参数就可以），目的是为了演示call的用法。
``` js
var animals = [
  {species: 'Lion', name: 'King'},
  {species: 'Whale', name: 'Fail'}
];

for (var i = 0; i < animals.length; i++) {
  (function (i) { 
    this.print = function () { 
      console.log('#' + i  + ' ' + this.species + ': ' + this.name); 
    } 
    this.print();
  }).call(animals[i], i);
}
//#0 Lion: King
//#1 Whale: Fail
```
#### 使用call方法调用函数传参数
``` js
var a = {
    name:'JSLite.io', //定义a的属性
    say:function(){ //定义a的方法
        console.log("Hi,I'm function a!");
    }
};
function b(name){
    console.log("Post params: "+ name);
    console.log("I'm "+ this.name);
    this.say();
}

b.call(a,'test');
//Post params: test
//I'm JSLite.io
//I'm function a!
```

## apply()
语法与`call()` 方法的语法几乎完全相同，唯一的区别在于，apply的第二个参数必须是一个包含多个参数的数组（或类数组对象）。
`apply`的这个特性很重要，在调用一个存在的函数时，你可以为其指定一个`this` 对象。 `this`指当前对象，也就是正在调用这个函数的对象。 使用`apply`， 你可以只写一次这个方法然后在另一个对象中继承它，而不用在新对象中重复写该方法。
```
语法：fun.apply(thisArg[, argsArray])
```
**注意**: 需要注意：Chrome 14 以及 Internet Explorer 9 仍然不接受类数组对象。如果传入类数组对象，它们会抛出异常。

### thisArg
同上`call`的`thisArg`参数。

### argsArray
一个数组或者类数组对象，其中的数组元素将作为单独的参数传给`fun`函数。如果该参数的值为`null`或`undefined`，则表示不需要传入任何参数。从`ECMAScript 5`开始可以使用类数组对象。

### 举个栗子
```
function jsy(x,y,z){
    console.log(x,y,z);
}

jsy.apply(null,[1,2,3]); 
// 1 2 3
```

#### 使用apply来链接构造器的例子
你可以使用`apply`来给一个对象链接构造器，类似于`Java` 在接下来的例子中我们会创建一个叫做`construct`的全局的`Function`函数,来使你能够在构造器中使用一个类数组对象而非参数列表。
``` js
Function.prototype.construct = function(aArgs) {
  var fConstructor = this, 
  fNewConstr = function() { 
    fConstructor.apply(this, aArgs); 
  };
  fNewConstr.prototype = fConstructor.prototype;
  return new fNewConstr();
};
function MyConstructor () {
    for (var nProp = 0; nProp < arguments.length; nProp++) {
        console.log(arguments,this)
        this["property" + nProp] = arguments[nProp];
    }
}
var myArray = [4, "Hello world!", false];
var myInstance = MyConstructor.construct(myArray);

console.log(myInstance.property1);                // logs "Hello world!"
console.log(myInstance instanceof MyConstructor); // logs "true"
console.log(myInstance.constructor);              // logs "MyConstructor"
```
#### 使用apply和内置函数
聪明的apply用法允许你在某些本来需要写成遍历数组变量的任务中使用内建的函数。在接下里的例子中我们会使用`Math.max/Math.min`来找出一个数组中的`最大/最小`

``` js
//里面有最大最小数字值的一个数组对象
var numbers = [5, 6, 2, 3, 7];

/* 使用 Math.min/Math.max 在 apply 中应用 */
var max = Math.max.apply(null, numbers);
// 一般情况是用 Math.max(5, 6, ..) 或者 Math.max(numbers[0], ...) 来找最大值
var min = Math.min.apply(null, numbers);

//通常情况我们会这样来找到数字的最大或者最小值
//比对上面的栗子，是不是下面的看起来没有上面的舒服呢？
max = -Infinity, min = +Infinity;
for (var i = 0; i < numbers.length; i++) {
  if (numbers[i] > max)
    max = numbers[i];
  if (numbers[i] < min) 
    min = numbers[i];
}
```
#### 参数数组切块后循环传入
``` js
function minOfArray(arr) {
  var min = Infinity;
  var QUANTUM = 32768;

  for (var i = 0, len = arr.length; i < len; i += QUANTUM) {
    var submin = Math.min.apply(null, arr.slice(i, Math.min(i + QUANTUM, len)));
    console.log(submin, min)
    min = Math.min(submin, min);
  }

  return min;
}

var min = minOfArray([5, 6, 2, 3, 7]);
```

## bind
`bind()` 函数会创建一个新函数（称为绑定函数）
1. bind是ES5新增的一个方法
2. 传参和call或apply类似
3. 不会执行对应的函数，call或apply会自动执行对应的函数
4. 返回对函数的引用
```
语法 fun.bind(thisArg[, arg1[, arg2[, ...]]])
```
下面例子：当点击网页时，`EventClick`被触发执行，输出`JSLite.io p1 p2`, 说明`EventClick`中的`this`被`bind`改变成了`obj`对象。如果你将`EventClick.bind(obj,'p1','p2')` 变成 `EventClick.call(obj,'p1','p2')` 的话，页面会直接输出 `JSLite.io p1 p2`
``` js
var obj = {name:'JSLite.io'};
/**
 * 给document添加click事件监听，并绑定EventClick函数
 * 通过bind方法设置EventClick的this为obj，并传递参数p1,p2
 */
document.addEventListener('click',EventClick.bind(obj,'p1','p2'),false);
//当点击网页时触发并执行
function EventClick(a,b){
    console.log(
            this.name, //JSLite.io
            a, //p1
            b  //p2
    )
}
// JSLite.io p1 p2
```
## 应用场景举例

### 继承
``` js
function Animal(name,weight){
   this.name = name;
   this.weight = weight;
}
function Cat(){
    // 在call中将this作为thisArgs参数传递
    // Animal方法中的this就指向了Cat中的this
    // 所以Animal中的this指向的就是cat对象
    // 在Animal中定义了name和weight属性，就相当于在cat中定义了这些属性
    // cat对象便拥有了Animal中定义的属性，从而达到了继承的目的
    Animal.call(this,'cat','50');
    //Animal.apply(this,['cat','50']);
    this.say = function(){
       console.log("I am " + this.name+",my weight is " + this.weight);
    }
}
//当通过new运算符产生了cat时，Cat中的this就指向了cat对象
var cat = new Cat();
cat.say();
//输出=> I am cat,my weight is 50
```

### 原型扩展
在原型函数上扩展和自定义方法，从而不污染原生函数。例如：我们在 `Array` 上扩展一个 `forEach`
``` js
function test(){
    // 检测arguments是否为Array的实例
    console.log(
        arguments instanceof Array, //false
        Array.isArray(arguments)  //false
    );
    // 判断arguments是否有forEach方法
    console.log(arguments.forEach); 
    // undefined
    // 将数组中的forEach应用到arguments上
    Array.prototype.forEach.call(arguments,function(item){
        console.log(item); // 1 2 3 4
    });
}
test(1,2,3,4);
```



