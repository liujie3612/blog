---
title: Vue.js源码解析 2-1-new Vue
date: 2020-04-27 16:11:36
tags:
- vue
- 源码解析
- 源码
- 数据驱动
categories: Vue源码解析
---

# new Vue发生了什么

我们来一步步找到Vue的核心定义，以`web-full-esm`为例：

```js
// ...

// Runtime+compiler ES modules build (for bundlers)
'web-full-esm': {
  entry: resolve('web/entry-runtime-with-compiler.js'),
  dest: resolve('dist/vue.esm.js'),
  format: 'es',
  alias: { he: './entity-decoder' },
  banner
}
```
* src/platforms/web/entry-runtime-with-compiler.js（入口）
* —> src/platforms/web/runtime/index.js
* —> src/core/index.js
* —> src/core/instance/index.js (核心)

<!--more-->

Vue 构造函数定义就在`src/core/instance/index.js`中

# Vue定义:

```js
// src/core/instance/index.js
function Vue(options) {
  if (process.env.NODE_ENV !== 'production' &&
    !(this instanceof Vue)
  ) {
    warn('Vue is a constructor and should be called with the `new` keyword');
  }
  this._init(options);
}

initMixin(Vue);
stateMixin(Vue);
eventsMixin(Vue);
lifecycleMixin(Vue);
renderMixin(Vue);

export default Vue
```

* initMixin(Vue)：就做了一件事，定义`_init`方法。
* stateMixin(Vue)：定义数据相关的方法`$set`,`$delete`,`$watch`方法。
* eventsMixin(Vue)：定义事件相关的方法`$on`，`$once`，`$off`，`$emit`。
* lifecycleMixin(Vue)：定义`_update`，及生命周期相关的`$forceUpdate`和`$destroy`。
* renderMixin(Vue)：定义`$nextTick`，`_render`将render函数转为vnode。

可以看到 new Vue 主要就是调用了 _init 方法

## _init方法

`this._init`方法在执行 `initMixin` 时绑定的，在`src/core/instance/init.js`中：

```js
export function initMixin (Vue: Class<Component>) {
  Vue.prototype._init = function (options?: Object) {
    const vm: Component = this
    // a uid
    vm._uid = uid++

    let startTag, endTag
    /* istanbul ignore if */
    // ...
    // a flag to avoid this being observed
    vm._isVue = true
    // merge options
    if (options && options._isComponent) { 
      // 优化内部组件实例化，因为动态选项合并非常慢，并且没有内部组件选项需要特殊处理。
      // 合并option
      // _parentVnode 占位符vnode
      // parent 当前vm的实例 子组件父级实例
      initInternalComponent(vm, options)
    } else {
      // 合并传进来的options
      vm.$options = mergeOptions(
        resolveConstructorOptions(vm.constructor),
        options || {},
        vm
      )
    }
    /* istanbul ignore else */
    if (process.env.NODE_ENV !== 'production') {
      initProxy(vm)
    } else {
      vm._renderProxy = vm
    }
    // expose real self
    vm._self = vm
    initLifecycle(vm)
    initEvents(vm)
    initRender(vm)
    callHook(vm, 'beforeCreate')
    initInjections(vm) // resolve injections before data/props
    initState(vm)
    initProvide(vm) // resolve provide after data/props
    callHook(vm, 'created')

    // render函数走不到
    if (vm.$options.el) {
      vm.$mount(vm.$options.el)
    }
  }
}
```

Vue 初始化主要就干了几件事情：

`mergeOptions` 合并配置
`initLifecycle` 初始化生命周期
`initEvents` 初始化事件中心
`initRender` 初始化渲染，比如定义 `vm._c` 和 `vm.$createElement`
`initState` 初始化 data、props、computed、watcher 等等。


# 总结:

Vue 的初始化逻辑写的非常清楚，把不同的功能逻辑拆成一些单独的函数执行，让主线逻辑一目了然
由于我们这一章的目标是弄清楚模板和数据如何渲染成最终的 DOM，所以各种初始化逻辑我们先不看。
在初始化的最后，检测到如果有 el 属性，则调用 `vm.$mount` 方法`挂载vm`，挂载的目标就是把模板渲染成最终的 DOM，那么接下来我们来分析 Vue 的挂载过程。
![](https://cdn.liujiefront.com/images/algorithm/i0fpx.png)



