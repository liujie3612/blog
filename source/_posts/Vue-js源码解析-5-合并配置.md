---
title: Vue.js源码解析(5) - 合并配置
date: 2020-08-19 15:39:24
tags:
  - vue
  - 源码解析
  - 源码
---

new Vue 的过程通常有 2 种场景：

1. 一种是**外部**我们的代码主动调用 `new Vue(options)` 的方式实例化一个 Vue 对象；
2. 另一种是我们上一节分析的组件过程中**内部*通过 `new Sub(options)` 实例化子组件。

<!-- more -->

无论哪种场景，都会执行实例的 `_init(options)` 方法，它首先会执行一个 `merge options` 的逻辑，相关的代码在 `src/core/instance/init.js` 中：

```js
Vue.prototype._init = function (options?: Object) {
  // merge options
  if (options && options._isComponent) {
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
```
其实就是调用了 `mergeOptions` 函数，把 `mixin` 中的内容合并到 `Vue.options` 上。

# 外部调用场景：

当执行 `new Vue` 的时候，在执行 `this._init(options)` 的时候，就会执行如下逻辑去合并 `options`：

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
if 语句通过 `Ctor.super` 判断 `Ctor` 是 Vue 还是 Vue 的子类，显然在我们的例子中是 Vue, 所以 **`resolveConstructorOptions` 函数直接返回 `Vue.options`**(重点)。

## Vue.options
那么 `Vue.options` 又是在哪定义的呢，其实在 `initGlobalAPI(Vue)` 的时候定义了这个值，代码在 `src/core/global-api/index.js` 中：

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
* 通过 Object.create(null) 创建一个空对象并赋值给 `Vue.options`
* 然后遍历 `ASSET_TYPES`，这里的 ASSET_TYPES 是一个常量：
* 
```js
export const ASSET_TYPES = [
  'component',
  'directive',
  'filter'
]
```
* 接着执行了 `Vue.options._base = Vue`，它用于[创建子类构造函数](https://blog.liujiefront.com/2020/08/18/Vue-js%E6%BA%90%E7%A0%81%E8%A7%A3%E6%9E%90-3-createComponent/#%E6%9E%84%E9%80%A0%E5%AD%90%E7%B1%BB%E6%9E%84%E9%80%A0%E5%87%BD%E6%95%B0)
```js
export function createComponent (
  Ctor: Class<Component> | Function | Object | void,
  data: ?VNodeData,
  context: Component,
  children: ?Array<VNode>,
  tag?: string
): VNode | Array<VNode> | void {
  if (isUndef(Ctor)) {
    return
  }
  // 核心逻辑1：创建子类构造函数
  const baseCtor = context.$options._base
  if (isObject(Ctor)) {
    Ctor = baseCtor.extend(Ctor)
  }
  // Weex的一些逻辑...
  return vnode
}
```
* 最后通过 `extend(Vue.options.components, builtInComponents)` 把一些内置组件扩展到 `Vue.options.components` 上，Vue 的内置组件目前有 <keep-alive>、<transition> 和 <transition-group> 组件，这也就是为什么我们在其它组件中使用 <keep-alive> 组件不需要注册的原因，这块儿后续我们介绍 <keep-alive> 组件的时候会详细讲。
此时的 Vue.options 大概长这样：

![](https://cdn.liujiefront.com/images/algorithm/xax4l.png)

## mergeOptions

回到 `mergeOptions` 这个函数，它的定义在 `src/core/util/options.js` 中
```js
function mergeOptions(
  parent,
  child,
  vm
) {
  // ...

  if (typeof child === 'function') {
    child = child.options;
  }

  normalizeProps(child, vm);
  normalizeInject(child, vm);
  normalizeDirectives(child);

  // 只对未合并的 options 做处理，因为只有已合并的 options 才有 _base 属性
  if (!child._base) {
    if (child.extends) {
      parent = mergeOptions(parent, child.extends, vm);
    }
    if (child.mixins) {
      for (var i = 0, l = child.mixins.length; i < l; i++) {
        parent = mergeOptions(parent, child.mixins[i], vm);
      }
    }
  }

  var options = {};
  var key;
  for (key in parent) {
    mergeField(key);
  }
  for (key in child) {
    // 如果 key 不在 parent 的自身属性上
    if (!hasOwn(parent, key)) {
      mergeField(key);
    }
  }
  // 合并策略
  function mergeField(key) {
    var strat = strats[key] || defaultStrat;
    options[key] = strat(parent[key], child[key], vm, key);
  }
  return options
}
```

`mergeOptions` 主要功能就是把 `parent` 和 `child` 这两个对象根据一些合并策略，合并成一个新对象并返回。有两个核心逻辑：

* 当 `child` 是未合并的 `options` 时(`!child._base`)，递归调用 `mergeOptions` 。将 `parent` 分别和 `child.extends`、`child.mixins` 合并，最后的结果赋给 `parent`
* 遍历 `parent`，调用 `mergeField`，然后再遍历 `child`，如果 `key` 不在 `parent` 的自身属性上，则调用 `mergeField`

### mergeField

首先定义了 `strat`， `strat` 实际上也是个函数，它的取值有两个来源，我们先看这个 `defaultStrat` 的定义：
```js
const defaultStrat = function(parentVal: any, childVal: any): any {
  return childVal === undefined ? parentVal : childVal;
};
```
`defaultStrat` 的逻辑很简单，有 `childVal` 就用 `childVal` ，没有就用 `parentVal` 。

再看`strats`的定义：
```js
const strats = config.optionMergeStrategies;  // Object.create(null)
```
这里 `strats` 的值其实就是个**空对象**。`strats` 就是各种选项合并策略函数的集合，用来合并父 `options` 的 `value` 和`子options` 的 `value`。

举例来说，对于生命周期函数，它的合并策略是这样的：

```js
function mergeHook (
  parentVal: ?Array<Function>,
  childVal: ?Function | ?Array<Function>
): ?Array<Function> {
  return childVal
    ? parentVal
      ? parentVal.concat(childVal)
      : Array.isArray(childVal)
        ? childVal
        : [childVal]
    : parentVal
}

LIFECYCLE_HOOKS.forEach(hook => {
  strats[hook] = mergeHook
})
```

这其中的 `LIFECYCLE_HOOKS` 的定义在 `src/shared/constants.js` 中：
```js
export const LIFECYCLE_HOOKS = [
  'beforeCreate',
  'created',
  'beforeMount',
  'mounted',
  'beforeUpdate',
  'updated',
  'beforeDestroy',
  'destroyed',
  'activated',
  'deactivated',
  'errorCaptured'
]
```
这里定义了所有的钩子函数名称，所以对于钩子函数，他们的合并策略都是 `mergeHook` 函数。
下面分析一下 mergeHook 函数：

* 如果不存在 `childVal`，就返回 `parentVal`
* 否则再判断是否存在 `parentVal`，如果存在就把 `childVal` 添加到 `parentVal` 后返回新数组；否则返回 `childVal` 的数组。
所以回到 mergeOptions 函数，一旦 parent 和 child 都定义了相同的钩子函数，那么它们会把 2 个钩子函数合并成一个数组。

关于其它属性的合并策略的定义都可以在 `src/core/util/options.js` 文件中看到。

因此，在我们这个例子下，执行完如下合并后：
```js
vm.$options = mergeOptions(
  resolveConstructorOptions(vm.constructor),
  options || {},
  vm
)
```
`vm.$options` 的值差不多是如下这样：

```js
vm.$options = {  
  components: { },  
  created: [    
    function created() {      
      console.log('parent created')    
    }  
  ],  
  directives: { },  
  filters: { },  
  _base: function Vue(options) {   
     // ...  
  },  
  el: "#app",  
  render: function (h) {    
    //...  
  }
}
```

# 内部调用场景：

回忆下子组件的初始化过程，代码定义在 `src/core/vdom/create-component.js` 中：
```js
export function createComponentInstanceForVnode (  
  vnode: any,  
  parent: any, // activeInstance in lifecycle state
): Component {  
  const options: InternalComponentOptions = {    
    _isComponent: true,    
    _parentVnode: vnode,    
    parent  
  }  
  // ...  
  return new vnode.componentOptions.Ctor(options)
}
```
* `vnode.componentOptions.Ctor` 就是在 `createComponent` 过程中通过调用 `Vue.extend` 返回的 `Sub构造函数`
* 所以 执行 `new vnode.componentOptions.Ctor(options)` 接着执行 `this._init(options)`
* 在 `Vue.extend` 中定义了 `Sub.options`

## Sub.options

回顾一下这个过程，代码定义在 `src/core/global-api/extend.js` 中。

```js
Vue.extend = function (extendOptions: Object): Function {
  // ...
  Sub.options = mergeOptions(
    Super.options,
    extendOptions
  )

  // ...
  // keep a reference to the super options at extension time.
  // later at instantiation we can check if Super's options have
  // been updated.
  Sub.superOptions = Super.options
  Sub.extendOptions = extendOptions
  Sub.sealedOptions = extend({}, Sub.options)

  // ...
  return Sub
}
```
`extendOptions` 对应的就是的组件对象，它会和 `Vue.options` 合并到 `Sub.opitons` 中

## mergeOptions

执行`new vnode.componentOptions.Ctor(options)`紧接着会执行`this._init(options)`，因为 `options._isComponent` 为 `true`，那么合并 `options` 的过程走到了 `initInternalComponent(vm, options)` 逻辑
```js
Vue.prototype._init = function (options?: Object) {  
  // merge options  
  if (options && options._isComponent) {    
    initInternalComponent(vm, options)  
  } else {    
    // ...  
  }  
  // ...
}
```
```js
export function initInternalComponent (vm: Component, options: InternalComponentOptions) {
  const opts = vm.$options = Object.create(vm.constructor.options)
  // doing this because it's faster than dynamic enumeration.
  const parentVnode = options._parentVnode
  opts.parent = options.parent
  opts._parentVnode = parentVnode

  const vnodeComponentOptions = parentVnode.componentOptions
  opts.propsData = vnodeComponentOptions.propsData
  opts._parentListeners = vnodeComponentOptions.listeners
  opts._renderChildren = vnodeComponentOptions.children
  opts._componentTag = vnodeComponentOptions.tag

  if (options.render) {
    opts.render = options.render
    opts.staticRenderFns = options.staticRenderFns
  }
}
```
1. 首先执行 `const opts = vm.$options = Object.create(vm.constructor.options)`，这里的 `vm.constructor` 就是子组件的`构造函数Sub`，相当于: `vm.$options = Object.create(Sub.options)`。
2. 保存父VNode实例 `parentVnode` 实例到 `vm.$options` 中
3. 保存子组件的父Vue实例 `parent` 到 `vm.$options` 中
4. 另外还保留了`parentVnode` 配置中的如 propsData、listeners 等其它的属性。

总结：这么看来，initInternalComponent 只是做了简单一层对象赋值，并不涉及到递归、合并策略等复杂逻辑。

最后vm.$options 的值差不多是如下这样：

```js
vm.$options = {
  parent: Vue /*父Vue实例*/,
  propsData: undefined,
  _componentTag: undefined,
  _parentVnode: VNode /*父VNode实例*/,
  _renderChildren:undefined,
  __proto__: {
    components: { },
    directives: { },
    filters: { },
    _base: function Vue(options) {
        //...
    },
    _Ctor: {},
    created: [
      function created() {
        console.log('parent created')
      }, function created() {
        console.log('child created')
      }
    ],
    mounted: [
      function mounted() {
        console.log('child mounted')
      }
    ],
    data() {
       return {
         msg: 'Hello Vue'
       }
    },
    template: '<div>{{msg}}</div>'
  }
}
```

# 总结：

，Vue 初始化阶段对于options 的合并有 2 种方式，子组件初始化过程通过 initInternalComponent 方式要比外部初始化 Vue 通过 mergeOptions 的过程要快,合并完的结果保留在 vm.$options 中。