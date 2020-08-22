---
title: Vue.js源码解析(6) - 生命周期
date: 2020-08-20 22:24:29
tags:
  - vue
  - 源码解析
  - 源码
---

每个 Vue 实例在被创建之前都要经过一系列的初始化过程。例如需要设置数据监听、编译模板、挂载实例到 DOM、在数据变化时更新 DOM 等。同时在这个过程中也会运行一些叫做**生命周期**钩子的函数，给予用户机会在一些特定的场景下添加他们自己的代码。

<!-- more -->

先上一张大图：
![](https://cdn.liujiefront.com/images/vue-source/lifecycle.png)

# callHook

源码中最终执行生命周期的函数都是调用 callHook 方法，它的定义在 src/core/instance/lifecycle 中：

```js
export function callHook(vm: Component, hook: string) {
  // 为了避免在某些生命周期钩子中使用 props 数据导致收集冗余的依赖
  pushTarget();
  var handlers = vm.$options[hook];
  var info = hook + " hook";
  if (handlers) {
    for (var i = 0, j = handlers.length; i < j; i++) {
      invokeWithErrorHandling(handlers[i], vm, null, vm, info);
    }
  }
  // 2. 判断是否存在生命周期钩子的事件侦听器
  if (vm._hasHookEvent) {
    vm.$emit("hook:" + hook);
  }
  // 为了避免在某些生命周期钩子中使用 props 数据导致收集冗余的依赖
  popTarget();
}
```

- 选项合并时会把生命周期钩子选项合并成一个数组
- 遍历对应 hook 的数组，执行 invokeWithErrorHandling
- 判断是否 vm.\_hasHookEvent 触发相应的事件侦听器

## invokeWithErrorHandling

这个函数定义在：src/core/util/error.js

```js
function invokeWithErrorHandling(handler, context, args, vm, info) {
  var res;
  try {
    // 调用handler
    res = args ? handler.apply(context, args) : handler.call(context);
    if (res && !res._isVue && isPromise(res) && !res._handled) {
      res.catch(function (e) {
        return handleError(e, vm, info + " (Promise/async)");
      });
      // 对不同的钩子返回相同的promise时只绑定一次catch函数
      res._handled = true;
    }
  } catch (e) {
    handleError(e, vm, info);
  }
  return res;
}
```

- 调用 handler，同时绑定 this，这样我们在钩子回调就能通过 this 访问到 vm 实例了
- 钩子如果返回一个 promise，那么给这个 promise 绑定一个 catch 函数
- 同时 \_handled 保证了只绑定一次 catch

## \_hasHookEvent

vm.\_hasHookEvent 是在 initEvents 函数中定义的，它的作用是判断是否存在生命周期钩子的事件侦听器，初始化值为 false 代表没有，当组件检测到存在生命周期钩子的事件侦听器时，会将 vm.\_hasHookEvent 设置为 true 介绍下生命周期钩子事件帧听器：

```js
<child  
  @hook:beforeCreate="handleChildBeforeCreate"  
  @hook:created="handleChildCreated"  
  @hook:mounted="handleChildMounted"  
  @hook:生命周期钩子 
/>
```

到这里就把 callHook 的逻辑给介绍完了，下面来看看 callHook 都在什么时候调用

# beforeCreate & created

这两个钩子是在 \_init 方法中执行的

```js
Vue.prototype._init = function (options) {
  initLifecycle(vm);
  initEvents(vm);
  initRender(vm);
  callHook(vm, "beforeCreate");
  initInjections(vm); // resolve injections before data/props
  initState(vm);
  initProvide(vm); // resolve provide after data/props
  callHook(vm, "created");

  if (vm.$options.el) {
    vm.$mount(vm.$options.el);
  }
};
```

- beforeCreate 和 created 的钩子调用是在 initState 的前后执行的
- initState 的作用是初始化 props、data、methods、watch、computed 等属性。
- 所以 beforeCreate 的钩子函数中就不能获取到 props、data 中定义的值，也不能调用 methods 中定义的函数。
- 在这俩个钩子函数执行的时候，并没有渲染 DOM，所以我们也不能够访问 DOM

# beforeMount & mounted

beforeMount 钩子函数发生在 mount，也就是 DOM 挂载之前，它的调用时机是在 `mountComponent` 函数中，定义在 `src/core/instance/lifecycle.js` 中：

```js
function mountComponent(vm, el, hydrating) {
  vm.$el = el;
  // ...
  callHook(vm, "beforeMount")

  var updateComponent;
  /* istanbul ignore if */
  if (process.env.NODE_ENV !== "production" && config.performance && mark) {
    // ...
  } else {
    updateComponent = function () {
      vm._update(vm._render(), hydrating);
    };
  }

  new Watcher(
    vm,
    updateComponent,
    noop,
    {
      before: function before() {
        if (vm._isMounted && !vm._isDestroyed) {
          callHook(vm, "beforeUpdate");
        }
      },
    },
    true /* isRenderWatcher */
  );
  hydrating = false;

  // 手动调用根实例的 mounted 钩子
  // 子组件的 mounted 钩子在 占位符vnode的insert 钩子中调用
  if (vm.$vnode == null) {
    vm._isMounted = true;
    callHook(vm, "mounted")
  }
  return vm;
}
```

- 在执行 `vm._render()` 函数渲染 VNode 之前，执行了 `beforeMount` 钩子函数
- 在执行完 `vm._update()` 把 VNode patch 到真实 DOM 后，执行 `mounted` 钩子。

注意，这里对 mounted 钩子函数执行有一个判断逻辑，`vm.$vnode` 如果为 null，则表明这不是一次组件的初始化过程，而是我们通过外部 `new Vue` 初始化过程。那么对于组件，它的 mounted 时机在哪儿呢？

## 组件的 mounted

之前我们提到过，组件的 VNode patch 到 DOM 后，会执行 `invokeInsertHook` 函数，把 insertedVnodeQueue 里保存的钩子函数依次执行一遍，它的定义在 `src/core/vdom/patch.js`中：

```js
return function patch(oldVnode, vnode, hydrating, removeOnly) {
  // ...
  let isInitialPatch = false; // 区分是否组件patch
  const insertedVnodeQueue = []; // 存放占位符vnode，记录子节点组件创建顺序的队列，调用子组件的mounted

  // oldVnode为空表示这是一个组件的patch
  if (isUndef(oldVnode)) {
    isInitialPatch = true;
    // ...
  } else {
    // ...
  }
  // 传入 insertedVnodeQueue，isInitialPatch
  invokeInsertHook(vnode, insertedVnodeQueue, isInitialPatch);
  return vnode.elm;
};
```

- `isInitialPatch` 表示这是组件的 patch 上下文还是根实例的 patch 上下文
- 调用 invokeInsertHook

```js
function invokeInsertHook(vnode, queue, initial) {
  // 新建的组件实例 vnode（如未挂载、组件实例）且有父 vnode
  if (isTrue(initial) && isDef(vnode.parent)) {
    // 组件调用的逻辑，会往当前渲染 vnode 的占位符 vnode 上的 data 对象挂载 pendingInsert 属性，用来存放队列
    vnode.parent.data.pendingInsert = queue;
  } else {
    // 根实例调用
    // 遍历队列中的占位符 vnode，并执行 insert 钩子
    for (let i = 0; i < queue.length; ++i) {
      queue[i].data.hook.insert(queue[i]);
    }
  }
}
```

该函数会执行 insert 这个钩子函数，对于组件而言，insert 钩子函数的定义在 `src/core/vdom/create-component.js` 中的 componentVNodeHooks 中：

```js
const componentVNodeHooks = {
  // ...
  insert(vnode: MountedComponentVNode) {
    const { context, componentInstance } = vnode;
    if (!componentInstance._isMounted) {
      componentInstance._isMounted = true;
      callHook(componentInstance, "mounted");
    }
    // ...
  },
};
```

可以看到，每个子组件都是在这个钩子函数中执行 mounted 钩子函数，并且我们之前分析过，`insertedVnodeQueue` 的添加顺序是先子后父，所以对于同步渲染的子组件而言，mounted 钩子函数的执行顺序也是先子后父。

## 结合例子分析组件的 mounted

假设现在我们有以下例子：

```js
const App = {
  name: "app",
  render(h) {
    return h("div", {}, "hi vue");
  },
};

var root = new Vue({
  el: "#app",
  render(h) {
    return h(App);
  },
});
```

红色的标号表示步骤:
![](https://cdn.liujiefront.com/images/algorithm/cimn9.png)

步骤 4：invokeInsertHook

![](https://cdn.liujiefront.com/images/algorithm/6dmxz.png)

- 此时的 vnode 是 App 组件的渲染 vnode
- 因为 App 组件已经是最深的那个组件了，所以此时的 queue 是一个空数组
- 通过 vnode.parent 拿到 App 组件的占位符 vnode
- 将 queue 临时保存到占位符 vnode 上

步骤 5: initComponent

```js
function initComponent(vnode, insertedVnodeQueue) {
  if (isDef(vnode.data.pendingInsert)) {
    insertedVnodeQueue.push.apply(insertedVnodeQueue, vnode.data.pendingInsert);
    vnode.data.pendingInsert = null;
  }
  vnode.elm = vnode.componentInstance.$el;
  if (isPatchable(vnode)) {
    invokeCreateHooks(vnode, insertedVnodeQueue);
    // ...
  } else {
    // ...
  }
}
```

- 此时的 vnode 就是 App 组件的占位符 vnode
- 将占位符 vnode 上的临时数组 push 到队列中
- isPatchable 返回 true，执行 invokeCreateHooks 方法

步骤 6：invokeCreateHooks

```js
function invokeCreateHooks(vnode, insertedVnodeQueue) {
  // ...
  let i = vnode.data.hook;
  if (isDef(i)) {
    // ...
    if (isDef(i.insert)) {
      insertedVnodeQueue.push(vnode);
    }
  }
}
```

- 判断 vnode 是否定义了 hook，如果是的话则表明这是一个占位符 vnode
- 将占位符 vnode 推进队列中 此时的 `insertedVnodeQueue` 状态：

![](https://cdn.liujiefront.com/images/algorithm/pzkxg.png)

步骤 7：invokeInsertHook
![](https://cdn.liujiefront.com/images/algorithm/7agc6.png)
![](https://cdn.liujiefront.com/images/algorithm/ddy8v.png)

- 由于此时的上下文已经是根实例了，所以走的是 else 逻辑
- 遍历 insertedVnodeQueue 队列，执行 insert 钩子，在这个钩子又会执行 mounted 钩子

总结:

- beforeMount 先父后子
- mounted 先子后父

# beforeUpdate & updated

顾名思义，beforeUpdate 和 updated 的钩子函数执行时机都应该是在数据更新的时候。
`beforeUpdate` 的执行时机是在渲染 Watcher 的 before 函数中，我们刚才提到过：

```js
export function mountComponent(
  vm: Component,
  el: ?Element,
  hydrating?: boolean
): Component {
  // ...
  new Watcher(
    vm,
    updateComponent,
    noop,
    {
      before() {
        if (vm._isMounted) {
          callHook(vm, "beforeUpdate");
        }
      },
    },
    true /* isRenderWatcher */
  );
  // ...
}
```

注意这里有个判断，也就是在组件已经 mounted 之后，才会去调用这个钩子函数。

`update` 的执行时机是在 `flushSchedulerQueue` 函数调用的时候，它的定义在 `src/core/observer/scheduler.js` 中：

```js
function flushSchedulerQueue() {
  // ...
  // 只需要知道 queue 存放的是一个个 watcher
  for (index = 0; index < queue.length; index++) {
    watcher = queue[index];
    if (watcher.before) {
      watcher.before(); // 执行 before函数，会调用 beforeUpdate 钩子
    }
    // ...
  }

  // 获取到 updatedQueue
  callUpdatedHooks(updatedQueue);
}

function callUpdatedHooks(queue) {
  let i = queue.length;
  while (i--) {
    const watcher = queue[i];
    const vm = watcher.vm;
    if (vm._watcher === watcher && vm._isMounted) {
      callHook(vm, "updated");
    }
  }
}
```

- 遍历 queue，执行了 before 函数，从而执行了 beforeUpdate 函数
- 调用 callUpdatedHooks 函数，参数 updatedQueue 是更新了的 wathcer 数组

在组件 mount 的过程中，会实例化一个渲染的 Watcher 去监听 vm 上的数据变化重新渲染，这段逻辑发生在 `mountComponent` 函数执行的时候，那么在实例化 Watcher 的过程中，在它的构造函数里会判断 `isRenderWatcher`，接着把当前 watcher 的实例赋值给 `vm._watcher`，定义在 `src/core/observer/watcher.js` 中：

```js
export default class Watcher {
  // ...
  constructor(
    vm: Component,
    expOrFn: string | Function,
    cb: Function,
    options?: ?Object,
    isRenderWatcher?: boolean
  ) {
    this.vm = vm;
    if (isRenderWatcher) {
      vm._watcher = this;
    }
    vm._watchers.push(this);
    // ...
  }
}
```

同时，还把当前 wathcer 实例 push 到 `vm._watchers` 中，`vm._watcher` 是专门用来监听 vm 上数据变化然后重新渲染的，所以它是一个渲染相关的 watcher，`updatedQueue` 是更新了的 wathcer 数组，因此在 `callUpdatedHooks` 函数中，它对这些数组做遍历，只有满足当前 watcher 为 `vm._watcher` 以及组件已经 `mounted` 这两个条件，才会执行 updated 钩子函数。

总结:

- beforeUpdate 先父后子
- updated 先子后父

# beforeDestroy & destroyed

顾名思义，beforeDestroy 和 destroyed 钩子函数的执行时机在组件销毁的阶段，组件的销毁过程之后会详细介绍，最终会调用 `$destroy 方法`，它的定义在 `src/core/instance/lifecycle.js` 中：

```js
Vue.prototype.$destroy = function () {
  // ...
  callHook(vm, "beforeDestroy");
  // 递归销毁逻辑
  callHook(vm, "destroyed");
  // ...
};
```

- beforeDestroy 钩子函数的执行时机是在 `$destroy` 函数执行最开始的地方
- 接着执行了一系列的销毁动作
  - 包括从 parent 的 `$children` 中删掉自身
  - 删除 watcher
  - 当前的 VNode 执行销毁钩子函数等
- 执行 vm.\_\_patch\_\_(vm.\_vnode, null) 触发它子组件的销毁钩子函数，这样一层层的递归调用
- 执行完毕后再调用 destroy 钩子函数。

总结一下：

beforeDestroy 先父后子
destroyed 先子后父

# activated & deactivated

activated 和 deactivated 钩子函数是专门为 keep-alive 组件定制的钩子，在介绍 `keep-alive` 组件的时候详细介绍

# 总结

这一节主要介绍了 Vue 生命周期中各个钩子函数的执行时机以及顺序，通过分析，我们知道了如

在 created 钩子函数中可以访问到数据
在 mounted 钩子函数中可以访问到 DOM
在 destroy 钩子函数中可以做一些定时器销毁工作
