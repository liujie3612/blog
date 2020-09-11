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

