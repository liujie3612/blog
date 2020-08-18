---
title: Vue-js源码解析-3-createComponent
date: 2020-08-18 15:42:11
tags:
- vue
- 源码解析
- 源码
---

Vue.js 另一个核心思想是组件化。所谓组件化，就是把页面拆分成多个组件 (component)，每个组件依赖的 CSS、JavaScript、模板、图片等资源放在一起开发和维护。组件是资源独立的，组件在系统内部可复用，组件和组件之间可以嵌套。

用 Vue-cli 初始化的代码为例，来分析一下 Vue 组件初始化的一个过程。

<!-- more -->

## 核心代码

```js
import Vue from 'vue'
import App from './App.vue'

var app = new Vue({
  el: '#app',
  render: h => h(App)
})
```
这里的 h 是 `createElement` 方法，上一节的学习中我们了解到它最终会调用 `_createElement` 方法，其中有一段逻辑是对参数 tag 的判断，如果是一个普通的 html 标签，则会实例化一个普通 VNode 节点，否则通过 createComponent 方法创建一个组件 VNode。
``` js
if (typeof tag === 'string') {

} else {
  // direct component options / constructor
  vnode = createComponent(tag, data, context, children)
}
```

看下createComponent的实现，它定义在 `src/core/vdom/create-component.js` 文件中：
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
  if (typeof Ctor !== 'function') {
    if (process.env.NODE_ENV !== 'production') {
      warn(`Invalid Component definition: ${String(Ctor)}`, context)
    }
    return
  }

    // 暂时不需要关心的其他逻辑：  
    // 1. 异步组件  
    // 2. 如果在创建组件构造函数之后应用了全局mixin，则解析构造函数options  
    // 3. 将组件 v-model 转换成 props & events  
    // 4. 提取props  
    // 5. 函数式组件  
    // 6. 对事件监听的处理  
    // 7. 抽象组件处理


  // 核心逻辑2：安装组件钩子函数
  installComponentHooks(data)

  // 核心逻辑3：实例化 VNode
  const name = Ctor.options.name || tag
  const vnode = new VNode(
    `vue-component-${Ctor.cid}${name ? `-${name}` : ''}`,
    data, undefined, undefined, undefined, context,
    { Ctor, propsData, listeners, tag, children },
    asyncFactory
  )

  // Weex的一些逻辑...
  return vnode
}
```
核心流程只有三个：
1. 构造子类构造函数
2. 安装组件钩子函数
3. 实例化 vnode

### 构造子类构造函数

```js
const baseCtor = context.$options._base
// plain options object: turn it into a constructor
if (isObject(Ctor)) {
  Ctor = baseCtor.extend(Ctor)
}
```
这里的baseCtor实际上是Vue，这个的定义是在最开始初始化 Vue 的阶段，在 `initGlobalAPI` 函数有这么一段逻辑：`Vue.options._base = Vue`。这里虽然定义的是`Vue.options`但是createComponent 取的是 `context.$options`，实际在 src/core/instance/init.js 里 Vue 原型上的 _init 函数中有这么一段逻辑：
```js
vm.$options = mergeOptions(
  resolveConstructorOptions(vm.constructor),
  options || {},
  vm
)
```
这样就把 Vue 上的一些 option 扩展到了 vm.$options 上。所以我们也就能通过 vm.$options._base 拿到 Vue 这个构造函数了。![mergeOptions]()的功能是**把 Vue 构造函数的 options 和用户传入的 options 做一层合并，到 vm.$options 上**。

另外，我们的组件通常都是一个普通的对象，比如通过 `vue-loader` 对我们的单文件组件处理以后返回的就是一个`普通的对象`
![](https://cdn.liujiefront.com/images/vue-source/7ushl.png)

所以 isObject(Ctor) 为真，然后通过 baseCtor.extend(Ctor) 创建构造函数，也就是 `Vue.extend`

``` js
Vue.extend = function (extendOptions: Object): Function {
  extendOptions = extendOptions || {}
  const Super = this
  const SuperId = Super.cid
  const cachedCtors = extendOptions._Ctor || (extendOptions._Ctor = {})
  // 是否返回缓存构造函数
  if (cachedCtors[SuperId]) {
    return cachedCtors[SuperId]
  }

  const name = extendOptions.name || Super.options.name
  if (process.env.NODE_ENV !== 'production' && name) {
    validateComponentName(name) // 验证name
  }

  const Sub = function VueComponent (options) {
     // 执行 this._init 逻辑再次走到了 Vue 实例的初始化逻辑，实例化子组件的逻辑在之后的章节会介绍。
    this._init(options)
  }
  // 原型继承
  Sub.prototype = Object.create(Super.prototype)
  Sub.prototype.constructor = Sub
  Sub.cid = cid++
  Sub.options = mergeOptions(
    Super.options,
    extendOptions
  )
  Sub['super'] = Super

  // ...

  // 缓存构造函数
  cachedCtors[SuperId] = Sub
  return Sub
}
```
Vue.extend 的作用就是：
1. 定义子类构造函数 Sub，基于原型链继承于 Vue（把一个**纯对象**转换一个**继承于 Vue 的构造器 Sub** 并返回（对象转函数））
2. 对 Sub 这个对象本身扩展了一些属性，如：
   - 扩展 options，添加全局 API
   - 对配置中的 props 和 computed 做了初始化工作。
   - initProps
3. 缓存构造函数，避免多次执行 Vue.extend 的时候对同一个子组件重复构造。

### 安装组件钩子函数

`installComponentHooks(data)`安装的作用就是在 VNode 执行 ![pach]() 的过程中执行相关的钩子函数：

```js
function installComponentHooks (data: VNodeData) {
  const hooks = data.hook || (data.hook = {})
  for (let i = 0; i < hooksToMerge.length; i++) {
    const key = hooksToMerge[i]
    const existing = hooks[key]
    const toMerge = componentVNodeHooks[key]
    if (existing !== toMerge && !(existing && existing._merged)) {
      hooks[key] = existing ? mergeHook(toMerge, existing) : toMerge
    }
  }
}
```
这里需要了解两个东西：
- componentVNodeHooks对象
- mergeHook函数

#### componentVNodeHooks

Vue.js 使用的 Virtual DOM 参考的是开源库 snabbdom，它的一个特点是在 VNode 的 patch 流程中对外暴露了各种时机的钩子函数，方便我们做一些额外的事情，Vue.js 也是充分利用这一点，在初始化一个 Component 类型的 VNode 的过程中实现了几个钩子函数：
```js
const componentVNodeHooks = {
  init (vnode: VNodeWithData, hydrating: boolean): ?boolean {
    // ...
  },

  prepatch (oldVnode: MountedComponentVNode, vnode: MountedComponentVNode) {
    // ...
  },

  insert (vnode: MountedComponentVNode) {
    // ...
  },

  destroy (vnode: MountedComponentVNode) {
    // ...
  }
}
```

####  mergeHook
```js
function mergeHook (f1: any, f2: any): Function {
  const merged = (a, b) => {
    // flow complains about extra args which is why we use any
    f1(a, b)
    f2(a, b)
  }
  merged._merged = true
  return merged
}
```
`mergeHook` 函数逻辑很简单，所谓合并就是先执行 `componentVNodeHooks` 定义的, 再执行 data.hooks 定义的，再将合并标志位设为 true。

所以`installComponentHooks`的过程就是把 `componentVNodeHooks` 的钩子函数合并到 `data.hook` 中，在 VNode 执行 patch 的过程中执行相关的钩子函数，具体的执行我们稍后在介绍 patch 过程中会详细介绍。这里要注意的是合并策略，在合并过程中，如果某个时机的钩子已经存在 data.hook 中，那么通过执行 mergeHook 函数做合并，这个逻辑很简单，就是在最终执行的时候，依次执行这两个钩子函数即可。

### 实例化 VNode
```js
const name = Ctor.options.name || tag
const vnode = new VNode(
  `vue-component-${Ctor.cid}${name ? `-${name}` : ''}`,
  data, undefined, undefined, undefined, context,
  { Ctor, propsData, listeners, tag, children },
  asyncFactory
)
return vnode
```
1. 通过 new VNode 实例化一个 vnode 并返回。
2. 和普通元素节点的 vnode 不同，**组件的 vnode 没有 children**，这点很关键，在之后的 patch 过程中我们会再提。
3. 第七个参数是 `componentOptions` ，在 patch 过程中可以通过 `new vnode.componentOptions.Ctor` 来实例化子组件构造函数

## 总结：

这一节我们分析了 createComponent 的实现，了解到它在渲染一个组件的时候的 3 个关键逻辑：构造子类构造函数，安装组件钩子函数和实例化 vnode。createComponent 后返回的是组件 vnode，它也一样走到 vm._update 方法，进而执行了 patch 函数，我们在上一章对 patch 函数做了简单的分析，那么下一节我们会对它做进一步的分析。