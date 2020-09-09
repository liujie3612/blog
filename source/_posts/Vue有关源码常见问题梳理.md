---
title: Vue有关源码常见问题梳理(1)
date: 2020-08-13 17:13:08
tags:
  - vue
  - 源码解析
  - 面试
categories: vue常见问题梳理
---

# v-for中为什么要用key

![](https://cdn.liujiefront.com/images/vue-source/zwkos.png)

<!-- more -->

## 什么是diff算法？

```html
<ul>
  <li>1</li>
  <li>2</li>
</ul>
```

有这样的一个 dom 节点，那个这个节点表示的 vnode 是这样的：

```javascript
{
  tag: 'ul',
  children: [
    { tag: 'li', children: [ { vnode: { text: '1' }}]  },
    { tag: 'li', children: [ { vnode: { text: '2' }}]  },
  ]
}
```

假设我们现在要交换`li`的位置,那么 vnode 就会变为这样：

```javascript
{
  "tag": "ul",
  "children": [
    +{ "tag": "li", "children": [{ "vnode": { "text": "2" } }] },
    +{ "tag": "li", "children": [{ "vnode": { "text": "1" } }] }
  ]
}
```

可以看出`children`的部分就是要 diff 的重点了。

在讲正文之前，我们先梳理下 diff 算法的过程。

1. 响应式数据更新后，触发了 `渲染 Watcher` 的回调函数 `vm._update(vm._render())`去驱动视图更新
2. `vm._render()` 其实生成的就是 `vnode`，而 `vm._update` 就会带着新的 `vnode` 去走触发 `vm.__patch__` 过程
3. `__patch__`会调用`patch`函数: 因为这里是更新数据，和首次渲染有所差别的是`oldVnode`不为空，接下来会执行`sameVNode(oldVnode, vnode)`，这里根据`VNode`是否相同来决定不同的更新逻辑。

```javascript
function sameVnode(a, b) {
  return (
    a.key === b.key &&
    ((a.tag === b.tag &&
      a.isComment === b.isComment &&
      isDef(a.data) === isDef(b.data) &&
      sameInputType(a, b)) ||
      (isTrue(a.isAsyncPlaceholder) &&
        a.asyncFactory === b.asyncFactory &&
        isUndef(b.asyncFactory.error)))
  );
}
```

`sameVnode` 的逻辑比较简单，如果两个 `vnode` 的 `key` 不相等，则是不同的；

4. 对于新旧节点不一样的话，大概分为三步：

   1. 创建新节点：以当前旧节点为参考节点，创建新的节点，并插入到 DOM 中，调用`createElm` 的逻辑;
   2. 更新父的占位符节点：找到当前 `vnode` 的父的占位符节点，先执行各个 `module` 的 `destroy` 的钩子函数，如果当前占位符是一个可挂载的节点，则执行 `module` 的 `create` 钩子函数。
   3. 删除旧节点：遍历待删除的 vnodes 做删除

5. 新旧节点一样的话，尽可能的要做到节点的复用。`updateChildren`方法调用了`patchVNode`方法。先记住几个原则：

   1. 新 vnode 是`文字 vnode`：直接调用浏览器的 dom api 把节点的直接替换掉文字内容。
   2. 新 vnode 不是`文字 vnode`：开始对子节点 children 进行对比（比如 ul 下的 li）
   3. 有`新 children` 而没有`旧 children`：说明是`新增 children`，直接 addVnodes 添加新子节点。
   4. 有`旧 children` 而没有`新 children`：说明是`删除 children`，直接 removeVnodes 删除旧子节点
   5. 新旧 children 都存在：进到`新旧节点的diff` 过程，执行 `updateChildren` 函数比较子节点（diff 算法的核心）

6. 新旧节点的 diff 过程：

```javascript
// 旧首节点
let oldStartIdx = 0;
// 新首节点
let newStartIdx = 0;
// 旧尾节点
let oldEndIdx = oldCh.length - 1;
// 新尾节点
let newEndIdx = newCh.length - 1;
```

一共有四个指针，这些变量分别指向旧节点的首和尾、新节点的首和尾。

![](https://cdn.liujiefront.com/images/vue-source/fjoep.png)

我们将它们取出来并分别用 s 和 e 指针指向它们的头 child 和尾 child

![](https://cdn.liujiefront.com/images/vue-source/sj0a8.png)

根据这些指针，在一个 while 循环中不停的对新旧节点的两端的进行对比，然后把两端的指针向不断内部收缩，直到没有节点可以对比。

之前提到的`sameVnode`，它是用来判断节点是否可用的关键函数，可以看到，判断是否是 `sameVnode`，传递给节点的 `key` 是关键。

`updateChildren`方法里:
![](https://cdn.liujiefront.com/images/vue-source/tkj0j.png)

然后我们接着进入 diff 过程，每一轮都是同样的对比，其中某一项命中了，就递归的进入 `patchVnode` 针对单个 vnode 进行的过程（如果这个 vnode 又有 children，那么还会来到这个 diff children（updateChildren） 的过程）。

针对`sameNode`规则，我们进行如下顺序的比对：

1. 旧首和新首对比。
2. 旧尾和新尾对比
3. 旧首和新尾对比
4. 旧尾和新首对比
5. 如果以上逻辑都匹配不到，再把所有旧子节点的 key 做一个 `hash` 表，然后用新 vnode 的 key 去找出在旧节点中可以复用的位置。
6. 如果没有 key，那么就将新 vnode 插入到`真实的dom`（ps：这下可以解释为什么 v-for 的时候需要设置 key 了，如果没有 key 那么就只会做四种匹配，就算指针中间有可复用的节点都不能被复用了）

然后不停的把匹配到的指针向内部收缩，直到新旧节点有一端的指针相遇（这个端的节点都被 patch 过了）。

在指针相遇以后，还有可能出现两种情况：

1. ** 有新节点需要加入 **。如果更新完以后，`oldStartIdx > oldEndIdx`，说明旧节点都被 patch 完了，但是有可能还有新的节点没有被处理到。接着会去判断是否要新增子节点。

2. ** 有旧节点需要删除 **。如果新节点先 patch 完了，那么此时会走 `newStartIdx > newEndIdx` 的逻辑，那么就会去删除多余的旧子节点。

![](https://cdn.liujiefront.com/images/vue-source/smf41.png)


## 为什么不用 index 作为 key？

回到一开始的话题，如果用了 index 作为 key 会怎么样？

### 节点 reverse 场景

```xml
<div id="app">
      <ul>
        <item
          :key="index"
          v-for="(num, index) in nums"
          :num="num"
          :class="`item${num}`"
        ></item>
      </ul>
      <button @click="change">改变</button>
    </div>
<script src="./vue.js"></script>
<script>
var vm = new Vue({
  name: "parent",
  el: "#app",
  data: {
    nums: [1, 2, 3],
  },
  methods: {
    change() {
      this.nums.reverse();
    },
  },
  components: {
    item: {
      props: ["num"],
      template: `
                    <div>
                       {{num}}
                    </div>
                `,
      name: "child",
    },
  },
});
</script>
```

在首次渲染的时候，我们的虚拟节点列表 oldChildren 粗略表示是这样的：

```javascript
[
  {
    tag: "item",
    key: 0,
    props: {
      num: 1,
    },
  },
  {
    tag: "item",
    key: 1,
    props: {
      num: 2,
    },
  },
  {
    tag: "item",
    key: 2,
    props: {
      num: 3,
    },
  },
];
```

在我们点击按钮的时候，会对数组做 reverse 的操作。那么我们此时生成的 newChildren 列表是这样的：

```javascript
[
  {
    tag: "item",
    key: 0,
    props: {
+     num: 3
    }
  },
  {
    tag: "item",
    key: 1,
    props: {
+     num: 2
    }
  },
  {
    tag: "item",
    key: 2,
    props: {
+     num: 1
    }
  }
];
```

发现的问题是 key 的顺序变了，但是传入的值完全变了。这会导致一个什么问题？
本来按照最合理的逻辑来说，`旧的第一个 vnode` 是应该直接完全复用 `新的第三个 vnode` 的，因为它们本来就应该是同一个 vnode，自然所有的属性都是相同的。
但是在进行子节点的 diff 过程中，会在 `旧首节点`和`新首节点`用 `sameNode` 对比。 这一步命中逻辑，因为现在新旧两次首部节点 的 key 都是 0 了，
然后把旧的节点中的第一个 vnode 和 新的节点中的第一个 vnode 进行 `patchVnode` 操作。

这样的话本应该直接复用的节点变成了触发`dep.notify`，触发子组件视图的重新渲染等一套很重的逻辑。

### 节点删除场景

假设我们有这样的一段代码：

```xml
<body>
  <div id="app">
    <ul>
      <li v-for="(value, index) in arr" :key="index">
        <test />
      </li>
    </ul>
    <button @click="handleDelete">delete</button>
  </div>
  </div>
</body>
<script>
  new Vue({
    name: "App",
    el: '#app',
    data() {
      return {
        arr: [1, 2, 3]
      };
    },
    methods: {
      handleDelete() {
        this.arr.splice(0, 1);
      }
    },
    components: {
      test: {
        template: "<li>{{Math.random()}}</li>"
      }
    }
  })
</script>

```

对应的 vnode 列表是这样的：

```javascript
[
  {
    tag: "li",
    key: 0,
    // 这里其实子组件对应的是第一个 假设子组件的text是1
  },
  {
    tag: "li",
    key: 1,
    // 这里其实子组件对应的是第二个 假设子组件的text是2
  },
  {
    tag: "li",
    key: 2,
    // 这里其实子组件对应的是第三个 假设子组件的text是3
  },
];
```

这里有个一个很重要的细节就是 **Vue 对于组件的 diff 是不关心子组件内部实现的**，它只会看你在模板上声明的传递给子组件的一些属性是否有更新。

也就是和`v-for`平级的那部分，回顾一下判断 `sameNode` 的时候，只会判断 key、 tag、是否有 data 的存在（不关心内部具体的值）、是否是注释节点、是否是相同的 input type，来判断是否可以复用这个节点。

有了这些前置知识以后，我们来看看，点击删除子元素后，vnode 列表 变成什么样了。

```javascript
[
  // 第一个被删了
  {
    tag: "li",
    key: 0,
    // 这里其实上一轮子组件对应的是第二个 假设子组件的text是2
  },
  {
    tag: "li",
    key: 1,
    // 这里其实子组件对应的是第三个 假设子组件的text是3
  },
];
```

虽然在注释里我们自己清楚的知道，第一个 vnode 被删除了，但是对于 Vue 来说，它是感知不到子组件里面到底是什么样的实现（它不会深入子组件去对比文本内容），那么这时候 Vue 会怎么 patch 呢？

由于对应的 key 使用了 index 导致的错乱，它会把

1. 原来的第一个节点 text: 1 直接复用。
2. 原来的第二个节点 text: 2 直接复用。
3. 然后发现新节点里少了一个，直接把多出来的第三个节点 text: 3 丢掉。

至此为止，我们本应该把 `text: 1` 节点删掉，然后 `text: 2`、`text: 3` 节点复用，就变成了错误的把 `text: 3` 节点给删掉了。

### 为什么不要用随机数作为 key？

```xml
<item
  :key="Math.random()"
  v-for="(num, index) in nums"
  :num="num"
  :class="`item${num}`"
/>
```

这种做法其实挺常见的，既然官方要求一个 唯一的 key，是不是可以用 Math.random() 作为 key 来偷懒？

首先 oldVnode 是这样的：

```javascript
[
  {
    tag: "item",
    key: 0.6330715699108844,
    props: {
      num: 1,
    },
  },
  {
    tag: "item",
    key: 0.25104533240710514,
    props: {
      num: 2,
    },
  },
  {
    tag: "item",
    key: 0.4114769152411637,
    props: {
      num: 3,
    },
  },
];
```

更新以后是：

```diff
[
  {
    tag: "item",
+   key: 0.11046018699748683,
    props: {
+     num: 3
    }
  },
  {
    tag: "item",
+   key: 0.8549799545696619,
    props: {
+     num: 2
    }
  },
  {
    tag: "item",
+   key: 0.18674467938937478,
    props: {
+     num: 1
    }
  }
];
```

可以看到，key 变成了完全全新的 3 个随机数。
上面说到，diff 子节点的首尾对比如果都没有命中，就会进入 key 的详细对比过程，简单来说，就是利用旧节点的 key -> index 的关系建立一个 map 映射表，然后用新节点的 key 去匹配，如果没找到的话，就会调用 `createElm` 方法 重新建立 一个新节点，这和不写key岂不是一样的效果了。

```javascript
// 建立旧节点的 key -> index 映射表
oldKeyToIdx = createKeyToOldIdx(oldCh, oldStartIdx, oldEndIdx);

// 去映射表里找可以复用的 index
idxInOld = findIdxInOld(newStartVnode, oldCh, oldStartIdx, oldEndIdx);
// 一定是找不到的，因为新节点的 key 是随机生成的。
if (isUndef(idxInOld)) {
  // 完全通过 vnode 新建一个真实的子节点
  createElm();
}
```

## 参考文章

1. 晨曦时梦见兮：[为什么 Vue 中不要用 index 作为 key？（diff 算法详解）](https://juejin.im/post/6844904113587634184#heading-11)
2. windlany：[详解vue的diff算法](https://juejin.im/post/6844903607913938951)