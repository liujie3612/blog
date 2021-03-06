---
title: 关于JavaScript数组，你所不知道的3件事
date: 2016-10-26 14:46:06
tags: javascript
---

在编程语言当中，数组（Array）是一个非常常用的功能；它是一种特殊的变量，可以用来同时储存多个数值。然而，在JavaScript方面，数组的功能还有很多其他值得探索的地方。 
在这篇文字中，我们将会讨论JavaScript数组的三个并不那么常见的功能。 
<!-- more -->

# 1、给数组添加自定义属性

在网上搜寻有关JavaScript数组的定义时，你会发现几乎所有人对于数组的定义都一样：一种对象。

事实上，我们用JavaScript处理的所有东西，都可以视为是一种对象。
JavaScript中有两种数据类型，基本类型、引用类型，但是基本类型基本都是包括在引用类型之中的。 

数组、函数、Date在JavaScript中都是预定义的对象，它们内部都包含了方法、属性和各自的标准化句法。

## JavaScript数组有以下三种不同的属性： 
1、数组的索引也是其属性
2、内置属性
3、你可以自己添加自定义属性
前两种属性是大家比较熟知的，你可能每天都在使用，但是我还是想在这里简单的多说两句，然后再来谈谈如何给数组添加自定义属性。 

### 将索引作为属性
JavaScript数组可以使用方括号句法，例如var ary = [“orange”,"apple","lychee"];。 

数组元素的索引基本上也是一种属性，而其属性的名称永远都是非负整数。 
数组的索引元素对类似一个对象的关键值对。索引是数组对象的独特特性，与其他内置属性不同，它们可以单独通过方括号进行配置，例如 ary[3] = “peach”;。

### 内置属性
数组拥有内置属性，例如array.length。这个长度属性包含了一个整数值，用来表示数组的长度。

一般情况下，内置属性经常可以在数组等预先定义的JavaScript对象中找到。内置属性与内置方法联合在一起，它们可以对普通对象进行自定义，让对象满足不同的需求。 

在访问内置属性的时候，你可以使用两种句法：object.key或是object[“key”]。也就是说，在获取数组长度的时候，你可以写成ary[“length"]。

### 为数组对象创建自定义属性

现在我们来谈一谈如何为数组添加自定义属性。数组是一种预定义对象，它在不同的索引中储存了不同的种类的值。

通常情况下，我们没有给数组添加自定义属性的需要；也是出于这个原因，我们在刚刚学习JavaScript的时候，没有人告诉我们可以给数组添加属性。事实上，如果你想要向对待一般对象那样，给数组添加关键值对，你也可以使用一般的对象来达到目的。但是，这并不是说完全没有特殊情况，在某些情况下，你可以利用数组也是一种对象的事实，给它添加一个或多个自定义属性。<br> 例如，你可以给数组添加一个可以识别元素“类型（kind）”或是“类（class）”的自定义属性。具体请参见下方实例：
```
var ary = ["orange","apple","lychee"];   
ary.itemClass = "fruits";   
console.log(ary + " are " + ary.itemClass);
```
请注意，你给数组所添加的自定义属性都是可数的，也就是说，它可以被for……in等循环所拣选。

---

# 在数组元素中进行循环

你可能会说：“这个我早就知道了。”没错，你已经知道如何对数组元素进行索引了。但是“在数组元素中进行循环”这样的说法你可能会觉得有些抽象，因为我们真正循环的，是数组的索引。

由于数组索引都是又非负整数所构成的，因此通常情况下，我们都会从0开始，直到数组的全部长度，来对整数值进行迭代，然后使用那个迭代后的值来根据特定的索引来获取数组元素。 

然而，自从ECMAScript6出现之后，我们可以不再管索引，直接在数组值中进行循环，而且这个操作可以使用for……of循环来完成。 

在数组中，for……of循环可以根据索引的顺序对数组元素进行循环，换句话说，它可以掌管索引的迭代，根据给予的索引获取一个已经存在的数组值。如果你只是想要在所有数组元素中进行循环，并且使用它们，这个循环非常实用。
```
var ary = ["orange","apple","lychee"];   
for (let item of ary){   
  console.log(item);   
}   

For comparison, with the regular for loop, we get the indices instead of the values as output.  var ary = ["orange","apple","lychee"];   
for (var item = 0; item < ary.length; item++){   
  console.log(item);   
}
```

---

# 元素的数量不等同于其长度 

一般情况下，当我们在谈到数组长度的时候，我们会认为其长度要么是数组值的数量，要么是我们手动给数组设定的长度。但是事实上，数组的长度取决于其内部最大的已经存在的索引。 

长度是一个非常灵活的属性。无论你是否曾实现调整了数组的长度，只要你不断的给数组添加新的值，它的长度也会随之增长。
```
var ary = [];
ary.length = 3;
console.log(ary.length);
ary[5] = "abcd";
console.log(ary.length);
```
在上面的例子中，你可以看到我给数组的索引5只指定了一个值，之后长度变成了6。现在，如果你觉得给index 5添加一个值，数组就会自动创建索引0-4，那么你的推测就出现了错误。数组中并没有应经存在的索引0-4。你可以使用in operator来查看。
```
 var ary = [];   
ary.length = 3;   
console.log(ary.length);   
ary[5] = "abcd";   
console.log(ary.length);   
console.log(0 in ary);
```
上面的ary数组被我们成为稀疏数组（sparse array），这个数组的索引不会持续的被创建，而且索引之间有空气。sparse数组的对立面为密集数组（dense array）。密集数组的索引会被持续的创建，其元素的数量等于其长度。

数组的长度属性也可以用来缩短数字，确保数组中索引的最大数量永远小于数组本身，因为在默认情况下，长度的数值永远会大于索引数量的最高值。 
在下面的例子中，你可以看到，我利用减少ary数组长度的方式，删掉了索引5中的元素。
```
var ary = [];   
ary.length = 3;   
console.log(ary.length);   
ary[5] = "abcd";   
console.log(ary.length);   
ary.length = 2;   
console.log(ary.length);   
console.log(ary[5]);
```