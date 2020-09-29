---
title: Vuejs源码解析 6-3 slot
date: 2020-09-14 17:58:07
tags:
- vue
- 源码解析
- 源码
- 拓展
- 插槽
categories: Vue源码解析
---

Vue 实现了一套内容分发的 API，将 `<slot>` 元素作为承载分发内容的出口。`<slot>` 在子组件中可以有多个，使用 name 属性实现具名插槽。
从插槽内容能否使用子组件数据的角度可将插槽分为两类：`普通插槽`、`作用域插槽`。
- `普通插槽`不能使用子组件的数据，父级模板里的所有内容都是在父级作用域中编译的；子模板里的所有内容都是在子作用域中编译的。
- `作用域插槽`是指在子组件 `<slot>` 上绑定 **插槽prop**，父组件可以访问子组件插槽上的全部prop。

![](https://tva1.sinaimg.cn/large/007S8ZIlly1gj6pims20oj30k80e4wgu.jpg)

<!--more-->

# 插槽的使用

在Vue2.x版本中，父组件向插槽提供内容的方式并不是一成不变的，普通插槽与作用域插槽的使用均有所改变。

## slot

在2.6.0以前，父组件中使用 slot 属性实现普通插槽。借用官网示例，能够很清晰的阐述其用法。假设组件 `<base-layout>` 代码如下：
```js
<div class="container">
  <header>
    <slot name="header"></slot>
  </header>
  <main>
    <slot></slot>
  </main>
  <footer>
    <slot name="footer"></slot>
  </footer>
</div>
```

使用 slot 属性实现具名插槽时，没有 slot 属性的按照放在默认插槽中，如果子组件中没有实现默认插槽则丢弃该部分内容。
```js
<base-layout>
  <template slot="header">
    <h1>Here might be a page title</h1>
  </template>

  <p>A paragraph for the main content.</p>
  <p>And another one.</p>

  <template slot="footer">
    <p>Here's some contact info</p>
  </template>
</base-layout>
```

slot 属性不仅可以放在 `<template>` 元素中，也可以放在普通元素中。

```js
<base-layout>
  <h1 slot="header">Here might be a page title</h1>

  <p>A paragraph for the main content.</p>
  <p>And another one.</p>

  <p slot="footer">Here's some contact info</p>
</base-layout>
```

上述两种写法渲染的结果一样，如下所示：
```js
<div class="container">
  <header>
    <h1>Here might be a page title</h1>
  </header>
  <main>
    <p>A paragraph for the main content.</p>
    <p>And another one.</p>
  </main>
  <footer>
    <p>Here's some contact info</p>
  </footer>
</div>
```

## scope 和 slot-scope

最初Vue2.0版本使用 `scope` 属性来实现作用域插槽，在2.5.0以后被 `slot-scope` 取代。二者唯一的区别在于 `scope` 属性只能用在 `<template>` 元素上，`slot-scope` 可以在普通元素上使用。
依旧使用官方示例来介绍 `slot-scope`，假设有组件 `<slot-example>` 代码如下：
```js
<span>
  <slot v-bind:user="user">
    {{ user }}
  </slot>
</span>
```
 在父组件中，可以使用如下方式获取到子组件的数据 user：
```js
<slot-example>
  <template slot="default" slot-scope="slotProps">
    {{ slotProps.user }}
  </template>
</slot-example>
```
前面提到过，`slot-scope` 与 `scope` 的唯一区别在于能够在普通元素上使用，因此可以省略掉 `<template>` 元素。
```js
<slot-example>
  <span slot-scope="slotProps">
    {{ slotProps.user }}
  </span>
</slot-example>
```

## v-slot

从 Vue2.6.0 版本开始，原有的 slot 与 slot-scope 皆被废弃，新版本使用 `v-slot` 指令来实现普通插槽与作用域插槽。
v-slot 指令向前面示例中 `<base-layout>` 组件提供普通插槽内容的方式如下：

```js
<base-layout>
  <template v-slot:header>
    <h1>Here might be a page title</h1>
  </template>

  <p>A paragraph for the main content.</p>
  <p>And another one.</p>

  <template v-slot:footer>
    <p>Here's some contact info</p>
  </template>
</base-layout>
```

`v-slot` 指令可以被缩写成字符 `#`

```js
<base-layout>
  <template #header>
    <h1>Here might be a page title</h1>
  </template>

  <p>A paragraph for the main content.</p>
  <p>And another one.</p>

  <template #footer>
    <p>Here's some contact info</p>
  </template>
</base-layout>
```

使用` v-slot` 指令实现作用域插槽的方式如下所示：
```js
<current-user>
  <template v-slot:default="slotProps">
    {{ slotProps.user.firstName }}
  </template>

  <template #other="otherSlotProps">
    {{otherSlotProps.data}}
  </template>
</current-user>
```

v-slot 指令一般只能添加在 `<template>` 元素上，除非当被提供的内容**只有默认插槽**时，才能在组件标签上使用。
```js
<current-user v-slot="slotProps">
  {{ slotProps.user.firstName }}
</current-user>
```

# 新增v-slot的原因

作用域插槽原本是通过 `scope` 实现的，scope 只能在 `<template>` 元素上使用。为了提升使用的灵活性，在2.5.0版本之后，使用 slot-scope 取代 scope。
slot-scope 与 scope 用法基本一致，唯一有区别的是不仅可以在 `<template>` 元素上使用，还可以在普通标签上使用。可以在普通标签上使用，也就意味着可以在组件标签上使用。这在一定程度上提高了灵活性，但是也带来了一些问题。
```js
<foo>
  <bar slot-scope="foo">
    <baz slot-scope="bar">
      <div slot-scope="baz">
        {{ foo }} {{ bar }} {{ baz }}
      </div>
    </baz>
  </bar>
</foo>
```

在这种深度嵌套的情况下，并不能清晰的知道哪个组件在此模板中提供哪个变量。后来 Vue 作者说允许在没有模板的情况下使用 slot-scope 是一个错误。
Vue2.6.0之后废弃 slot、slot-scope，将关于插槽的功能统一到 v-slot 指令中。这样首先能够使语法更为简洁，更重要的是能够解决组件提供变量不清的问题。
v-slot 指令规定只能使用在 <template> 元素上，当被提供的内容只有默认插槽时，组件的标签才可以被当作插槽的模板来使用。这样就能很清晰的确定变量是哪个组件提供的。
```js
<foo v-slot="foo">
  <bar v-slot="bar">
    <baz v-slot="baz">
      {{ foo }} {{ bar }} {{ baz }}
    </baz>
  </bar>
</foo>
```
采用新指令 `v-slot` 而不是修复 `slot-scope` 功能漏洞的原因主要有以下三点：

1. Vue2.x版本在2.6.0时已到了后期，Vue3.x马上发布了，类似这种突破性的改变没有合适的时机发布。
2. 一旦改变 slot-scope 的功能，会使得之前关于 slot-scope 的资料全部过时，容易给新学习者带来迷惑。
3. 在3.x中，插槽类型将会被统一起来，使用 v-slot 指令统一语法是很好的选择。

# 原理解析：

虽然 slot、slot-scope 被废弃，不建议开发者使用，但是在 Vue2.6.0 版本里依然保留其实现代码，这两个属性依然可以使用。因此探究二者的实现代码还是挺有必要的。
以下面示例代码的编译渲染过程来阐述 slot、slot-scope 属性的实现原理。

```vue
<!--父组件使用插槽-->
<div>
  <app-layout>
    <template slot="header">标题</template>
    <div>内容</div>
    <div slot="footer" slot-scope="slotProps">{{slotProps.footer}}</div>
  </app-layout>
</div>

<!--appLayout 组件模板代码-->
<div class="container">
  <slot name="header"></slot>
  <slot></slot>
  <slot name="footer" footer="尾部"></slot>
</div>
```
## 父组件slot、slot-scope属性的编译
在模板编译的过程中，解析结束标签时会调用 `processElement` 函数对 AST 中的当前节点进行处理：
```js
function processElement(element,options) {
  /*...*/
  processSlotContent(element)
  /*...*/
}
```
对插槽的解析，就从 `processSlotContent` `函数开始。processSlotContent` 函数对普通插槽属性 slot、slot-scope 的处理代码如下：
```js
function processSlotContent (el) {
  var slotScope;
  if (el.tag === 'template') {
    slotScope = getAndRemoveAttr(el, 'scope');
    if (slotScope) {/* 省略警告信息 */}
      el.slotScope = slotScope || getAndRemoveAttr(el, 'slot-scope');
  } else if ((slotScope = getAndRemoveAttr(el, 'slot-scope'))) {
    if (el.attrsMap['v-for']) {/* 省略警告信息 */}
    el.slotScope = slotScope;
  }

  var slotTarget = getBindingAttr(el, 'slot');
  if (slotTarget) {
    el.slotTarget = slotTarget === '""' ? '"default"' : slotTarget;
    el.slotTargetDynamic = !!(el.attrsMap[':slot'] || el.attrsMap['v-bind:slot']);
    if (el.tag !== 'template' && !el.slotScope) {
      addAttr(el, 'slot', slotTarget, getRawBindingAttr(el, 'slot'));
    }
  }
  /* 省略v-slot相关部分 */
}
```

` processSlotContent` 函数主要有以下几点功能：

1. 将作用域插槽信息取出，然后赋值给节点 slotScope 属性。
2. 取出插槽名称赋值给节点 slotTarget 属性，如果没有则置为 default。
3. 根据slot值是否使用了v-bind指令绑定来赋予节点slotTargetDynamic属性不同的布尔值。
4. 如果 slot 是普通标签（非template）的属性且不是作用域插槽，则在节点上添加 attrs 对象数组，用于存储 slot 的信息。

属性 slot、slot-scope 在优化 AST 的部分不进行处理，在根据 AST 生成渲染函数时会调用 `genData` 函数处理节点属性。
```js
function genData (el, state){
  /*...*/
  if (el.slotTarget && !el.slotScope) {
    data += `slot:${el.slotTarget},`
  }
  if (el.scopedSlots) {
    data += `${genScopedSlots(el, el.scopedSlots, state)},`
  }
  /*...*/
}
```

其中 `genScopedSlots` 函数代码如下所示：
```js
function genScopedSlots (el,slots,state){
  let needsForceUpdate = el.for || Object.keys(slots).some(key => {
    const slot = slots[key]
    return (slot.slotTargetDynamic||slot.if||slot.for||containsSlotChild(slot))
  })
  /* ... */
  const generatedSlots = Object.keys(slots)
    .map(key => genScopedSlot(slots[key], state))
    .join(',')

  return `scopedSlots:_u([${generatedSlots}]${
    needsForceUpdate ? `,null,true` : ``
  }${
    !needsForceUpdate && needsKey ? `,null,false,${hash(generatedSlots)}` : ``
  })`
}
```
可以看到只带有 slot 属性的节点被正常解析成子组件的子节点，而带有 slot-scope 属性的节点被 `_u()` 方法包裹，作为子组件 `scopedSlots` 属性的一部分。
另外一点需要注意的是，上面提到过不在 `template` 上使用普通插槽时，会将 slot 信息存储到 attrs 中，因此 genData 函数中对 attrs 的处理也可能与普通插槽有关：
```js
if (el.attrs) {
  data += `attrs:${genProps(el.attrs)},`
}
```
上述实例最终生成的渲染函数为：
```js
_c(
  'div',
  [
    _c(
      'app-layout',
      {
        scopedSlots:_u(
          [
            {
              key:"footer",
              fn:function(slotProps){
                return _c('div',{},[_v(_s(slotProps.footer))])
              }
            }
          ]
        )
      },
      [
        _c('template',{slot:"header"},[_v("标题")]),
        _c('div',[_v("内容")])
      ],
      2
    )
  ],
  1
)
```

## v-slot 指令的编译

`processSlotContent` 函数对指令 `v-slot` 的处理代码如下：
```js
if (el.tag === 'template') {
  // v-slot on <template>
  var slotBinding = getAndRemoveAttrByRegex(el, slotRE);
  if (slotBinding) {
    /*...*/
    var ref = getSlotName(slotBinding);
    var name = ref.name;
    var dynamic = ref.dynamic;
    el.slotTarget = name;
    el.slotTargetDynamic = dynamic;
    el.slotScope = slotBinding.value || emptySlotScopeToken;
  } else {
    /* 当被提供的内容只有默认插槽时，使用组件标签作为插槽的模板使用的情况 */
  }
}
```
可以看到在 <template> 标签上使用指令时，经过 processSlotContent 函数处理后，跟使用slot、slot-scope属性生成的结果一样，因此后续的处理与上一小节描述的相同。

## 子组件<slot>标签的编译

在编译过程中，会使用 `processSlotOutlet` 函数对 `<slot>` 标签处理，提取出 `<slot>` 标签上 `name` 属性的值。

```js
function processSlotOutlet (el) {
  if (el.tag === 'slot') {
    el.slotName = getBindingAttr(el, 'name')
    /*...*/
  }
}
```

在 `codegen` 阶段会调用 `genSlot` 函数，根据子组件的内容生成被 `_t()` 包裹的字符串。

```js
function genSlot (el, state) {
  var slotName = el.slotName || '"default"';
  var children = genChildren(el, state);
  var res = "_t(" + slotName + (children ? ("," + children) : '');
  /* 省略标签上有属性以及有指令v-bind的情况 */
  return res + ')'
}
```
最终示例中子组件的渲染函数为：
```js
_c(
  'div',
  {staticClass:"container"},
  [
    _t("header"),
    _t("default"),
    _t("footer",null,{"footer":"尾部"})
  ],
  2
)
```

## 渲染

上述示例中父组件经过 _render 方法处理后生成的 `VNode` 如下所示：

```js
{
  tag: "div",
  children: [
    {
      tag: "vue-component-1-app-layout",
      data: {
        hook: {/* 省略... */},
        on: undefined,
        scopedSlots:{
          footer: function(){/* 省略... */}
        }
      },
      componentOptions:{
        Ctro: function VueComponent (options) {
          this._init(options);
        },
        children: [
          {tag: "template",/* 省略... */}
          {tag: "div",/* 省略... */}
        ]
        listeners: undefined
        propsData: undefined
        tag: "app-layout"
      }
      /* 省略其它属性 */
    }
  ]
  /* 省略其它属性 */
}
```
由上可知，仅含有 slot 属性的标签被处理成父组件的 `子VNode` 节点，含有 `slot-scope` 属性的标签被存放在 `父VNode` 的 `data.scopedSlots` 属性对象上。
子组件 `<slot>` 标签生成的渲染函数中 `_t()` 为 `renderSlot` 函数：

```js
function renderSlot (name,fallback,props,bindObject) {
  var scopedSlotFn = this.$scopedSlots[name];
  var nodes;
  if (scopedSlotFn) { // scoped slot
    props = props || {};
    /*...*/
    nodes = scopedSlotFn(props) || fallback;
  } else {
    nodes = this.$slots[name] || fallback;
  }

  var target = props && props.slot;
  if (target) {
    return this.$createElement('template', { slot: target }, nodes)
  } else {
    return nodes
  }
}
```

`renderSlot` 函数返回值为父组件的子VNode数组，根据不同情况来完成父组件替换子组件插槽内容的过程。`renderSlot` 函数的逻辑分为两部分：

1. 如果是普通插槽，则取已经生成的以父实例为上下文的子VNode作为返回值。
2. 如果是作用域插槽，则根据 `$scopedSlots` 属性中的值生成新的VNode作为返回值。

由此可知：**普通插槽只能使用父组件数据的原因在于其VNode是以父实例为上下文生成的，而作用域插槽则是在编译渲染子组件的时候才生成的。**

# 总结：

在2.x版本中，插槽的使用有过改变。最初使用scope属性实现作用域插槽，2.5.0版本以后被slot-scope 取代，普通插槽的使用在2.6.0版本之前使用slot属性完成。在2.6.0之后使用v-slot指令来实现普通插槽与作用域插槽。
slot-scope属性可以在普通标签上使用，在深度嵌套的情况下，不能很清晰的知道组件和变量的关系。另外，2.x版本已经到了后期，做出这种突破性的改变并不合适，因此2.6.0版本新增v-slot指令来规避这种错误。
v-slot指令在 <template> 标签上使用时，内部实现上与slot、slot-scope本质上相同。普通插槽的子组件生成的上下文是父组件实例，因此不能使用自身的数据，只能使用父组件的数据。作用域插槽在父组件生成VNode时并没有一起生成，而是在渲染子组件时才生成的，因此可以使用子组件自身的数据。

