---
title: github上contributions图(js-calendar-graph)
date: 2017-05-15 17:43:51
tags:
- github
- d3
- bower
- js-calendar-graph
---

前几天注意到github上有一个 “293 contributions in the last year”这样的东西，如下图，觉得挺有意思的，查看了半天的资料，现在分享下这个模块的具体实现方式。

![](/images/git/contributions.png)
<!--more-->


## 引入文件
要实现这个模块是需要借助第三方js插件的，这里就有大名鼎鼎的d3。

新建一个html文件，引入所需要的js文件和css文件，这里我用的是bower包,

```
<link rel="stylesheet" href="./bower_components/cal-heatmap/cal-heatmap.css" />
...
<div id="cal-heatmap"></div>
<script type="text/javascript" src="./bower_components/d3/d3.min.js"></script>
<script type="text/javascript" src="./bower_components/cal-heatmap/cal-heatmap.min.js"></script>
```
当然了也可以使用cdn
```
<script type="text/javascript" src="//d3js.org/d3.v3.min.js"></script>
...
<script type="text/javascript" src="//cdn.jsdelivr.net/cal-heatmap/3.3.10/cal-heatmap.min.js"></script>
<link rel="stylesheet" href="//cdn.jsdelivr.net/cal-heatmap/3.3.10/cal-heatmap.css" />
```

## 初始化

```
var cal = new CalHeatMap();
cal.init({
    
});
```

## mock数据

要实现这个可视化数据图本应该要get到后端的json数据的，现在我为了模拟，先做一些假的数据出来，到了具体环境中可以真正的去获取数据

```
var datas = {};
    var start = new Date("2017-1-1".replace(/-/g, "/"));
    var end = new Date("2017-12-31".replace(/-/g, "/"));

    do {
        var value = Math.floor(Math.random() * 30);
        var startYML = start.getFullYear() + "-" + (start.getMonth() + 1) + "-" + start.getDate()
        var timeStamp = (Date.parse(startYML)) / 1000;
        datas[timeStamp] = value;
        start.setDate(start.getDate() + 1);
    } while (end >= start);

    console.log(datas)

    var cal = new CalHeatMap();
    cal.init({
        //from 2017,0,1
        start: new Date(2017, 0, 1),
        data: datas,
        domain: "month",
        subDomain: "day",
        // subDomain: "x_day",
        range: 12,
        tooltip: true,
        cellsize: 15,
        cellpadding: 3,
        domainGutter: 15,
        cellSize: 10,
        // displayLegend: false
    });
```
最后的效果如下：
![](/images/git/results.png)
这里我做了一个2017年一整年的数据出来，注意下，这里的`timeStamp`是距离1970年1月1号的秒，而不是毫秒，要是定制不同的数据体，可以参考下 [cal-heatmap](http://cal-heatmap.com/)

