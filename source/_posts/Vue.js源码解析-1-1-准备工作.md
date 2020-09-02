---
title: Vue.js源码解析 1-1-准备工作
date: 2020-04-12 23:11:21
tags:
- vue
- 源码解析
- 源码
---

## 文章说明

前年的时候学习过vue源码相关的知识，主要是参考了[手动实现mvvm](https://github.com/DMQ/mvvm)这篇文章，这里主要学习了：
1. Observer类：采用数据劫持结合发布者-订阅者模式的方式，通过Object.defineProperty()来劫持各个属性的setter，getter，在数据变动时发布消息给订阅者，触发相应的监听回调。
2. Compile类：主要做的事情是解析模板指令，将模板中的变量替换成数据，然后初始化渲染页面视图，并将每个指令对应的节点绑定更新函数，添加监听数据的订阅者，一旦数据有变动，收到通知，更新视图，
3. Watcher类：Observer和Compile之间通信的桥梁的实现，主要做的事情是: 1、在自身实例化时往属性订阅器(dep)里面添加自己 2、自身必须有一个update()方法 3、待属性变动dep.notice()通知时，能调用自身的update()方法，并触发Compile中绑定的回调。

<!-- more -->

有一个核心的架构图说明了这一切![](https://cdn.liujiefront.com/images/vue-source/vue%E6%BA%90%E7%A0%81.png)
不过这个实现比起真正的源码还是有很多的细节没说清楚的，比如diff算法，源码的项目结构分析等等，所以今年准备再系统的复习一次vue的源码，学习主要是参考了[huangyi大神](https://github.com/ustbhuangyi)的[文章](https://github.com/ustbhuangyi/vue-analysis),整个分析会的文章会从
1. 核心
  - 数据驱动
  - 组件化
  - 响应式原理
2. 编译
  - parse
  - optimize
  - codegen
3. 拓展
  - event、v-model
  - slot、keep-alive
  - transition
4. 生态
  - Vue-router
  - Vuex

这样的体系进行深入，本篇和后续的文章本身写出来的目的是为了作为自己的学习笔记，更深入的还是建议看原作者的文章

## 文章的结构

```
src
├── compiler        # 编译相关 
├── core            # 核心代码 
├── platforms       # 不同平台的支持
├── server          # 服务端渲染
├── sfc             # .vue 文件解析
├── shared          # 共享代码
```
### compiler

compiler 目录包含 Vue.js 所有编译相关的代码。它包括
1. 把模板解析成 ast 语法树
2. ast 语法树优化
3. 3代码生成等功能等

编译分为`Runtime Only` 和 `Runtime + Compiler`，我们在利用 `vue-cli` 去初始化我们的 Vue.js 项目的时候会询问我们用 `Runtime Only` 版本的还是 `Runtime + Compiler` 版本，`Runtime Only`是说借助如 webpack 的 vue-loader 工具把 .vue 文件编译成 JavaScript，因为是在编译阶段做的，所以它只包含运行时的 Vue.js 代码，因此代码体积也会更轻量。

### core
包含了 Vue.js 的核心代码，包括内置组件、全局 API 封装，Vue 实例化、观察者、虚拟 DOM、工具函数等等。是重点需要分析的目录

### platform
platform 也是 Vue.js 的入口，目前是分为运行在web和weex这两个平台

### server
服务端渲染相关，可以了解下vue的ssr方案，因为node本身也能运行js代码，所以我们借助这个特性，在nodejs里运行vue，来解决spa遇到的首屏加载过慢和seo的问题，ssr我觉得最核心的是叫 ** 同构 **的思路，有兴趣的可以自行深入了解，其实ssr主要的还是学习思想。

### sfc
借助 webpack 构建， 然后通过 .vue 单文件来编写组件，这个目录下的代码逻辑会把 .vue 文件内容解析成一个 JavaScript 的对象。

### shared
定义一些工具方法，这里定义的工具方法都是会被浏览器端的 Vue.js 和服务端的 Vue.js 所共享的。

## 从入口开始分析

如果是web应用下的构建，入口是`src/platforms/web/entry-runtime-with-compiler.js`,这个文件的最下面一行是写了`export default Vue`,当我们的代码执行 `import Vue from 'vue'` 的时候，就是从这个入口执行代码来初始化 Vue

### 追本溯源

在这个入口 JS 的上方我们可以找到 Vue 的来源：`import Vue from './runtime/index'`,runtime里的index写了`import Vue from 'core/index'`，我们再到core的index里找到`import Vue from './instance/index'`,instance里终于找到了vue的庐山真面目就是
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
它实际上就是一个用 `Function` 实现的类，我们只能通过 new Vue 去实例化它,至于为什么不用ES6 的 Class，是因为后面有很多的混入函数，比如`initMixin`,`stateMixin`等`xxxMixin`的函数调用，我们把Vue传进去的时候，就能给 Vue 的 prototype 上扩展一些方法，这么做的好处是非常方便代码的维护和管理，这种编程技巧也非常值得我们去学习。

### initGlobalAPI

Vue.js 在整个初始化过程中，除了给它的原型 prototype 上扩展方法，还会给 Vue 这个对象本身扩展全局的静态方法，它的定义在 `src/core/global-api/index.js` 中
这里就是在 Vue 上扩展的一些全局方法的定义，比如option，set，nextTick等，Vue 官网中关于全局 API 都可以找到

## 总结

Vue它本质上就是一个用 Function 实现的 Class,然后它的原型 prototype 以及它本身都扩展了一系列的方法和属性，下面就重点分析这些东西