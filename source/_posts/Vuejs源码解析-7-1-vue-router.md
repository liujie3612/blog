---
title: Vuejs源码解析 7-1 vue-router
date: 2020-09-29 19:01:02
tags:
- vue
- 源码解析
- 源码
- vue-router
- 介绍
categories: Vue源码解析
---

路由的概念相信大部分同学并不陌生，它的作用就是根据不同的路径映射到不同的视图。我们在用 Vue 开发过实际项目的时候都会用到 Vue-Router 这个官方插件来帮我们解决路由的问题。Vue-Router 的能力十分强大，它支持 `hash`、`history`、`abstract` 3 种路由方式，提供了 <router-link> 和 <router-view> 2 种组件，还提供了简单的路由配置和一系列好用的 API。

大部分同学已经掌握了路由的基本使用，但使用的过程中也难免会遇到一些坑，那么这一章我们就来深挖 `Vue-Router` 的实现细节，一旦我们掌握了它的实现原理，那么就能在开发中对路由的使用更加游刃有余。

同样我们也会通过一些具体的示例来配合讲解，先来看一个最基本使用例子：

<!--more-->

```js
<div id="app">
  <h1>Hello App!</h1>
  <p>
    <!-- 使用 router-link 组件来导航. -->
    <!-- 通过传入 `to` 属性指定链接. -->
    <!-- <router-link> 默认会被渲染成一个 `<a>` 标签 -->
    <router-link to="/foo">Go to Foo</router-link>
    <router-link to="/bar">Go to Bar</router-link>
  </p>
  <!-- 路由出口 -->
  <!-- 路由匹配到的组件将渲染在这里 -->
  <router-view></router-view>
</div>
```

```js
import Vue from 'vue'
import VueRouter from 'vue-router'
import App from './App'

Vue.use(VueRouter)

// 1. 定义（路由）组件。
// 可以从其他文件 import 进来
const Foo = { template: '<div>foo</div>' }
const Bar = { template: '<div>bar</div>' }

// 2. 定义路由
// 每个路由应该映射一个组件。 其中"component" 可以是
// 通过 Vue.extend() 创建的组件构造器，
// 或者，只是一个组件配置对象。
// 我们晚点再讨论嵌套路由。
const routes = [
  { path: '/foo', component: Foo },
  { path: '/bar', component: Bar }
]

// 3. 创建 router 实例，然后传 `routes` 配置
// 你还可以传别的配置参数, 不过先这么简单着吧。
const router = new VueRouter({
  routes // （缩写）相当于 routes: routes
})

// 4. 创建和挂载根实例。
// 记得要通过 router 配置参数注入路由，
// 从而让整个应用都有路由功能
const app = new Vue({
  el: '#app',
  render(h) {
    return h(App)
  },
  router
})
```

这是一个非常简单的例子，接下来我们先从 `Vue.use(VueRouter)` 说起。

# 路由注册

Vue 从它的设计上就是一个渐进式 JavaScript 框架，它本身的核心是解决视图渲染的问题，其它的能力就通过插件的方式来解决。Vue-Router 就是官方维护的路由插件，在介绍它的注册实现之前，我们先来分析一下 Vue 通用的插件注册原理。

## Vue.use

Vue 提供了 `Vue.use` 的全局 API 来注册这些插件，所以我们先来分析一下它的实现原理，定义在 `vue/src/core/global-api/use.js` 中：
```js
export function initUse (Vue: GlobalAPI) {
  Vue.use = function (plugin: Function | Object) {
    const installedPlugins = (this._installedPlugins || (this._installedPlugins = []))
    // 自动阻止多次注册相同插件，即使多次调用也只会注册一次该插件。
    if (installedPlugins.indexOf(plugin) > -1) {
      return this
    }

    const args = toArray(arguments, 1)
    args.unshift(this)
    if (typeof plugin.install === 'function') {
      plugin.install.apply(plugin, args)
    } else if (typeof plugin === 'function') {
      plugin.apply(null, args)
    }
    installedPlugins.push(plugin)
    return this
  }
}
```

`Vue.use` 接受一个 `plugin` 参数，并且维护了一个 `_installedPlugins 数组`，它存储所有注册过的 `plugin`；
接着又会判断 `plugin` 有没有定义 `install` 方法，如果有的话则调用该方法，并且该方法执行的第一个参数是 `Vue`；
最后把 `plugin` 存储到 `installedPlugins` 中。

可以看到 Vue 提供的插件注册机制很简单，每个插件都需要实现一个静态的 `install` 方法，当我们执行 `Vue.use` 注册插件的时候，就会执行这个 `install` 方法。
并且在这个 `install` 方法的第一个参数我们可以拿到 `Vue 对象`，这样的好处就是作为插件的编写方不需要再额外去 `import Vue` 了

## 路由安装

`Vue-Router` 的入口文件是 `src/index.js`，其中定义了 `VueRouter` 类，也实现了 `install` 的静态方法：`VueRouter.install = install`，它的定义在 `src/install.js` 中。

```js
export let _Vue
export function install (Vue) {
  if (install.installed && _Vue === Vue) return
  install.installed = true

  _Vue = Vue

  const isDef = v => v !== undefined

  const registerInstance = (vm, callVal) => {
    let i = vm.$options._parentVnode
    if (isDef(i) && isDef(i = i.data) && isDef(i = i.registerRouteInstance)) {
      i(vm, callVal)
    }
  }

  Vue.mixin({
    beforeCreate () {
      if (isDef(this.$options.router)) {
        this._routerRoot = this
        this._router = this.$options.router
        this._router.init(this)
        Vue.util.defineReactive(this, '_route', this._router.history.current)
      } else {
        this._routerRoot = (this.$parent && this.$parent._routerRoot) || this
      }
      registerInstance(this, this)
    },
    destroyed () {
      registerInstance(this)
    }
  })

  Object.defineProperty(Vue.prototype, '$router', {
    get () { return this._routerRoot._router }
  })

  Object.defineProperty(Vue.prototype, '$route', {
    get () { return this._routerRoot._route }
  })

  Vue.component('RouterView', View)
  Vue.component('RouterLink', Link)

  const strats = Vue.config.optionMergeStrategies
  strats.beforeRouteEnter = strats.beforeRouteLeave = strats.beforeRouteUpdate = strats.created
}
```

当用户执行 `Vue.use(VueRouter)` 的时候，实际上就是在执行 `install 函数`。
为了确保 `install` 逻辑只执行一次，用了 `install.installed` 变量做已安装的标志位。另外用一个全局的 `_Vue` 来接收参数 `Vue`，因为作为 `Vue` 的插件对 Vue 对象是有依赖的，但又不能去单独去 `import Vue`，因为那样会增加包体积，所以就通过这种方式拿到 Vue 对象。

`Vue-Router` 安装**最重要**的一步就是利用 `Vue.mixin` 去把 `beforeCreate` 和 `destroyed` 钩子函数注入到每一个组件中。`Vue.mixin` 的定义，在 `vue/src/core/global-api/mixin.js` 中：

```js
export function initMixin (Vue: GlobalAPI) {
  Vue.mixin = function (mixin: Object) {
    this.options = mergeOptions(this.options, mixin)
    return this
  }
}
```

它的实现实际上非常简单，就是把要混入的对象通过 `mergeOptions` 合并到 Vue 的 options 中，由于每个组件的构造函数都会在 `extend` 阶段`合并Vue.options` 到自身的 `options` 中，所以也就相当于`每个组件`都定义了 `mixin` 定义的选项。

回到 `Vue-Router` 的 `install` 方法，先看混入的 `beforeCreate` 钩子函数，对于根 Vue 实例而言，执行该钩子函数时定义了 `this._routerRoot` 表示它自身；
`this._router` 表示 `VueRouter` 的实例 router，它是在 new Vue 的时候传入的；
另外执行了 `this._router.init()` 方法初始化 router，这个逻辑之后介绍
然后用 `defineReactive` 方法把 `this._route` 变成响应式对象，这个作用我们之后会介绍。
而对于子组件而言，由于组件是树状结构，在遍历组件树的过程中，它们在执行该钩子函数的时候 `this._routerRoot` 始终指向的离它最近的传入了 router 对象作为配置而实例化的父实例。

对于 `beforeCreate` 和 `destroyed` 钩子函数，它们都会执行 `registerInstance` 方法，这个方法的作用我们也是之后会介绍。

接着给 Vue 原型上定义了 `$router` 和 `$route` 2 个属性的 get 方法，这就是为什么我们可以在组件实例上可以访问 `this.$router` 以及 `this.$route`，它们的作用之后介绍。

接着又通过 `Vue.component` 方法定义了全局的 `<router-link>` 和 `<router-view>` 2 个组件，这也是为什么我们在写模板的时候可以使用这两个标签，它们的作用也是之后介绍。

最后定义了路由中的钩子函数的合并策略，和普通的钩子函数一样。

**总结**：那么到此为止，我们分析了 `Vue-Router` 的安装过程，Vue 编写插件的时候通常要提供静态的 `install` 方法，我们通过 `Vue.use(plugin)` 时候，就是在执行 `install` 方法。`Vue-Router` 的 `install` 方法会给每一个组件注入 `beforeCreate` 和 `destoryed` 钩子函数，在 `beforeCreate` 做一些私有属性定义和路由初始化工作，下一节我们就来分析一下 `VueRouter` 对象的实现和它的初始化工作。

# VueRouter 对象

`VueRouter `的实现是一个类，我们先对它做一个简单地分析，它的定义在 `src/index.js` 中：

```js
export default class VueRouter {
  static install: () => void;
  static version: string;

  app: any;
  apps: Array<any>;
  ready: boolean;
  readyCbs: Array<Function>;
  options: RouterOptions;
  mode: string;
  history: HashHistory | HTML5History | AbstractHistory;
  matcher: Matcher;
  fallback: boolean;
  beforeHooks: Array<?NavigationGuard>;
  resolveHooks: Array<?NavigationGuard>;
  afterHooks: Array<?AfterNavigationHook>;

  constructor (options: RouterOptions = {}) {
    this.app = null
    this.apps = []
    this.options = options
    this.beforeHooks = []
    this.resolveHooks = []
    this.afterHooks = []
    this.matcher = createMatcher(options.routes || [], this)

    let mode = options.mode || 'hash'
    this.fallback = mode === 'history' && !supportsPushState && options.fallback !== false
    if (this.fallback) {
      mode = 'hash'
    }
    if (!inBrowser) {
      mode = 'abstract'
    }
    this.mode = mode

    switch (mode) {
      case 'history':
        this.history = new HTML5History(this, options.base)
        break
      case 'hash':
        this.history = new HashHistory(this, options.base, this.fallback)
        break
      case 'abstract':
        this.history = new AbstractHistory(this, options.base)
        break
      default:
        if (process.env.NODE_ENV !== 'production') {
          assert(false, `invalid mode: ${mode}`)
        }
    }
  }

  match (
    raw: RawLocation,
    current?: Route,
    redirectedFrom?: Location
  ): Route {
    return this.matcher.match(raw, current, redirectedFrom)
  }

  get currentRoute (): ?Route {
    return this.history && this.history.current
  }

  init (app: any) {
    process.env.NODE_ENV !== 'production' && assert(
      install.installed,
      `not installed. Make sure to call \`Vue.use(VueRouter)\` ` +
      `before creating root instance.`
    )

    this.apps.push(app)

    if (this.app) {
      return
    }

    this.app = app

    const history = this.history

    if (history instanceof HTML5History) {
      history.transitionTo(history.getCurrentLocation())
    } else if (history instanceof HashHistory) {
      const setupHashListener = () => {
        history.setupListeners()
      }
      history.transitionTo(
        history.getCurrentLocation(),
        setupHashListener,
        setupHashListener
      )
    }

    history.listen(route => {
      this.apps.forEach((app) => {
        app._route = route
      })
    })
  }

  beforeEach (fn: Function): Function {
    return registerHook(this.beforeHooks, fn)
  }

  beforeResolve (fn: Function): Function {
    return registerHook(this.resolveHooks, fn)
  }

  afterEach (fn: Function): Function {
    return registerHook(this.afterHooks, fn)
  }

  onReady (cb: Function, errorCb?: Function) {
    this.history.onReady(cb, errorCb)
  }

  onError (errorCb: Function) {
    this.history.onError(errorCb)
  }

  push (location: RawLocation, onComplete?: Function, onAbort?: Function) {
    this.history.push(location, onComplete, onAbort)
  }

  replace (location: RawLocation, onComplete?: Function, onAbort?: Function) {
    this.history.replace(location, onComplete, onAbort)
  }

  go (n: number) {
    this.history.go(n)
  }

  back () {
    this.go(-1)
  }

  forward () {
    this.go(1)
  }

  getMatchedComponents (to?: RawLocation | Route): Array<any> {
    const route: any = to
      ? to.matched
        ? to
        : this.resolve(to).route
      : this.currentRoute
    if (!route) {
      return []
    }
    return [].concat.apply([], route.matched.map(m => {
      return Object.keys(m.components).map(key => {
        return m.components[key]
      })
    }))
  }

  resolve (
    to: RawLocation,
    current?: Route,
    append?: boolean
  ): {
    location: Location,
    route: Route,
    href: string,
    normalizedTo: Location,
    resolved: Route
  } {
    const location = normalizeLocation(
      to,
      current || this.history.current,
      append,
      this
    )
    const route = this.match(location, current)
    const fullPath = route.redirectedFrom || route.fullPath
    const base = this.history.base
    const href = createHref(base, fullPath, this.mode)
    return {
      location,
      route,
      href,
      normalizedTo: location,
      resolved: route
    }
  }

  addRoutes (routes: Array<RouteConfig>) {
    this.matcher.addRoutes(routes)
    if (this.history.current !== START) {
      this.history.transitionTo(this.history.getCurrentLocation())
    }
  }
}
```

`VueRouter` 定义了一些属性和方法，我们先从它的构造函数看，当我们执行 `new VueRouter` 的时候做了哪些事情。

```js
constructor (options: RouterOptions = {}) {
  this.app = null
  this.apps = []
  this.options = options
  this.beforeHooks = []
  this.resolveHooks = []
  this.afterHooks = []
  this.matcher = createMatcher(options.routes || [], this)

  let mode = options.mode || 'hash'
  this.fallback = mode === 'history' && !supportsPushState && options.fallback !== false
  if (this.fallback) {
    mode = 'hash'
  }
  if (!inBrowser) {
    mode = 'abstract'
  }
  this.mode = mode

  switch (mode) {
    case 'history':
      this.history = new HTML5History(this, options.base)
      break
    case 'hash':
      this.history = new HashHistory(this, options.base, this.fallback)
      break
    case 'abstract':
      this.history = new AbstractHistory(this, options.base)
      break
    default:
      if (process.env.NODE_ENV !== 'production') {
        assert(false, `invalid mode: ${mode}`)
      }
  }
}
```

构造函数定义了一些属性，其中：
1. this.app 表示根 Vue 实例;
2. this.apps 保存持有 $options.router 属性的 Vue 实例
3. this.options 保存传入的路由配置
4. this.beforeHooks、 this.resolveHooks、this.afterHooks 表示一些钩子函数，我们之后会介绍
5. this.matcher 表示路由匹配器，我们之后会介绍
6. this.fallback 表示在浏览器不支持 history.pushState 的情况下，根据传入的 fallback 配置参数，决定是否回退到hash模式
7. this.mode 表示路由创建的模式
8. this.history 表示路由历史的具体的实现实例，它是根据 `this.mode` 的不同实现不同，它有 `History` 基类，然后不同的 history 实现都是继承 History。

实例化 VueRouter 后会返回它的实例 router，我们在 `new Vue` 的时候会把 `router` 作为配置的属性传入，回顾一下上一节我们讲 `beforeCreate` 混入的时候有这么一段代码：

```js
beforeCreate() {
  if (isDef(this.$options.router)) {
    // ...
    this._router = this.$options.router
    this._router.init(this)
    // ...
  }
}  
```
所以组件在执行 `beforeCreate` 钩子函数的时候，如果传入了 `router` 实例，都会执行 `router.init` 方法：
```js
init (app: any) {
  process.env.NODE_ENV !== 'production' && assert(
    install.installed,
    `not installed. Make sure to call \`Vue.use(VueRouter)\` ` +
    `before creating root instance.`
  )

  this.apps.push(app)

  if (this.app) {
    return
  }

  this.app = app

  const history = this.history

  if (history instanceof HTML5History) {
    history.transitionTo(history.getCurrentLocation())
  } else if (history instanceof HashHistory) {
    const setupHashListener = () => {
      history.setupListeners()
    }
    history.transitionTo(
      history.getCurrentLocation(),
      setupHashListener,
      setupHashListener
    )
  }

  history.listen(route => {
    this.apps.forEach((app) => {
      app._route = route
    })
  })
}
```
`init` 的逻辑很简单，它传入的参数是 `Vue 实例`，然后存储到 `this.apps` 中；
只有`根 Vue 实例`会保存到 `this.app` 中，并且会拿到当前的 `this.history`，根据它的不同类型来执行不同逻辑，由于我们平时使用 hash 路由多一些，所以我们先看这部分逻辑，先定义了 `setupHashListener` 函数，接着执行了 `history.transitionTo` 方法，它是定义在 `History` 基类中，代码在 `src/history/base.js`：
```js
transitionTo (location: RawLocation, onComplete?: Function, onAbort?: Function) {
  const route = this.router.match(location, this.current)
  // ...
}
```
我们先不着急去看 transitionTo 的具体实现，先看第一行代码，它调用了 `this.router.match` 函数：

```js
match (
  raw: RawLocation,
  current?: Route,
  redirectedFrom?: Location
): Route {
  return this.matcher.match(raw, current, redirectedFrom)
}
```

实际上是调用了 `this.matcher.match` 方法去做匹配，所以接下来我们先来了解一下 `matcher` 的相关实现。

**总结：** 通过这一节的分析，我们大致对 VueRouter 类有了大致了解，知道了它的一些属性和方法，同时了解到在组件的初始化阶段，执行到 beforeCreate 钩子函数的时候会执行 router.init 方法，然后又会执行 history.transitionTo 方法做路由过渡，进而引出了 matcher 的概念，接下来我们先研究一下 matcher 的相关实现。

# matcher

`matcher` 相关的实现都在 `src/create-matcher.js` 中，我们先来看一下 `matcher` 的数据结构：

```js
export type Matcher = {
  match: (raw: RawLocation, current?: Route, redirectedFrom?: Location) => Route;
  addRoutes: (routes: Array<RouteConfig>) => void;
};
```

Matcher 返回了 2 个方法: `match` 和 `addRoutes`，在上一节我们接触到了 match 方法，顾名思义它是做匹配，那么匹配的是什么，在介绍之前，我们先了解路由中重要的 2 个概念，`Loaction` 和 `Route`，它们的数据结构定义在 `flow/declarations.js` 中。

## Location

```js
declare type Location = {
  _normalized?: boolean;
  name?: string;
  path?: string;
  hash?: string;
  query?: Dictionary<string>;
  params?: Dictionary<string>;
  append?: boolean;
  replace?: boolean;
}
```
`Vue-Router` 中定义的 `Location` 数据结构和浏览器提供的 `window.location` 部分结构有点类似，它们都是对 `url的结构化描述`。举个例子：/abc?foo=bar&baz=qux#hello，它的 path 是 /abc，query 是 {foo:'bar',baz:'qux'}。Location 的其他属性我们之后会介绍。

## Route
```js
declare type Route = {
  path: string;
  name: ?string;
  hash: string;
  query: Dictionary<string>;
  params: Dictionary<string>;
  fullPath: string;
  matched: Array<RouteRecord>;
  redirectedFrom?: string;
  meta?: any;
}
```
`Route` 表示的是路由中的一条线路，它除了描述了类似 `Loctaion` 的 `path、query、hash` 这些概念，还有 `matched` 表示匹配到的所有的 `RouteRecord`。
`Route` 的其他属性我们之后会介绍。

## createMatcher

在了解了 `Location` 和 `Route` 后，我们来看一下 `matcher` 的创建过程：

### 创建

```js
export function createMatcher (
  routes: Array<RouteConfig>,
  router: VueRouter
): Matcher {
  const { pathList, pathMap, nameMap } = createRouteMap(routes)

  function addRoutes (routes) {
    createRouteMap(routes, pathList, pathMap, nameMap)
  }

  function match (
    raw: RawLocation,
    currentRoute?: Route,
    redirectedFrom?: Location
  ): Route {
    const location = normalizeLocation(raw, currentRoute, false, router)
    const { name } = location

    if (name) {
      const record = nameMap[name]
      if (process.env.NODE_ENV !== 'production') {
        warn(record, `Route with name '${name}' does not exist`)
      }
      if (!record) return _createRoute(null, location)
      const paramNames = record.regex.keys
        .filter(key => !key.optional)
        .map(key => key.name)

      if (typeof location.params !== 'object') {
        location.params = {}
      }

      if (currentRoute && typeof currentRoute.params === 'object') {
        for (const key in currentRoute.params) {
          if (!(key in location.params) && paramNames.indexOf(key) > -1) {
            location.params[key] = currentRoute.params[key]
          }
        }
      }

      if (record) {
        location.path = fillParams(record.path, location.params, `named route "${name}"`)
        return _createRoute(record, location, redirectedFrom)
      }
    } else if (location.path) {
      location.params = {}
      for (let i = 0; i < pathList.length; i++) {
        const path = pathList[i]
        const record = pathMap[path]
        if (matchRoute(record.regex, location.path, location.params)) {
          return _createRoute(record, location, redirectedFrom)
        }
      }
    }
    return _createRoute(null, location)
  }

  // ...

  function _createRoute (
    record: ?RouteRecord,
    location: Location,
    redirectedFrom?: Location
  ): Route {
    if (record && record.redirect) {
      return redirect(record, redirectedFrom || location)
    }
    if (record && record.matchAs) {
      return alias(record, location, record.matchAs)
    }
    return createRoute(record, location, redirectedFrom, router)
  }

  return {
    match,
    addRoutes
  }
}
```

`createMatcher` 接收 2 个参数: 
1. 一个是 `routes`，它是用户定义的`路由配置`，来看一下我们之前举的例子中的配置
2. 一个是 `router`，它是我们 `new VueRouter` 返回的实例

```js
const Foo = { template: '<div>foo</div>' }
const Bar = { template: '<div>bar</div>' }

const routes = [
  { path: '/foo', component: Foo },
  { path: '/bar', component: Bar }
]
```

#### createRouteMap

`createMathcer` 首先执行的逻辑是 `const { pathList, pathMap, nameMap } = createRouteMap(routes)` 创建一个路由映射表，`createRouteMap` 的定义在 `src/create-route-map` 中：

```js
export function createRouteMap (
  routes: Array<RouteConfig>,
  oldPathList?: Array<string>,
  oldPathMap?: Dictionary<RouteRecord>,
  oldNameMap?: Dictionary<RouteRecord>
): {
  pathList: Array<string>;
  pathMap: Dictionary<RouteRecord>;
  nameMap: Dictionary<RouteRecord>;
} {
  const pathList: Array<string> = oldPathList || []
  const pathMap: Dictionary<RouteRecord> = oldPathMap || Object.create(null)
  const nameMap: Dictionary<RouteRecord> = oldNameMap || Object.create(null)

  routes.forEach(route => {
    addRouteRecord(pathList, pathMap, nameMap, route)
  })

  for (let i = 0, l = pathList.length; i < l; i++) {
    if (pathList[i] === '*') {
      pathList.push(pathList.splice(i, 1)[0])
      l--
      i--
    }
  }

  return {
    pathList,
    pathMap,
    nameMap
  }
}
```

`createRouteMap` 函数的目标是把`用户的路由配置`转换成一张`路由映射表`，它包含 3 个部分：
1. `pathList` 存储所有的 path
2. `pathMap` 表示一个 path 到 RouteRecord 的映射关系
3. `nameMap` 表示 name 到 RouteRecord 的映射关系。


那么 `RouteRecord` 到底是什么，先来看一下它的数据结构：

```js
declare type RouteRecord = {
  path: string;
  regex: RouteRegExp;
  components: Dictionary<any>;
  instances: Dictionary<any>;
  name: ?string;
  parent: ?RouteRecord;  // 父亲路由
  redirect: ?RedirectOption; // 重定向
  matchAs: ?string; // alias 会用到
  beforeEnter: ?NavigationGuard; // 钩子
  meta: any;
  props: boolean | Object | Function | Dictionary<boolean | Object | Function>;
}
```
它的创建是通过遍历 `routes` 为每一个 route 执行 `addRouteRecord` 方法生成一条记录，来看一下它的定义：

##### addRouteRecord

```js
function addRouteRecord (
  pathList: Array<string>,
  pathMap: Dictionary<RouteRecord>,
  nameMap: Dictionary<RouteRecord>,
  route: RouteConfig,
  parent?: RouteRecord,
  matchAs?: string
) {
  const { path, name } = route
  if (process.env.NODE_ENV !== 'production') {
    assert(path != null, `"path" is required in a route configuration.`)
    assert(
      typeof route.component !== 'string',
      `route config "component" for path: ${String(path || name)} cannot be a ` +
      `string id. Use an actual component instead.`
    )
  }

  const pathToRegexpOptions: PathToRegexpOptions = route.pathToRegexpOptions || {}
  const normalizedPath = normalizePath(
    path,
    parent,
    pathToRegexpOptions.strict
  )

  if (typeof route.caseSensitive === 'boolean') {
    pathToRegexpOptions.sensitive = route.caseSensitive
  }

  const record: RouteRecord = {
    path: normalizedPath,
    regex: compileRouteRegex(normalizedPath, pathToRegexpOptions),
    components: route.components || { default: route.component },
    instances: {},
    name,
    parent,
    matchAs,
    redirect: route.redirect,
    beforeEnter: route.beforeEnter,
    meta: route.meta || {},
    props: route.props == null
      ? {}
      : route.components
        ? route.props
        : { default: route.props }
  }

  if (route.children) {
    if (process.env.NODE_ENV !== 'production') {
      if (route.name && !route.redirect && route.children.some(child => /^\/?$/.test(child.path))) {
        warn(
          false,
          `Named Route '${route.name}' has a default child route. ` +
          `When navigating to this named route (:to="{name: '${route.name}'"), ` +
          `the default child route will not be rendered. Remove the name from ` +
          `this route and use the name of the default child route for named ` +
          `links instead.`
        )
      }
    }
    route.children.forEach(child => {
      const childMatchAs = matchAs
        ? cleanPath(`${matchAs}/${child.path}`)
        : undefined
      addRouteRecord(pathList, pathMap, nameMap, child, record, childMatchAs)
    })
  }

  if (route.alias !== undefined) {
    const aliases = Array.isArray(route.alias)
      ? route.alias
      : [route.alias]

    aliases.forEach(alias => {
      const aliasRoute = {
        path: alias,
        children: route.children
         }
      addRouteRecord(
        pathList,
        pathMap,
        nameMap,
        aliasRoute,
        parent,
        record.path || '/'
      )
    })
  }

  if (!pathMap[record.path]) {
    pathList.push(record.path)
    pathMap[record.path] = record
  }

  if (name) {
    if (!nameMap[name]) {
      nameMap[name] = record
    } else if (process.env.NODE_ENV !== 'production' && !matchAs) {
      warn(
        false,
        `Duplicate named routes definition: ` +
        `{ name: "${name}", path: "${record.path}" }`
      )
    }
  }
}
```

1. 创建 RouteRecord：

```js
 const record: RouteRecord = {
  path: normalizedPath,
  regex: compileRouteRegex(normalizedPath, pathToRegexpOptions),
  components: route.components || { default: route.component },
  instances: {},
  name,
  parent,
  matchAs,
  redirect: route.redirect,
  beforeEnter: route.beforeEnter,
  meta: route.meta || {},
  props: route.props == null
    ? {}
    : route.components
      ? route.props
      : { default: route.props }
}
```
这里要注意几个点：
  - `path` 是规范化后的路径，它会根据 `parent` 的 `path` 做计算；
  - `regex` 是一个正则表达式的扩展，它利用了`path-to-regexp` 这个工具库，把 `path` 解析成一个`正则表达式的扩展`，举个例子：
  - `components` 是一个对象，通常我们在配置中写的 `component` 实际上这里会被转换成 `{components: route.component}`
  - `instances` 表示组件的实例，也是一个对象类型；
  - `parent` 表示父的 `RouteRecord`，因为我们配置的时候有时候会配置子路由，所以整个 `RouteRecord` 也就是一个树型结构。

2. route.children：

如果配置了 `children`，那么递归执行 `addRouteRecord` 方法，并把当前的 `record` 作为 `parent` 传入，通过这样的`深度遍历`，我们就可以拿到一个 `route` 下的完整记录。

```js
if (route.children) {
  // ...
  route.children.forEach(child => {
  const childMatchAs = matchAs
    ? cleanPath(`${matchAs}/${child.path}`)
    : undefined
  addRouteRecord(pathList, pathMap, nameMap, child, record, childMatchAs)
})
}
```

3. 为 `pathList` 和 `pathMap` 各添加一条记录。
```js
if (!pathMap[ record.path]) {
  pathList.push(record.path)
  pathMap[record.path] = record
}
```

4. 给 `nameMap` 添加一条记录
```js
if (name) {
  if (!nameMap[name]) {
    nameMap[name] = record
  }
  // ...
}
```
如果我们在路由配置中配置了 `name`，则给 `nameMap` 添加一条记录。

由于 `pathList`、`pathMap`、`nameMap` 都是引用类型，所以在遍历整个 `routes` 过程中去执行 `addRouteRecord` 方法，会不断给他们添加数据。那么经过整个 `createRouteMap` 方法的执行，我们得到的就是 `pathList`、`pathMap` 和 `nameMap`。其中 `pathList` 是为了记录路由配置中的所有 `path`，而 `pathMap` 和 `nameMap` 都是为了通过 `path` 和 `name` 能快速查到对应的 `RouteRecord`。

再回到 `createMatcher` 函数，接下来就定义了一系列方法，最后返回了一个对象。
```js
return {
  match,
  addRoutes
}
```
也就是说，`matcher` 是一个对象，它对外暴露了 `match` 和 `addRoutes` 方法；

`createMatcher`这个小结一下:

1. `createMatcher` 就是暴露出两个方法给 `VueRouter` ，需要做路由的映射以及动态添加路由的方法。
2. `addRouteRecord`函数有 `path` 的时候存 `pathMap` ，有 `name` 的时候存 `nameMap`;
3. `record: RouteRecord`: 保存着一个路由里所需的信息，比如我们可以通过路径来找到对应要渲染的组件。
4. `createMatcher`和`createRouteMap`就是为了将数组 `routes`
```js
const routes = [
  { path: '/foo', component: Foo },
  { path: '/bar', component: Bar }
]
```
转换成树形结构 `map`
```js
map = {
  '/foo': {
    component: Foo
  },
  '/bar': {
    component: Bar
  }
}
```
再加上一个可以动态添加的函数 `addRoutes` 。



## addRoutes

`addRoutes` 方法的作用是`动态添加路由配置`，因为在实际开发中有些场景是不能提前把路由写死的，需要根据一些条件动态添加路由，所以 `Vue-Router` 也提供了这一接口：
```js
function addRoutes (routes) {
  createRouteMap(routes, pathList, pathMap, nameMap)
}
```
`addRoutes` 的方法十分简单，再次调用 `createRouteMap` 即可，传入新的 `routes` 配置，由于 `pathList`、`pathMap`、`nameMap` 都是引用类型，执行 `addRoutes` 后会修改它们的值。


## match
```js
function match (
  raw: RawLocation,
  currentRoute?: Route,
  redirectedFrom?: Location
): Route {
  const location = normalizeLocation(raw, currentRoute, false, router)
  const { name } = location

  if (name) {
    const record = nameMap[name]
    if (process.env.NODE_ENV !== 'production') {
      warn(record, `Route with name '${name}' does not exist`)
    }
    if (!record) return _createRoute(null, location)
    const paramNames = record.regex.keys
      .filter(key => !key.optional)
      .map(key => key.name)

    if (typeof location.params !== 'object') {
      location.params = {}
    }

    if (currentRoute && typeof currentRoute.params === 'object') {
      for (const key in currentRoute.params) {
        if (!(key in location.params) && paramNames.indexOf(key) > -1) {
          location.params[key] = currentRoute.params[key]
        }
      }
    }

    if (record) {
      location.path = fillParams(record.path, location.params, `named route "${name}"`)
      return _createRoute(record, location, redirectedFrom)
    }
  } else if (location.path) {
    location.params = {}
    for (let i = 0; i < pathList.length; i++) {
      const path = pathList[i]
      const record = pathMap[path]
      if (matchRoute(record.regex, location.path, location.params)) {
        return _createRoute(record, location, redirectedFrom)
      }
    }
  }
  
  return _createRoute(null, location)
}
```
match 方法接收 3 个参数:
1. `raw` 是 `RawLocation` 类型，它可以是一个 `url` 字符串，也可以是一个 `Location` 对象；
2. `currentRoute` 是 `Route` 类型，它表示当前的路径；
3. `redirectedFrom` 和重定向相关，这里先忽略。

`match` 方法返回的是一个路径，它的作用是根据传入的 `raw` 和当前的路径 `currentRoute` 计算出一个新的路径并返回。

逻辑如下：

1. 调用 `normalizeLocation` 获取 `location` 的信息。
![](https://tva1.sinaimg.cn/large/007S8ZIlly1gjk8vqh7awj31160lajsi.jpg)
2. 判断是否有 `name` ，有的话通过 `nameMap` 来创建 `route`
3. 判断是否有 `path` ，有的话通过 `pathMap` 来创建 `route`
4. 如果 `name` 、 `path` 都没有，则直接用 `null` 创建 `route`

### _createRoute

```js
function _createRoute (
  record: ?RouteRecord,
  location: Location,
  redirectedFrom?: Location
): Route {
  if (record && record.redirect) {
    return redirect(record, redirectedFrom || location)
  }
  if (record && record.matchAs) {
    return alias(record, location, record.matchAs)
  }
  return createRoute(record, location, redirectedFrom, router)
}
```
我们先不考虑 `record.redirect` 和 `record.matchAs` 的情况，最终会调用 `createRoute` 方法，它的定义在 `src/uitl/route.js` 中：
```js
export function createRoute (
  record: ?RouteRecord,
  location: Location,
  redirectedFrom?: ?Location,
  router?: VueRouter
): Route {
  const stringifyQuery = router && router.options.stringifyQuery

  let query: any = location.query || {}
  try {
    query = clone(query)
  } catch (e) {}

  const route: Route = {
    name: location.name || (record && record.name),
    meta: (record && record.meta) || {},
    path: location.path || '/',
    hash: location.hash || '',
    query,
    params: location.params || {},
    fullPath: getFullPath(location, stringifyQuery),
    matched: record ? formatMatch(record) : []
  }
  if (redirectedFrom) {
    route.redirectedFrom = getFullPath(redirectedFrom, stringifyQuery)
  }
  return Object.freeze(route)
}
```
`createRoute` 可以根据 `record` 和 `location` 创建出来，最终返回的是一条 `Route 路径`，在 `Vue-Router` 中，所有的 `Route` 最终都会通过 `createRoute` 函数创建，并且它最后是不可以被外部修改的。`Route` 对象中有一个非常重要属性是 `matched`，它通过 `formatMatch(record)` 计算而来：

```js
function formatMatch (record: ?RouteRecord): Array<RouteRecord> {
  const res = []
  while (record) {
    res.unshift(record)
    record = record.parent
  }
  return res
}
```
可以看它是通过 `record` 循环向上找 `parent`，直到找到最外层，并把所有的 `record` 都 `push` 到一个数组中，最终返回的就是 `record` 的数组，它记录了一条线路上的所有 `record`。`matched` 属性非常有用，它为之后渲染组件提供了依据。

以 `pathMap` 举例：
```js
const routes = [
  // 有 path 没 name
  { path: '/foo', component: Foo },
  { path: '/bar', component: Bar }
]
```
`createRouteMap` 之后会转换成 `Object` 形式

![](https://tva1.sinaimg.cn/large/007S8ZIlly1gjkc0f6y9wj31bt0u040i.jpg)
  
`var route = this.router.match(location, this.current)`中返回的`route`格式如下：

![](https://tva1.sinaimg.cn/large/007S8ZIlly1gjmqta51e1j30zv0f7dgj.jpg)

**总结：** `matcher` 相关的主流程的分析就结束了，我们了解了 `Location`、`Route`、`RouteRecord` 等概念。并通过 `matcher` 的 `match` 方法，我们会找到匹配的路径 `Route`，这个对 `Route的切换`，`组件的渲染`都有非常重要的指导意义。下一节我们会回到 `transitionTo` 方法，看一看路径的切换都做了哪些事情。

# 路径切换

`history.transitionTo `是 `Vue-Router` 中非常重要的方法，当我们切换路由线路的时候，就会执行到该方法，前一节我们分析了 `matcher` 的相关实现，知道它是如何找到匹配的新线路，那么匹配到新线路后又做了哪些事情，接下来我们来完整分析一下 `transitionTo` 的实现，它的定义在 `src/history/base.js` 中：
```js
transitionTo (location: RawLocation, onComplete?: Function, onAbort?: Function) {
  const route = this.router.match(location, this.current)
  this.confirmTransition(route, () => {
    this.updateRoute(route)
    onComplete && onComplete(route)
    this.ensureURL()

    if (!this.ready) {
      this.ready = true
      this.readyCbs.forEach(cb => { cb(route) })
    }
  }, err => {
    if (onAbort) {
      onAbort(err)
    }
    if (err && !this.ready) {
      this.ready = true
      this.readyErrorCbs.forEach(cb => { cb(err) })
    }
  })
}
```
`transitionTo` 首先根据目标 `location` 和当前路径 `this.current` 执行 `this.router.match` 方法去匹配到目标的路径。这里 `this.current` 是 `history` 维护的当前路径，它的初始值是在 `history` 的构造函数中初始化的：`this.current = START`;

```js
export const START = createRoute(null, {
  path: '/'
})
```
这样就创建了一个初始的 `Route`，而 `transitionTo` 实际上也就是在切换 `this.current`，稍后我们会看到。

拿到新的路径后，那么接下来就会执行 `confirmTransition` 方法去做**真正的切换**，由于这个过程可能有一些异步的操作（如异步组件），所以整个 `confirmTransition` API 设计成带有成功回调函数和失败回调函数，先来看一下它的定义：
```js
confirmTransition (route: Route, onComplete: Function, onAbort?: Function) {
  const current = this.current
  const abort = err => {
    if (isError(err)) {
      if (this.errorCbs.length) {
        this.errorCbs.forEach(cb => { cb(err) })
      } else {
        warn(false, 'uncaught error during route navigation:')
        console.error(err)
      }
    }
    onAbort && onAbort(err)
  }

  if (
    isSameRoute(route, current) &&
    route.matched.length === current.matched.length
  ) {
    this.ensureURL()
    return abort()
  }

  const {
    updated,
    deactivated,
    activated
  } = resolveQueue(this.current.matched, route.matched)

  const queue: Array<?NavigationGuard> = [].concat(
    extractLeaveGuards(deactivated),
    this.router.beforeHooks,
    extractUpdateHooks(updated),
    activated.map(m => m.beforeEnter),
    resolveAsyncComponents(activated)
  )

  this.pending = route
  const iterator = (hook: NavigationGuard, next) => {
    if (this.pending !== route) {
      return abort()
    }
    try {
      hook(route, current, (to: any) => {
        if (to === false || isError(to)) {
          this.ensureURL(true)
          abort(to)
        } else if (
          typeof to === 'string' ||
          (typeof to === 'object' && (
            typeof to.path === 'string' ||
            typeof to.name === 'string'
          ))
        ) {
          abort()
          if (typeof to === 'object' && to.replace) {
            this.replace(to)
          } else {
            this.push(to)
          }
        } else {
          next(to)
        }
      })
    } catch (e) {
      abort(e)
    }
  }

  runQueue(queue, iterator, () => {
    const postEnterCbs = []
    const isValid = () => this.current === route
    const enterGuards = extractEnterGuards(activated, postEnterCbs, isValid)
    const queue = enterGuards.concat(this.router.resolveHooks)
    runQueue(queue, iterator, () => {
      if (this.pending !== route) {
        return abort()
      }
      this.pending = null
      onComplete(route)
      if (this.router.app) {
        this.router.app.$nextTick(() => {
          postEnterCbs.forEach(cb => { cb() })
        })
      }
    })
  })
}
```

首先定义了 `abort` 函数，然后判断如果满足计算后的 `route` 和 `current` 是相同路径的话，则直接调用 `this.ensureUrl` 和 `abort`，`ensureUrl` 这个函数我们之后会介绍。

接着又根据 `current.matched` 和 `route.matched` 执行了 `resolveQueue` 方法解析出 `3 个队列`：`updated`,`deactivated`,`activated`

```js
function resolveQueue (
  current: Array<RouteRecord>,
  next: Array<RouteRecord>
): {
  updated: Array<RouteRecord>,
  activated: Array<RouteRecord>,
  deactivated: Array<RouteRecord>
} {
  let i
  const max = Math.max(current.length, next.length)
  for (i = 0; i < max; i++) {
    if (current[i] !== next[i]) {
      break
    }
  }
  return {
    updated: next.slice(0, i),
    activated: next.slice(i),
    deactivated: current.slice(i)
  }
}
```

因为 `route.matched` 是一个 `RouteRecord` 的数组，由于路径是由 `current` 变向 `route`，那么就遍历对比 2 边的 `RouteRecord`，找到一个不一样的位置 `i`:
1. 那么 `next` 中从 `0` 到 `i` 的 `RouteRecord` 是两边都一样，则为 `updated` 的部分；
2. 从 `i` 到最后的 `RouteRecord` 是 `next` 独有的，为 `activated` 的部分；
3. 而 `current` 中从 `i` 到最后的 `RouteRecord` 则没有了，为 `deactivated` 的部分。

拿到 `updated`、`activated`、`deactivated` 3 个 `ReouteRecord` 数组后，接下来就是路径变换后的一个重要部分，执行一系列的`钩子函数`。

## 导航守卫

实际上就是发生在路由路径切换的时候，执行的一系列钩子函数。

1. 在失活的组件里调用离开守卫。获取到的就是所有失活组件中定义的 `beforeRouteLeave` 钩子函数。
2. 调用全局的 `beforeEach` 守卫。
3. 在重用的组件里调用 `beforeRouteUpdate` 守卫
4. 在激活的路由配置里调用 `beforeEnter`
5. 解析异步路由组件。`resolveAsyncComponents`返回的是一个导航守卫函数，有标准的 `to`、`from`、`next` 参数
6. 在被激活的组件里调用 `beforeRouteEnter`
7. 调用全局的 `beforeResolve` 守卫。
8. 调用全局的 `afterEach` 钩子。

