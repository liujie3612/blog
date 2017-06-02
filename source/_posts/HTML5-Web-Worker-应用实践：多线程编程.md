---
title: HTML5 Web Worker 应用实践：多线程编程
date: 2017-06-01 21:44:21
tags: 
- HTML5
- Web Workers
---

## HTML5 中工作线程（Web Worker）简介
至 2008 年 W3C 制定出第一个 HTML5 草案开始，HTML5 承载了越来越多崭新的特性和功能。它不但强化了 Web 系统或网页的表现性能，而且还增加了对本地数据库等 Web 应用功能的支持。其中，最重要的一个便是对多线程的支持。在 HTML5 中提出了工作线程（Web Worker）的概念，并且规范出 Web Worker 的三大主要特征：能够长时间运行（响应），理想的启动性能以及理想的内存消耗。
<!--more-->Web Worker 允许开发人员编写能够长时间运行而不被用户所中断的后台程序，去执行事务或者逻辑，并同时保证页面对用户的及时响应。本文深入 HTML5 多线程规范，讲述多线程实现原理、方法，同时以实例的形式讲解 HTML5 中多线程编程以及应用。
W3C 中的工作线程规范到目前为止已经定义了出了一系列公共接口，它允许 Web 程序开发人员去创建后台线程在他们的主页面中并发的运行脚本。这将使得线程级别的消息通信成为现实。


## 详解 HTML5 工作线程原理
传统上的线程可以解释为轻量级进程，它和进程一样拥有独立的执行控制，一般情况下由操作系统负责调度。而在 HTML5 中的多线程是这样一种机制，它允许在 Web 程序中并发执行多个 JavaScript 脚本，每个脚本执行流都称为一个线程，彼此间互相独立，并且有浏览器中的 JavaScript 引擎负责管理。下面我们将详细讲解 HTML5 的工作线程原理。

### 工作线程与多线程编程
在 HTML5 中，工作线程的出现使得在 Web 页面中进行多线程编程成为可能。众所周知，传统页面中（HTML5 之前）的 JavaScript 的运行都是以单线程的方式工作的，虽然有多种方式实现了对多线程的模拟（例如：JavaScript 中的 setinterval 方法，setTimeout 方法等），但是在本质上程序的运行仍然是由 JavaScript 引擎以单线程调度的方式进行的。在 HTML5 中引入的工作线程使得浏览器端的 JavaScript 引擎可以并发地执行 JavaScript 代码，从而实现了对浏览器端多线程编程的良好支持。
HTML5 中的 Web Worker 可以分为两种不同线程类型，一个是专用线程 Dedicated Worker，一个是共享线程 Shared Worker。两种类型的线程各有不同的用途。下面对这两种工作线程作了详细的说明和描述。

### 专用线程：Dedicated Worker

1. 专用线程（dedicated worker）的创建方式：
在创建专用线程的时候，需要给 Worker 的构造函数提供一个指向 JavaScript 文件资源的 URL，这也是创建专用线程时 Worker 构造函数所需要的唯一参数。当这个构造函数被调用之后，一个工作线程的实例便会被创建出来。下面是创建专用线程代码示例：
创建专用线程示例代码
```
var worker = new Worker('dedicated.js');
```

2. 与一个专用线程通信：
专用线程在运行的过程中会在后台使用 MessagePort 对象，而 MessagePort 对象支持 HTML5 中多线程提供的所有功能，例如：可以发送和接受结构化数据（JSON 等），传输二进制数据，并且支持在不同端口中传输数据等。
为了在页面主程序接收从专用线程传递过来的消息，我们需要使用工作线程的 onmessage 事件处理器，定义 onmessage 的实例代码如下：
接收来至工作线程示例代码
```
worker.onmessage = function (event) { ... };
```
另外，开发人员也可以选择使用 addEventListener 方法，它最终的实现方式和作用和 onmessage 相同。

就像前面讲述的，专用线程会使用隐式的 MessagePort 实例，当专用线程被创建的时候，MessagePort 的端口消息队列便被主动启用。因此，这也和工作线程接口中定义的 start 方法作用一致。

如果要想一个专用线程发送数据，那么我们需要使用线程中的 postMessage 方法。专用线程不仅仅支持传输二进制数据，也支持结构化的 JavaScript 数据格式。在这里有一点需要注意，为了高效地传输 ArrayBuffer 对象数据，需要在 postMessage 方法中的第二个参数中指定它。实例代码如下：
高效的发送 ArrayBuffer 数据代码
```
worker.postMessage({ 
 operation: 'list_all_users', 
 //ArrayBuffer object 
 input: buffer, 
 threshold: 0.8, 
}, [buffer]);
```

### 共享线程 Shared Worker
1. 共享线程
共享线程可以由两种方式来定义：一是通过指向JavaScript脚本资源的URL来创建，而是通过显式的名称。当由显式的名称来定义的时候，由创建这个共享线程的第一个页面中使用 URL 会被用来作为这个共享线程的 JavaScript 脚本资源URL。通过这样一种方式，它允许同域中的多个应用程序使用同一个提供公共服务的共享线程，从而不需要所有的应用程序都去与这个提供公共服务的 URL 保持联系。

无论在什么情况下，共享线程的作用域或者是生效范围都是由创建它的域来定义的。因此，两个不同的站点（即域）使用相同的共享线程名称也不会冲突。

2. 共享线程的创建
创建共享线程可以通过使用 SharedWorker() 构造函数来实现，这个构造函数使用 URL 作为第一个参数，即是指向 JavaScript 资源文件的 URL，同时，如果开发人员提供了第二个构造参数，那么这个参数将被用于作为这个共享线程的名称。创建共享线程的代码示例如下：
```
var worker = new SharedWorker('sharedworker.js', ’ mysharedworker ’ );
```
3. 与共享线程通信
共享线程的通信也是跟专用线程一样，是通过使用隐式的 MessagePort 对象实例来完成的。当使用 SharedWorker() 构造函数的时候，这个对象将通过一种引用的方式被返回回来。我们可以通过这个引用的 port 端口属性来与它进行通信。发送消息与接收消息的代码示例如下：
发送消息与接收消息代码
```
// 从端口接收数据 , 包括文本数据以及结构化数据
1. worker.port.onmessage = function (event) { define your logic here... }; 
// 向端口发送普通文本数据
2. worker.port.postMessage('put your message here … '); 
// 向端口发送结构化数据
3. worker.port.postMessage({ username: 'usertext'; live_city: 
['data-one', 'data-two', 'data-three','data-four']});
```
上面示例代码中，第一个我们使用 onmessage 事件处理器来接收消息，第二个使用 postMessage 来发送普通文本数据，第三个使用 postMessage 来发送结构化的数据，这里我们使用了 JSON 数据格式。

### 工作线程事件处理模型
当工作线程被一个具有 URL 参数的构造函数创建的时候，它需要有一系列的处理流程来处理和记录它本身的数据和状态。下面我们给出了工作线程的处理模型如下（注：由于 W3C 中工作线程的规范依然在更新，您读到这篇文章的时候可能看到已不是最新的处理模型，建议参考 W3C 中的最新规范）：
1. 创建一个独立的并行处理环境，并且在这个环境里面异步的运行下面的步骤。
2. 如果它的全局作用域是 SharedWorkerGlobalScope 对象，那么把最合适的应用程序缓存和它联系在一起。
3. 尝试从它提供的 URL 里面使用 synchronous 标志和 force same-origin 标志获取脚本资源。
4. 新脚本创建的时候会按照下面的步骤：
创建这个脚本的执行环境。
使用脚本的执行环境解析脚本资源。
设置脚本的全局变量为工作线程全局变量。
设置脚本编码为 UTF-8 编码。
5. 启动线程监视器，关闭孤儿线程。
6. 对于挂起线程，启动线程监视器监视挂起线程的状态，即时在并行环境中更改它们的状态。
7. 跳入脚本初始点，并且启动运行。
8. 如果其全局变量为 DedicatedWorkerGlobalScope 对象，然后在线程的隐式端口中启用端口消息队列。
9. 对于事件循环，等待一直到事件循环列表中出现新的任务。
10. 首先运行事件循环列表中的最先进入的任务，但是用户代理可以选择运行任何一个任务。
11. 如果事件循环列表拥有存储 mutex 互斥信号量，那么释放它。
12. 当运行完一个任务后，从事件循环列表中删除它。
13. 如果事件循环列表中还有任务，那么继续前面的步骤执行这些任务。
14. 如果活动超时后，清空工作线程的全局作用域列表。
15. 释放工作线程的端口列表中的所有端口。

### 工作线程应用范围和作用域
工作线程的全局作用域仅仅限于工作线程本身，即在线程的生命周期内有效。规范中 WorkerGlobalScope 接口代表了它的全局作用域，下面我们来看下这个接口的具体实施细节（WorkerGlobalScope 抽象接口）。
WorkerGlobalScope 抽象接口代码
```
interface WorkerGlobalScope { 
 readonly attribute WorkerGlobalScope self; 
 readonly attribute WorkerLocation location; 
 
 void close(); 
          attribute Function onerror; 
}; 
WorkerGlobalScope implements WorkerUtils; 
WorkerGlobalScope implements EventTarget;
```
我们可以使用 WorkerGlobalScope 的 self 属性来或者这个对象本身的引用。location 属性返回当线程被创建出来的时候与之关联的 WorkerLocation 对象，它表示用于初始化这个工作线程的脚步资源的绝对 URL，即使页面被多次重定向后，这个 URL 资源位置也不会改变。
当脚本调用 WorkerGlobalScope 上的 close()方法后，会自动的执行下面的两个步骤：
1. 删除这个工作线程事件队列中的所有任务。
2. 设置 WorkerGlobalScope 对象的 closing 状态为 true （这将阻止以后任何新的任务继续添加到事件队列中来）。

### 工作线程生命周期
工作线程之间的通信必须依赖于浏览器的上下文环境，并且通过它们的 MessagePort 对象实例传递消息。每个工作线程的全局作用域都拥有这些线程的端口列表，这些列表包括了所有线程使用到的 MessagePort 对象。在专用线程的情况下，这个列表还会包含隐式的 MessagePort 对象。
每个工作线程的全局作用域对象 WorkerGlobalScope 还会有一个工作线程的线程列表，在初始化时这个列表为空。当工作线程被创建的时候或者拥有父工作线程的时候，它们就会被填充进来。
最后，每个工作线程的全局作用域对象 WorkerGlobalScope 还拥有这个线程的文档模型，在初始化时这个列表为空。当工作线程被创建的时候，文档对象就会被填充进来。无论何时当一个文档对象被丢弃的时候，它就要从这个文档对象列举里面删除出来。
在工作线程的生命周期中，定义了下面四种不同类型的线程名称，用以标识它们在线程的整个生命周期中的不同状态：
* 当一个工作线程的文档对象列举不为空的时候，这个工作线程会被称之为许可线程。（A worker is said to be a permissible worker if its list of the worker's Documents is not empty.）
* 当一个工作线程是许可线程并且或者拥有数据库事务或者拥有网络连接或者它的工作线程列表不为空的时候，这个工作线程会被称之为受保护的线程。（A worker is said to be a protected worker if it is a permissible worker and either it has outstanding timers, database transactions, or network connections, or its list of the worker's ports is not empty）
* 当一个工作线程的文档对象列表中的任何一个对象都是处于完全活动状态的时候，这个工作线程会被称之为需要激活线程。（A worker is said to be an active needed worker if any of the Document objects in the worker's Documents are fully active.）
* 当一个工作线程是一个非需要激活线程同时又是一个许可线程的时候，这个工作线程会被称之为挂起线程。（A worker is said to be a suspendable worker if it is not an active needed worker but it is a permissible worker.）
由于 W3C 的 Web Worker 规范目前还是处于完善阶段，没有形成最终的规范，本文也将上面线程的四种不同状态的原文定义附在了后面。

## 工作线程（Web Worker）API 接口
### 类库和脚本的访问和引入
对于类库和脚本的访问和引入，规范中规定可以使用 WorkerGlobalScope 对象的 importScripts(urls) 方法来引入网络中的脚本资源。当用户调用这个方法引入资源的时候会执行下面的步骤来完成这个操作：
1. 如果没有给 importScripts 方法任何参数，那么立即返回，终止下面的步骤。
2. 解析 importScripts 方法的每一个参数。
3. 如果有任何失败或者错误，抛出 SYNTAX_ERR 异常。
4. 尝试从用户提供的 URL 资源位置处获取脚本资源。
5. 对于 importScripts 方法的每一个参数，按照用户的提供顺序，获取脚本资源后继续进行其它操作。
外部资源脚本引入和访问示例代码
```
/** 
 * 使用 importScripts 方法引入外部资源脚本，在这里我们使用了数学公式计算工具库 math_utilities.js 
 * 当 JavaScript 引擎对这个资源文件加载完毕后，继续执行下面的代码。同时，下面的的代码可以访问和调用
 * 在资源文件中定义的变量和方法。
 **/ 
 importScripts('math_utilities.js'); 
 
 /** 
 * This worker is used to calculate 
 * the least common multiple 
 * and the greatest common divisor 
 */ 
 onmessage = function (event) 
 { 
 var first=event.data.first; 
 var second=event.data.second; 
 calculate(first,second); 
 }; 
 
 
 /* 
 * calculate the least common multiple 
 * and the greatest common divisor 
 */ 
 function calculate(first,second) { 
    //do the calculation work 
 var common_divisor=divisor(first,second); 
 var common_multiple=multiple(first,second); 
    postMessage("Work done! " + 
"The least common multiple is "+common_divisor 
 +" and the greatest common divisor is "+common_multiple); 
 }
 ```

### 工作导航器对象（WorkerNavigator）
在 HTML5 中， WorkerUtils 接口的 navigator 属性会返回一个工作导航器对象（WorkerNavigator），这个对象定义并且代表了用户代理（即 Web 客户端）的标识和状态。因此，用户和 Web 脚本开发人员可以在多线程开发过程中通过这个对象来取得或者确定用户的状态。
1. 工作导航器对象（WorkerNavigator）
WorkerUtils 抽象接口的 navigator 属性会返回一个 WorkerNavigator 用户接口，用于用户代理的识别的状态标识。我们来看下 WorkerNavigator 接口的定义。
2. WorkerNavigator 接口定义
WorkerNavigator 接口定义代码
```
interface WorkerNavigator {}; 
WorkerNavigator implements NavigatorID; 
WorkerNavigator implements NavigatorOnLine;
```
其中，有一点需要注意：如果接口的相对命名空间对象为 Window 对象的时候，WorkerNavigator 对象一定不可以存在，即无法再使用这个对象。

### 创建与终止线程
在讲解创建新的工作线程之前，我们先看下 W3C 规范对工作线程的定义。工作线程规范中定义了线程的抽象接口类 AbstractWorker ，专用线程以及共享线程都继承自该抽象接口。专用线程以及共享线程的创建方法读者可以参考第一小节中的示例代码。下面是此抽象接口的定义。
1. AbstractWorker 抽象接口
AbstractWorker 抽象接口代码
```
[Supplemental, NoInterfaceObject] 
interface AbstractWorker { 
          attribute Function onerror; 
 
}; 
AbstractWorker implements EventTarget;
```
此外，该接口还定义了错误处理的事件处理器 onerror，当工作线程在通信过程中遇到错误时便会触发这个事件处理器。

2. 专用线程及其定义
专用线程定义代码
```
[Constructor(in DOMString scriptURL)] 
interface Worker : AbstractWorker { 
 void terminate(); 
 
 void postMessage(in any message, in optional MessagePortArray ports); 
          attribute Function onmessage; 
};
```
当创建完线程以后，我们可以调用 terminate() 方法去终止一个线程。每个专用线程都拥有一个隐式的 MessagePort 对象与之相关联。这个端口随着线程的创建而被创建出来，但并没有暴露给用户。所有的基于这个端口的消息接收都以线程本身为目标。

3. 共享线程及其定义
共享线程定义代码
```
[Constructor(DOMString scriptURL, optional DOMString name)] 
interface SharedWorker : AbstractWorker { 
readonly attribute MessagePort port; 
};
```
共享线程同专用线程一样，当创建完线程以后，我们可以调用 terminate() 方法去终止一个共享线程。

### 工作线程位置属性
工作线程被创建出来以后，需要记录它的状态以及位置信息，在工作线程规范中定义了 WorkerLocation 来表示它们的位置。接口定义如下：
共享线程定义代码
```
interface WorkerLocation { 
 // URL decomposition IDL attributes 
 stringifier readonly attribute DOMString href; 
 readonly attribute DOMString protocol; 
 readonly attribute DOMString host; 
 readonly attribute DOMString hostname; 
 readonly attribute DOMString port; 
 readonly attribute DOMString pathname; 
 readonly attribute DOMString search; 
 readonly attribute DOMString hash; 
};
```
WorkerLocation 对象表示了工作线程脚本资源的绝对 URL 信息。我们可以使用它的 href 属性取得这个对象的绝对 URL。WorkerLocation 接口还定义了与位置信息有关的其它属性，例如：用于信息传输的协议（protocol），主机名称（hostname），端口（port），路径名称（pathname）等。

## 工作线程（Web Worker）应用与实践
我们可以写出很多的例子来说明后台工作线程的合适的用法，下面我们以几种典型的应用场景为例，用代码实例的形式讲解在各种需求背景下正确的使用它们。
### 应用场景一：使用工作线程做后台数值（算法）计算
工作线程最简单的应用就是用来做后台计算，而这种计算并不会中断前台用户的操作。下面我们提供了一个工作线程的代码片段，用来执行一个相对来说比较复杂的任务：计算两个非常大的数字的最小公倍数和最大公约数。
在这个例子中，我们在主页面中创建一个后台工作线程，并且向这个工作线程分配任务（即传递两个特别大的数字），当工作线程执行完这个任务时，便向主页面程序返回计算结果，而在这个过程中，主页面不需要等待这个耗时的操作，可以继续进行其它的行为或任务。
我们把这个应用场景分为两个主要部分，一个是主页面，可以包含主 JavaScript 应用入口，用户其它操作 UI 等。另外一个是后台工作线程脚本，即用来执行计算任务。代码片段如下：
主程序页面代码
```
<!DOCTYPE HTML> 
<html> 
<head> 
<title> 
Background Worker Application Example 1: Complicated Number Computation 
</title> 
</head> 
<body> 
<div> 
The least common multiple and greatest common divisor is: 
<p id="computation_results">please wait, computing … </p> 
</div> 
 <script>
  var worker = new Worker('numberworker.js'); 
worker.postMessage("{first:347734080,second:3423744400}"); 
  worker.onmessage = function (event) 
{ 
 document.getElementById(' computation_result').textContent = event.data; 
}; 
 </script>
</body> 
</html>
```
后台工作线程代码
```
/** 
 * This worker is used to calculate 
 * the least common multiple 
 * and the greatest common divisor 
 */ 
 
 onmessage = function (event) 
 { 
 var first=event.data.first; 
 var second=event.data.second; 
 calculate(first,second); 
 }; 
 
 
 /* 
 * calculate the least common multiple 
 * and the greatest common divisor 
 */ 
 function calculate(first,second) { 
    //do the calculation work 
 var common_divisor=divisor(first,second); 
 var common_multiple=multiple(first,second); 
    postMessage("Work done! " + 
"The least common multiple is "+common_divisor 
 +" and the greatest common divisor is "+common_multiple); 
 } 
 
 
 
 /** 
 * calculate the greatest common divisor 
 * @param number 
 * @param number 
 * @return 
 */ 
 function divisor(a, b) { 
 if (a % b == 0) { 
 return b; 
 } else { 
 return divisor(b, a % b); 
 } 
 } 
 
 /** 
 * calculate the least common multiple 
 * @param number 
 * @param number 
 * @return 
 */ 
 function multiple( a,  b) { 
 var multiple = 0; 
 multiple = a * b / divisor(a, b); 
 return multiple; 
 }
 ```
在主程序页面中，我们使用 Worker()构造函数创建一个新的工作线程，它会返回一个代表此线程本身的线程对象。接下来我们使用这个线程对象与后台脚本进行通信。线程对象有两个主要事件处理器：postMessage 和 onmessage 。postMessage 用来向后台脚本发送消息，onmessage 用以接收从后台脚本中传递过来的消息。

在后台工作线程代码片段中，我们定一个两个 JavaScript 函数，一个是 function divisor：用以计算最大公约数，一个是 function multiple：用以计算最小公倍数。同时工作线程的 onmessage 事件处理器用以接收从主页面中传递过来的数值，然后把这两个数值传递到 function calculate 用以计算。当计算完成后，调用事件处理器 postMessage，把计算结果发送到主页面。

### 应用场景二：使用共享线程处理多用户并发连接
由于线程的构建以及销毁都要消耗很多的系统性能，例如 CPU 的处理器调度，内存的占用回收等，在一般的编程语言中都会有线程池的概念，线程池是一种对多线程并发处理的形式，在处理过程中系统将所有的任务添加到一个任务队列，然后在构建好线程池以后自动启动这些任务。处理完任务后再把线程收回到线程池中，用于下一次任务调用。线程池也是共享线程的一种应用。
在 HTML5 中也引入了共享线程技术，但是由于每个共享线程可以有多个连接，HTML5 对共享线程提供了和普通工作线程稍微有些区别的 API 接口。下面我们提供几个例子来讲述对共享线程的用法。
下面我们给出一个例子：创建一个共享线程用于接收从不同连接发送过来的指令，然后实现自己的指令处理逻辑，指令处理完成后将结果返回到各个不同的连接用户。
共享线程用户连接页面代码
```
<!DOCTYPE html> 
<html> 
<head> 
<meta charset="UTF-8"> 
<title>Shared worker example: how to use shared worker in HTML5</title> 
 
<script>
 var worker = new SharedWorker('sharedworker.js'); 
 var log = document.getElementById('response_from_worker'); 
 worker.port.addEventListener('message', function(e) { 
//log the response data in web page 
log.textContent =e.data; 
 }, false); 
 worker.port.start(); 
 worker.port.postMessage('ping from user web page..'); 
  
 //following method will send user input to sharedworker 
 function postMessageToSharedWorker(input) 
 { 
 //define a json object to construct the request 
 var instructions={instruction:input.value}; 
 worker.port.postMessage(instructions); 
 } 
</script>
 
</head> 
<body onload=''> 
<output id='response_from_worker'> 
Shared worker example: how to use shared worker in HTML5 
</output> 
send instructions to shared worker: 
<input type="text" autofocus oninput="postMessageToSharedWorker(this);return false;"> 
</input> 
</body> 
</html>
```
用于处理用户指令的共享线程代码
```
// 创建一个共享线程用于接收从不同连接发送过来的指令，指令处理完成后将结果返回到各个不同的连接用户。
 
/* 
* define a connect count to trace connecting 
* this variable will be shared within all connections 
*/ 
var connect_number = 0; 
 
onconnect = function(e) { 
 connect_number =connect_number+ 1; 
 //get the first port here 
 var port = e.ports[0]; 
 port.postMessage('A new connection! The current connection number is ' 
 + connect_number); 
 port.onmessage = function(e) { 
//get instructions from requester 
var instruction=e.data.instruction; 
var results=execute_instruction(instruction); 
   port.postMessage('Request: '+instruction+' Response '+results 
   +' from shared worker...'); 
 }; 
}; 
 
/* 
* this function will be used to execute the instructions send from requester 
* @param instruction 
* @return 
*/ 
function execute_instruction(instruction) 
{ 
var result_value; 
//implement your logic here 
//execute the instruction... 
return result_value 
}
```
在上面的共享线程例子中，在主页面即各个用户连接页面构造出一个共享线程对象，然后定义了一个方法 postMessageToSharedWorker 向共享线程发送来之用户的指令。同时，在共享线程的实现代码片段中定义 connect_number 用来记录连接到这个共享线程的总数。之后，用 onconnect 事件处理器接受来自不同用户的连接，解析它们传递过来的指令。最后，定义一个了方法 execute_instruction 用于执行用户的指令，指令执行完成后将结果返回给各个用户。

这里我们并没有跟前面的例子一样使用到了工作线程的 onmessage 事件处理器，而是使用了另外一种方式 addEventListener。实际上，这两种的实现原理基本一致，只有有些稍微的差别，如果使用到了 addEventListener 来接受来自共享线程的消息，那么就要使用 worker.port.start() 方法来启动这个端口。之后就可以像工作线程的使用方式一样正常的接收和发送消息。

### 应用场景三：HTML5 线程代理

#### 多线程代理技术
随着多核处理器的流行，现代的计算机一般都拥有多核的 CPU，这也使得任务能够在处理器级别上并发执行。如果我们要在一个具有多核 CPU 的客户端上用单线程去执行程序即处理业务逻辑，往往不能最大化的利用系统资源。因此，在这种情况下我们可以将一个耗时或者复杂的任务拆分成多个子任务，把每一个子任务分担给一个工作线程，这样多个工作现场就共同承担了单个线程的工作负载，同时又能够并发的去执行，最大化的利用了系统资源（CPU、内存、I/O 等）。
下面我们向读者提供一个线程代理应用的例子：计算全球人口的数量。
主页面（仅仅是用来显示计算结果）代码
```
<!DOCTYPE html> 
<html> 
<head> 
<meta charset="UTF-8"> 
<title>Shared worker example: how to use delegation worker in HTML5</title> 
 
<script>
 var worker = new SharedWorker('delegationworker.js'); 
 var log = document.getElementById('response_from_worker'); 
 worker.onmessage = function (event) { 
 //resolve the population from delegation worker 
 var resultdata=event.data; 
 var population=resultdata.total_population; 
 var showtext='The total population of the word is '+population; 
 document.getElementById('response_from_worker').textContent = showtext; 
 }; 
</script>
 
</head> 
<body onload=''> 
<output id='response_from_worker'> 
Shared worker example: how to use delegation worker in HTML5 
</output> 
</body> 
</html>
```
主工作线程代码
```
/* 
* define the country list in the whole word 
* take following Array as an example 
*/ 
var country_list = ['Albania','Algeria','American','Andorra','Angola','Antigua','....']; 
 
// define the variable to record the population of the word 
var total_population=0; 
var country_size=country_list.length; 
var processing_size=country_list.length; 
 
for (var i = 0; i < country_size; i++) 
{ 
 var worker = new Worker('subworker.js'); 
 //wrap the command, send to delegations 
 var command={command:'start',country:country_list[i]}; 
 worker.postMessage(command); 
 worker.onmessage = update_results; 
} 
 
/* 
* this function will be used to update the result 
* @param event 
* @return 
*/ 
 
function storeResult(event) 
{ 
total_population += event.data; 
processing_size -= 1; 
if (processing_size <= 0) 
{ 
//complete the whole work, post results to web page 
postMessage(total_population); 
} 
}
```
代理线程代码
```
//define the onmessage hander for the delegation 
onmessage = start_calculate; 
 
/* 
* resolve the command and kick off the calculation 
*/ 
function start_calculate(event) 
{ 
var command=event.data.command; 
if(command!=null&&command=='start') 
{ 
var coutry=event.data.country; 
do_calculate(country); 
} 
onmessage = null; 
} 
 
/* 
* the complex calculation method defined here 
* return the population of the country 
*/ 
function do_calculate(country) 
{ 
 var population = 0; 
 var cities=//get all the cities for this country 
 for (var i = 0; i < cities.length; i++) 
 { 
 var city_popu=0; 
     // perform the calculation for this city 
 //update the city_popu 
 population += city_popu; 
 } 
 postMessage(population); 
 close(); 
}
```
## 总结
HTML5 Web Worker 的多线程特性为基于 Web 系统开发的程序人员提供了强大的并发程序设计功能，它允许开发人员设计开发出性能和交互更好的富客户端应用程序。本文不仅仅详细讲述 HTML5 中的多线程规范。同时，也以几种典型的应用场景为例，以实例的形式讲解 HTML5 中多线程编程以及应用，为用户提供了详细而全面的参考价值，并且指导开发人员设计和构建更为高效和稳定的 Web 多线程应用。