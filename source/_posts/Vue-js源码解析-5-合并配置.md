---
title: Vue-js源码解析(5) - 合并配置
date: 2020-08-19 15:39:24
tags:
  - vue
  - 源码解析
  - 源码
---

new Vue 的过程通常有 2 种场景：

1. 一种是**外部**我们的代码主动调用 `new Vue(options)` 的方式实例化一个 Vue 对象；
2. 另一种是我们上一节分析的组件过程中\**内部*通过 `new Sub(options)` 实例化子组件。

<!-- more -->

无论哪种场景，都会执行实例的 `_init(options)` 方法，它首先会执行一个 `merge options` 的逻辑，相关的代码在 `src/core/instance/init.js` 中：

```js
Vue.prototype._init = function (options?: Object) {
  // merge options
  if (options && options._isComponent) {
    // optimize internal component instantiation
    // since dynamic options merging is pretty slow, and none of the
    // internal component options needs special treatment.
    initInternalComponent(vm, options);
  } else {
    vm.$options = mergeOptions(
      resolveConstructorOptions(vm.constructor),
      options || {},
      vm
    );
  }
  // ...
};
```

可以看到不同场景对于 `options` 的合并逻辑是不一样的，并且传入的 `options` 值也有非常大的不同，接下来我会分开介绍 2 种场景的 `options` 合并过程。

为了更直观，我们可以举个简单的示例：

```js
import Vue from "vue";

let childComp = {
  template: "<div>{{msg}}</div>",
  created() {
    console.log("child created");
  },
  mounted() {
    console.log("child mounted");
  },
  data() {
    return {
      msg: "Hello Vue",
    };
  },
};

Vue.mixin({
  created() {
    console.log("parent created");
  },
});

let app = new Vue({
  el: "#app",
  render: (h) => h(childComp),
});
```
例子中使用了 `Vue.mixin` 函数，是因为 mixin 本身就是合并 options 的过程，来看 Vue.mixin 的定义：

```js
import { mergeOptions } from '../util/index'
export function initMixin (Vue: GlobalAPI) {
  Vue.mixin = function (mixin) {
    this.options = mergeOptions(this.options, mixin);
    return this
  }
}
其实就是调用了 `mergeOptions` 函数，把 mixin 中的内容合并到 Vue.options 上。关于 mergeOptions 函数在下文介绍

```

# 外部调用场景：

当执行 new Vue 的时候，在执行 `this._init(options)` 的时候，就会执行如下逻辑去合并 `options`：

```js
vm.$options = mergeOptions(
  resolveConstructorOptions(vm.constructor),
  options || {},
  vm
);
```

这里通过调用 `mergeOptions` 方法来合并，它实际上就是把 `resolveConstructorOptions(vm.constructor)` 的返回值和 `options` 做合并。
```js
export function resolveConstructorOptions (Ctor: Class<Component>) {  
  let options = Ctor.options // 在这其实是Vue.options  
  if (Ctor.super) {    
    // ...  
  }  
  return options
}
```
if 语句通过 `Ctor.super` 判断 `Ctor` 是 Vue 还是 Vue 的子类，显然在我们的例子中是 Vue，所以 `resolveConstructorOptions` 函数直接返回 `Vue.options`，那么这个值又是什么呢，其实在 `initGlobalAPI(Vue)` 的时候定义了这个值，代码在 `src/core/global-api/index.js` 中：

```js
export function initGlobalAPI(Vue: GlobalAPI) {
  // ...
  Vue.options = Object.create(null);
  ASSET_TYPES.forEach((type) => {
    Vue.options[type + "s"] = Object.create(null);
  });

  Vue.options._base = Vue;

  extend(Vue.options.components, builtInComponents);
  // ...
}
```
* 接着执行了 `Vue.options._base = Vue`，它用于[创建子类构造函数](https://blog.liujiefront.com/2020/08/18/Vue-js%E6%BA%90%E7%A0%81%E8%A7%A3%E6%9E%90-3-createComponent/)
* 最后通过 `extend(Vue.options.components, builtInComponents)` 把一些内置组件扩展到 `Vue.options.components` 上，Vue 的内置组件目前有 <keep-alive>、<transition> 和 <transition-group> 组件，这也就是为什么我们在其它组件中使用 <keep-alive> 组件不需要注册的原因，这块儿后续我们介绍 <keep-alive> 组件的时候会详细讲。
此时的 Vue.options 大概长这样：

![](https://cdn.liujiefront.com/images/algorithm/xax4l.png)