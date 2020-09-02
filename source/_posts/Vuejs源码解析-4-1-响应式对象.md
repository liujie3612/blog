---
title: Vuejs源码解析 4-1-响应式对象
date: 2020-08-29 11:27:32
tags:
- vue
- 源码解析
- 源码
- 响应式原理
---

# initState

在 Vue 的初始化阶段，`_init` 方法执行的时候，会执行 `initState(vm)` 方法：
```js
export function initState (vm: Component) {
  vm._watchers = []
  const opts = vm.$options
  if (opts.props) initProps(vm, opts.props)
  if (opts.methods) initMethods(vm, opts.methods)
  if (opts.data) {
    initData(vm)
  } else {
    observe(vm._data = {}, true /* asRootData */)
  }
  if (opts.computed) initComputed(vm, opts.computed)
  if (opts.watch && opts.watch !== nativeWatch) {
    initWatch(vm, opts.watch)
  }
}
```
`initState` 方法主要是对 `props`、`methods`、`data`、`computed`和 `wathcer` 等属性做了初始化操作。这里我们重点分析 **props 和 data**，对于其它属性的初始化我们之后再详细分析。

<!--more-->

## initProps

```js
function initProps (vm: Component, propsOptions: Object) {
  const propsData = vm.$options.propsData || {}
  const props = vm._props = {}
  const keys = vm.$options._propKeys = []
  const isRoot = !vm.$parent

  if (!isRoot) {
    // 关闭观测的开关，observe将是无效调用
    toggleObserving(false)
  }

  for (const key in propsOptions) {
    keys.push(key)

    const value = validateProp(key, propsOptions, propsData, vm)

    defineReactive(props, key, value)

    // 数据代理，对于非根实例的子组件而言，代理发生在 Vue.extend 阶段
    // 这是一种优化手段，不用为每个组件实例都调用 Object.defineProperty 来实现代理
    if (!(key in vm)) {
      proxy(vm, `_props`, key)
    }
  }

  toggleObserving(true)
}
```
`initProps` 的初始化主要过程：
1. 关闭观测的开关，具体的之后章节还会介绍，这里先简单了解：
   - 将 `src/core/observer/index.js` 文件中的 `shouldObserve` 全局变量置为 `false`。
   - 这使得  `defineReactive` 中调用 `observe` 是一个无效调用。
   - 因为对于对象的 prop 值，`子组件的prop值` 始终指向`父组件的prop值`，只要`父组件的prop值`变化，就会触发子组件的重新渲染，所以这个 `observe 过程`是可以省略的。
2. 遍历定义的 props 配置。遍历的过程主要做两件事情：
   - 一个是调用 `defineReactive` 方法把每个 `prop` 对应的值变成响应式，可以通过 `vm._props.xxx` 访问到定义 `props` 中**对应的属性**。
   - 另一个是通过 `proxy` 把对 `vm.xxx` 的访问代理到 `vm._props.xxx` 上。这里的一个细节是对于非根实例的子组件而言，代理发生在 `Vue.extend阶段`，在之后章节还会介绍。

## initData
```js
function initData (vm: Component) {
  let data = vm.$options.data
  data = vm._data = typeof data === 'function'
    ? getData(data, vm)
    : data || {}
  // ...
  // proxy data on instance
  const keys = Object.keys(data)

  // ...

  let i = keys.length
  while (i--) {    
    const key = keys[i]        
    // 简化后的...    
    proxy(vm, `_data`, key)  
  }

  // observe data  
  observe(data, true /* asRootData */)
}
```

`initData` 的初始化主要做两件事：

- 遍历data对象，通过 `proxy` 把 `vm.xxx` 代理到 `vm._data.xxx` 上
- 调用 `observe` 方法观测整个 data 的变化，把 data 也变成响应式，可以通过 `vm._data.xxx` 访问到定义 data 中对应的属性。

## 总结

可以看到，无论是 `props` 或是 `data` 的初始化都是把它们变成响应式对象，这个过程我们接触到几个函数，接下来我们来详细分析它们。

## proxy

首先介绍一下代理，代理的作用是把 `props` 和 `data` 上的属性代理到 `vm实例`上，这也就是为什么比如我们定义了如下 props，却可以通过 vm 实例访问到它。

```js
let comP = {
  props: {
    msg: 'hello'
  },
  methods: {
    say() {
      console.log(this.msg)
    }
  }
}
```

我们可以在 `say函数`中通过 `this.msg` 访问到我们定义在 props 中的 msg，这个过程发生在 proxy 阶段：

```js
const sharedPropertyDefinition = {
  enumerable: true,
  configurable: true,
  get: noop,
  set: noop
}

export function proxy (target: Object, sourceKey: string, key: string) {
  sharedPropertyDefinition.get = function proxyGetter () {
    return this[sourceKey][key]
  }
  sharedPropertyDefinition.set = function proxySetter (val) {
    this[sourceKey][key] = val
  }
  Object.defineProperty(target, key, sharedPropertyDefinition)
}
```
proxy 方法的实现很简单，通过 `Object.defineProperty` 把 `target[sourceKey][key]` 的读写变成了对 `target[key]` 的读写。

所以对于 `props` 而言，对 `vm._props.xxx` 的读写变成了 `vm.xxx` 的读写，而对于 `vm._props.xxx` 我们可以访问到定义在 props 中的属性，所以我们就可以通过 `vm.xxx` 访问到定义在 `props` 中的 xxx 属性了。同理，对于 data 而言，对 `vm._data.xxxx` 的读写变成了对 `vm.xxxx` 的读写，而对于 `vm._data.xxxx` 我们可以访问到定义在 data 函数返回对象中的属性，所以我们就可以通过 `vm.xxxx` 访问到定义在 data 函数返回对象中的 xxxx 属性了。

## observe

`observe` 的功能就是用来监测数据的变化，它的定义在 `src/core/observer/index.js` 中：
```js
export function observe (value: any, asRootData: ?boolean): Observer | void {
  if (!isObject(value) || value instanceof VNode) {
    return
  }
  let ob: Observer | void
  if (hasOwn(value, '__ob__') && value.__ob__ instanceof Observer) {
    ob = value.__ob__
  } else if (
    shouldObserve && // 观测开关打开
    !isServerRendering() && // 非SSR
    (Array.isArray(value) || isPlainObject(value)) && // value是数组或普通对象
    Object.isExtensible(value) && // value可扩展
    !value._isVue // value是非vue对象
  ) {
    ob = new Observer(value)
  }
  if (asRootData && ob) {
    ob.vmCount++
  }
  return ob
}
```

`observe` 方法的作用就是给`非VNode` 的对象类型数据添加一个 `Observer`，如果已经添加过则直接返回，否则在满足一定条件下（见注释）去实例化一个 Observer 对象实例。
接下来我们来看一下 Observer 的作用。

## Observer

Observer 是一个类，它的作用是给对象的属性添加 `getter` 和 `setter`，用于**依赖收集**和**派发更新**：
```js
export class Observer {
  value: any;
  dep: Dep;
  vmCount: number; // 将当前对象作为根$data的vm实例的数量

  constructor (value: any) {
    this.value = value
    this.dep = new Dep()
    this.vmCount = 0
    def(value, '__ob__', this)
    if (Array.isArray(value)) {
      const augment = hasProto
        ? protoAugment
        : copyAugment
      augment(value, arrayMethods, arrayKeys)
      this.observeArray(value)
    } else {
      this.walk(value)
    }
  }

  walk (obj: Object) {
    const keys = Object.keys(obj)
    for (let i = 0; i < keys.length; i++) {
      defineReactive(obj, keys[i])
    }
  }

  /**
   * Observe a list of Array items.
   */
  observeArray (items: Array<any>) {
    for (let i = 0, l = items.length; i < l; i++) {
      observe(items[i])
    }
  }
}
```
1. 首先实例化 `Dep对象`，这是给 `Vue.set` 用的，在之后的章节会介绍。
2. 接着通过执行 def 函数把**自身实例**添加到数据对象value的 __ob__ 属性上
   
```js
// def 的定义在 src/core/util/lang.js 中：

export function def (obj: Object, key: string, val: any, enumerable?: boolean) {  
  Object.defineProperty(obj, key, {    
    value: val,    
    enumerable: !!enumerable,    
    writable: true,    
    configurable: true  
  }
  )
}
```
def 函数是一个非常简单的`Object.defineProperty` 的封装，这就是为什么在开发中输出 data 上对象类型的数据，会发现该对象多了一个 __ob__ 的属性。

  - value 对象上多了一个 __ob__ 的属性，指向 Observer 实例。
  - 同时 `enumerable` 默认置为 false，这样当 for 循环时不会遍历到这个属性。
3. 对 value 做判断，对于数组会调用 `observeArray` 方法，否则对纯对象调用 `walk` 方法。可以看到 `observeArray` 是遍历数组**再次调用** `observe` 方法
4. 而 walk 方法是遍历对象的 key 调用 `defineReactive` 方法


## defineReactive

`defineReactive` 的功能就是定义一个响应式对象，给对象动态添加 getter 和 setter，它的定义在 `src/core/observer/index.js` 中：
```js
export function defineReactive (
  obj: Object,
  key: string,
  val: any,
  customSetter?: ?Function,
  shallow?: boolean
) {
  const dep = new Dep()

  const property = Object.getOwnPropertyDescriptor(obj, key)
  if (property && property.configurable === false) {
    return
  }

  // cater for pre-defined getter/setters
  const getter = property && property.get
  const setter = property && property.set
  if ((!getter || setter) && arguments.length === 2) {
    val = obj[key]
  }

  let childOb = !shallow && observe(val)

  Object.defineProperty(obj, key, {
    enumerable: true,
    configurable: true,
    get: function reactiveGetter () {
      const value = getter ? getter.call(obj) : val
      if (Dep.target) {
        dep.depend()
        if (childOb) {
          childOb.dep.depend()
          if (Array.isArray(value)) {
            dependArray(value)
          }
        }
      }
      return value
    },
    set: function reactiveSetter (newVal) {
      const value = getter ? getter.call(obj) : val
      /* eslint-disable no-self-compare */
      if (newVal === value || (newVal !== newVal && value !== value)) {
        return
      }
      /* eslint-enable no-self-compare */
      if (process.env.NODE_ENV !== 'production' && customSetter) {
        customSetter()
      }
      if (setter) {
        setter.call(obj, newVal)
      } else {
        val = newVal
      }
      childOb = !shallow && observe(newVal)
      dep.notify()
    }
  })
}
```
`defineReactive` 函数最开始`初始化Dep对象`的实例，接着拿到 obj 的属性描述符，然后对子对象**递归**调用 `observe` 方法，这样就保证了无论 obj 的结构多复杂，它的所有子属性也能变成响应式的对象，这样我们访问或修改 obj 中一个嵌套较深的属性，也能触发 getter 和 setter。最后利用 `Object.defineProperty` 去给 obj 的`属性key` 添加 getter 和 setter。而关于 getter 和 setter 的具体实现，我们会在之后介绍。

# 总结：

这一节我们介绍了响应式对象，核心就是利用 `Object.defineProperty` 给数据添加了 getter 和 setter，目的就是为了在我们访问数据以及写数据的时候能自动执行一些逻辑：`getter 做的事情是依赖收集`，`setter 做的事情是派发更新`，那么在接下来的章节我们会重点对这两个过程分析。

如果我们有如下的对象:
```js
{
    a: 1,
    b: [2, 3, 4],
    c: {
        d: 5
    }
}
```

经过观测之后：
```js
{
    __ob__,          // Observer类的实例，里面保存着Dep实例 __ob__.dep => dep(uid:0)
    a: 1,            // 在defineReactive闭包里存在dep(uid:1)
    b: [2, 3, 4],    // 在defineReactive闭包里存在着dep(uid:2)，还有b.__ob__.dep => dep(uid:3)
    c: {             // 在defineReactive闭包里存在着dep(uid:4)
        __ob__,      // Observer类的实例，里面保存着Dep实例__ob__.dep => dep(uid:5)
        d: 5         // 在闭包里存在着dep(uid:6)
    }
}
```

流程图：
![](https://cdn.liujiefront.com/images/algorithm/xhh7t.png)
