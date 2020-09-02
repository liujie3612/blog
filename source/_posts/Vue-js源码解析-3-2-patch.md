---
title: Vue.js源码解析 3-2-patch
date: 2020-08-18 21:47:51
tags:
  - vue
  - 源码解析
  - 源码
  - 组件化
---

之前的章节分析我们已经知道，当我们通过 createComponent 创建了组件 VNode，接下来会走到 vm._update，执行 `vm.__patch__` 去把 VNode 转换成真正的 DOM 节点。

patch 的流程比较复杂，先画一个图加深下印象：

![](https://cdn.liujiefront.com/images/algorithm/n3xgy.png)

<!-- more -->

## 两个概念：

进入正文之前先了解两个概念，后面会经常提到：

### 组件的两个 vnode

1. 占位符 vnode：vm.$vnode 只有组件实例才有。在 `_render` 过程中赋值
   ![](https://cdn.liujiefront.com/images/algorithm/fi64p.png)
2. 渲染 vnode：vm._vnode 可以直接映射成真实 DOM。在 `_update` 过程中赋值
   ![](https://cdn.liujiefront.com/images/algorithm/6za0m.png)

它们是父子关系：`vm._vnode.parent = vm.$vnode`

比如对于本文的例子来说：

- 当根 Vue 实例的 render 函数执行完毕，会生成根实例的 _vnode
- 由于 createElement 直接返回了 App 组件，所以根实例_vnode 同样也是 App 组件的$vnode。
  `$vm0._vnode === $vm1.$vnode`
- 对于 App 组件来说，他的占位符 vnode 和渲染 vnode 实际上是一种父子关系
  ![](https://cdn.liujiefront.com/images/algorithm/3pzu6.png)

### activeInstance

整个初始化是一个深度遍历的过程。在实例化子组件的过程中，它需要知道当前上下文的 Vue 实例是什么，并把它作为子组件的父 Vue 实例。

```js
export let activeInstance: any = null;
export function setActiveInstance(vm: Component) {
  const prevActiveInstance = activeInstance;
  activeInstance = vm;
  return () => {
    activeInstance = prevActiveInstance;
  };
}
export function lifecycleMixin(Vue: Class<Component>) {
  Vue.prototype._update = function (vnode: VNode, hydrating?: boolean) {
    const vm: Component = this;
    // 在调用 __patch__ 前先用 prevActiveInstance 保存 activeInstance
    // 然后将当前实例 vm 赋给 activeInstance
    const restoreActiveInstance = setActiveInstance(vm);
    // vm.__patch__...
    // 在执行完 __patch__ 后再恢复 activeInstance 原来的值
    restoreActiveInstance();
  };
}
```

在 vm._update 的过程中，把当前的 vm 赋值给 activeInstance，同时用 prevActiveInstance 保留上一次的 activeInstance。prevActiveInstance 和当前的 vm 是一个父子关系。当一个 vm 实例完成它的所有子树的 patch 或者 update 过程后，**activeInstance 会回到它的父实例**这样就完美地保证了整个深度遍历过程中，我们在实例化子组件的时候能传入当前子组件的父 Vue 实例。

## patch

patch 的过程会调用 `createElm` 创建元素节点，作用是：通过虚拟节点创建真实的 DOM 并插入到它的父节点中。它的定义在 `src/core/vdom/patch.js` 中：

```js
function createElm(
  vnode,
  insertedVnodeQueue,
  parentElm,
  refElm,
  nested,
  ownerArray,
  index
) {
  // ...
  if (createComponent(vnode, insertedVnodeQueue, parentElm, refElm)) {
    return;
  }
  // ...
}
```

（上一节的`createComponent`是定义在`src/core/vdom/create-component.js`，目的是返回组件 vnode；而这里的`createComponent`是根据 vnode 完成组件 DOM 的插入）

```js
function createComponent(vnode, insertedVnodeQueue, parentElm, refElm) {
  let i = vnode.data;
  if (isDef(i)) {
    const isReactivated = isDef(vnode.componentInstance) && i.keepAlive;
    if (isDef((i = i.hook)) && isDef((i = i.init))) {
      // 1 执行 init 钩子，执行完时已经创建了一个子实例并挂载
      i(vnode, false /* hydrating */);
    }
    if (isDef(vnode.componentInstance)) {
      // 2 设置占位符vnode的elm
      initComponent(vnode, insertedVnodeQueue);
      // 3 挂载子组件
      insert(parentElm, vnode.elm, refElm);
      // ...
      return true;
    }
  }
}
```

1. if 语句的意思是判断 vnode.data.hook.init 是否存在，这里 vnode 是一个组件 VNode，那么条件满足，并且得到 i 就是 init 钩子函数。主要作用是：

- 实例化 App 子组件
- 执行子组件挂载 child.$mount

2. initComponent 主要是执行了 vnode.elm = vnode.componentInstance.$el
3. insert 是将其组件插入到 body 中

### 执行 init 钩子

回顾[上一节](https://blog.liujiefront.com/2020/08/18/Vue-js%E6%BA%90%E7%A0%81%E8%A7%A3%E6%9E%90-3-createComponent/)，在执行 `createComponent` 函数的时候会调用 `installComponentHooks` 函数给 vnode.data.hook 安装四个钩子函数`init,prepatch,insert,destroy`。

```js
const componentVNodeHooks = {
  init(vnode: VNodeWithData, hydrating: boolean): ?boolean {
    if (
      vnode.componentInstance &&
      !vnode.componentInstance._isDestroyed &&
      vnode.data.keepAlive
    ) {
      // keepAlive 相关...
    } else {
      // 创建一个 Vue 的实例
      const child = (vnode.componentInstance = createComponentInstanceForVnode(
        vnode,
        activeInstance
      ));
      // 子组件挂载
      child.$mount(hydrating ? vnode.elm : undefined, hydrating);
    }
  },
  prepatch: function prepatch(oldVnode, vnode) {},

  insert: function insert(vnode) {},

  destroy: function destroy(vnode) {},
};
```

- 通过 createComponentInstanceForVnode 创建一个 Vue 实例，传入两个参数：
  - vnode 表示当前 App 组件的占位符 VNode
  - activeInstance 表示根 Vue 实例
- 返回的子组件实例保存到 App 组件的占位符 vnode 的 componentInstance 属性中。
- 通过 $mount 挂载子组件

#### 创建子组件实例

先来看一下 `createComponentInstanceForVnode` 的实现：

```js
export function createComponentInstanceForVnode(
  vnode: any,
  parent: any // activeInstance in lifecycle state
): Component {
  const options: InternalComponentOptions = {
    _isComponent: true,
    _parentVnode: vnode, // 占位符vnode
    parent,
  };
  // inline-template 相关...
  return new vnode.componentOptions.Ctor(options);
}
```

分别做了两件事：

1. 创建 options 对象：

   - _isComponent 为 true 表示它是一个组件
   - _parentVnode 表示当前组件的 vnode，也就是占位符 vnode,`_render`过程中赋值
   - parent 表示当前激活的组件实例，也就是 根 Vue 实例

2. 实例化 App 子组件：
   - vnode.componentOptions.Ctor 就是子组件的构造函数
   - 我们上一节分析了它实际上是继承于 Vue 的一个构造器 Sub，所以相当于 `new Sub(options)`，所以子组件的实例化实际上就是在这个时机执行的，并且它会执行实例的 `_init` 方法

```js
const Sub = function VueComponent() {
  this._init(options);
};
```

所以子组件的实例化实际上就是在这个时机执行的，并且它会执行实例的 `_init` 方法，代码在`src/core/instance/init.js`

```js
Vue.prototype._init = function (options?: Object) {
  const vm: Component = this;
  // merge options
  if (options && options._isComponent) {
    // 子组件mergeOptions
    initInternalComponent(vm, options);
  } else {
    vm.$options = mergeOptions(
      resolveConstructorOptions(vm.constructor),
      options || {},
      vm
    );
  }
  // ...
  initLifecycle(vm);
  // 组件初始化的时候是不传 el 的，因此组件是自己接管了 $mount 的过程
  if (vm.$options.el) {
    vm.$mount(vm.$options.el);
  }
};
```

- 首先是合并 options 的过程有变化，`_isComponent` 为 true，所以走到了 `initInternalComponent` 过程。
- 执行 `initLifecycle`，**建立父子实例之间的关系**
- 组件初始化的时候是不传 el 的，因此**组件是自己接管了 $mount 的过程**，相当于执行
`child.$mount(undefined, false)`，它最终会调用 `mountComponent` 方法，进而执行 `vm._render()` 方法

##### initInternalComponent

```js
export function initInternalComponent(
  vm: Component,
  options: InternalComponentOptions
) {
  // 创建 vm.$options 对象
  const opts = (vm.$options = Object.create(vm.constructor.options));
  const parentVnode = options._parentVnode;
  opts.parent = options.parent; // 保存父Vue实例
  opts._parentVnode = parentVnode; // 保存组件占位符vnode
}
```

它们是把之前我们通过 `createComponentInstanceForVnode` 函数传入的几个参数合并到内部的选项 $options 里了。

##### initLifecycle

```js
export function initLifecycle(vm: Component) {
  const options = vm.$options;
  // 找到第一个非抽象的parent
  let parent = options.parent;
  if (parent && !options.abstract) {
    while (parent.$options.abstract && parent.$parent) {
      parent = parent.$parent;
    }
    // 保存父子实例关系
    parent.$children.push(vm);
  }
  vm.$parent = parent;
  vm.$root = parent ? parent.$root : vm;
  vm.$children = [];
  // ...
}
```

可以看到 vm.$parent 就是用来保留当前 vm 的父实例，并且通过 parent.$children.push(vm) 来把当前的 vm 存储到父实例的 $children 中。

#### 挂载子组件

由于组件初始化的时候是不传 el 的，因此组件是自己接管了 $mount 的过程。
回到组件 init 的过程，`componentVNodeHooks` 的 init 钩子函数，在完成实例化的 _init 后，接着会执行
`child.$mount(hydrating ? vnode.elm : undefined, hydrating)`
所以这里 $mount 相当于执行 child.$mount(undefined, false)，它最终会调用 mountComponent 方法，进而执行 vm._render() 方法：

```js
Vue.prototype._render = function (): VNode {
  const vm: Component = this;
  const { render, _parentVnode } = vm.$options;

  // 保存占位符vnode  外壳节点
  vm.$vnode = _parentVnode;

  let vnode;
  try {
    // 通过render函数创建组件渲染vnode
    vnode = render.call(vm._renderProxy, vm.$createElement);
  } catch (e) {
    // ...
  }
  // 将占位符vnode保存到渲染vnode的parent属性中
  vnode.parent = _parentVnode;
  return vnode;
};
```

- 保存占位符 vnode 到 App 组件实例的 `vm.$vnode` 中
- 调用 render 函数生成`渲染vnode`
- 保存`占位符vnode` 和 `渲染vnode` 的父子关系。vm._vnode.parent = vm.$vnode

执行完 `vm._render` 生成 VNode 后，接下来就要执行 `vm._update` 去渲染 VNode 了,vm._update 的定义在 `src/core/instance/lifecycle.js` 中：

```js
export function lifecycleMixin(Vue: Class<Component>) {
  Vue.prototype._update = function (vnode: VNode, hydrating?: boolean) {
    const vm: Component = this;
    const prevEl = vm.$el;
    const prevVnode = vm._vnode;
    // activeInstance 保存为当前 App 组件的实例...
    const prevActiveInstance = activeInstance;
    activeInstance = vm;

    // 保存通过vm._render()生成的渲染vnode
    // vm._vnode 和 vm.$vnode 的关系就是一种父子关系
    vm._vnode = vnode;

    if (!prevVnode) {
      // 首次渲染
      vm.$el = vm.__patch__(vm.$el, vnode, hydrating, false /* removeOnly */);
    } else {
      // updates
      vm.$el = vm.__patch__(prevVnode, vnode);
    }
    // 恢复 activeInstance 为根Vue实例...
    activeInstance = prevActiveInstance;
    // ...
  };
}
```

- 保存通过 render 生成的 `渲染vnode`
- activeInstance 更新为 App 组件的实例
- 调用 __patch__ 渲染 VNode，
  - 返回结果为 App 子组件的渲染 vnode 的 elm，也就是 vnode.elm
  - 将结果赋值给 App 子组件实例的 $el
- 恢复 activeInstance 为根 Vue 实例

##### 调用 __patch__ 渲染 VNode

```js
vm.$el = vm.__patch__(vm.$el, vnode, hydrating, false /* removeOnly */);

function patch(oldVnode, vnode, hydrating, removeOnly) {
  // ...
  let isInitialPatch = false;
  const insertedVnodeQueue = [];

  if (isUndef(oldVnode)) {
    // empty mount (likely as component), create new root element
    isInitialPatch = true;
    createElm(vnode, insertedVnodeQueue);
  } else {
    // ...
  }
  // ...
}
```

传入的前两个参数分别是：
- oldVnode：App 子组件的 $el，此时是 undefined
- vnode：App 子组件的渲染 vnode

之前分析过负责渲染成 DOM 的函数是 `createElm`，注意这里我们只传了 2 个参数，所以对应的 `parentElm` 是 `undefined`

```js
function createElm(
  vnode, // 渲染vnode
  insertedVnodeQueue,
  parentElm, // undefined
  refElm,
  nested,
  ownerArray,
  index
) {
  // ...
  if (createComponent(vnode, insertedVnodeQueue, parentElm, refElm)) {
    return;
  }

  const data = vnode.data;
  const children = vnode.children;
  const tag = vnode.tag;
  if (isDef(tag)) {
    // ...

    vnode.elm = vnode.ns
      ? nodeOps.createElementNS(vnode.ns, tag)
      : nodeOps.createElement(tag, vnode);
    setScope(vnode);

    /* istanbul ignore if */
    if (__WEEX__) {
      // ...
    } else {
      createChildren(vnode, children, insertedVnodeQueue);
      if (isDef(data)) {
        invokeCreateHooks(vnode, insertedVnodeQueue);
      }
      insert(parentElm, vnode.elm, refElm);
    }

    // ...
  } else if (isTrue(vnode.isComment)) {
    vnode.elm = nodeOps.createComment(vnode.text);
    insert(parentElm, vnode.elm, refElm);
  } else {
    vnode.elm = nodeOps.createTextNode(vnode.text);
    insert(parentElm, vnode.elm, refElm);
  }
  // ...
}
```

注意：这里我们传入的 vnode 是组件渲染的 vnode，也就是我们之前说的 vm._vnode

- 再次执行 createComponent 判断，此时组件根节点是普通元素，因此返回 false
- 先创建一个父节点占位符
- 然后再遍历所有子 VNode 递归调用 createElm
- 在遍历的过程中，如果遇到子 VNode 是一个组件的 VNode，则重复本节开始的过程，这样通过一个递归的方式就可以完整地构建了整个组件树。
- 由于我们这个时候传入的 parentElm 是空，所以实际上 insert(parentElm, vnode.elm, refElm) 不做任何事，那子组件是怎么插入的呢？在 `createComponent` 有这么一段逻辑：

### initComponent

```js
function createComponent(vnode, insertedVnodeQueue, parentElm, refElm) {
  let i = vnode.data;
  if (isDef(i)) {
    // ....
    if (isDef((i = i.hook)) && isDef((i = i.init))) {
      i(vnode, false /* hydrating */);
    }
    // ...
    if (isDef(vnode.componentInstance)) {
      initComponent(vnode, insertedVnodeQueue);
      insert(parentElm, vnode.elm, refElm);
      if (isTrue(isReactivated)) {
        reactivateComponent(vnode, insertedVnodeQueue, parentElm, refElm);
      }
      return true;
    }
  }
}
```

看下 initComponent 函数：

```js
function initComponent(vnode, insertedVnodeQueue) {
  // ...
  vnode.elm = vnode.componentInstance.$el;
  // ...
}
```

这个函数主要就是将 App 子组件实例上的 $el 保存到占位符 vnode 的 elm 属性上

### 挂载子组件（组件dom的插入）

**实际上对于对组件的插入，在 createComponent 中调用了 insert 方法**

```js
function createComponent (vnode, insertedVnodeQueue, parentElm, refElm) {
  let i = vnode.data
  if (isDef(i)) {
    // ....
    if (isDef(i = i.hook) && isDef(i = i.init)) {
       // 2.1 执行 init 钩子，执行完时已经创建了一个子实例并挂载
      i(vnode, false /* hydrating */)
    }
    // ...
    if (isDef(vnode.componentInstance)) {
      // 2.2 设置占位符vnode的elm
      initComponent(vnode, insertedVnodeQueue)
      // 2.3 挂载子组件
      insert(parentElm, vnode.elm, refElm)
      // ...
      return true
    }
  }
}
```

在完成组件的整个 patch 过程后，最后执行 `insert(parentElm, vnode.elm, refElm)` 完成组件的 DOM 插入，如果组件 patch 过程中又创建了子组件，那么 DOM 的插入顺序是**先子后父**。`parentElm`最后会是 body
