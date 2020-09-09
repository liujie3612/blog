---
title: Vue.js源码解析 3-6-异步组件
date: 2020-08-22 15:23:17
tags:
  - vue
  - 源码解析
  - 源码
  - 组件化
  - 异步组件
categories: Vue源码解析
---

在我们平时的开发工作中，为了减少首屏代码体积，往往会把一些非首屏的组件设计成异步组件，**按需加载**。Vue 也原生支持了异步组件的能力。

<!--more-->

# Vue 支持三种异步组件方式：

1. 工厂函数中使用 `resolve`：
```js
Vue.component('async-example', function (resolve, reject) {
   // 这个特殊的 require 语法告诉 webpack
   // 自动将编译后的代码分割成不同的块，
   // 这些块将通过 Ajax 请求自动下载。
   require(['./my-async-component'], resolve)
})
```
2. 工厂函数中使用 `Promise`：
```js
Vue.component(
  'async-webpack-example',
  // 这个 `import` 函数会返回一个 `Promise` 对象。
  () => import('./my-async-component')
)
```
3. 工厂函数使用`高级组件对象`:
```js
const AsyncComponent = () => ({
  // 需要加载的组件 (应该是一个 `Promise` 对象)
  component: import('./MyComponent.vue'),
  // 异步组件加载时使用的组件
  loading: LoadingComponent,
  // 加载失败时使用的组件
  error: ErrorComponent,
  // 展示加载时组件的延时时间。默认值是 200 (毫秒)
  delay: 200,
  // 如果提供了超时时间且组件加载也超时了，
  // 则使用加载失败时使用的组件。默认值是：`Infinity`
  timeout: 3000
})

Vue.component('async-webpack-example', AsyncComponent)
```
示例中可以看到，Vue 注册的组件不再是一个对象，而是一个**工厂函数**，函数有两个参数 `resolve` 和 `reject`，函数内部用 `setTimout` 模拟了异步，实际使用可能是通过动态请求异步组件的 JS 地址，最终通过执行 `resolve` 方法，它的`参数`就是我们的`异步组件对象`。

在了解了异步组件如何注册后，我们从源码的角度来分析一下它的实现。


# 异步组件分析

上一节我们分析了组件的注册逻辑

```js
Vue.component("my-component", {
  // 选项
});
```
由于组件的定义并不是一个普通对象, 所以**不会**执行 `Vue.extend` 的逻辑把它变成一个组件的构造函数，但是它仍然可以执行到 `createComponent` 函数，我们再来对这个函数做回顾，它的定义在 `src/core/vdom/create-component/js` 中：

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

  const baseCtor = context.$options._base

  // plain options object: turn it into a constructor
  if (isObject(Ctor)) {
    Ctor = baseCtor.extend(Ctor)
  }
  
  // ...

  // async component
  let asyncFactory
  if (isUndef(Ctor.cid)) {
    asyncFactory = Ctor
    Ctor = resolveAsyncComponent(asyncFactory, baseCtor, context)
    if (Ctor === undefined) {
      // 返回一个空的vnode，会被渲染成一个注释节点
      return createAsyncPlaceholder(
        asyncFactory,
        data,
        context,
        children,
        tag
      )
    }
  }
}
```

由于我们这个时候传入的 `Ctor` 是一个函数，那么它也并不会执行 `Vue.extend` 逻辑，因此它的 `cid` 是 `undefiend`，进入了**异步组件创建**的逻辑。这里首先执行了 `Ctor = resolveAsyncComponent(asyncFactory, baseCtor, context)` 方法，它的定义在 `src/core/vdom/helpers/resolve-async-component.js` 中：

```js
function resolveAsyncComponent(
  factory,
  baseCtor
) {
  // 返回异常组件
  if (isTrue(factory.error) && isDef(factory.errorComp)) {
    return factory.errorComp
  }

  // 返回组件的构造函数
  if (isDef(factory.resolved)) {
    return factory.resolved
  }

  // 表示当前正在渲染的实例，在 _render 中赋值
  var owner = currentRenderingInstance;
  // 当前异步组件已经初始化
  if (owner && isDef(factory.owners) && factory.owners.indexOf(owner) === -1) {
    // already pending
    factory.owners.push(owner);
  }
  // 返回loading组件
  if (isTrue(factory.loading) && isDef(factory.loadingComp)) {
    return factory.loadingComp
  }
  // 异步组件初始化
  if (owner && !isDef(factory.owners)) {
    var owners = factory.owners = [owner];
    var sync = true;
    var timerLoading = null;
    var timerTimeout = null

    ;
    (owner).$on('hook:destroyed', function () { return remove(owners, owner); });
    // 强制渲染
    var forceRender = function (renderCompleted) {
      for (var i = 0, l = owners.length; i < l; i++) {
        (owners[i]).$forceUpdate();
      }

      if (renderCompleted) {
        owners.length = 0;
        if (timerLoading !== null) {
          clearTimeout(timerLoading);
          timerLoading = null;
        }
        if (timerTimeout !== null) {
          clearTimeout(timerTimeout);
          timerTimeout = null;
        }
      }
    };

    var resolve = once(function (res) {
      // cache resolved
      factory.resolved = ensureCtor(res, baseCtor);
      // invoke callbacks only if this is not a synchronous resolve
      // (async resolves are shimmed as synchronous during SSR)
      if (!sync) {
        // 当非同步时，调用forceRender
        forceRender(true);
      } else {
        // 在SSR期间异步解析被同步填充
        owners.length = 0;
      }
    });

    var reject = once(function (reason) {
      // ...
      // 显示异常组件
      if (isDef(factory.errorComp)) {
        factory.error = true;
        forceRender(true);
      }
    });

    // 调用工厂函数
    var res = factory(resolve, reject);

    if (isObject(res)) {
      if (isPromise(res)) { // 工厂函数返回 Promise
        // () => Promise
        if (isUndef(factory.resolved)) {
          res.then(resolve, reject);
        }
      } else if (isPromise(res.component)) { // 工厂函数返回高级组件对象
        res.component.then(resolve, reject);

        if (isDef(res.error)) {
          factory.errorComp = ensureCtor(res.error, baseCtor);
        }

        if (isDef(res.loading)) {
          factory.loadingComp = ensureCtor(res.loading, baseCtor);
          if (res.delay === 0) {
            factory.loading = true;
          } else {
            timerLoading = setTimeout(function () {
              timerLoading = null;
              if (isUndef(factory.resolved) && isUndef(factory.error)) {
                 // 渲染loading组件
                factory.loading = true;
                forceRender(false);
              }
            }, res.delay || 200);
          }
        }
        // 超时处理
        if (isDef(res.timeout)) {
          timerTimeout = setTimeout(function () {
            timerTimeout = null;
            if (isUndef(factory.resolved)) {
              reject(
                process.env.NODE_ENV !== 'production' ?
                ("timeout (" + (res.timeout) + "ms)") :
                null
              );
            }
          }, res.timeout);
        }
      }
    }

    sync = false;
    // return in case resolved synchronously
    return factory.loading ?
      factory.loadingComp :
      factory.resolved
  }
}
```

`resolveAsyncComponent` 函数的逻辑略复杂，因为它实际上处理了 3 种异步组件的创建方式，下面我们分别来看看这三种方式的源码流程

## 1. 工厂函数使用 resolve(普通函数异步组件)

还是这个例子：

```js
Vue.component('async-example', function (resolve, reject) {
   // 这个特殊的 require 语法告诉 webpack
   // 自动将编译后的代码分割成不同的块，
   // 这些块将通过 Ajax 请求自动下载。
   require(['./my-async-component'], resolve)
})
```
### 异步组件加载前:
```js
export function resolveAsyncComponent (  
  factory: Function,  
  baseCtor: Class<Component>
): Class<Component> | void {  
  // ... 
   
  // 如果 factory.resolved 已定义则直接返回  
  if (isDef(factory.resolved)) {    
    return factory.resolved  
  }
      
  // 表示当前正在渲染的实例，在 _render 中赋值  
  const owner = currentRenderingInstance  
  // 当前异步组件已经初始化  
  if (owner && isDef(factory.owners) && factory.owners.indexOf(owner) === -1) {    
    // already pending    
    factory.owners.push(owner)  
  }  
  
  // ...  
  
  // 第一次初始化异步组件时
  if (owner && !isDef(factory.owners)) {    
    const owners = factory.owners = [owner]    
    let sync = true    
    let timerLoading = null    
    let timerTimeout = null    
    
    // ...    
    
    const forceRender = (renderCompleted: boolean) => {...}   
     
    const resolve = once((res: Object | Class<Component>) => {...})  
      
    const reject = once(reason => {...})   
    
    // 执行工厂函数    
    
    const res = factory(resolve, reject)   

    if (isObject(res)) {      
      // ...    
    }    
    
    sync = false    

    return factory.loading
    ? factory.loadingComp      
    : factory.resolved  
  }
}
```
这里有个函数叫`once`,对`resolve` 和 `reject` 函数做了一层包装：
```js
export function once (fn: Function): Function {
  let called = false
  return function () {
    if (!called) {
      called = true
      fn.apply(this, arguments)
    }
  }
}
```
`once` 逻辑非常简单，传入一个函数，并返回一个新函数，它非常巧妙地利用`闭包`和一个`标志位`保证了它包装的函数只会执行一次，也就是确保 `resolve` 和 `reject` 函数只执行一次。

* 如果当前异步组件已经初始化完毕，那么只需要往工厂函数的 `owners` 中 `push` 当前渲染的实例
* 如果是第一次初始化异步组件时：
  - `sync` 表示当前是否同步执行
  - 定义了 `forceRender`、`resolve` 和 `reject` 函数
  - 执行工厂函数，把 `resolve` 和 `reject` 函数作为参数传入，并取得返回值 `res`
  - `isObject(res)` 返回 `false`，因为在当前例子中工厂函数并没有返回值
  - 将 `syn`c 置为 `false`
  - 返回 `factory.resolved`，但此时还是 `undefined`

再回到`createComponent`
```js
Ctor = resolveAsyncComponent(asyncFactory, baseCtor, context)
if (Ctor === undefined) {
  // 返回一个空的vnode，会被渲染成一个注释节点
  return createAsyncPlaceholder(
    asyncFactory,
    data,
    context,
    children,
    tag
  )
}
```

因为此时 `resolveAsyncComponent` 函数返回了 `undefined`，所以通过 `createAsyncPlaceholder`创建一个`注释节点`作为占位符(实际上就是就是创建了一个`占位的注释VNode`,同时把 `asyncFactory` 和 `asyncMeta` 赋值给`当前vnode`。)

![](https://cdn.liujiefront.com/images/algorithm/4ra03.png)


当执行 `forceRender` 的时候，会触发组件的重新渲染，那么会再一次执行 `resolveAsyncComponent`，这时候就会根据不同的情况，可能返回 `loading`、`error` 或成功加载的异步组件，返回值不为 undefined，因此就走正常的组件 `render`、`patch` 过程，与组件第一次渲染流程不一样，这个时候是存在`新旧vnode` 的。在组件更新patch过程中会讲到。

### 异步组件加载后:

当执行完同步逻辑后，我们再来看看异步加载后的流程：

在工厂函数中通常会先发送请求去加载我们的异步组件的 JS 文件，拿到组件定义的对象 res 后，执行 resolve(res) 逻辑。
![](https://cdn.liujiefront.com/images/algorithm/ocoej.png)

resolve 函数源码如下：
```js
const resolve = once((res: Object | Class<Component>) => {  
  factory.resolved = ensureCtor(res, baseCtor)    

  // 当非同步时，调用forceRender  
  if (!sync) {    
    forceRender(true)      
    // 在SSR期间异步解析被同步填充    
  } else {    
    owners.length = 0  
  }
})
```

```js
function ensureCtor (comp: any, base) {
  //  支持 ESModule
  if (
    comp.__esModule ||
    (hasSymbol && comp[Symbol.toStringTag] === 'Module')
  ) {
    comp = comp.default
  }
  return isObject(comp)
    ? base.extend(comp)
    : comp
}
```

这个函数目的是为了保证能找到异步组件 JS 定义的组件对象，并且如果它是一个普通对象，则调用 `Vue.extend` 把它转换成一个组件的构造函数。

回到 `resolve函数`，将返回的组件构造函数挂载到 `factory.resolved`

resolve 逻辑最后判断了 `sync`，显然我们这个场景下 `sync` 为 `false`，那么就会执行 **`forceRender`** 函数，它会遍历 `factory.contexts`，拿到每一个调用异步组件的实例 vm, 执行 `vm.$forceUpdate()` 方法，它的定义在 `src/core/instance/lifecycle.js` 中：

```js
Vue.prototype.$forceUpdate = function () {
  const vm: Component = this
  if (vm._watcher) {
    vm._watcher.update()
  }
}
```

`$forceUpdate` 的逻辑非常简单，就是调用`渲染watcher` 的 `update` 方法，让`渲染watcher` 对应的回调函数执行，也就是触发了组件的重新渲染。之所以这么做是因为 Vue 通常是数据驱动视图重新渲染，但是在整个异步组件加载过程中是**没有数据发生变化**的，所以通过执行 `$forceUpdate` 可以强制组件重新渲染一次。

##  2. 工厂函数中使用 Promise

```js
Vue.component(
  'async-webpack-example',
  // 该 `import` 函数返回一个 `Promise` 对象。
  () => import('./my-async-component')
)
```

其实这种情况和第一个例子基本上相差无几，看下 `resolveAsyncComponent` 函数：

```js
// src/core/vdom/helpers/resolve-async-component.js

export function resolveAsyncComponent (  
  factory: Function,  
  baseCtor: Class<Component>): Class<Component> | void {  
  // ...  
  if (owner && !isDef(factory.owners)) {    
    // ...    
    // 执行工厂函数    
    const res = factory(resolve, reject)    
    
    // res 是 import('./my-async-component') 的返回值    
    if (isObject(res)) {      
      if (isPromise(res)) {        
        // () => Promise       
        if (isUndef(factory.resolved)) {          
          res.then(resolve, reject)        
        }      
      } else {...}    
    }        
    
    // ...
        
    return factory.loading
    ? factory.loadingComp      
    : factory.resolved  
  }
}
```

当执行完 `res = factory(resolve, reject)`，返回的值就是 `import('./my-async-component')` 的返回值，它是一个 `Promise对象`。接着进入 if 条件：

- isObject(res) 为 true
- isPromise(res) 为 true
- isUndef(factory.resolved) 为 true

然后给 Promise 对象添加 then 方法: `res.then(resolve, reject)`

当组件异步加载成功后，执行 resolve，加载失败则执行 reject，这样就非常巧妙地实现了配合 webpack 2+ 的异步加载组件的方式（Promise）加载异步组件。

## 3. 工厂函数使用高级组件对象

```js
const AsyncComponent = () => ({
  // 需要加载的组件 (应该是一个 `Promise` 对象)
  component: import('./MyComponent.vue'),
  // 异步组件加载时使用的组件
  loading: LoadingComponent,
  // 加载失败时使用的组件
  error: ErrorComponent,
  // 展示加载时组件的延时时间。默认值是 200 (毫秒)
  delay: 200,
  // 如果提供了超时时间且组件加载也超时了，
  // 则使用加载失败时使用的组件。默认值是：`Infinity`
  timeout: 3000
})

Vue.component('async-webpack-example', AsyncComponent)
```

高级异步组件的初始化逻辑和普通异步组件一样，也是执行 `resolveAsyncComponent`，当执行完 `res = factory(resolve, reject)`，返回值就是定义的组件对象。接着进入 if 条件：

- isObject(res) 为 true
- isPromise(res) 为 false

显然满足 else 的逻辑，接着执行 `res.component.then(resolve, reject)`，当异步组件加载成功后，执行 resolve，失败执行 reject。

因为异步组件加载是一个异步过程，它接着又同步执行了如下逻辑：

```js
if (isDef(res.error)) {
  factory.errorComp = ensureCtor(res.error, baseCtor)
}

if (isDef(res.loading)) {
  factory.loadingComp = ensureCtor(res.loading, baseCtor)
  if (res.delay === 0) {
    factory.loading = true
  } else {
    setTimeout(() => {
      if (isUndef(factory.resolved) && isUndef(factory.error)) {
        // 渲染loading组件
        factory.loading = true
        forceRender()
      }
    }, res.delay || 200)
  }
}
// 超时处理
if (isDef(res.timeout)) {
  setTimeout(() => {
    if (isUndef(factory.resolved)) {
      reject(
        process.env.NODE_ENV !== 'production'
          ? `timeout (${res.timeout}ms)`
          : null
      )
    }
  }, res.timeout)
}
```

1. 先判断 `res.error` 是否定义了 `error` 组件，如果有的话则赋值给 `factory.errorComp`。 
2. 接着判断 `res.loading` 是否定义了 `loading组件`，如果有的话则赋值给 `factory.loadingComp`
3. 如果设置了 `res.delay` 且为 `0`，则设置 `factory.loading = true`，否则延时 `delay` 的时间执行：
```js
if (isUndef(factory.resolved) && isUndef(factory.error)) {
  factory.loading = true
  forceRender(false)
}
```
4. 最后判断 `res.timeout`，如果配置了该项，则在 `res.timout` 时间后，如果组件没有成功加载，执行 reject。

在 `resolveAsyncComponent` 的最后有一段逻辑：

```js
sync = false
return factory.loading
  ? factory.loadingComp
  : factory.resolved
```

如果 `delay` 配置为 0，则这次直接渲染 `loading组件`，否则则延时 delay 执行 `forceRender`，那么又会再一次执行到 `resolveAsyncComponent`。

那么这时候我们有几种情况，按逻辑的执行顺序，对不同的情况做判断。

### 当异步组件加载失败，会执行 reject 函数：

```js
const reject = once(reason => {
  process.env.NODE_ENV !== 'production' && warn(
    `Failed to resolve async component: ${String(factory)}` +
    (reason ? `\nReason: ${reason}` : '')
  )
  if (isDef(factory.errorComp)) {
    factory.error = true
    forceRender()
  }
})
```

这个时候会把 `factory.error` 设置为 true，同时执行 `forceRender()` 再次执行到 `resolveAsyncComponent`：
```js
if (isTrue(factory.error) && isDef(factory.errorComp)) {
  return factory.errorComp
}
```
那么这个时候就返回 factory.errorComp，直接渲染 error 组件。

### 异步组件加载成功

```js
const resolve = once((res: Object | Class<Component>) => {
  factory.resolved = ensureCtor(res, baseCtor)
  if (!sync) {
    forceRender()
  }
})
```

首先把加载结果缓存到 `factory.resolved` 中，这个时候因为 `sync` 已经为 `false`，则执行 `forceRender()` 再次执行到 `resolveAsyncComponent`：

```js
if (isDef(factory.resolved)) {
  return factory.resolved
}
```
那么这个时候直接返回 factory.resolved，渲染成功加载的组件。

### 异步组件加载中

如果异步组件加载中并未返回，这时候会走到这个逻辑：
```js
if (isTrue(factory.loading) && isDef(factory.loadingComp)) {
  return factory.loadingComp
}
```

那么则会返回 `factory.loadingComp`，渲染 `loading组件`。

### 异步组件加载超时

如果超时，则走到了 reject 逻辑，之后逻辑和加载失败一样，渲染 error 组件。

# 总结：
通过以上代码分析，我们对 Vue 的异步组件的实现有了深入的了解，知道了 3 种异步组件的实现方式，并且看到**高级异步组件**的实现是非常巧妙的，它实现了 `loading`、`resolve`、`reject`、`timeout` 4 种状态。异步组件实现的本质是 2 次渲染，除了 `0 delay` 的高级异步组件第一次直接渲染成 `loading组件`外，其它都是第一次渲染生成一个**注释节点**，当异步获取组件成功后，再通过 `forceRender` 强制重新渲染，这样就能正确渲染出我们异步加载的组件了。
