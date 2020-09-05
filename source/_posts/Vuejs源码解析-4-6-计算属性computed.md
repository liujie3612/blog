---
title: Vuejs源码解析 4-6-计算属性computed
date: 2020-09-04 17:33:10
tags:
- vue
- 源码解析
- 源码
- 响应式原理
- computed
---


计算属性的初始化是发生在 Vue 实例初始化阶段的 `initState` 函数中：
```js
export function initState (vm: Component) {
  // ...
  if (opts.computed) initComputed(vm, opts.computed)
  // ...
}
```

`initComputed` 的定义在 `src/core/instance/state.js` 中：

<!--more-->
# initComputed

```js
function initComputed(vm, computed) {
  // $flow-disable-line
  var watchers = vm._computedWatchers = Object.create(null);
  // computed properties are just getters during SSR
  var isSSR = isServerRendering();

  for (var key in computed) {
    var userDef = computed[key];
    var getter = typeof userDef === 'function' ? userDef : userDef.get;
    if (process.env.NODE_ENV !== 'production' && getter == null) {
      warn(
        ("Getter is missing for computed property \"" + key + "\"."),
        vm
      );
    }

    if (!isSSR) {
      // create internal watcher for the computed property.
      watchers[key] = new Watcher(
        vm,
        getter || noop,
        noop,
        computedWatcherOptions
      );
    }

    // 对于组件来说，在创建子组件构造函数时已经调用了 defineComputed，并将 computed 定义在其原型上
    // 只有对于当根实例来说，才会执行此处的 defineComputed
    if (!(key in vm)) {
      defineComputed(vm, key, userDef);
    } else if (process.env.NODE_ENV !== 'production') {
      if (key in vm.$data) {
        warn(("The computed property \"" + key + "\" is already defined in data."), vm);
      } else if (vm.$options.props && key in vm.$options.props) {
        warn(("The computed property \"" + key + "\" is already defined as a prop."), vm);
      }
    }
  }
}
```

1. 创建 `vm._computedWatchers` 为一个空对象，用来保存 computed watcher。
2. 对 `computed对象`做遍历，拿到计算属性的getter。
3. 为每一个 getter 创建一个 `computed watcher`。(区别于`渲染 watcher`)
4. 判断如果 key 不是 vm 的属性，则调用 `defineComputed(vm, key, userDef)`。

## 实例化computed watcher

```js
watchers[key] = new Watcher(
  vm,
  getter || noop,
  noop,
  computedWatcherOptions
)
```
* `getter`：表示计算属性的 getter（具体的函数，比如后面的function部分）
```js
computed: {
  fullName: function () {
    return this.firstName + ' ' + this.lastName
  }
}
```
* `computedWatcherOptions`：一个配置对象`{ lazy: true }`，表示这是一个 `computed watcher`

当初始化这个 `computed watcher` 实例的时候，构造函数部分逻辑稍有不同：
```js
constructor (
  vm: Component,
  expOrFn: string | Function,
  cb: Function,
  options?: ?Object,
  isRenderWatcher?: boolean
) {
  // ...
  this.value = this.lazy ? undefined : this.get()
}  
```
和`渲染 watcher` 不一样的是，由于我们传入配置的 lazy 是 true，所以**不会**立刻调用 `this.get()` 进行求值

## defineComputed

注意这里 `Vue` 有一个优化处理，在**创建组件构造函数**时：

```js
Vue.extend = function (extendOptions: Object): Function {
  // ...
  if (Sub.options.computed) {
    initComputed(Sub)
  }
  // ...
}

function initComputed (Comp) {
  const computed = Comp.options.computed
  for (const key in computed) {    
    defineComputed(Comp.prototype, key, computed[key])
  }
}
```
这里提前调用了 `defineComputed`，并且第一个参数传入的是组件的原型，也就是 `Comp.prototype`。

这样做的目的就是避免多次实例化同一组件时，在实例上重复调用 `defineComputed` 方法。

```js
const sharedPropertyDefinition = {
  enumerable: true,
  configurable: true,
  get: noop,
  set: noop
}

export function defineComputed (
  target: any,
  key: string,
  userDef: Object | Function
) {
  const shouldCache = !isServerRendering()
  if (typeof userDef === 'function') {
     // 简化后的
    sharedPropertyDefinition.get = createComputedGetter(key)
    sharedPropertyDefinition.set = noop
  } else {
    // 简化后的    
    sharedPropertyDefinition.get = userDef.get ? createComputedGetter(key) : noop    
    sharedPropertyDefinition.set = userDef.set || noop
  }

  Object.defineProperty(target, key, sharedPropertyDefinition)
}
```
这段逻辑很简单，其实就是利用 `Object.defineProperty` 给计算属性对应的 `key` 值添加 `getter` 和 `setter`，`setter` 通常是计算属性是一个对象，并且拥有 `set` 方法的时候才有，否则是一个空函数。在平时的开发场景中，计算属性有 setter 的情况比较少。

```js
function createComputedGetter(key) {
  return function computedGetter() {
    var watcher = this._computedWatchers && this._computedWatchers[key];
    if (watcher) {
      if (watcher.dirty) {
        watcher.evaluate();
      }

      if (Dep.target) {
        watcher.depend();
      }
      return watcher.value
    }
  }
}
```
`createComputedGetter` 返回一个函数 `computedGetter`，它就是计算属性对应的 `getter`。

# 2 过程分析：

举个栗子🌰：
```js
var vm = new Vue({
  data: {
    firstName: 'Foo',
    lastName: 'Bar'
  },
  computed: {
    fullName: function () {
      return this.firstName + ' ' + this.lastName
    }
  }
})
```

## 2.1 依赖收集

当我们的 `render函数`执行访问到 `this.fullName` 的时候，就触发了计算属性的 `getter`，也就是在 `createComputedGetter` 中返回的 `computedGetter`：
```js
  return function computedGetter() {
    var watcher = this._computedWatchers && this._computedWatchers[key];
    // console.log(watcher)
    debugger
    if (watcher) {
      if (watcher.dirty) {
        watcher.evaluate();
      }
      if (Dep.target) {
        watcher.depend();
      }
      return watcher.value
    }
  }
  ```

  首先拿到这个计算属性的 `computed watcher`。

  这里会对 `watcher.dirty` 进行判断，`dirty` 是用来标志是否已经执行过计算结果，这是因为只有在相关响应式数据发生变化时，`computed` 才会重新求值，其余情况多次访问计算属性的值都会返回之前计算的结果，这就是**缓存的优化**。

![](https://cdn.liujiefront.com/images/algorithm/ts5jl.png)

### 2.1.1 watcher.evaluate
```js
evaluate () {
  this.value = this.get()
  this.dirty = false
}
```

执行 `this.get()` 进行求值。
将 `dirty` 置为 `false`，当下次访问 `computed` 时，可以直接取 `watcher.value`，**达到缓存目的**。

在执行 `this.get()` 进行求值的过程中会执行 `value = this.getter.call(vm, vm)`，这实际上就是执行了用户定义的计算属性的 `getter 函数`，在我们这个例子就是执行了：

```js
 return this.firstName + ' ' + this.lastName
 ```
 特别注意的是：由于 `this.firstName` 和 `this.lastName` 都是`响应式对象`，这里会触发它们的 `getter`，根据我们之前的分析，它们会把自身持有的 `dep` 添加到当前正在计算的 `watcher` 中，**这个时候 `Dep.target` 就是这个 `computed watcher`**。


> “它们会把自身持有的 `dep` 添加到当前正在计算的 `watcher` 中”这句话之前不理解什么是dep、deps、subs，和watcher又是什么关系？
> data中的每一个`属性`对应一个dep
> `dep`中的`subs`保存了依赖该属性的`watcher`
> 每一个`watcher`有一个`update`方法，该方法会在依赖的属性的值发生变化的时候调用。

> 一个`对象或数组`对应一个`__ob__`属性即` Observer实例`。在`observer`中执行`new Observer(value)`操作，`new Observer`中遍历`value对象`，为每一个值> `defineReactive`。
> 在`defineReactive`中默认会对观测的`data对象`进行`深度观测`，即会**递归**观测属性值，如果属性值是`对象或数组`的话。此时的`watcher`只有一个，即为`渲染watcher`，**所有> 的`dep`**都会添加到该`watcher`的`deps`中。


> 综上，三者之间的关系为：一个`渲染watcher`对应一个组件，该`watcher`中的`deps`保存了`data`中`所有属性值的dep`，`wacther`中保存`deps`的目的是为了`依赖取消时`移除dep实例中subs记录的watcher，`每个dep实例`有一个`subs属性`，该属性用于保存依赖产生dep实例的data属性的watcher，`dep`由`observer`产生，一个`对象或数组`对应一个`observer实例`，每一个属性对应一个dep。


 ![](https://cdn.liujiefront.com/images/algorithm/lqdri.png)

 ### 2.1.2 watcher.depend
```js
function computedGetter () {  
  const watcher = this._computedWatchers && this._computedWatchers[key]  
  if (watcher) {    
    if (watcher.dirty) {      
      watcher.evaluate()    
    }    
    if (Dep.target) {      
      watcher.depend()    
    }    
    return watcher.value  
  }
}
```
这时会执行 `watcher.depend` 进行**依赖的收集**：
```js
depend () {
  let i = this.deps.length
  while (i--) {
    this.deps[i].depend()
  }
}
```
**注意**：这时候的 `Dep.target` 是`渲染 watcher`，所以 `this.dep[i].depend()` 相当于`渲染 watcher` 订阅了这个 `computed watcher` 的变化，所以就构造了 渲染 watcher 和 dep 之间的关系。


 最后通过 `return this.value` 拿到计算属性对应的值。我们知道了计算属性的求值过程，那么接下来看一下它依赖的数据变化后的逻辑。

 ## 2.2 派发更新

派发更新的条件是 `computed` 中依赖的数据发生改变，在本例中就是 `this.firstName` 或 `this.lastName` 发生改变。下面来看看如果 `this.firstName` 发生改变时发生了什么。

1. 会调用 `this.firstName` 的 `setter`，进而执行 `dep.notify`。
2. 当执行 `dep.notify` 方法时，会遍历 `subs` 数组，然后依次调用 sub.update。在本例中 `this.firstName` 的 `dep.subs` 数组如下 `[computedWatcher, 渲染watcher]`。
![](https://cdn.liujiefront.com/images/algorithm/b2lby.png)

### 2.2.1 computed watcher 执行 update
```js
update () {
  if (this.lazy) {
    this.dirty = true
  } else if (this.sync) {
    this.run()
  } else {
    queueWatcher(this)
  }
}
```
`this.lazy`为`true`，所以 `update` 过程不会执行状态更新的操作，只会将 `dirty` 标记为 `true`。

### 2.2.2 渲染 watcher 执行 update

当执行 `渲染 watcher` 的 `update` 方法时：

会执行 `updateComponent` 进行视图重新渲染，而 `render` 过程中会访问到计算属性，此时由于 `this.dirty `值为 `true`，所以又会对`计算属性重新求值`。

