---
title: Vuejs源码解析 6-1 event
date: 2020-09-11 17:26:16
tags:
- vue
- 源码解析
- 源码
- 拓展
- event
categories: Vue源码解析
---
我们平时开发工作中，处理组件间的通讯，原生的交互，都离不开事件。对于一个组件元素，我们不仅仅可以绑定`原生的 DOM 事件`，还可以绑定`自定义事件`，非常灵活和方便。那么接下来我们从源码角度来看看它的实现原理。

为了更加直观，我们通过一个例子来分析它的实现：

```js
let Child = {
  template: '<button @click="clickHandler($event)">' +
  'click me' +
  '</button>',
  methods: {
    clickHandler(e) {
      console.log('Button clicked!', e)
      this.$emit('select')
    }
  }
}

let vm = new Vue({
  el: '#app',
  template: '<div>' +
  '<child @select="selectHandler" @click.native.prevent="clickHandler"></child>' +
  '</div>',
  methods: {
    clickHandler() {
      console.log('Child clicked!')
    },
    selectHandler() {
      console.log('Child select!')
    }
  },
  components: {
    Child
  }
})
```

<!--more-->

# 1.编译

先从编译阶段开始看起，在 `parse` 阶段，会执行 `processAttrs` 方法，它的定义在 `src/compiler/parser/index.js` 中：
```js
export const onRE = /^@|^v-on:/
export const dirRE = /^v-|^@|^:/
export const bindRE = /^:|^v-bind:/

function processAttrs(el) {
  var list = el.attrsList;
  var i, l, name, rawName, value, modifiers, syncGen, isDynamic;
  for (i = 0, l = list.length; i < l; i++) {
    name = rawName = list[i].name;
    value = list[i].value;
    if (dirRE.test(name)) {
      // mark element as dynamic
      el.hasBindings = true;
      // modifiers
      modifiers = parseModifiers(name.replace(dirRE, ''));
      // support .foo shorthand syntax for the .prop modifier
      if (modifiers) {
        name = name.replace(modifierRE, '');
      }
      if (bindRE.test(name)) {
      // v-bind
      // ...
      } else if (onRE.test(name)) {
        // v-on 
        name = name.replace(onRE, '');
        isDynamic = dynamicArgRE.test(name);
        if (isDynamic) {
          name = name.slice(1, -1);
        }
        addHandler(el, name, value, modifiers, false, warn$2, list[i], isDynamic);
      } else { 
        // normal directives
        // ...
      }
    } else {
      // literal attribute
      // ...
    }
  }
}
```
在对标签属性的处理过程中，判断如果是指令，首先通过 `parseModifiers` 解析出修饰符:
```js
const modifierRE = /\.[^.\]]+(?=[^\]]*$)/g

function parseModifiers(name) {
  var match = name.match(modifierRE);
  if (match) {
    var ret = {};
    match.forEach(function (m) { ret[m.slice(1)] = true; });
    return ret
  }
}
```

回到 `processAttrs` 方法，接着判断如果事件的指令，则执行 `addHandler(el, name, value, modifiers, false, warn)` 方法，它的定义在 `src/compiler/helpers.js` 中：
```js
function addHandler(
  el,
  name,
  value,
  modifiers,
  important,
  warn,
  range,
  dynamic
) {
  modifiers = modifiers || emptyObject;
  // warn prevent and passive modifier
  /* istanbul ignore if */
  if (
    process.env.NODE_ENV !== 'production' && warn &&
    modifiers.prevent && modifiers.passive
  ) {
    warn(
      'passive and prevent can\'t be used together. ' +
      'Passive handler can\'t prevent default event.',
      range
    );
  }

  // normalize click.right and click.middle since they don't actually fire
  // this is technically browser-specific, but at least for now browsers are
  // the only target envs that have right/middle clicks.
  if (modifiers.right) {
    if (dynamic) {
      name = "(" + name + ")==='click'?'contextmenu':(" + name + ")";
    } else if (name === 'click') {
      name = 'contextmenu';
      delete modifiers.right;
    }
  } else if (modifiers.middle) {
    if (dynamic) {
      name = "(" + name + ")==='click'?'mouseup':(" + name + ")";
    } else if (name === 'click') {
      name = 'mouseup';
    }
  }

  // check capture modifier
  // 根据 modifier 修饰符对事件名 name 做处理
  if (modifiers.capture) {
    delete modifiers.capture;
    name = prependModifierMarker('!', name, dynamic);
  }
  if (modifiers.once) {
    delete modifiers.once;
    name = prependModifierMarker('~', name, dynamic);
  }
  /* istanbul ignore if */
  if (modifiers.passive) {
    delete modifiers.passive;
    name = prependModifierMarker('&', name, dynamic);
  }

  var events;
  // 根据 modifier.native 判断是一个纯原生事件还是普通事件，分别对应 el.nativeEvents 和 el.events
  if (modifiers.native) {
    delete modifiers.native;
    events = el.nativeEvents || (el.nativeEvents = {});
  } else {
    events = el.events || (el.events = {});
  }

  var newHandler = rangeSetItem({ value: value.trim(), dynamic: dynamic }, range);
  if (modifiers !== emptyObject) {
    newHandler.modifiers = modifiers;
  }
  // 按照 name 对事件做归类，并把回调函数的字符串保留到对应的事件中。
  var handlers = events[name];
  /* istanbul ignore if */
  if (Array.isArray(handlers)) {
    important ? handlers.unshift(newHandler) : handlers.push(newHandler);
  } else if (handlers) {
    events[name] = important ? [newHandler, handlers] : [handlers, newHandler];
  } else {
    events[name] = newHandler;
  }

  el.plain = false;
}
```

addHandler 函数看起来长，实际上就做了 3 件事情：

1. 首先根据 `modifier` 修饰符对事件名 `name` 做处理
2. 接着根据 `modifier.native` 判断是一个`纯原生事件还是普通事件`，分别对应 `el.nativeEvents` 和 `el.events`
3. 最后按照 `name` 对事件做归类，并把回调函数的字符串保留到对应的事件中。

在我们的例子中，父组件的 · 节点生成的 `el.events` 和 `el.nativeEvents` 如下：
```js
el.events = {
  select: {
    value: 'selectHandler'
  }
}

el.nativeEvents = {
  click: {
    value: 'clickHandler',
    modifiers: {
      prevent: true
    }
  }
}
```
子组件的 `button` 节点生成的 `el.events` 如下：
```js
el.events = {
  click: {
    value: 'clickHandler($event)'
  }
}
```

![](https://cdn.liujiefront.com/images/algorithm/8jch3.png)

![](https://cdn.liujiefront.com/images/algorithm/9hydb.png)

然后在 `codegen` 的阶段，会在 `genData` 函数中根据 `AST` 元素节点上的 `events` 和 `nativeEvents` 生成 `data 数据`，它的定义在 `src/compiler/codegen/index.js` 中：

```js
export function genData (el: ASTElement, state: CodegenState): string {
  // ...  
  if (el.events) {    
    data += `${genHandlers(el.events, false, state.warn)},`  
  }  
  if (el.nativeEvents) {    
    data += `${genHandlers(el.nativeEvents, true, state.warn)},`  
  } 
  // ...  
  return data
}
```
对于这两个属性，会调用 `genHandlers` 函数，定义在 `src/compiler/codegen/events.js` 中：

```js
function genHandlers(
  events,
  isNative
) {
  var prefix = isNative ? 'nativeOn:' : 'on:';
  var staticHandlers = "";
  var dynamicHandlers = "";
  for (var name in events) {
    var handlerCode = genHandler(events[name]);
    if (events[name] && events[name].dynamic) {
      dynamicHandlers += name + "," + handlerCode + ",";
    } else {
      staticHandlers += "\"" + name + "\":" + handlerCode + ",";
    }
  }
  staticHandlers = "{" + (staticHandlers.slice(0, -1)) + "}";
  if (dynamicHandlers) {
    return prefix + "_d(" + staticHandlers + ",[" + (dynamicHandlers.slice(0, -1)) + "])"
  } else {
    return prefix + staticHandlers
  }
}
```

```js
const fnExpRE = /^\s*([\w$_]+|\([^)]*?\))\s*=>|^function\s*\(/
const simplePathRE = /^\s*[A-Za-z_$][\w$]*(?:\.[A-Za-z_$][\w$]*|\['.*?']|\[".*?"]|\[\d+]|\[[A-Za-z_$][\w$]*])*\s*$/

function genHandler(handler) {
  if (!handler) {
    return 'function(){}'
  }

  if (Array.isArray(handler)) {
    // 递归调用 genHandler 方法并拼接结果
    return ("[" + (handler.map(function (handler) { return genHandler(handler); }).join(',')) + "]")
  }

  var isMethodPath = simplePathRE.test(handler.value);
  var isFunctionExpression = fnExpRE.test(handler.value);
  var isFunctionInvocation = simplePathRE.test(handler.value.replace(fnInvokeRE, ''));

  if (!handler.modifiers) {
    if (isMethodPath || isFunctionExpression) {
      return handler.value
    }
    return ("function($event){" + (isFunctionInvocation ? ("return " + (handler.value)) : handler.value) + "}") // inline statement
  } else {
    var code = '';
    var genModifierCode = '';
    var keys = [];
    for (var key in handler.modifiers) {
      if (modifierCode[key]) {
        genModifierCode += modifierCode[key];
        // left/right
        if (keyCodes[key]) {
          keys.push(key);
        }
      } else if (key === 'exact') {
        var modifiers = (handler.modifiers);
        genModifierCode += genGuard(
          ['ctrl', 'shift', 'alt', 'meta']
          .filter(function (keyModifier) { return !modifiers[keyModifier]; })
          .map(function (keyModifier) { return ("$event." + keyModifier + "Key"); })
          .join('||')
        );
      } else {
        keys.push(key);
      }
    }
    if (keys.length) {
      code += genKeyFilter(keys);
    }
    // Make sure modifiers like prevent and stop get executed after key filtering
    if (genModifierCode) {
      code += genModifierCode;
    }
    var handlerCode = isMethodPath ?
      ("return " + (handler.value) + "($event)") :
      isFunctionExpression ?
      ("return (" + (handler.value) + ")($event)") :
      isFunctionInvocation ?
      ("return " + (handler.value)) :
      handler.value;
    return ("function($event){" + code + handlerCode + "}")
  }
}

```

`genHandlers` 方法遍历事件对象 `events`，对同一个事件名称的事件调用 `genHandler(name, events[name])` 方法，它的内容看起来多：

1. 首先先判断如果 `handler` 是一个数组，就遍历它然后递归调用 `genHandler` 方法并拼接结果
2. 然后判断 `hanlder.value` 是一个函数的`调用路径`还是一个`函数表达式`
3. 接着对 `modifiers` 做判断，对于没有 `modifiers` 的情况，就根据 `handler.value` 不同情况处理：要么直接返回，要么返回一个函数包裹的表达式
4. 对于有 `modifiers` 的情况，则对各种不同的 `modifer` 情况做不同处理，添加相应的代码串。

那么对于我们的例子而言，父组件生成的 `data` 串为：

```js
{
  on: {"select": selectHandler},
  nativeOn: {"click": function($event) {
      $event.preventDefault();
      return clickHandler($event)
    }
  }
}
```

子组件生成的 `data` 串为：
```js
{
  on: {"click": function($event) {
      clickHandler($event)
    }
  }
}
```
![](https://cdn.liujiefront.com/images/algorithm/f34mc.png)

![](https://cdn.liujiefront.com/images/algorithm/yrp97.png)

那么到这里，**编译**部分完了，接下来我们来看一下运行时部分是如何实现的。
其实 Vue 的事件有 2 种，一种是`原生 DOM 事件`，一种是`用户自定义事件`，我们分别来看。

# 2.DOM事件

还记得我们之前在 `patch` 的时候执行各种 `module` 的钩子函数吗，当时这部分是略过的，我们之前只分析了 DOM 是如何渲染的，而 DOM 元素相关的属性、样式、事件等都是通过这些 `module` 的`钩子函数`完成设置的。

所有和 web 相关的 `module` 都定义在 `src/platforms/web/runtime/modules` 目录下，我们这次只关注目录下的 `events.js` 即可。
在 `patch` 过程中的**创建阶段**和**更新阶段**都会执行 `updateDOMListeners`：
```js
function updateDOMListeners(oldVnode, vnode) {
  if (isUndef(oldVnode.data.on) && isUndef(vnode.data.on)) {
    return
  }
  var on = vnode.data.on || {};
  var oldOn = oldVnode.data.on || {};
  target$1 = vnode.elm;
  normalizeEvents(on);
  updateListeners(on, oldOn, add$1, remove$2, createOnceHandler$1, vnode.context);
  target$1 = undefined;
}
```

首先获取 `vnode.data.on`，这就是我们之前的生成的 `data` `中对应的事件对象，target` 是当前 `vnode` 对于的 `DOM 对象``，normalizeEvents` 主要是对 `v-model` 相关的处理，我们之后分析 `v-model` 的时候会介绍，接着调用 `updateListeners(on, oldOn, add, remove, vnode.context)` 方法，它的定义在 `src/core/vdom/helpers/update-listeners.js` 中：

```js
function updateListeners(
  on,
  oldOn,
  add,
  remove$$1,
  createOnceHandler,
  vm
) {
  var name, def$$1, cur, old, event;
  for (name in on) {
    def$$1 = cur = on[name];
    old = oldOn[name];
    event = normalizeEvent(name);
    if (isUndef(cur)) {
      process.env.NODE_ENV !== 'production' && warn(
        "Invalid handler for event \"" + (event.name) + "\": got " + String(cur),
        vm
      );
    } else if (isUndef(old)) {
      if (isUndef(cur.fns)) {
        // 创建一个回调函数
        cur = on[name] = createFnInvoker(cur, vm);
      }
      if (isTrue(event.once)) {
        cur = on[name] = createOnceHandler(event.name, cur, event.capture);
      }
      // 完成一次事件绑定
      add(event.name, cur, event.capture, event.passive, event.params);
    } else if (cur !== old) {
      old.fns = cur;
      on[name] = old;
    }
  }
  for (name in oldOn) {
    if (isUndef(on[name])) {
      event = normalizeEvent(name);
      remove$$1(event.name, oldOn[name], event.capture);
    }
  }
}
```
`updateListeners` 的逻辑很简单，遍历 `on` 去`添加事件监听`，遍历 `oldOn` 去`移除事件监听`，关于监听和移除事件的方法都是外部传入的，因为它既处理原生 DOM 事件的添加删除，也处理自定义事件的添加删除。

对于 on 的遍历，首先获得每一个事件名，然后做 `normalizeEvent` 的处理：

```js
var normalizeEvent = cached(function (name) {
  var passive = name.charAt(0) === '&';
  name = passive ? name.slice(1) : name;
  var once$$1 = name.charAt(0) === '~'; // Prefixed last, checked first
  name = once$$1 ? name.slice(1) : name;
  var capture = name.charAt(0) === '!';
  name = capture ? name.slice(1) : name;
  return {
    name: name,
    once: once$$1,
    capture: capture,
    passive: passive
  }
});
```

根据我们的的事件名的一些特殊标识（之前在 `addHandler` 的时候添加上的）区分出这个事件是否有 `once`、`capture`、`passive` 等修饰符。

处理完事件名后，又对事件回调函数做处理，对于第一次，满足 `isUndef(old)` 并且 `isUndef(cur.fns)`
1. 执行 `cur = on[name] = createFnInvoker(cur)` 方法去创建一个回调函数
2. 执行 `add(event.name, cur, event.once, event.capture, event.passive, event.params)` 完成一次事件绑定。

## 创建一个回调函数

我们先看一下 `createFnInvoker` 的实现：

```js
function createFnInvoker(fns, vm) {
  function invoker() {
    var arguments$1 = arguments;

    var fns = invoker.fns;
    if (Array.isArray(fns)) {
      var cloned = fns.slice();
      for (var i = 0; i < cloned.length; i++) {
        invokeWithErrorHandling(cloned[i], null, arguments$1, vm, "v-on handler");
      }
    } else {
      // return handler return value for single handlers
      return invokeWithErrorHandling(fns, null, arguments, vm, "v-on handler")
    }
  }
  invoker.fns = fns;
  return invoker
}
```

这里定义了 `invoker` 方法并返回，由于一个事件可能会对应多个回调函数，所以这里做了数组的判断，多个回调函数就`依次调用`。
注意最后的赋值逻辑， `invoker.fns = fns`，每一次执行 `invoker` 函数都是从 `invoker.fns` 里取执行的回调函数，回到 `updateListeners`，当我们第二次执行该函数的时候，判断如果 `cur !== old`，那么只需要更改 `old.fns = cur` 把之前绑定的 `involer.fns` 赋值为新的回调函数即可，并且 通过 `on[name] = old` 保留引用关系，这样就保证了事件回调只添加一次，之后仅仅去修改它的回调函数的引用。

`updateListeners` 函数的最后遍历 `oldOn` 拿到事件名称，判断如果满足 `isUndef(on[name])`，则执行 `remove(event.name, oldOn[name], event.capture)` 去移除事件回调。

## 事件绑定

了解了 `updateListeners` 的实现后，我们来看一下在原生 DOM 事件中真正`添加回调`和`移除回调函数`的实现，它们的定义都在 `src/platforms/web/runtime/modules/event.js` 中：
```js
var useMicrotaskFix = isUsingMicroTask && !(isFF && Number(isFF[1]) <= 53);

function add(
  name,
  handler,
  capture,
  passive
) {
  if (useMicrotaskFix) {
 // ...
  }
  target$1.addEventListener(
    name,
    handler,
    supportsPassive ? { capture: capture, passive: passive } :
    capture
  );
}

function remove$2(
  name,
  handler,
  capture,
  _target
) {
  (_target || target$1).removeEventListener(
    name,
    handler._wrapper || handler,
    capture
  );
}

```
`add` 和 `remove` 的逻辑很简单，就是实际上调用原生 `addEventListener` 和 `removeEventListener`，并根据参数传递一些配置。

# 3.自定义事件

除了原生 DOM 事件，Vue 还支持了自定义事件，并且自定义事件只能作用在组件上，如果在组件上使用原生事件，需要加 `.native` 修饰符，普通元素上使用 `.native` 修饰符无效，接下来我们就来分析它的实现。

在 `render` 阶段，如果是一个`组件节点`，则通过 `createComponent` 创建一个`组件vnode`，我们再来回顾这个方法，定义在 `src/core/vdom/create-component.js` 中：

```js
export function createComponent (
  Ctor: Class<Component> | Function | Object | void,
  data: ?VNodeData,
  context: Component,
  children: ?Array<VNode>,
  tag?: string
): VNode | Array<VNode> | void {
  // ...
  const listeners = data.on
  
  data.on = data.nativeOn
  
  // ...
  const name = Ctor.options.name || tag
  const vnode = new VNode(
    `vue-component-${Ctor.cid}${name ? `-${name}` : ''}`,
    data, undefined, undefined, undefined, context,
    { Ctor, propsData, listeners, tag, children },
    asyncFactory
  )

  return vnode
}
```
我们只关注事件相关的逻辑，可以看到，它把 `data.on` 赋值给了 `listeners`，把 `data.nativeOn` 赋值给了 `data.on`，这样所有的原生 DOM 事件处理跟我们刚才介绍的一样，它是在当前组件环境中处理的。而对于`自定义事件`，我们把 `listeners` 作为 `vnode` 的 `componentOptions` 传入，它是在`子组件初始化阶段`中处理的，所以它的处理环境是`子组件`。

然后在`子组件的初始化`的时候，会执行 `initInternalComponent` 方法，它的定义在 `src/core/instance/init.js` 中：
```js
export function initInternalComponent (vm: Component, options: InternalComponentOptions) {
  const opts = vm.$options = Object.create(vm.constructor.options)
  // ....
  const vnodeComponentOptions = parentVnode.componentOptions
 
  opts._parentListeners = vnodeComponentOptions.listeners
  // ...
}
```
这里拿到了父组件传入的 `listeners`，然后在执行 `initEvents` 的过程中，会处理这个 `listeners`，定义在 `src/core/instance/events.js` 中：
```js
export function initEvents (vm: Component) {
  vm._events = Object.create(null)
  vm._hasHookEvent = false
  // init parent attached events
  const listeners = vm.$options._parentListeners
  if (listeners) {
    updateComponentListeners(vm, listeners)
  }
}
```
拿到 `listeners` 后，执行 `updateComponentListeners(vm, listeners)` 方法：
```js
let target: any
export function updateComponentListeners (
  vm: Component,
  listeners: Object,
  oldListeners: ?Object
) {
  target = vm
  updateListeners(listeners, oldListeners || {}, add, remove, vm)
  target = undefined
}
```
`updateListeners` 我们之前介绍过，所以对于`自定义事件`和`原生 DOM 事件`处理的差异就在事件`添加`和`删除`的实现上，来看一下**自定义事件** `add` 和 `remove` 的实现：
```js
function add (event, fn, once) {
  if (once) {
    target.$once(event, fn)
  } else {
    target.$on(event, fn)
  }
}

function remove (event, fn) {
  target.$off(event, fn)
}
```

实际上是利用 Vue 定义的`事件中心`，简单分析一下它的实现：
```js
function initEvents(vm) {
  vm._events = Object.create(null);
  vm._hasHookEvent = false;
  // init parent attached events
  var listeners = vm.$options._parentListeners;
  if (listeners) {
    updateComponentListeners(vm, listeners);
  }
}

var target;

function add(event, fn) {
  target.$on(event, fn);
}

function remove$1(event, fn) {
  target.$off(event, fn);
}

function createOnceHandler(event, fn) {
  var _target = target;
  return function onceHandler() {
    var res = fn.apply(null, arguments);
    if (res !== null) {
      _target.$off(event, onceHandler);
    }
  }
}

function updateComponentListeners(
  vm,
  listeners,
  oldListeners
) {
  target = vm;
  updateListeners(listeners, oldListeners || {}, add, remove$1, createOnceHandler, vm);
  target = undefined;
}

function eventsMixin(Vue) {
  var hookRE = /^hook:/;
  Vue.prototype.$on = function (event, fn) {
    var vm = this;
    if (Array.isArray(event)) {
      for (var i = 0, l = event.length; i < l; i++) {
        vm.$on(event[i], fn);
      }
    } else {
      (vm._events[event] || (vm._events[event] = [])).push(fn);
      // optimize hook:event cost by using a boolean flag marked at registration
      // instead of a hash lookup
      if (hookRE.test(event)) {
        vm._hasHookEvent = true;
      }
    }
    return vm
  };

  Vue.prototype.$once = function (event, fn) {
    var vm = this;

    function on() {
      vm.$off(event, on);
      fn.apply(vm, arguments);
    }
    on.fn = fn;
    vm.$on(event, on);
    return vm
  };

  Vue.prototype.$off = function (event, fn) {
    var vm = this;
    // all
    if (!arguments.length) {
      vm._events = Object.create(null);
      return vm
    }
    // array of events
    if (Array.isArray(event)) {
      for (var i$1 = 0, l = event.length; i$1 < l; i$1++) {
        vm.$off(event[i$1], fn);
      }
      return vm
    }
    // specific event
    var cbs = vm._events[event];
    if (!cbs) {
      return vm
    }
    if (!fn) {
      vm._events[event] = null;
      return vm
    }
    // specific handler
    var cb;
    var i = cbs.length;
    while (i--) {
      cb = cbs[i];
      if (cb === fn || cb.fn === fn) {
        cbs.splice(i, 1);
        break
      }
    }
    return vm
  };

  Vue.prototype.$emit = function (event) {
    var vm = this;
    if (process.env.NODE_ENV !== 'production') {
      var lowerCaseEvent = event.toLowerCase();
      if (lowerCaseEvent !== event && vm._events[lowerCaseEvent]) {
        tip(
          "Event \"" + lowerCaseEvent + "\" is emitted in component " +
          (formatComponentName(vm)) + " but the handler is registered for \"" + event + "\". " +
          "Note that HTML attributes are case-insensitive and you cannot use " +
          "v-on to listen to camelCase events when using in-DOM templates. " +
          "You should probably use \"" + (hyphenate(event)) + "\" instead of \"" + event + "\"."
        );
      }
    }
    var cbs = vm._events[event];
    if (cbs) {
      cbs = cbs.length > 1 ? toArray(cbs) : cbs;
      var args = toArray(arguments, 1);
      var info = "event handler for \"" + event + "\"";
      for (var i = 0, l = cbs.length; i < l; i++) {
        invokeWithErrorHandling(cbs[i], vm, args, vm, info);
      }
    }
    return vm
  };
}
```

非常经典的事件中心的实现: 
1. 把所有的`事件`用 `vm._events` 存储起来
2. 当执行 `vm.$on(event,fn)` 的时候，按事件的名称 `event` 把`回调函数 fn` 存储起来(`vm._events[event].push(fn)`)
3. 当执行 `vm.$emit(event)` 的时候，根据事件名 event 找到所有的回调函数：(`let cbs = vm._events[event]`)，然后遍历执行所有的回调函数。
4. 当执行 `vm.$off(event,fn)` 的时候会`移除`指定事件名 event 和指定的 fn；
5. 当执行 `vm.$once(event,fn)` 的时候，内部就是执行 `vm.$on`，并且当回调函数执行一次后再通过 `vm.$off` 移除事件的回调，这样就确保了回调函数只执行一次。

所以对于用户自定义的事件添加和删除就是利用了这几个事件中心的 API。需要注意的事一点，`vm.$emit` 是给`当前的vm上`派发的实例，之所以我们常用它做`父子组件通讯`，是因为它的`回调函数`的定义是在`父组件中`。
对于我们这个例子而言，当子组件的 button 被点击了，它通过 `this.$emit('select')` 派发事件，那么子组件的实例就监听到了这个 select 事件，并执行它的回调函数 —— 定义在父组件中的 `selectHandler` 方法，这样就相当于完成了一次父子组件的通讯。

# 总结：

那么至此我们对 Vue 的事件实现有了进一步的了解。
Vue 支持 2 种事件类型，`原生 DOM 事件`和`自定义事件`，它们主要的区别在于`添加`和`删除事件`的方式不一样，并且自定义事件的派发是往当前实例上派发，但是可以利用在父组件环境定义回调函数来实现父子组件的通讯。

另外：
1. 组件节点： 
   1. 能添加添加自定义事件。
   2. 添加`原生 DOM 事件`需要使用 `native 修饰符`；
2. 普通元素：
   1. 只能添加原生 DOM 事件
   2. 使用 `.native` 修饰符没有作用







