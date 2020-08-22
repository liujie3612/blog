---
title: Vue-js源码解析(7) - 组件注册
date: 2020-08-22 15:23:17
tags:
---

在 Vue.js 中，除了它内置的组件如 keep-alive、component、transition、transition-group 等，其它用户自定义组件在使用前必须注册。很多同学在开发过程中可能会遇到如下报错信息：
![](https://cdn.liujiefront.com/images/algorithm/j8xc9.png)
一般报这个错的原因都是我们使用了未注册的组件。Vue.js 提供了 2 种组件的注册方式，全局注册和局部注册。接下来我们从源码分析的角度来分析这两种注册方式。

<!-- more -->

# 全局注册

要注册一个全局组件，可以使用 Vue.component(tagName, options)。例如：

```js
Vue.component("my-component", {
  // 选项
});
```

那么，Vue.component 函数是在什么时候定义的呢，它的定义过程发生在最开始初始化 Vue 的全局函数的时候，代码在 `src/core/global-api/assets.js` 中：

```js
import { ASSET_TYPES } from "shared/constants";
import { isPlainObject, validateComponentName } from "../util/index";

export function initAssetRegisters(Vue: GlobalAPI) {
  /**
   * Create asset registration methods.
   */
  ASSET_TYPES.forEach((type) => {
    Vue[type] = function (
      id: string,
      definition: Function | Object
    ): Function | Object | void {
      if (!definition) {
        return this.options[type + "s"][id];
      } else {
        /* istanbul ignore if */
        if (process.env.NODE_ENV !== "production" && type === "component") {
          validateComponentName(id);
        }
        if (type === "component" && isPlainObject(definition)) {
          definition.name = definition.name || id;
          definition = this.options._base.extend(definition);
        }
        if (type === "directive" && typeof definition === "function") {
          definition = { bind: definition, update: definition };
        }
        this.options[type + "s"][id] = definition;
        return definition;
      }
    };
  });
}
```

函数首先遍历 `ASSET_TYPES`，得到 type 后挂载到 Vue 上 。ASSET_TYPES 的定义在 `src/shared/constants.js` 中：

```js
export const ASSET_TYPES = ["component", "directive", "filter"];
```

所以实际上 Vue 是初始化了 3 个全局函数，并且如果 type 是 component 且 definition 是一个对象的话，通过 `this.opitons._base.extend`， 相当于 `Vue.extend` 把这个对象转换成一个继承于 Vue 的构造函数，最后通过 `this.options[type + 's'][id] = definition` 把它挂载到 `Vue.options.components` 上。

由于我们每个组件的创建都是通过 Vue.extend 继承而来，我们之前分析过在继承的过程中有这么一段逻辑：

```js
Sub.options = mergeOptions(Super.options, extendOptions);
```
