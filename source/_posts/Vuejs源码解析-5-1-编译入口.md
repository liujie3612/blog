---
title: Vuejs源码解析-5-1-编译入口
date: 2020-09-10 15:17:20
tags:
- vue
- 源码解析
- 源码
- 编译
- 入口
categories: Vue源码解析
---
之前我们分析过模板到真实 DOM 渲染的过程，中间有一个环节是把`模板` 编译成 `render 函数`，这个过程我们把它称作`编译`。

Vue.js 提供了 2 个版本，一个是 `Runtime + Compiler` 的，一个是 `Runtime only` 的，前者是包含编译代码的，可以把编译过程放在运行时做，后者是不包含编译代码的，需要借助 webpack 的 `vue-loader` 事先把模板编译成 `render函数`。

这一章我们就来分析编译的过程，对编译过程的了解会让我们对 Vue 的指令、内置组件等有更好的理解。不过由于编译的过程是一个相对复杂的过程，我们只要求理解整体的流程、输入和输出即可，对于细节我们不必抠太细。有些细节比如对于 slot 的处理我们可以在之后去分析插槽实现的时候再详细分析。

<!--more-->

# 编译入口

当我们使用 `Runtime + Compiler` 的 `Vue.js`，它的入口是 `src/platforms/web/entry-runtime-with-compiler.js`，看一下它对 `$mount` 函数的定义：
```js
Vue.prototype.$mount = function (
  el,
  hydrating
) {
  // ...

  if (!options.render) {
    // ...
    if (template) {
      // ...
      // 编译的入口
      const { render, staticRenderFns } = compileToFunctions(template, {
        outputSourceRange: process.env.NODE_ENV !== 'production',
        shouldDecodeNewlines: shouldDecodeNewlines,
        shouldDecodeNewlinesForHref: shouldDecodeNewlinesForHref,
        delimiters: options.delimiters,
        comments: options.comments
      }, this);
      options.render = render;
      options.staticRenderFns = staticRenderFns;

      // ...
    }
  }
  return mount.call(this, el, hydrating)
};
```
`compileToFunctions` 方法就是把模板 `template` 编译生成 `render` 以及 `staticRenderFns`，它的定义在 `src/platforms/web/compiler/index.js` 中：
```js
// src/platforms/web/compiler/index.js
import { baseOptions } from './options'
import { createCompiler } from 'compiler/index'
const { compile, compileToFunctions } = createCompiler(baseOptions)
export { compile, compileToFunctions }
```
`compileToFunctions` 方法实际上是 `createCompiler` 方法的返回值，该方法接收一个编译配置参数，接下来我们来看一下 `createCompiler` 方法的定义，在 `src/compiler/index.js` 中：

```js
var createCompiler = createCompilerCreator(function baseCompile(
  template,
  options
) {
  var ast = parse(template.trim(), options);
  if (options.optimize !== false) {
    optimize(ast, options);
  }
  var code = generate(ast, options);
  return {
    ast: ast,
    render: code.render,
    staticRenderFns: code.staticRenderFns
  }
});
```

`createCompiler` 方法实际上是通过调用 `createCompilerCreator` 方法返回的，该方法传入的参数是一个函数，真正的编译过程都在这个 `baseCompile` 函数里执行，那么 `createCompilerCreator` 又是什么呢，它的定义在 `src/compiler/create-compiler.js` 中：
```js
function createCompilerCreator(baseCompile) {
  return function createCompiler(baseOptions) {
    function compile(
      template,
      options
    ) {
      // ...
      var compiled = baseCompile(template.trim(), finalOptions);

      // ...

      return compiled
    }

    return {
      compile: compile,
      compileToFunctions: createCompileToFunctionFn(compile)
    }
  }
}
```
可以看到该方法返回了一个 `createCompiler` 的函数，它接收一个 `baseOptions` 的参数，返回的是一个对象，包括 `compile` 方法属性和 `compileToFunctions` 属性，这个 `compileToFunctions` 对应的就是 `$mount` 函数调用的 `compileToFunctions` 方法，它是调用 `createCompileToFunctionFn` 方法的返回值，我们接下来看一下 `createCompileToFunctionFn` 方法，它的定义在 `src/compiler/to-function/js` 中：
```js
// src/compiler/to-function/js
export function createCompileToFunctionFn (compile: Function): Function {  
  const cache = Object.create(null)  
  return function compileToFunctions (    
    template: string,    
    options?: CompilerOptions,    
    vm?: Component  
  ): CompiledFunctionResult {    
    options = extend({}, options)        
    
    // ...    
    
    // compile    
    const compiled = compile(template, options)    
    // ...    
    return (cache[key] = res)  
  }
}
```
至此我们总算找到了 `compileToFunctions` 的最终定义，核心的编译过程就一行代码：
```js
const compiled = compile(template, options)
```
`compile` 函数在执行 `createCompileToFunctionFn` 的时候作为参数传入，它是 `createCompiler` 函数中定义的 `compile` 函数。

`compile` 函数执行的逻辑是先处理配置参数，真正执行编译过程就一行代码：
```js
const compiled = baseCompile(template, finalOptions)
```

`baseCompile` 在执行 `createCompilerCreator` 方法时作为参数传入，如下：
```js
function baseCompile(
  template,
  options
) {
  var ast = parse(template.trim(), options);
  if (options.optimize !== false) {
    optimize(ast, options);
  }
  var code = generate(ast, options);
  return {
    ast: ast,
    render: code.render,
    staticRenderFns: code.staticRenderFns
  }
}
```
所以编译的入口我们终于找到了，它主要就是执行了如下几个逻辑：
1. 解析模板字符串生成 AST
```js
const ast = parse(template.trim(), options)
```
2. 优化语法树
```js
optimize(ast, options)
```
3. 生成代码
```js
const code = generate(ast, options)
```
找到真正调用`compileToFunctions`的函数，是`createCompileToFunctionFn`

步骤：`createCompilerCreator (baseCompile)` —> `createCompiler(baseOptions)` -> `createCompileToFunctionFn(compile)` -> `compileToFunctions`

# 总结：
编译入口逻辑之所以这么绕，是因为 Vue.js 在不同的平台下都会有编译的过程，因此编译过程中的依赖的配置 `baseOptions` 会有所不同。

而同一个平台下编译过程会多次执行，但每一次的编译过程配置又是相同的，为了不让这些配置在每次编译过程都通过参数传入，Vue.js 利用了`函数柯里化`的技巧很好的实现了 `baseOptions` 的参数保留。

同样，Vue.js 也是利用`函数柯里化技巧`把`基础的编译过程函数`抽出来，通过 `createCompilerCreator(baseCompile)` 的方式把`真正编译的过程`和`其它逻辑如对编译配置处理`、`缓存处理`等剥离开，这样的设计还是非常巧妙的。

# parse

编译过程首先就是对模板做解析，生成 `AST`，它是一种`抽象语法树`，是对源代码的抽象语法结构的`树状表现形式`。在很多编译技术中，如 `babel` 编译 `ES6` 的代码都会先生成 `AST`。

这个过程是比较复杂的，它会用到大量`正则表达式对字符串解析`，如果对正则不是很了解，建议先去补习正则表达式的知识。为了直观地演示 `parse` 的过程，我们先来看一个例子：

```vue
<ul :class="bindCls" class="list" v-if="isShow">
    <li v-for="(item,index) in data" @click="clickItem(index)">{{item}}:{{index}}</li>
</ul>
```
经过 `parse` 过程后，生成的 `AST` 如下：
```js
ast = {
  'type': 1,
  'tag': 'ul',
  'attrsList': [],
  'attrsMap': {
    ':class': 'bindCls',
    'class': 'list',
    'v-if': 'isShow'
  },
  'if': 'isShow',
  'ifConditions': [{
    'exp': 'isShow',
    'block': // ul ast element
  }],
  'parent': undefined,
  'plain': false,
  'staticClass': 'list',
  'classBinding': 'bindCls',
  'children': [{
    'type': 1,
    'tag': 'li',
    'attrsList': [{
      'name': '@click',
      'value': 'clickItem(index)'
    }],
    'attrsMap': {
      '@click': 'clickItem(index)',
      'v-for': '(item,index) in data'
     },
    'parent': // ul ast element
    'plain': false,
    'events': {
      'click': {
        'value': 'clickItem(index)'
      }
    },
    'hasBindings': true,
    'for': 'data',
    'alias': 'item',
    'iterator1': 'index',
    'children': [
      'type': 2,
      'expression': '_s(item)+":"+_s(index)'
      'text': '{{item}}:{{index}}',
      'tokens': [
        {'@binding':'item'},
        ':',
        {'@binding':'index'}
      ]
    ]
  }]
}
```
可以看到，生成的 AST 是一个`树状结构`，每一个节点都是一个 `ast element`，除了它自身的一些属性，还维护了它的`父子关系`，如 `parent` 指向它的`父节点`，`children` 指向它的`所有子节点`。

## 流程图

![](https://cdn.liujiefront.com/images/algorithm/ssa2u.png)

## 总结

`parse` 的目标是把 `template` 模板字符串转换成 `AST 树`，它是一种用 `JavaScript 对象`的形式来描述整个模板。那么整个 `parse` 的过程是利用`正则表达式顺序解析模板`，当解析到`开始标签`、`闭合标签`、`文本`的时候都会分别执行对应的回调函数，来达到构造 AST 树的目的。

AST 元素节点总共有` 3 种类型`：
1. type 为 1 表示是`普通元素`
2. type 为 2 表示是`表达式`
3. type 为 3 表示是`纯文本`。

# optimize 

当我们的模板 `template` 经过 `parse` 过程后，会输出生成 `AST 树`，那么接下来我们需要对这颗树做`优化`，`optimize` 的逻辑是远简单于 `parse` 的逻辑，所以理解起来会轻松很多。

为什么要有优化过程，因为我们知道 Vue 是数据驱动，是响应式的，但是我们的模板并不是`所有数据都是响应式的`，也有很多数据是首次渲染后就永远不会变化的，那么这部分数据生成的 DOM 也不会变化，我们可以在 patch 的过程跳过对他们的比对。

经过 optimize 后，AST 树变成了如下：
```js
ast = {
  'type': 1,
  'tag': 'ul',
  'attrsList': [],
  'attrsMap': {
    ':class': 'bindCls',
    'class': 'list',
    'v-if': 'isShow'
  },
  'if': 'isShow',
  'ifConditions': [{
    'exp': 'isShow',
    'block': // ul ast element
  }],
  'parent': undefined,
  'plain': false,
  'staticClass': 'list',
  'classBinding': 'bindCls',
  'static': false,
  'staticRoot': false,
  'children': [{
    'type': 1,
    'tag': 'li',
    'attrsList': [{
      'name': '@click',
      'value': 'clickItem(index)'
    }],
    'attrsMap': {
      '@click': 'clickItem(index)',
      'v-for': '(item,index) in data'
     },
    'parent': // ul ast element
    'plain': false,
    'events': {
      'click': {
        'value': 'clickItem(index)'
      }
    },
    'hasBindings': true,
    'for': 'data',
    'alias': 'item',
    'iterator1': 'index',
    'static': false,
    'staticRoot': false,
    'children': [
      'type': 2,
      'expression': '_s(item)+":"+_s(index)'
      'text': '{{item}}:{{index}}',
      'tokens': [
        {'@binding':'item'},
        ':',
        {'@binding':'index'}
      ],
      'static': false
    ]
  }]
}
```
我们发现每一个 AST 元素节点都多了 `staic` 属性，并且 `type 为 1` 的普通元素 AST 节点多了 `staticRoot` 属性。

`optimize` 的过程，就是**深度**遍历这个 `AST 树`，去检测它的每一颗子树是不是`静态节点`，如果是`静态节点`则它们生成 `DOM` 永远不需要改变，这对运行时对模板的更新起到极大的优化作用。

我们通过 `optimize` 我们把整个 AST 树中的每一个 AST 元素节点标记了 `static` 和 `staticRoot`，它会影响我们接下来执行代码生成的过程。

# codegen

编译的最后一步就是把优化后的 AST 树转换成可执行的代码

为了方便理解，我们还是用之前的例子：
```js
<ul :class="bindCls" class="list" v-if="isShow">
    <li v-for="(item,index) in data" @click="clickItem(index)">{{item}}:{{index}}</li>
</ul>
```

它经过编译，执行 `const code = generate(ast, options)`，生成的 `render` 代码串如下：

```js
with(this){
  return (isShow) ?
    _c('ul', {
        staticClass: "list",
        class: bindCls
      },
      _l((data), function(item, index) {
        return _c('li', {
          on: {
            "click": function($event) {
              clickItem(index)
            }
          }
        },
        [_v(_s(item) + ":" + _s(index))])
      })
    ) : _e()
}
```

