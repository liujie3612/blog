---
title: js的预编译及变量提升
date: 2019-01-28 19:46:59
tags:
- 基础
---

JS属于解释型语言，在执行过程中顺序执行，但是会分块先预编译然后才执行。因此在JS中存在一种变量提升的现象。
<!-- more -->

## 问题

``` javascript
 function fn(a){
    console.log(a);
    var a = 123;
    console.log(a);

    function a(){};
    console.log(a);

    var b = function(){};
    console.log(b);

    function d(){};
 }

 //调用函数
 fn(1);

```

## 预编译执行步骤

预编译发生在函数执行的前一刻，过程如下：
1. 创建AO对象，执行期上下文
2. 找形参和变量声明，将变量和形参名作为AO属性名，值为undefined
3. 将实参值和形参统一
4. 在函数体里面找函数声明，值赋予函数体

这是个不断覆盖的过程。

> 函数声明才存在变量提升。即function a(){};,而var b =function (){};不会提升。

## 详细分析

1. 创建AO对象
``` javascript
AO{
    //空对象
}
```

2. 找形参和变量声明
``` javascript
AO{
    a : undefined,
    b : undefined
}
```

3. 将实参值和形参统一
``` javascript
AO{
    a : 1,
    b : undefined
}
```

4. 找函数声明
``` javascript
AO{
    a : function a(){},
    b : undefined,
    d : function d(){}
}
```

预编译环节就此结束，此时的AO对象已经更新为：
``` javascript
AO{
    a : function a(){},
    b : undefined,
    d : function d(){}
}
```

函数开始逐行顺序执行：
``` javascript
 function fn(a){
    console.log(a);// 输出functiona(){}
    var a = 123;//执行到这里重新对a赋，AO对象再一次更新
    console.log(a);// 输出123

    function a(){};//预编译环节已经进行了变量提升，故执行时不在看这行代码
    console.log(a);// 输出123

    var b = function(){};//这个是函数表达式不是函数声明，故不能提升，会对AO中的b重新赋值
    console.log(b);//输出function(){}

    function d(){};
 }
```

至此，函数执行完毕，销毁AO对象。
