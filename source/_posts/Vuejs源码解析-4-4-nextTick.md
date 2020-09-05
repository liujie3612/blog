---
title: Vuejs源码解析 4-4-nextTick
date: 2020-09-03 15:49:07
tags:
- vue
- 源码解析
- 源码
- 响应式原理
- nextTick
---

广义上将 JavaScript 所有任务可以分成两种，一种是同步任务（synchronous），另一种是异步任务（asynchronous）。
- 同步任务指的是，在主线程上排队执行的任务，只有前一个任务执行完毕，才能执行后一个任务；
- 异步任务指的是，不进入主线程、而进入"任务队列"（task queue）的任务，只有"任务队列"通知主线程，某个异步任务可以执行了，该任务才会进入主线程执行。

具体来说，异步执行的运行机制如下（同步执行也是如此，因为它可以被视为没有异步任务的异步执行）：
1. 所有同步任务都在主线程上执行，形成一个"执行栈"（execution context stack）；
2. 主线程之外，还存在一个"任务队列"（task queue）。只要异步任务有了运行结果，就在"任务队列"之中放置一个事件；
3. 一旦"执行栈"中的所有同步任务执行完毕，系统就会取出"任务队列"中事件所对应的回调函数进入"执行栈"，开始执行；
4. 主线程不断重复上面的第三步。

除了广义上的定义，我们可以将任务进行更精细的定义，分为`宏任务`与`微任务`：

<!-more-->

1. 宏任务（macro-task）： 包括整体代码`script`、`ajax`，`dom`、`MessageChannel`、`postMessage`、`setInterval`、`setImmediate`、`setTimeout`操作
2. 微任务（micro-task）： `Promise.then`,`MutationObsever`

具体来说，宏任务与微任务执行的运行机制如下：
1. 首先，将"执行栈"最开始的所有同步代码(宏任务)执行完成；
2. 检查是否有微任务，如有则执行所有的微任务；
3. 取出"任务队列"中事件所对应的回调函数(宏任务)进入"执行栈"并执行完成；
4. 再检查是否有微任务，如有则执行所有的微任务；
5. 主线程不断重复上面的（3）（4）步。

![](https://cdn.liujiefront.com/images/algorithm/7i1tp.png)

以上两种运行机制，主线程都从"任务队列"中读取事件，这个过程是循环不断的，所以整个的这种运行机制又称为 `Event Loop（事件循环）`。

# 选择异步方式

在 `@2.6` 的最新版本：`Promise` > `MutationObserver` > `setImmediate` > `setTimeout`

```js
if (typeof Promise !== 'undefined' && isNative(Promise)) {
  var p = Promise.resolve();
  timerFunc = function () {
    p.then(flushCallbacks);
    if (isIOS) { setTimeout(noop); }
  };
  isUsingMicroTask = true; // 使用微任务
} else if (!isIE && typeof MutationObserver !== 'undefined' && (
    isNative(MutationObserver) ||
    MutationObserver.toString() === '[object MutationObserverConstructor]'
  )) {

  var counter = 1;
  var observer = new MutationObserver(flushCallbacks);
  var textNode = document.createTextNode(String(counter));
  observer.observe(textNode, {
    characterData: true  // 监听文本内容的修改
  });
  timerFunc = function () {
    counter = (counter + 1) % 2;
    textNode.data = String(counter);
  };
  isUsingMicroTask = true; // 使用微任务
} else if (typeof setImmediate !== 'undefined' && isNative(setImmediate)) {
  // 宏任务
  timerFunc = function () {
    setImmediate(flushCallbacks);
  };
} else {
  // 宏任务
  timerFunc = function () {
    setTimeout(flushCallbacks, 0);
  };
}
```
总结：只用一个 `timerFunc` 变量用来保存异步的实现，优先级是 `Promise` > `MutationObserver` > `setImmediate` > `setTimeout`

# nextTick


```js
var isUsingMicroTask = false; // 是否使用微任务
var callbacks = []; // 存储nextTick cb的数组
var pending = false;

function flushCallbacks() {
  pending = false;
  var copies = callbacks.slice(0);
  callbacks.length = 0;
  for (var i = 0; i < copies.length; i++) {
    copies[i]();
  }
}

let timerFunc
// ...实现优先级：Promise > MutationObserver > setImmediate > setTimeout

export function nextTick(cb?: Function, ctx?: Object) {
  var _resolve;

  // 将传入的函数包装一层，绑定作用域，并try-catch捕获错误
  callbacks.push(function () {
    if (cb) {
      try {
        cb.call(ctx);
      } catch (e) {
        handleError(e, ctx, 'nextTick');
      }
    } else if (_resolve) {
      _resolve(ctx);
    }
  });

  // pending 是一个开关，每次执行 flushCallbacks 后，会将 pending 重置为 fasle
  if (!pending) {
    pending = true;
    timerFunc();
  }

  // 这里返回一个 Promise, 所以我们可以这样调用，$this.nextTick().then(xxx)
  // callbacks.push里如果没传入函数，且浏览器原生支持 Promise 的情况下，让 Promise resolve;
  if (!cb && typeof Promise !== 'undefined') {
    return new Promise(function (resolve) {
      _resolve = resolve;
    })
  }
}
```

把传入的回调函数 cb 压入 `callbacks数组`，最后一次性地执行 `timerFunc`，而它们都会在下一个 tick 执行 `flushCallbacks`，`flushCallbacks` 的逻辑非常简单，**对 callbacks 遍历，然后执行相应的回调函数**。

这里使用 `callbacks` 而不是直接在 `nextTick` 中执行回调函数的原因是：保证在`同一个tick` 内`多次执行 nextTick`时，不会开启多个异步任务，而把这些异步任务都压成一个同步任务，在下一个 tick 执行完毕。

# 总结：
通过这一节对 nextTick 的分析，并结合上一节的 setter 分析，我们了解到数据的变化到 DOM 的重新渲染是一个异步过程，发生在下一个 tick。这就是我们平时在开发的过程中，比如从服务端接口去获取数据的时候，数据做了修改，如果我们的某些方法去依赖了数据修改后的 DOM 变化，我们就必须在 nextTick 后执行。比如下面的伪代码：

```js
getData(res).then(()=>{
  this.xxx = res.data
  this.$nextTick(() => {
    // 这里我们可以获取变化后的 DOM
  })
})
```
Vue.js 提供了 2 种调用 nextTick 的方式，
1. 一种是`全局API`: Vue.nextTick
2. 一种是实例上的方法 `vm.$nextTick`
无论我们使用哪一种，最后都是调用 next-tick.js 中实现的 `nextTick` 方法。

参考:[全方位理解JavaScript的Event Loop](https://juejin.im/post/6844903692898942990#heading-4)