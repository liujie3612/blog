---
title: webpack热更新原理
date: 2020-11-16 17:10:39
tags:
- webpack
---

`Hot Module Replacement`，简称`HMR`，无需完全刷新整个页面的同时，更新模块。HMR的好处，在日常开发工作中体会颇深：节省宝贵的开发时间、提升开发体验。

# 刷新我们一般分为两种：

1. 一种是页面刷新，不保留页面状态，就是简单粗暴，直接`window.location.reload()`。
2. 另一种是基于`WDS` (Webpack-dev-server)的模块热替换，只需要局部刷新页面上发生变化的模块，同时可以保留当前的页面状态，比如复选框的选中状态、输入框的输入等。

HMR作为一个Webpack内置的功能，可以通过`HotModuleReplacementPlugin`或 `--hot` 开启。

<!--more-->

# webpack的编译构建过程

每次修改代码保存后，控制台会出现`Compiling`字样，触发新的编译中...,产生两个文件
![](https://tva1.sinaimg.cn/large/0081Kckwly1gkr5uajo91j30tv02bdfw.jpg)

Hash值代表每一次编译的标识。其次，根据新生成文件名可以发现，上次输出的Hash值会作为本次编译新生成的文件标识。依次类推，本次输出的Hash值会被作为下次热更新的标识。

首先看json文件，返回的结果中，h代表本次新生成的Hash值，用于下次文件热更新请求的前缀。c表示当前要热更新的文件对应的模块。

再看下生成的js文件，那就是本次修改的代码，重新编译打包后的。

![](https://tva1.sinaimg.cn/large/0081Kckwly1gkr5w5pxvdj30o30krabh.jpg)

# 热更新实现原理 

## webpack-dev-server启动本地服务

根据`webpack-dev-server`的`package.json`中的`bin`命令，可以找到命令的入口文件`bin/webpack-dev-server.js`。

```js
// node_modules/webpack-dev-server/bin/webpack-dev-server.js

// 生成webpack编译主引擎 compiler
let compiler = webpack(config);

// 启动本地服务
let server = new Server(compiler, options, log);
server.listen(options.port, options.host, (err) => {
    if (err) {throw err};
});
```

本地服务代码：
``` js
// node_modules/webpack-dev-server/lib/Server.js
class Server {
    constructor() {
        this.setupApp();
        this.createServer();
    }
    
    setupApp() {
        // 依赖了express
    	this.app = new express();
    }
    
    createServer() {
        this.listeningApp = http.createServer(this.app);
    }
    listen(port, hostname, fn) {
        return this.listeningApp.listen(port, hostname, (err) => {
            // 启动express服务后，启动websocket服务
            this.createSocketServer();
        }
    }                                   
}
```
1. 启动`webpack`，生成`compiler`实例。`compiler`上有很多方法，比如可以启动 `webpack` 所有编译工作，以及监听本地文件的变化。
2. 使用`express`框架启动本地`server`，让浏览器可以请求本地的静态资源。
3. 本地server启动之后，再去启动`websocket服务`，通过`websocket`，可以建立本地服务和浏览器的双向通信。这样就可以实现当本地文件发生变化，立马告知浏览器可以热更新代码啦！

## 修改webpack.config.js的entry配置

启动本地服务前，调用了`updateCompiler(this.compiler)`方法。这个方法中有 2 段关键性代码。

1. 获取`websocket客户端`代码路径
2. 根据配置获取`webpack热更新`代码路径

```js
// 获取websocket客户端代码
const clientEntry = `${require.resolve(
    '../../client/'
)}?${domain}${sockHost}${sockPath}${sockPort}`;

// 根据配置获取热更新代码
let hotEntry;
if (options.hotOnly) {
    hotEntry = require.resolve('webpack/hot/only-dev-server');
} else if (options.hot) {
    hotEntry = require.resolve('webpack/hot/dev-server');
}
```

修改后的webpack入口配置如下：

```js
// 修改后的entry入口
{ entry:
    { index: 
        [
            // 上面获取的clientEntry
            'xxx/node_modules/webpack-dev-server/client/index.js?http://localhost:8080',
            // 上面获取的hotEntry
            'xxx/node_modules/webpack/hot/dev-server.js',
            // 开发配置的入口
            './src/index.js'
    	],
    },
}
```

为什么要新增了 2 个文件？在入口默默增加了 2 个文件，那就意味会一同打包到`bundle`文件中去，也就是线上运行时。

## 监听webpack编译结束

修改好入口配置后，又调用了`setupHooks`方法。这个方法是用来注册监听事件的，监听每次`webpack编译完成`。
```js
// node_modules/webpack-dev-server/lib/Server.js
// 绑定监听事件
setupHooks() {
    const {done} = compiler.hooks;
    // 监听webpack的done钩子，tapable提供的监听方法
    done.tap('webpack-dev-server', (stats) => {
        this._sendStats(this.sockets, this.getStats(stats));
        this._stats = stats;
    });
};
```
当监听到一次webpack编译结束，就会调用`_sendStats`方法通过`websocket`给浏览器发送通知，`ok`和`hash`事件，这样浏览器就可以拿到最新的hash值了，做检查更新逻辑。
```js
// 通过websoket给客户端发消息
_sendStats() {
    this.sockWrite(sockets, 'hash', stats.hash);
    this.sockWrite(sockets, 'ok');
}
```
## webpack监听文件变化

每次修改代码，就会触发编译。说明我们还需要监听本地代码的变化，主要是通过`setupDevMiddleware`方法实现的。

这个方法主要执行了`webpack-dev-middleware`库。很多人分不清`webpack-dev-middleware`和`webpack-dev-server`的区别。其实就是因为`webpack-dev-server`只负责`启动服务`和`前置准备工作`，所有`文件相关的操作`都抽离到`webpack-dev-middleware`库了，主要是本地文件的编译和输出以及监听，无非就是职责的划分更清晰了。

那我们来看下`webpack-dev-middleware`源码里做了什么事:
```js
// node_modules/webpack-dev-middleware/index.js
compiler.watch(options.watchOptions, (err) => {
    if (err) { /*错误处理*/ }
});

// 通过“memory-fs”库将打包后的文件写入内存
setFs(context, compiler); 

```
1. 调用了`compiler.watch`方法，在第 1 步中也提到过，compiler的强大。这个方法主要就做了 2 件事：
   - 首先对本地文件代码进行编译打包，也就是webpack的一系列编译流程。
   - 其次编译结束后，开启对本地文件的监听，当文件发生变化，重新编译，编译完成之后继续监听。

为什么代码的改动保存会自动编译，重新打包？这一系列的重新检测编译就归功于`compiler.watch`这个方法了。监听本地文件的变化主要是通过`文件的生成时间`是否有变化

2. 执行`setFs`方法，这个方法主要目的就是将编译后的文件打包到`内存`。这就是为什么在开发的过程中，你会发现dist目录没有打包后的代码，因为都在内存中。原因就在于访问内存中的代码比访问文件系统中的文件更快，而且也减少了代码写入文件的开销，这一切都归功于`memory-fs`。

## 浏览器接收到热更新的通知

我们已经可以监听到文件的变化了，当文件发生变化，就触发重新编译。
同时还监听了每次编译结束的事件。当监听到一次webpack编译结束，`_sendStats`方法就通过`websoket`给浏览器发送通知，检查下是否需要热更新。下面重点讲的就是`_sendStats`方法中的ok和hash事件都做了什么。

那浏览器是如何接收到websocket的消息呢？回忆下第 2 步骤增加的入口文件，也就是`websocket`客户端代码。

```js
'xxx/node_modules/webpack-dev-server/client/index.js?http://localhost:8080'
```

这个文件的代码会被打包到bundle.js中，运行在浏览器中。来看下这个文件的核心代码吧。

```js
// webpack-dev-server/client/index.js
var socket = require('./socket');
var onSocketMessage = {
    hash: function hash(_hash) {
        // 更新currentHash值
        status.currentHash = _hash;
    },
    ok: function ok() {
        sendMessage('Ok');
        // 进行更新检查等操作
        reloadApp(options, status);
    },
};
// 连接服务地址socketUrl，?http://localhost:8080，本地服务地址
socket(socketUrl, onSocketMessage);

function reloadApp() {
	if (hot) {
        log.info('[WDS] App hot update...');
        
        // hotEmitter其实就是EventEmitter的实例
        var hotEmitter = require('webpack/hot/emitter');
        hotEmitter.emit('webpackHotUpdate', currentHash);
    } 
}
```
socket方法建立了websocket和服务端的连接，并注册了 2 个监听事件。

1. hash事件：更新最新一次打包后的hash值。
2. ok事件：进行热更新检查。

热更新检查事件是调用`reloadApp`方法,利用`node.js`的`EventEmitter`，发出`webpackHotUpdate`消息给`webpack`(为了更好的维护代码，以及职责划分的更明确。websocket仅仅用于客户端（浏览器）和服务端进行通信。而真正做事情的活还是交回给了webpack)

那webpack怎么做的呢？再来回忆下第 2 步。入口文件还有一个文件没有讲到，就是：

```js
'xxx/node_modules/webpack/hot/dev-server.js'
```
这个文件的代码同样会被打包到`bundle.js`中，运行在浏览器中。

```js
// node_modules/webpack/hot/dev-server.js
var check = function check() {
    module.hot.check(true).then(function(updatedModules) {
      // 容错，直接刷新页面
      if (!updatedModules) {
          window.location.reload();
          return;
      }
      // 热更新结束，打印信息
      if (upToDate()) {
          log("info", "[HMR] App is up to date.");
      }
    }).catch(function(err) {
      window.location.reload();
    });
};

var hotEmitter = require("./emitter");

hotEmitter.on("webpackHotUpdate", function(currentHash) {
  lastHash = currentHash;
  check();
});
```

这里webpack监听到了`webpackHotUpdate`事件，并获取最新了`最新的hash`值，然后终于进行检查更新了。检查更新呢调用的是`module.hot.check`方法。那么问题又来了，module.hot.check又是哪里冒出来了的！答案是`HotModuleReplacementPlugin`。

## HotModuleReplacementPlugin

前面好像一直是`webpack-dev-server`做的事，那`HotModuleReplacementPlugin`在热更新过程中又做了什么呢？
首先你可以对比下，配置热更新和不配置时bundle.js的区别。内存中看不到？直接执行`webpack`命令就可以看到生成的`bundle.js`文件啦。不要用`webpack-dev-server`启动就好了。

1. 没有配置的:

![](https://tva1.sinaimg.cn/large/0081Kckwly1gkuxf1faxcj30in06hmxj.jpg)

2. 配置了`HotModuleReplacementPlugin`或`--hot`的：

![](https://tva1.sinaimg.cn/large/0081Kckwly1gkuxfq8khxj30kc07tjs0.jpg)

我们发现`moudle`新增了一个属性为`hot`，再看`hotCreateModule`方法。 这不就找到`module.hot.check`是哪里冒出来的。

![](https://tva1.sinaimg.cn/large/0081Kckwly1gkuxggkjpbj30k00f6wfg.jpg)

经过对比打包后的文件，`__webpack_require__`中的`moudle`以及代码行数的不同。我们都可以发现`HotModuleReplacementPlugin`原来也是默默的塞了很多代码到`bundle.js`中呀。这和第 2 步骤很是相似哦！为什么? 因为检查更新是在浏览器中操作呀。这些代码必须在运行时的环境。

也可以直接看浏览器Sources下的代码，会发现webpack和plugin偷偷加的代码都在哦。在这里调试也很方便。

![](https://tva1.sinaimg.cn/large/0081Kckwly1gkuxhu6ajyj30nk0d7myn.jpg)

`HotModuleReplacementPlugin`如何做到的？这需要你对`tapable`以及`plugin`机制有一定了解

## moudle.hot.check 开始热更新

通过第 6 步，我们就可以知道`moudle.hot.check`方法是如何来的啦。那都做了什么？之后的源码都是`HotModuleReplacementPlugin`塞入到`bundle.js`中的

1. 利用`上一次保存的hash值`，调用`hotDownloadManifest`发送`xxx/hash.hot-update.json`的ajax请求；
2. 请求结果获取热`更新模块`，以及`下次热更新的Hash标识`，并进入热更新准备阶段。

```js
hotAvailableFilesMap = update.c; // 需要更新的文件
hotUpdateNewHash = update.h; // 更新下次热更新hash值
hotSetStatus("prepare"); // 进入热更新准备状态
```

3. 调用`hotDownloadUpdateChunk`发送`xxx/hash.hot-update.js`请求，通过`JSONP`方式。

```js
function hotDownloadUpdateChunk(chunkId) {
    var script = document.createElement("script");
    script.charset = "utf-8";
    script.src = __webpack_require__.p + "" + chunkId + "." + hotCurrentHash + ".hot-update.js";
    if (null) script.crossOrigin = null;
    document.head.appendChild(script);
}
```

这个函数体为什么要单独拿出来，因为这里要解释下为什么使用JSONP获取最新代码？主要是因为JSONP获取的代码可以直接执行。为什么要直接执行？我们来回忆下`/hash.hot-update.js`的代码格式是怎么样的。

![](https://cdn.liujiefront.com/images/webpack/s8yu5.png)

可以发现，新编译后的代码是在一个`webpackHotUpdate`函数体内部的。也就是要立即执行`webpackHotUpdate`这个方法。
再看下`webpackHotUpdate`这个方法。
```js
window["webpackHotUpdate"] = function (chunkId, moreModules) {
    hotAddUpdateChunk(chunkId, moreModules);
};
```
`hotAddUpdateChunk`方法会把更新的模块`moreModules`赋值给全局全量`hotUpdate`。
`hotUpdateDownloaded`方法会调用`hotApply`进行代码的替换。

```js
function hotAddUpdateChunk(chunkId, moreModules) {
    // 更新的模块moreModules赋值给全局全量hotUpdate
    for (var moduleId in moreModules) {
        if (Object.prototype.hasOwnProperty.call(moreModules, moduleId)) {
	    hotUpdate[moduleId] = moreModules[moduleId];
        }
    }
    // 调用hotApply进行模块的替换
    hotUpdateDownloaded();
}
```

## hotApply 热更新模块替换

1. 删除过期的模块，就是需要替换的模块
2. 将新的模块添加到 modules 中
3. 通过`__webpack_require__`执行相关模块的代码

# 总结

![](https://cdn.liujiefront.com/images/webpack/3w8ps.png)

文章转载自[轻松理解webpack热更新原理](https://juejin.cn/post/6844904008432222215)

