---
title: Vuejs源码解析 4-7-侦听属性watcher
date: 2020-09-05 17:27:06
tags:
- vue
- 源码解析
- 源码
- 响应式原理
- watch
---

# 初始化过程

侦听属性的初始化也是发生在 Vue 的实例初始化阶段的 `initState` 函数中，在 `computed 初始化之后`，执行了：

```js
if (opts.watch && opts.watch !== nativeWatch) {
  initWatch(vm, opts.watch)
}
```

<!--more-->

看一下 `initWatch` 的实现，它的定义在 `src/core/instance/state.js` 中：
```js
function initWatch(vm, watch) {
  for (var key in watch) {
    var handler = watch[key];
    if (Array.isArray(handler)) {
      for (var i = 0; i < handler.length; i++) {
        createWatcher(vm, key, handler[i]);
      }
    } else {
      createWatcher(vm, key, handler);
    }
  }
}
```

这里就是对 watch 对象做遍历，拿到每一个 `handler`，因为 Vue 是支持 watch 的**同一个key** 对应`多个 handler`，所以如果 `handler` 是一个数组，则遍历这个数组，调用 `createWatcher` 方法，否则直接调用 `createWatcher`：
```js
function createWatcher (
  vm: Component,
  expOrFn: string | Function,
  handler: any,
  options?: Object
) {
  if (isPlainObject(handler)) {
    options = handler
    handler = handler.handler
  }
  if (typeof handler === 'string') {
    handler = vm[handler]
  }
  return vm.$watch(expOrFn, handler, options)
}
```
对 `hanlder` 的类型做判断，拿到它最终的**回调函数**，最后调用 `vm.$watch(keyOrFn, handler, options)` 函数

```js
Vue.prototype.$watch = function (
  expOrFn: string | Function,
  cb: any,
  options?: Object
): Function {
  const vm: Component = this
  if (isPlainObject(cb)) {
    return createWatcher(vm, expOrFn, cb, options)
  }
  options = options || {}
  options.user = true
  const watcher = new Watcher(vm, expOrFn, cb, options)
  if (options.immediate) {
    cb.call(vm, watcher.value)
  }
  return function unwatchFn () {
    watcher.teardown()
  }
}
```

最后调用 `vm.$watch(keyOrFn, handler, options)` 函数，`$watch` 是 `Vue原型`上的方法，它是在执行 `stateMixin` 的时候定义的：
```js
function stateMixin(Vue) {
  Vue.prototype.$watch = function (
    expOrFn,
    cb,
    options
  ) {
    var vm = this;
    if (isPlainObject(cb)) {
      return createWatcher(vm, expOrFn, cb, options)
    }
    options = options || {};
    options.user = true; // user watcher
    var watcher = new Watcher(vm, expOrFn, cb, options);
    if (options.immediate) {
      try {
        cb.call(vm, watcher.value);
      } catch (error) {
        handleError(error, vm, ("callback for immediate watcher \"" + (watcher.expression) + "\""));
      }
    }
    return function unwatchFn() {
      watcher.teardown();
    }
  };
}
```
侦听属性 watch 最终会调用 `$watch` 方法:
1. 判断 `cb` 如果是一个对象，则调用 `createWatcher 方法`，这是因为 `$watch` 方法是用户可以直接调用的，它可以传递一个对象，也可以传递函数。
2. 接着执行 `const watcher = new Watcher(vm, expOrFn, cb, options)` 实例化了一个 **user watcher**，其中会进行`依赖收集`，稍后再展开分析。
3. 通过实例化 `watcher` 的方式，一旦我们 watch 的数据发生变化，它最终会执行 `watcher` 的 `run 方法`，执行`回调函数 cb`
4. 如果我们设置了 `immediate` 为 `true`，则`直接会执行回调函数 cb`。
5. 最后返回了一个 `unwatchFn` 方法，它会调用 `teardown` 方法去**移除**这个 `watcher`

# 依赖收集

```js
var vm = new Vue({
  el: '#app',
  data() {
    return {
      obj: {
        msg: 'hello'
      }
    }
  },
  watch: {
    'obj.msg': function() {}
  }
})
```

当执行到 `$watch` 中的 `const watcher = new Watcher(vm, expOrFn, cb, options)` 逻辑时：

```js
var Watcher = function Watcher(
  vm,
  expOrFn,
  cb,
  options,
  isRenderWatcher
) {
  this.vm = vm;
  if (isRenderWatcher) {
    vm._watcher = this;
  }
  vm._watchers.push(this);
  // options
  if (options) {
    this.deep = !!options.deep;
    this.user = !!options.user;
    this.lazy = !!options.lazy;
    this.sync = !!options.sync;
    this.before = options.before;
  } else {
    this.deep = this.user = this.lazy = this.sync = false;
  }
  this.cb = cb;
  this.id = ++uid$2; // uid for batching
  this.active = true;
  this.dirty = this.lazy; // for lazy watchers
  this.deps = [];
  this.newDeps = [];
  this.depIds = new _Set();
  this.newDepIds = new _Set();
  this.expression = process.env.NODE_ENV !== 'production' ?
    expOrFn.toString() :
    '';
  // parse expression for getter
  if (typeof expOrFn === 'function') {
    this.getter = expOrFn;
  } else {
    this.getter = parsePath(expOrFn);
    if (!this.getter) {
      this.getter = noop;
    }
  }
  this.value = this.lazy ?
    undefined :
    this.get();
};
```

重点关注一下对 `expOrFn` 的处理：

在本例中我们的 `expOrFn` 是 `'obj.msg'`，因此会调用 `parsePath` 方法并将返回值作为 `this.getter`。

```js
var unicodeRegExp = /a-zA-Z\u00B7\u00C0-\u00D6\u00D8-\u00F6\u00F8-\u037D\u037F-\u1FFF\u200C-\u200D\u203F-\u2040\u2070-\u218F\u2C00-\u2FEF\u3001-\uD7FF\uF900-\uFDCF\uFDF0-\uFFFD/;

var bailRE = new RegExp(("[^" + (unicodeRegExp.source) + ".$_\\d]"));

function parsePath(path) {
  if (bailRE.test(path)) {
    return
  }
  var segments = path.split('.');
  return function (obj) {
    for (var i = 0; i < segments.length; i++) {
      if (!obj) { return }
      obj = obj[segments[i]];
    }
    return obj
  }
}
```

* 首先对 `path` 进行`合法性校验`，如果`不合法`则返回 `undefined`
* 将 `path` 按 `.` 分割，比如本例中 `obj.msg` 将得到 `['obj', 'msg']`
* 返回一个函数，这个函数会保存为 `this.getter`

在实例化 `user watcher` 的最后调用 `this.get()` 进行求值时，`Dep.target` 是当前的 `user watcher`，然后又执行了 `this.getter.call(vm, vm)`，在这里函数里将遍历`['obj', 'msg']`，依次访问：

1. `vm.obj`，这会触发 `obj.__ob__.dep` 和 `obj dep` 两个 `dep` 的依赖收集。
2. `obj.msg`，这会触发 `msg dep` 的依赖收集

因此对于 `user watcher` 来说，其 `deps` 中也保存了`三者的 dep`

![](https://cdn.liujiefront.com/images/algorithm/k9178.png)

## 2.1 deep options

如果我们想对一下对象做深度观测的时候，需要设置 `deep` 这个属性为 `true`。

这样就创建了一个 `deep watcher` 了，在 `watcher` 执行 `get` 求值的过程中有一段逻辑：
```js
get() {
  let value = this.getter.call(vm, vm)
  // ...
  if (this.deep) {
    traverse(value)
  }
}
```
在对 watch 的表达式求值后，会调用 `traverse` 函数，它的定义在 `src/core/observer/traverse.js` 中：

```js
const seenObjects = new Set()

function traverse(val) {
  _traverse(val, seenObjects);
  seenObjects.clear();
}

function _traverse(val, seen) {
  var i, keys;
  var isA = Array.isArray(val);
  if ((!isA && !isObject(val)) || Object.isFrozen(val) || val instanceof VNode) {
    return
  }
  if (val.__ob__) {
    var depId = val.__ob__.dep.id;
    if (seen.has(depId)) {
      return
    }
    seen.add(depId);
  }
  if (isA) {
    i = val.length;
    while (i--) { _traverse(val[i], seen); }
  } else {
    keys = Object.keys(val);
    i = keys.length;
    while (i--) { _traverse(val[keys[i]], seen); }
  }
}
```
`traverse` 的逻辑也很简单，它实际上就是对一个对象做**深层递归遍历**，因为遍历过程中就是对一个子对象的**访问**，会触发它们的 `getter 过程`，这样就可以`收集到依赖`，也**就是订阅它们变化的 watcher**

，这个函数实现还有一个小的优化，遍历过程中会把子响应式对象通过它们的 `dep id` 记录到 `seenObjects`，避免以后**重复访问**。

那么在执行了 traverse 后，我们再对 watch 的对象内部任何一个值做修改，也会调用 watcher 的回调函数了。

# 3. 派发更新

在这个例子中，当我们改变 `vm.watcher` 或者 `vm.watcher.msg` 的时候，都会触发相应的 `setter`，最后会执行 `watcher.run`

```js

```

`Dep.prototype.notify` -> `subs[i].update()` -> `queueWatcher(this)` -> `nextTick(flushSchedulerQueue)` -> `watcher.run()`;
```js
Watcher.prototype.run = function run() {
  if (this.active) {
    var value = this.get();
    if (
      value !== this.value ||
      isObject(value) ||
      this.deep
    ) {
      // set new value
      var oldValue = this.value;
      this.value = value;
      if (this.user) {
        try {
          this.cb.call(this.vm, value, oldValue);
        } catch (e) {
          handleError(e, this.vm, ("callback for watcher \"" + (this.expression) + "\""));
        }
      } else {
        this.cb.call(this.vm, value, oldValue);
      }
    }
  }
};
```

总结：通过这两章的分析我们对计算属性和侦听属性的实现有了深入的了解，计算属性本质上是 `computed watcher`，而侦听属性本质上是 `user watcher`。

就应用场景而言，计算属性适合用在模板渲染中，某个值是依赖了其它的响应式对象甚至是计算属性计算而来；而侦听属性适用于观测某个值的变化去完成一段复杂的业务逻辑。