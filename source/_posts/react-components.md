---
title: React 组件间通讯
date: 2018-01-17 15:58:53
tags:
- react
- 前端
---

说 React 组件间通讯之前，我们先来讨论一下 React 组件究竟有多少种层级间的关系。假设我们开发的项目是一个纯 React 的项目，那我们项目应该有如下类似的关系：
![](https://cdn.liujiefront.com/images/react-component/react.png)
<!-- more -->

父子：Parent 与 Child_1、Child_2、Child_1_1、Child_1_2、Child_2_1

兄弟：Child_1 与 Child_2、Child_1_1 与 Child_2、etc.

针对这些关系，我们将来好好讨论一下这些关系间的通讯方式。

（在 React 中，React 组件之间的关系为从属关系，与 DOM 元素之间的父子关系有所不同，下面只是为了说明方便，将 React 组件的关系类比成父子关系进行阐述）

## 父组件向子组件通讯

通讯是单向的，数据必须是由一方传到另一方。在 React 中，父组件可以向子组件通过传 `props` 的方式，向子组件进行通讯。

``` js
class Parent extends Component{
  state = {
    msg: 'start'
  };

  componentDidMount() {
    setTimeout(() => {
      this.setState({
        msg: 'end'
      });
    }, 1000);
  }

  render() {
    return <Child_1 msg={this.state.msg} />;
  }
}

class Child_1 extends Component{
  render() {
    return <p>{this.props.msg}</p>
  }
}
```

如果父组件与子组件之间不止一个层级，如 Parent 与 Child_1_1 这样的关系，可通过 `... 运算符`（`Object` 剩余和展开属性），将父组件的信息，以更简洁的方式传递给更深层级的子组件。通过这种方式，不用考虑性能的问题，通过 `babel` 转义后的 `...` 运算符 性能和原生的一致，且上级组件 `props` 与 `state` 的改变，会导致组件本身及其子组件的生命周期改变

``` js
// 通过 ... 运算符 向 Child_1_1 传递 Parent 组件的信息
class Child_1 extends Component{
  render() {
    return <div>
      <p>{this.props.msg}</p>
      <Child_1_1 {...this.props}/>
    </div>
  }
}

class Child_1_1 extends Component{
  render() {
    return <p>{this.props.msg}</p>
  }
}
```

## 子组件向父组件通讯

在上一个例子中，父组件可以通过传递 `props` 的方式，自顶而下向子组件进行通讯。而子组件向父组件通讯，同样也需要父组件向子组件传递 `props` 进行通讯，只是父组件传递的，是作用域为父组件自身的函数，子组件调用该函数，将子组件想要传递的信息，作为参数，传递到父组件的作用域中。

``` js
class Parent extends Component{
  state = {
    msg: 'start'
  };

  transferMsg(msg) {
    this.setState({
      msg
    });
  }

  render() {
    return <div>
        <p>child msg: {this.state.msg}</p>
        <Child_1 transferMsg = {msg => this.transferMsg(msg)} />
      </div>;
  }
}

class Child_1 extends Component{
  componentDidMount() {
    setTimeout(() => {
      this.props.transferMsg('end')
    }, 1000);
  }

  render() {
    return <div>
      <p>child_1 component</p>
    </div>
  }
}
```
在上面的例子中，我们使用了 箭头函数，将父组件的 `transferMsg` 函数通过 props 传递给子组件，得益于箭头函数，保证子组件在调用 `transferMsg` 函数时，其内部 this 仍指向父组件。

当然，对于层级比较深的子组件与父组件之间的通讯，仍可使用 `...` 运算符，将父组件的调用函数传递给子组件，具体方法和上面的例子类似。

## 兄弟组件间通讯
对于没有直接关联关系的两个节点，就如 Child_1 与 Child_2 之间的关系，他们唯一的关联点，就是拥有相同的父组件。参考之前介绍的两种关系的通讯方式，如果我们向由 Child_1 向 Child_2 进行通讯，我们可以先通过 Child_1 向 Parent 组件进行通讯，再由 Parent 向 Child_2 组件进行通讯，所以有以下代码。

``` js
class Parent extends Component{
  state = {
    msg: 'start'
  };

  transferMsg(msg) {
    this.setState({
      msg
    });
  }

  componentDidUpdate() {
    console.log('Parent update');
  }

  render() {
    return (
      <div>
        <Child_1 transferMsg = {msg => this.transferMsg(msg)} />
        <Child_2 msg = {this.state.msg} />
      </div>
    );
  }
}

class Child_1 extends Component{
  componentDidMount() {
    setTimeout(() => {
      this.props.transferMsg('end')
    }, 1000);
  }

  componentDidUpdate() {
    console.log('Child_1 update');
  }

  render() {
    return <div>
      <p>child_1 component</p>
    </div>
  }
}

class Child_2 extends Component{
  componentDidUpdate() {
    console.log('Child_2 update');
  }

  render() {
    return <div>
      <p>child_2 component: {this.props.msg}</p>
      <Child_2_1 />
    </div>
  }
}

class Child_2_1 extends Component{
  componentDidUpdate() {
    console.log('Child_2_1 update');
  }

  render() {
    return <div>
      <p>child_2_1 component</p>
    </div>
  }
}
```
然而，这个方法有一个问题，由于 Parent 的 `state` 发生变化，会触发 Parent 及从属于 Parent 的子组件的生命周期，所以我们在控制台中可以看到，在各个组件中的 `componentDidUpdate` 方法均被触发。
![](https://cdn.liujiefront.com/images/react-component/react-2.png)
有没有更好的解决方式来进行兄弟组件间的通讯，甚至是父子组件层级较深的通讯的呢？

## 观察者模式

在传统的前端解耦方面，观察者模式作为比较常见一种设计模式，大量使用在各种框架类库的设计当中。即使我们在写 React，在写 JSX，我们核心的部分还是 JavaScript。

观察者模式也叫 发布者-订阅者模式，发布者发布事件，订阅者监听事件并做出反应，对于上面的代码，我们引入一个小模块，使用观察者模式进行改造。

``` js
import eventProxy from '../eventProxy'

class Parent extends Component{
  render() {
    return (
      <div>
        <Child_1/>
        <Child_2/>
      </div>
    );
  }
}
// componentDidUpdate 与 render 方法与上例一致
class Child_1 extends Component{
  componentDidMount() {
    setTimeout(() => {
      // 发布 msg 事件
      eventProxy.trigger('msg', 'end');
    }, 1000);
  }
}
// componentDidUpdate 方法与上例一致
class Child_2 extends Component{
  state = {
    msg: 'start'
  };

  componentDidMount() {
  	// 监听 msg 事件
    eventProxy.on('msg', (msg) => {
      this.setState({
        msg
      });
    });
  }

  render() {
    return <div>
      <p>child_2 component: {this.state.msg}</p>
      <Child_2_1 />
    </div>
  }
}
```
我们在 child_2 组件的 `componentDidMount` 中订阅了 msg 事件，并在 child_1 `componentDidMount` 中，在 1s 后发布了 msg 事件，child_2 组件对 msg 事件做出相应，更新了自身的 `state`，我们可以看到，由于在整个通讯过程中，只改变了 child_2 的 `state`，因而只有 child_2 和 child_2_1 出发了一次更新的生命周期。
![](https://cdn.liujiefront.com/images/react-component/react-3.png)

而上面代码中，神奇的 eventProxy.js 究竟是怎样的一回事呢？

``` js
// eventProxy.js
'use strict';
const eventProxy = {
  onObj: {},
  oneObj: {},
  on: function(key, fn) {
    if(this.onObj[key] === undefined) {
      this.onObj[key] = [];
    }

    this.onObj[key].push(fn);
  },
  one: function(key, fn) {
    if(this.oneObj[key] === undefined) {
      this.oneObj[key] = [];
    }

    this.oneObj[key].push(fn);
  },
  off: function(key) {
    this.onObj[key] = [];
    this.oneObj[key] = [];
  },
  trigger: function() {
    let key, args;
    if(arguments.length == 0) {
      return false;
    }
    key = arguments[0];
    args = [].concat(Array.prototype.slice.call(arguments, 1));

    if(this.onObj[key] !== undefined
      && this.onObj[key].length > 0) {
      for(let i in this.onObj[key]) {
        this.onObj[key][i].apply(null, args);
      }
    }
    if(this.oneObj[key] !== undefined
      && this.oneObj[key].length > 0) {
      for(let i in this.oneObj[key]) {
        this.oneObj[key][i].apply(null, args);
        this.oneObj[key][i] = undefined;
      }
      this.oneObj[key] = [];
    }
  }
};

export default eventProxy;
```

eventProxy 中，总共有 on、one、off、trigger 这 4 个函数：

1. on、one：on 与 one 函数用于订阅者监听相应的事件，并将事件响应时的函数作为参数，on 与 one 的唯一区别就是，使用 one 进行订阅的函数，只会触发一次，而 使用 on 进行订阅的函数，每次事件发生相应时都会被触发。
2. trigger：trigger 用于发布者发布事件，将除第一参数（事件名）的其他参数，作为新的参数，触发使用 one 与 on 进行订阅的函数。
3. off：用于解除所有订阅了某个事件的所有函数。

## Flux 与 Redux

`Flux` 作为 Facebook 发布的一种应用架构，他本身是一种模式，而不是一种框架，基于这个应用架构模式，在开源社区上产生了众多框架，其中最受欢迎的就是我们即将要说的 Redux。更多关于 Flux 和 Redux 的介绍这里就不一一展开，有兴趣的同学可以好好看看 Flux 官方介绍、Flux 架构入门教程–阮一峰等相关资料。
下面将来好好聊聊 Redux 在组件间通讯的方式。

Flux 需要四大部分组成：`Dispatcher`、`Stores`、`Views/Controller-Views`、`Actions`，其中的 `Views/Controller-Views` 可以理解为我们上面所说的 `Parent` 组件，其作用是从 state 当中获取到相应的数据，并将其传递给他的子组件（descendants）。而另外 3 个部分，则是由 Redux 来提供了。

``` js
// 该例子主要对各组件的 componentDidMount 进行改造，其余部分一致
import {createStore} from 'redux'

function reducer(state = {}, action) {
  return action;
}

let store = createStore(reducer);

class Child_1 extends Component{
  componentDidMount() {
    setTimeout(() => {
      store.dispatch({
        type: 'child_2',
        data: 'hello'
      })
    }, 1000);

    setTimeout(() => {
      store.dispatch({
        type: 'child_2_1',
        data: 'bye'
      })
    }, 2000);
  }
}

class Child_2 extends Component{
  state = {
    msg: 'start'
  };

  componentDidUpdate() {
    console.log('Child_2 update', store.getState());
  }

  componentDidMount() {
    store.subscribe(() => {
      let state = store.getState();
      if (state.type === 'child_2') {
        this.setState({
          msg: state.data
        });
      }
    });
  }
}

class Child_2_1 extends Component{
  state = {
    msg: 'start'
  };

  componentDidUpdate() {
    console.log('Child_2_1 update', store.getState());
  }


  componentDidMount() {
    store.subscribe(() => {
      let state = store.getState();
      if (state.type === 'child_2_1') {
        this.setState({
          msg: state.data
        });
      }
    });
  }

  render() {
    return <div>
      <p>child_2_1 component: {this.state.msg}</p>
    </div>
  }
}
```

在上面的例子中，我们将一个名为 `reducer` 的函数作为参数，生成我们所需要的 `store`，`reducer` 接受两个参数，一个是存储在 `store` 里面的 `state`，另一个是每一次调用 `dispatch` 所传进来的 `action`。`reducer` 的作用，就是对 `dispatch` 传进来的 `action` 进行处理，并将结果返回。而里面的 `state` 可以通过 `store` 里面的 `getState` 方法进行获得，其结果与最后一次通过 `reducer` 处理后的结果保持一致。

在 child_1 组件中，我们每隔 1s 通过 `store` 的 `dispatch` 方法，向 `store` 传入包含有 `type` 字段的 `action`，`reducer` 直接将 `action` 进行返回。

而在 child_2 与 child_2_1 组件中，通过 `store` 的 `subscribe` 方法，监听 `store` 的变化，触发 `dispatch` 后，所有通过 `subscribe` 进行监听的函数都会作出相应，根据当前通过 `store.getState()` 获取到的结果进行处理，对当前组件的 `state` 进行设置。所以我们可以在控制台上看到各个组件更新及存储在 `store` 中 `state` 的情况：

![](https://cdn.liujiefront.com/images/react-component/react-4.png)

在 Redux 中，`store` 的作用，与 MVC 中的 Model 类似，可以将我们项目中的数据传递给 `store`，交给 `store` 进行处理，并可以实时通过 `store.getState()` 获取到存储在 `store` 中的数据。我们对上面例子的 `reducer` 及各个组件的 `componentDidMount` 做点小修改，看看 `store` 的这一个特性。

``` js
import {createStore} from 'redux'

function reducer(state = {}, action) {
  switch (action.type) {
    case 'child_2':
      state.child_2 = action.data + ' child_2';
      return state;
    case 'child_2_1':
      state.child_2_1 = action.data + ' child_2_1';
      return state;
    default:
      return state
  }
}

let store = createStore(reducer);

class Child_1 extends Component{
  componentDidMount() {
    setTimeout(() => {
      store.dispatch({
        type: 'child_2',
        data: 'hello'
      })
    }, 1000);

    setTimeout(() => {
      store.dispatch({
        type: 'child_2_1',
        data: 'bye'
      })
    }, 2000);
  }
}

class Child_2 extends Component{
  componentDidMount() {
    store.subscribe(() => {
      let state = store.getState();

      if (state.hasOwnProperty('child_2')) {
        this.setState({
          msg: state.child_2
        });
      }
    });
  }
}

class Child_2_1 extends Component{
  componentDidMount() {
    store.subscribe(() => {
      let state = store.getState();

      if (state.hasOwnProperty('child_2_1')) {
        this.setState({
          msg: state.child_2_1
        });
      }
    });
  }
}
```

我们对创建 `store` 时所传进去的 `reducer` 进行修改。`reducer` 中，其参数 `state` 为当前 `store` 的值，我们对不同的 `action` 进行处理，并将处理后的结果存储在 `state` 中并进行返回。此时，通过 `store.getState()` 获取到的，就是我们处理完成后的 `state`。

![](https://cdn.liujiefront.com/images/react-component/react-5.png)

Redux 内部的实现，其实也是基于观察者模式的，`reducer` 的调用结果，存储在 `store` 内部的 `state` 中，并在每一次 `reducer` 的调用中并作为参数传入。所以在 child_1 组件第 2s 的 dispatch 后，child_2 与 child_2_1 组件通过 `subscribe` 监听的函数，其通过 `getState` 获得的值，都包含有 child_2 与 child_2_1 字段的，这就是为什么第 2s 后的响应，child_2 也进行了一次生命周期。所以在对 `subscribe` 响应后的处理，最好还是先校对通过 `getState()` 获取到的 `state` 与当前组件的 `state` 是否相同。

``` js
// child_2
 componentDidMount() {
    store.subscribe(() => {
      let state = store.getState();

      if (state.hasOwnProperty('child_2')
        && state.child_2 !== this.state.msg) {
        this.setState({
          msg: state.child_2
        });
      }
    });
  }
  ```

加上这样的校验，各个组件的生命周期的触发就符合我们的预期了。

![](https://cdn.liujiefront.com/images/react-component/react-6.png)

## 小结

Redux 对于组件间的解耦提供了很大的便利，如果你在考虑该不该使用 Redux 的时候，社区里有一句话说，“当你不知道该不该使用 Redux 的时候，那就是不需要的”。Redux 用起来一时爽，重构或者将项目留给后人的时候，就是个大坑，Redux 中的 `dispatch` 和 `subscribe` 方法遍布代码的每一个角落。刚刚的例子不是最好的，Flux 设计中的 Controller-Views 概念就是为了解决这个问题出发的，将所有的 `subscribe` 都置于 Parent 组件（Controller-Views），由最上层组件控制下层组件的表现，然而，这不就是我们所说的 `子组件向父组件通讯` 这种方式了。

