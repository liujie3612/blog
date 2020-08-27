---
title: Vue.js源码解析(2) - 数据驱动
date: 2020-04-27 16:11:36
tags:
- vue
- 源码解析
- 源码
---

所谓数据驱动是指视图是由数据驱动生成的，我们对视图的修改，不会直接操作 DOM，而是通过修改数据。这一节重点是模板和数据如何渲染成最终的 DOM，也就是初始化的步骤，还有就是数据更新驱动视图变化，这个后面会单独分析。

<!-- more -->

## new Vue

`src/core/instance/index.js`文件里：
``` js
function Vue (options) {
  if (process.env.NODE_ENV !== 'production' &&
    !(this instanceof Vue)
  ) {
    warn('Vue is a constructor and should be called with the `new` keyword')
  }
  this._init(options)
}
```
我们new vue其实就是就是执行_init。`src/core/instance/init.js`,vue干的事情有：合并配置，初始化生命周期，初始化事件中心，初始化渲染，初始化 data、props、computed、watcher 等等，这里有一个很重要的代码，`vm.$mount(vm.$options.el)`挂载的目标就是把模板渲染成最终的 DOM，那么接下来我们来分析 Vue 的挂载过程。

## 挂载

挂载是通过`$mount`实例方法去挂载 vm 的，不管是编译版本的还是直接写render函数，最终所有 Vue 的组件的渲染最终都需要 `render` 方法，。最后，调用原先原型上的 $mount 方法挂载。

原先原型上的 $mount 方法在 `src/platform/web/runtime/index.js` 中定义,所以这么设计完全是为了复用，因为它是可以被 `runtime only`(对比于`Runtime + Compiler`) 版本的 Vue 直接使用的。

$mount 方法实际上会去调用 mountComponent 方法，这个方法定义在 `src/core/instance/lifecycle.js` 文件中：mountComponent 核心就是先实例化一个 `渲染Watcher`，在它的回调函数中会调用 `updateComponent` 方法，在此方法中调用 `vm._render` 方法中生成虚拟 Node，最终调用 `vm._update` 更新 DOM。
![](https://cdn.liujiefront.com/images/vue-source/19cpk.png)

那么步骤就是 `$mount —> mountComponent -> new Watcher -> updateComponent -> vm._render() -> vm._update`
Watcher 在这里起到两个作用:
1. 初始化的时候会执行回调函数
2. 当 vm 实例中的监测的数据发生变化的时候执行回调函数。
   
下面重点分析`vm._render` 和 `vm._update`。

## render

Vue 的 _render 方法是实例的一个私有方法，它用来把实例渲染成一个 ** 虚拟 Node **。它的定义在 `src/core/instance/render.js` 文件中。render 函数的第一个参数是 `createElement`
``` js
<div id="app">
  {{ message }}
</div>
```
相当于我们编写如下 render 函数：
``` js
render: function (createElement) {
  return createElement('div', {
     attrs: {
        id: 'app'
      },
  }, this.message)
}
```
再回到 _render 函数中的 render 方法的调用：
``` js
vnode = render.call(vm._renderProxy, vm.$createElement)
```

`vm.$createElement` 的赋值是在 `initRender` 

- `vm._c`是`模板`版本使用的，
- `vm.$createElement`是`手写render` 方法

![](https://cdn.liujiefront.com/images/vue-source/gimx5.png)

总结：render 函数中的 `vm.$createElement` 方法其实就是 `createElement` 方法。

**vm._render 最终是通过执行 createElement 方法并返回的是 vnode(Virtual DOM)**

### Virtual DOM

背景: 真正的 DOM 元素是非常庞大的，因为浏览器的标准就把 DOM 设计的非常复杂。当我们频繁的去做 DOM 更新，会产生一定的性能问题。
![](https://cdn.liujiefront.com/images/vue-source/ozfdg.jpg)

Virtual DOM 就是用一个原生的 JS 对象去描述一个 DOM 节点。
Vue.js 中 Virtual DOM 是借鉴了一个开源库 snabbdom 的实现，然后加入了一些 Vue.js 特色的东西
其实 VNode 是对真实 DOM 的一种抽象描述，它的核心定义无非就几个关键属性: 标签名、数据、子节点、键值等，其它属性都是用来扩展 VNode 的灵活性以及实现一些特殊 feature 的。由于 VNode 只是用来映射到真实 DOM 的渲染，不需要包含操作 DOM 的方法，因此它是非常轻量和简单的。

Virtual DOM 除了它的数据结构的定义，映射到真实的 DOM 实际上要经历 VNode 的 `create`、`diff`、`patch` 等过程。那么在 Vue.js 中，VNode 的 create 是通过之前提到的 createElement 方法创建的

### createElement

Vue.js 利用 `createElement` 方法创建 VNode，它定义在 `src/core/vdom/create-elemenet.js` 中。createElement 方法实际上是对 `_createElement` 方法的封装,做了两件事：

* 如果第三个参数是一个 数组 或者 原始类型（不包括null和undefined），那么就参数重载。
* 判断 `alwaysNormalize` 是否为 true然后将 `normalizationType = ALWAYS_NORMALIZE`

_createElement方法有 5 个参数
- context：表示 VNode 的上下文环境,它是 Component 类型
- tag：表示标签，它可以是一个字符串，也可以是一个 Component
- data：表示 VNode 的数据，它是一个 VNodeData 类型
- children：表示当前 VNode 的子节点，它是任意类型的，下面会单独说到它
- normalizationType：表示子节点规范的类型，主要还是render 函数是编译生成的还是用户手写的

```js
export function _createElement (
  context: Component,
  tag?: string | Class<Component> | Function | Object,
  data?: VNodeData,
  children?: any,
  normalizationType?: number
): VNode | Array<VNode> {
 // 一些边缘情况，暂时不需要关注：  
 // 1. 传入的 data 参数不能是被观察的 data  
 // 2. 动态组件处理  
 // 3. key值如果不是原始类型则抛出警告  
 // 4. support single function children as default scoped slot

  // 核心逻辑1：规范化chidlren
  if (normalizationType === ALWAYS_NORMALIZE) {
    children = normalizeChildren(children)
  } else if (normalizationType === SIMPLE_NORMALIZE) {
    children = simpleNormalizeChildren(children)
  }
  
   // 核心逻辑2：创建vnode
  let vnode, ns
  if (typeof tag === 'string') {
    let Ctor
    ns = (context.$vnode && context.$vnode.ns) || config.getTagNamespace(tag)
    // 是否HTML原生保留标签
    if (config.isReservedTag(tag)) {
      // platform built-in elements
      vnode = new VNode(
        config.parsePlatformTagName(tag), data, children,
        undefined, undefined, context
      )
    // 是否是已注册的组件名
    } else if (isDef(Ctor = resolveAsset(context.$options, 'components', tag))) {
      vnode = createComponent(Ctor, data, context, children, tag)
    } else {
      // 未知或未列出的命名空间元素
      // 等在运行时检查，因为在其父级标准化子级时可能会为其分配一个名称空间
      vnode = new VNode(
        tag, data, children,
        undefined, undefined, context
      )
    }
  } else {
    // direct component options / constructor
    vnode = createComponent(tag, data, context, children)
  }

  // 返回vnode
  if (Array.isArray(vnode)) {
    return vnode
  } else if (isDef(vnode)) {
    if (isDef(ns)) applyNS(vnode, ns)
    if (isDef(data)) registerDeepBindings(data)
    return vnode
  } else {
    return createEmptyVNode()
  }
}
```

#### children的规范
根据`normalizationType`，分别调用`normalizeChildren`和`simpleNormalizeChildren`
- `simpleNormalizeChildren` 方法调用场景是 render 函数是编译生成的。理论上编译生成的 children 都已经是 VNode 类型的，但functional component 函数式组件返回的是一个数组而不是一个根节点，所以会通过 Array.prototype.concat 方法把整个 children 数组打平，让它的深度只有一层。
- `normalizeChildren`方法的调用场景有 2 种
  - 一个场景是 render 函数是用户手写的，children 允许写成基础类型用来创建单个简单的文本节点，这种情况会调用 `createTextVNode` 创建一个文本节点的 VNode
  - 当编译 <template>、slot、v-for 的时候会产生嵌套数组，这会调用 `normalizeArrayChildren` 方法

  `normalizeArrayChildren`主要的逻辑就是遍历 children，获得单个节点 c，然后对 c 的类型判断
    - 数组：递归调用 normalizeArrayChildren
    - 基础类型：通过 createTextVNode 方法转换成 VNode 类型
    - vnode类型：如果 children 是一个 v-for 列表，则根据 nestedIndex 去更新它的 key。

经过对 children 的规范化，children 变成了一个类型为 VNode 的 Array。

#### VNode的创建

当 tag 是一个字符串时：
  - 如果 tag 是内置标签则直接创建一个对应的 VNode 对象。
  - 如果 tag 如果是已注册的组件名，则调用 `createComponent` 函数。
  - tag 是一个未知的标签名，这里会直接按标签名创建 vnode，然后等运行时再来检查，因为它的父级规范化子级时可能会为其分配命名空间。

当 tag 不是字符串时：
  - 通过 `createComponent` 创建组件类型的 VNode

根据tag的类型，会调用不同的方法去生成vnode的实例，最终返回出去
![](https://cdn.liujiefront.com/images/vue-source/80180.png)

createElement总结：
每个 VNode 有 children，children 每个元素也是一个 VNode，这样就形成了一个 VNode Tree，它很好的描述了我们的 DOM Tree。

## update

上面的提到的`mountComponent`方法里有`vm._update(vm._render(), hydrating)`的调用。（ ** _update 方法的作用是把 VNode 渲染成真实的 DOM ** 对比于 ** _render的作用是把真实的DOM转化为VNode **）。它的定义在 `src/core/instance/lifecycle.js` 中
![](https://cdn.liujiefront.com/images/vue-source/975yl.png)

`_update` 的核心就是调用 `vm.__patch__ `方法, 浏览器下会指向`src/platforms/web/runtime/patch.js`。里面有`createPatchFunction`方法
![](https://cdn.liujiefront.com/images/vue-source/j0c5r.png)

`createPatchFunction`方法很长，内部定义了一系列的辅助方法；
最终一个关键代码是：`return function patch (oldVnode, vnode, hydrating, removeOnly)`。
这个方法就赋值给了`lifecycleMixin`里的`vm.$el`
```js
const hooks = ['create', 'activate', 'update', 'remove', 'destroy']
export function createPatchFunction (backend) {
  let i, j
  const cbs = {}

  const { modules, nodeOps } = backend
  // 遍历，将 hooks 作为 cbs 属性，然后将对应的 modules 的子项 push 到 cbs.hooks 中。
  for (i = 0; i < hooks.length; ++i) {
    cbs[hooks[i]] = []
    for (j = 0; j < modules.length; ++j) {
      if (isDef(modules[j][hooks[i]])) {
        cbs[hooks[i]].push(modules[j][hooks[i]])
      }
    }
  }

  // ...这里定义了很多辅助函数

  // 返回真正的patch
  return function patch (oldVnode, vnode, hydrating, removeOnly) {

  }
}
```

下面对`createPatchFunction`和`patch`函数单独的讲解下：

`createPatchFunction`方法有两个参数：
- nodeOps：表示对 “平台 DOM” 的一些操作方法
- modules：表示平台的一些模块，它们会在整个 patch 过程的不同阶段执行相应的钩子函数。

```js
<body>
    <div id="app"></div>
</body>
var app = new Vue({
    el: '#app',
    render: function(createElement) {
        return createElement('div', {
            attrs: { id: 'app' }
        }, 'Hello Vue!')
    }
})
```

`patch`方法有四个参数：
- oldVnode：例子中 id 为 app 的 DOM 对象，也就是在 HTML 模板中写的 <div id="app">，vm.$el 的赋值是在之前 mountComponent 函数做的。
- vnode：表示执行 _render 后返回的 VNode 的节点；
- hydrating 表示是否是服务端渲染
- removeOnly 是给 transition-group 用的

`patch`函数本身,内部的实现还是很复杂的，看几个关键步骤：
``` js
const isRealElement = isDef(oldVnode.nodeType)
if (!isRealElement && sameVnode(oldVnode, vnode)) {
  // ...

} else {
  if (isRealElement) {
    // ...     

    // 将真实的 DOM 转换成 vnode，也就是 <div id="app"></div>
    oldVnode = emptyNodeAt(oldVnode)
  }
  // 保存真实的DOM
  const oldElm = oldVnode.elm
  // body
  const parentElm = nodeOps.parentNode(oldElm)

  // insertedVnodeQueue 在这是空数组
  // oldEm._leaveCb 在这是 undefined
  // nextSibling表示DOM的右边的节点，在这是换行text节点
  createElm(
    vnode,
    insertedVnodeQueue,
    oldElm._leaveCb ? null : parentElm,
    nodeOps.nextSibling(oldElm)
  )

  // 销毁旧节点        
  if (isDef(parentElm)) {          
    removeVnodes([oldVnode], 0, 0)        
  } else if (isDef(oldVnode.tag)) {
    invokeDestroyHook(oldVnode)        
  }
}
```

1. oldVnode 是真实的 DOM，通过 emptyNodeAt 将真实的 DOM 转换成 vnode
```js
  oldVnode = emptyNodeAt(oldVnode)
```
2. parentElm: 比如 body 节点（`<body><div id="app"></div></body>`）
   
3. 调用 createElm 方法：作用是通过虚拟节点创建真实的 DOM 并插入到它的父节点中:
   
  - createComponent 尝试创建子组件
  - createChildren 创建子元素，实际上是遍历子虚拟节点，递归调用 createElm，这是一种常用的**深度优先**的遍历算法
  - invokeCreateHooks 执行所有的 create 的钩子并把 vnode push 到 insertedVnodeQueue 中
  - insert 把 DOM 插入到父节点中，因为是递归调用，子元素会优先调用 insert，所以整个 vnode 树节点的插入顺序是**先子后父**

4. vnode.parent: 父占位节点。和组件相关
   
5. 判断之前定义的 parentElm 是否存在，有则删除掉 vm.$el 对应的节点。在执行这一步前，浏览器的 DOM 结构是这样的：
```js
<body>
    <div id="app"></div>
    <div id="app">Hello Vue!</div>
</body>
```
之后删除 `<div id="app"></div>` 完成新旧节点替换工作。

6. 最后将 vnode.elm（也就是真实DOM）返回。

## 总结
从初始化 Vue 到最终渲染的整个过程大概能分为这样的步骤：

![](https://cdn.liujiefront.com/images/vue-source/dkmh3.jpg)

