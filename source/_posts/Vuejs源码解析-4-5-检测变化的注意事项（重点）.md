---
title: Vuejs源码解析 4-5-检测变化的注意事项
date: 2020-09-03 16:55:22
tags:
- vue
- 源码解析
- 源码
- 响应式原理
- nextTick
---

通过前面几节的分析，我们对响应式数据对象以及它的 `getter` 和 `setter` 部分做了了解，但是对于一些**特殊情况**是需要注意的，接下来我们就从源码的角度来看 Vue 是如何处理这些特殊情况的。

在 Vue 中，受限于 defineProperty 的原因，以下情况是无法触发视图更新的：

<!--more-->

```vue
<template>
  <div>
    <div>{{obj}}</div>
    <ul>
      <li v-for="(item, idx) in arr" :key="idx">{{item}}</li>
    </ul>
    <button @click="add">add</button>
    <button @click="change1">change1</button>
    <button @click="change2">change2</button>
  </div>
</template>

<script>
export default {
  data() {
    return {
      obj: {
        a: 1,
        b: 2
      },
      arr: [1, {x: 1, y: 2}]
    }
  },
  methods: {
    add() {
      this.obj.c = 3;  // 无法触发视图更新
      this.arr[2] = 3; // 无法触发视图更新
    },
    change1() {
      this.arr[0] = 0; // 无法触发视图更新
    },
    change2() {
      this.arr[1].x = 0; // 触发视图更新
    }
  }
}
</script>
```

* 当给一个对象或数组新增元素时，无法触发视图更新
* 当改变数组的值时
  - 如果这个值是基础类型，无法触发视图更新
  - 如果这个值是对象类型，那么改变这个对象的属性值是可以触发视图更新的
* 如果想要更新视图，只能调用 Vue 提供的 `Vue.set` 方法来间接实现。


# 依赖收集：

Vue.set 实际上是基于 `__ob__.dep` 的基础来实现派发更新的。
![](https://cdn.liujiefront.com/images/algorithm/uoowa.png)

1. `initState` -> `initData`
   - `initData`的参数就是vue里data函数里返回的值
2. `observe`
   - 处理后的`data`作为参数
3. `ob = new Observer(value)`
   - 处理后的`value`也发生了变化
4. `ob`对象有`value`和`dep`属性，参数`value`（实际的data值）也进行了`def`处理
```js
var Observer = function Observer(value) {
  this.value = value;
  this.dep = new Dep();
  this.vmCount = 0;
  def(value, '__ob__', this);
  // console.log(value)
  if (Array.isArray(value)) {
    if (hasProto) {
      protoAugment(value, arrayMethods);
    } else {
      copyAugment(value, arrayMethods, arrayKeys);
    }
    this.observeArray(value);
  } else {
    this.walk(value);
  }
};
```


# 对象添加属性

对于使用 `Object.defineProperty` 实现响应式的对象，当我们去给这个对象添加一个新的属性的时候，是不能够触发它的 `setter` 的，比如：
```js
var vm = new Vue({
  data:{
    a:1
  }
})
// vm.b 是非响应的
vm.b = 2
```

但是添加新属性的场景我们在平时开发中会经常遇到，那么 `Vue` 为了解决这个问题，定义了一个全局 API `Vue.set` 方法，它在 `src/core/global-api/index.js` 中初始化：
```js
Vue.set = set
```

这个 set 方法的定义在 `src/core/observer/index.js` 中：
```js
export function set (target: Array<any> | Object, key: any, val: any): any {
  // todo
  if (Array.isArray(target) && isValidArrayIndex(key)) {
    target.length = Math.max(target.length, key)
    target.splice(key, 1, val)
    return val
  }
  if (key in target && !(key in Object.prototype)) {
    target[key] = val
    return val
  }
  const ob = (target: any).__ob__
  // todo
  if (!ob) {
    target[key] = val
    return val
  }

  defineReactive(ob.value, key, val)
  ob.dep.notify()
  return val
}
```

set 方法接收 3个参数：
1. target 普通对象或者数组
2. key 对象的键值或数组的下标
3. val 代表添加的值。

* 首先判断如果 `target是数组` 且 `key`是一个合法的下标，则之前通过 `splice` 去添加进数组然后返回; **这里的 splice 其实已经不仅仅是原生数组的 splice 了**，稍后再介绍这部分逻辑。
* 接着又判断 key 已经存在于 `target` 中，则直接赋值返回，因为这样的变化是可以观测到的。
* 接着再获取到 `target.__ob__` 并赋值给 `ob`，之前分析过它是在 `Observer` 的构造函数执行的时候初始化的，表示 `Observer` 的一个实例; 如果它不存在，则说明 `target` 不是一个响应式的对象，则直接**赋值并返回*。
* 通过 `defineReactive(ob.value, key, val)` 把`新添加的属性`变成`响应式对象`
* 最后再通过 `ob.dep.notify()` **手动**的触发依赖通知

还记得我们在给对象添加 `getter` 的时候有这么一段逻辑：
```js
export function defineReactive (
  obj: Object,
  key: string,
  val: any,
  customSetter?: ?Function,
  shallow?: boolean
) {
  // ...
  let childOb = !shallow && observe(val)
  Object.defineProperty(obj, key, {
    enumerable: true,
    configurable: true,
    get: function reactiveGetter () {
      const value = getter ? getter.call(obj) : val
      if (Dep.target) {
        dep.depend()
        if (childOb) {
          childOb.dep.depend()
          if (Array.isArray(value)) {
            dependArray(value)
          }
        }
      }
      return value
    },
    // ...
  })
}
```

在 `getter` 过程中判断了 `childOb`，并调用了 `childOb.dep.depend()` 收集了依赖，这就是为什么执行 `Vue.set` 的时候通过 `ob.dep.notify()` 能够通知到 `watcher`，从而让添加新的属性到对象也可以检测到变化。
意思就是如果增加属性的值也是一个对象，那么这个对象也是响应式的。
```js
this.$set(this.c,'g', {
  a: 1,
  b: 2
});
```
这里如果 value 是个`数组`，那么就通过 `dependArray` 把数组每个元素也去做依赖收集。

# 数组

接着说一下数组的情况，Vue 也是不能检测到以下变动的数组：

1.当你利用索引直接设置一个项时，例如：`vm.items[indexOfItem] = newValue`
2.当你修改数组的长度时，例如：`vm.items.length = newLength`

对于第一种情况，可以使用：`Vue.set(example1.items, indexOfItem, newValue)`,也能用 `target.splice(key, 1, val)` 来添加
而对于第二种情况，可以使用 `vm.items.splice(newLength)`。

那么这里的 `splice` 到底怎么让添加的对象变成响应式的呢？

在通过 `observe` 方法去观察对象的时候会`实例化Observer`，在它的`构造函数`中是专门对数组做了处理，它的定义在 `src/core/observer/index.js` 中。

```js
export class Observer {
  constructor (value: any) {
    this.value = value
    this.dep = new Dep()
    this.vmCount = 0
    def(value, '__ob__', this)
    if (Array.isArray(value)) {
      const augment = hasProto
        ? protoAugment
        : copyAugment
      augment(value, arrayMethods, arrayKeys)
      this.observeArray(value)
    } else {
      // ...
    }
  }
}
```
这里我们只需要关注 `value` 是 `Array` 的情况，首先获取 `augment`，这里的 `hasProto` 实际上就是判断对象中是否存在 `__proto__`，如果存在则 `augment` 指向 `protoAugment`， 否则指向 `copyAugment`，来看一下这两个函数的定义：
```js
function protoAugment (target, src: Object, keys: any) {
  target.__proto__ = src
}

function copyAugment (target: Object, src: Object, keys: Array<string>) {
  for (let i = 0, l = keys.length; i < l; i++) {
    const key = keys[i]
    def(target, key, src[key])
  }
}
```
这里只看对象有`__proto__`的情况。
`protoAugment` 方法是直接把 `target.__proto__` 原型直接修改为 `src`, 那么它实际上就把 `value` 的原型指向了 `arrayMethods`

```js
import { def } from '../util/index'

const arrayProto = Array.prototype
export const arrayMethods = Object.create(arrayProto)

const methodsToPatch = [
  'push',
  'pop',
  'shift',
  'unshift',
  'splice',
  'sort',
  'reverse'
]

/**
 * Intercept mutating methods and emit events
 */
methodsToPatch.forEach(function (method) {
  // cache original method
  const original = arrayProto[method]
  def(arrayMethods, method, function mutator (...args) {
    const result = original.apply(this, args)
    const ob = this.__ob__
    let inserted
    switch (method) {
      case 'push':
      case 'unshift':
        inserted = args
        break
      case 'splice':
        inserted = args.slice(2)
        break
    }
    if (inserted) ob.observeArray(inserted)
    // notify change
    ob.dep.notify()
    return result
  })
})
```
1. `arrayMethods` 首先继承了 `Array`
2. 然后对数组中所有能改变数组自身的方法，如 `push`、`pop` 等这些方法进行重写。
3. 重写后的方法会先执行它们**本身原有的逻辑**，并对能**增加**数组长度的 3 个方法 `push`、`unshift`、`splice` 方法做了判断，**获取到插入的值**
4. 把获取到插入的值变成一个`响应式对象`，并且再调用 `ob.dep.notify()` 手动触发依赖通知。


总结：通过这一节的分析，我们对响应式对象又有了更全面的认识，如果在实际工作中遇到了这些特殊情况，我们就可以知道如何把它们也变成响应式的对象。其实对于对象属性的删除也会用同样的问题，Vue 同样提供了 `Vue.del` 的全局 API，它的实现和 Vue.set 大同小异，甚至还要更简单一些，这里我就不去分析了，感兴趣的同学可以自行去了解。
