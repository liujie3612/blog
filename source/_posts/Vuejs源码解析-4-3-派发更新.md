---
title: Vuejs源码解析 4-3-派发更新
date: 2020-09-02 16:55:15
tags:
- vue
- 源码解析
- 源码
- 响应式原理
- 派发更新
---

通过上一节分析我们了解了响应式数据依赖收集过程，**收集的目的就是为了当我们修改数据的时候，可以对相关的依赖派发更新**，那么这一节我们来详细分析这个过程。

<!--more-->

我们看下 `defineReactive` 中 `setter` 的逻辑：

```js
export function defineReactive (
  obj: Object,
  key: string,
  val: any,
  customSetter?: ?Function,
  shallow?: boolean
) {
  const dep = new Dep()

  const property = Object.getOwnPropertyDescriptor(obj, key)
  if (property && property.configurable === false) {
    return
  }

  // cater for pre-defined getter/setters
  const getter = property && property.get
  const setter = property && property.set
  if ((!getter || setter) && arguments.length === 2) {
    val = obj[key]
  }

  let childOb = !shallow && observe(val)
  Object.defineProperty(obj, key, {
    enumerable: true,
    configurable: true,
    // ...
    set: function reactiveSetter (newVal) {
      const value = getter ? getter.call(obj) : val
      /* eslint-disable no-self-compare */
      if (newVal === value || (newVal !== newVal && value !== value)) {
        return
      }
      /* eslint-enable no-self-compare */
      if (process.env.NODE_ENV !== 'production' && customSetter) {
        customSetter()
      }
      if (setter) {
        setter.call(obj, newVal)
      } else {
        val = newVal
      }
      childOb = !shallow && observe(newVal)
      dep.notify()
    }
  })
}
```
setter 的逻辑有 2 个关键的点：

1. 一个是 `childOb = !shallow && observe(newVal)`，如果 `shallow` 为 `false` 的情况，会对新设置的值变成一个响应式对象；
2. 另一个是 `dep.notify()`，通知所有的订阅者

# 1. 触发setter

当我们在组件中对响应的数据做了修改，就会触发 setter 的逻辑，最后调用 `dep.notify()` 方法， 它是 Dep 的一个实例方法，定义在 `src/core/observer/dep.js` 中：
```js
class Dep {
  // ...
  notify () {
  // stabilize the subscriber list first
    const subs = this.subs.slice()
    for (let i = 0, l = subs.length; i < l; i++) {
      subs[i].update()
    }
  }
}
```
这里的逻辑非常简单:
1. 首先浅拷贝 subs 返回一个新的数组
2. 遍历所有的 `subs`，也就是 `Watcher` 的实例数组，然后调用每一个 `watcher` 的 `update` 方法，它的定义在 `src/core/observer/watcher.js` 中：

```js
class Watcher {
  // ...
  update () {
    /* istanbul ignore else */
    if (this.computed) {
      if (this.dep.subs.length === 0) {
        this.dirty = true
      } else {
        this.getAndInvoke(() => {
          this.dep.notify()
        })
      }
    } else if (this.sync) {
      this.run()
    } else {
      queueWatcher(this)
    }
  }
}  
```

在这里我们只关心 `update函数` 其实就是调用了 `queueWatcher(this)`

# 2. queueWatcher

实现：
```js
const queue: Array<Watcher> = [] // watcher 队列
let has: { [key: number]: ?true } = {} // watcher id map
let waiting = false // 保证对 nextTick(flushSchedulerQueue) 的调用逻辑只有一次
let flushing = false // 是否正在调用 flushSchedulerQueue
let index = 0 // 当前正在作业的 watcher 在 queue 数组的下标

export function queueWatcher (watcher: Watcher) {
  const id = watcher.id
  if (has[id] == null) {
    has[id] = true
    if (!flushing) {
      queue.push(watcher)  // push watcher
    } else {
      let i = queue.length - 1
      while (i > index && queue[i].id > watcher.id) {
        i--
      }
      queue.splice(i + 1, 0, watcher) // 插入watcher
    }
    // queue the flush
    if (!waiting) {
      waiting = true
      nextTick(flushSchedulerQueue)
    }
  }
}
```

1. 这里引入了一个`队列`的概念，这也是 Vue 在做派发更新的时候的一个优化的点，它并不会每次数据改变都触发 watcher 的回调，而是把这些 watcher 先添加到一个队列里，然后在 `nextTick` 后执行 `flushSchedulerQueue`。
2. `has` 对象保证同一个 Watcher 只添加一次，但是当执行 `flushSchedulerQueue` 的过程中，watcher 是可以被添加进队列的，因为在 `flushSchedulerQueue` 遍历 `queue` 的时候会执行 `has[id] = null`
3. 接着对 `flushing` 的判断：
  - 为 false：表示还没有调用 `flushSchedulerQueue`，此时将 watcher 推入 `queue` 队列。
  - else 部分的逻辑稍后再说。
4. `waiting`：保证对 `nextTick(flushSchedulerQueue)` 的调用逻辑只有一次。
  - `nextTick` 的实现之后会抽一小节专门去讲，目前就可以理解它是在下一个 tick，也就是**异步**的去执行 `flushSchedulerQueue`。

# 3. flushSchedulerQueue

接下来我们来看 `flushSchedulerQueue` 的实现，它的定义在 `src/core/observer/scheduler.js` 中。

```js
// src/core/observer/scheduler.js
const queue: Array<Watcher> = [] // watcher 队列let 
has: { [key: number]: ?true } = {} // watcher id map
let waiting = false // 保证对 nextTick(flushSchedulerQueue) 的调用逻辑只有一次
let flushing = false // 是否正在调用 flushSchedulerQueue
let index = 0 // 当前正在作业的 watcher 在 queue 数组的下标

let circular: { [key: number]: number } = {}

export const MAX_UPDATE_COUNT = 100
```

```js
let flushing = false
let index = 0

// 排序
function flushSchedulerQueue () {
  flushing = true
  let watcher, id

  queue.sort((a, b) => a.id - b.id)

  // 每次遍历都需要重新计算 length
  for (index = 0; index < queue.length; index++) {
    watcher = queue[index]
    if (watcher.before) {
      watcher.before() // 执行 beforeUpdate 钩子
    }
    id = watcher.id
    has[id] = null
    watcher.run()

  // ...
  }

  const activatedQueue = activatedChildren.slice()
  // 状态恢复前保留队列副本
  const updatedQueue = queue.slice()

  // 状态恢复
  resetSchedulerState()

  // 调用 updated 钩子
  callActivatedHooks(activatedQueue)
  callUpdatedHooks(updatedQueue)

  // ...
}
```

## 3.1 队列排序

`queue.sort((a, b) => a.id - b.id)` 对队列做了从小到大的排序，这么做主要有以下要确保以下几点：

1. 组件的更新由父到子；因为父组件的创建过程是先于子的，所以 `watcher的创建` 也是先父后子，执行顺序也应该保持先父后子。
2. 用户的自定义 watcher 要优先于渲染 watcher 执行；因为用户自定义 watcher 是在渲染 watcher 之前创建的。
3. 如果一个组件在父组件的 watcher 执行期间被销毁，那么它对应的 watcher 执行都可以被跳过，所以父组件的 watcher 应该先执行。

## 3.2 队列遍历

在对 queue 排序后，接着就是要对它做遍历，拿到对应的 watcher，执行 `watcher.run()`。
```js
for (index = 0; index < queue.length; index++) {
 watcher = queue[index]
 if (watcher.before) {
   watcher.before()
 }
 id = watcher.id
 has[id] = null
 watcher.run()
}
```

这里需要注意一个细节，在遍历的时候每次都会对 `queue.length` 求值，因为在 `watcher.run()` 的时候，很可能用户会再次添加`新的watcher`：**修改数据值从而触发 setter**，这样会再次执行到 `queueWatcher`，如下：
```js
export function queueWatcher (watcher: Watcher) {
  const id = watcher.id
  if (has[id] == null) {
    has[id] = true
    if (!flushing) {
      queue.push(watcher)
    } else {
      let i = queue.length - 1
      while (i > index && queue[i].id > watcher.id) {
        i--
      }
      queue.splice(i + 1, 0, watcher)
    }
    // ...
  }
}
```
* `flushing` 为 `true`，就会执行到 else 的逻辑，然后就会**从后往前找**
* 找到**第一个**`待插入 watcher的id` 比`当前队列中 watcher的id` 大的位置
* 因此 queue 的长度发生了变化。

### 3.2.1 watcher.run()

```js
class Watcher {
  run() {
    // active: true
    if (this.active) {
      var value = this.get()
      if (
        value !== this.value || isObject(value) || this.deep
      ) {
        // set new value
        var oldValue = this.value
        this.value = value

        // 简化后
        this.cb.call(this.vm, value, oldValue)
      }
    }
  }
}
```

通过 `this.get()` 得到它当前的值，然后做判断，如果满足以下条件之一：

* 新旧值不等
* 新值是对象类型
* deep 模式

执行 `watcher的回调`，注意回调函数执行的时候会把第一个和第二个参数传入`新值value` 和 `旧值oldValue`，这就是当我们添加`自定义watcher` 的时候能在回调函数的参数中拿到新旧值的原因。

对么对于`渲染 watcher` 而言，它在执行 `this.get()` 方法求值的时候，会执行 `this.getter` 方法，也就是 `updateComponent`：

```js
updateComponent = () => {
  vm._update(vm._render(), hydrating)
}
```
所以这就是当我们去修改组件相关的响应式数据的时候，会触发组件重新渲染的原因，接着就会`重新执行patch` 的过程，但它和首次渲染有所不同，在之后的章节会介绍。

### 3.2.2 循环判断

```js
if (process.env.NODE_ENV !== 'production' && has[id] != null) {
  circular[id] = (circular[id] || 0) + 1;
  if (circular[id] > MAX_UPDATE_COUNT) {
    warn(
      'You may have an infinite update loop ' + (
        watcher.user ?
        ("in watcher with expression \"" + (watcher.expression) + "\"") :
        "in a component render function."
      ),
      watcher.vm
    );
    break
  }
}
```
每次遍历 queue 时，用 `circular[id]` 来记录 watcher 对象的循环次数，当大于 `MAX_UPDATE_COUNT` 时认为是**死循环**

举个栗子🌰
```js
<script>
export default {
  data() {
    return {
      msg: 1
    }
  },
  watch: {
    msg() {
      this.msg++
    }
  },
  mounted() {
    this.msg++
  }
}
</script>
```

## 3.3 状态恢复

这个过程就是执行 `resetSchedulerState` 函数，它的定义在 `src/core/observer/scheduler.js` 中。

```js
const queue: Array<Watcher> = []
let has: { [key: number]: ?true } = {}
let circular: { [key: number]: number } = {}
let waiting = false
let flushing = false
let index = 0
/**
 * Reset the scheduler's state.
 */
function resetSchedulerState () {
  index = queue.length = activatedChildren.length = 0
  has = {}
  if (process.env.NODE_ENV !== 'production') {
    circular = {}
  }
  waiting = flushing = false
}
```

# 总结：
通过这一节的分析，我们对 Vue 数据修改派发更新的过程也有了认识，实际上就是当数据发生变化的时候，触发 `setter 逻辑`，把在依赖过程中`订阅的的所有观察者`，也就是 `watcher`，都触发它们的 `update过程`，这个过程又利用了队列做了进一步**优化**，在 `nextTick后`执行所有 `watcher.run`，最后执行它们的`回调函数`。nextTick 是 Vue 一个比较核心的实现了，下一节我们来重点分析它的实现。