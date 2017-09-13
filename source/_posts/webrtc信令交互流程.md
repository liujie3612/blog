---
title: webrtc信令交互流程
date: 2017-09-13 20:00:37
tags:
- webrtc
- Real-Time Communications
---
WebRTC是HTML5支持的重要特性之一，有了它，不再需要借助音视频相关的客户端，直接通过浏览器的Web页面就可以实现音视频对聊功能。而且WebRTC项目是开源的，我们可以借助WebRTC源码快速构建自己的音视频对聊功能。无论是使用前端JS的WebRTC API接口，还是在WebRTC源码上构建自己的对聊框架，都需要遵循以下执行流程：

<!--more-->

![](/images/webrtc/webrtc.png)

上述序列中，WebRTC并不提供Stun服务器和Signal服务器，服务器端需要自己实现。Stun服务器可以用google提供的实现stun协议的测试服务器（stun:stun.l.google.com:19302），Signal服务器则完全需要自己实现了，它需要在ClientA和ClientB之间传送彼此的SDP信息和candidate信息，ClientA和ClientB通过这些信息建立P2P连接来传送音视频数据。由于网络环境的复杂性，并不是所有的客户端之间都能够建立P2P连接，这种情况下就需要有个relay服务器做音视频数据的中转，本文本着源码剖析的态度，这种情况就不考虑了。这里说明一下， stun/turn、relay服务器的实现在WebRTC源码中都有示例，真是个名副其实的大宝库。

上述序列中，标注的场景是ClientA向ClientB发起对聊请求，调用描述如下：

* ClientA首先创建`PeerConnection`对象，然后打开本地音视频设备，将音视频数据封装成`MediaStream`添加到`PeerConnection`中。

* ClientA调用`PeerConnection的CreateOffer`方法创建一个用于`offer`的`SDP`对象，`SDP`对象中保存当前音视频的相关参数。ClientA通过`PeerConnection`的`SetLocalDescription`方法将该`SDP`对象保存起来，并通过Signal服务器发送给ClientB。

* ClientB接收到ClientA发送过的`offer SDP`对象，通过`PeerConnection`的`SetRemoteDescription`方法将其保存起来，并调用`PeerConnection`的`CreateAnswer`方法创建一个应答的`SDP`对象，通过`PeerConnection`的`SetLocalDescription`的方法保存该应答`SDP`对象并将它通过Signal服务器发送给ClientA。

* ClientA接收到ClientB发送过来的应答`SDP`对象，将其通过`PeerConnection`的`SetRemoteDescription`方法保存起来。

* 在SDP信息的`offer/answer`流程中，ClientA和ClientB已经根据`SDP`信息创建好相应的音频Channel和视频Channel并开启`Candidate`数据的收集，`Candidate`数据可以简单地理解成Client端的IP地址信息（本地IP地址、公网IP地址、Relay服务端分配的地址）。

* 当ClientA收集到`Candidate`信息后，`PeerConnection`会通过`OnIceCandidate`接口给ClientA发送通知，ClientA将收到的`Candidate`信息通过Signal服务器发送给ClientB，ClientB通过`PeerConnection`的`AddIceCandidate`方法保存起来。同样的操作ClientB对ClientA再来一次。

* 这样ClientA和ClientB就已经建立了音视频传输的P2P通道，ClientB接收到ClientA传送过来的音视频流，会通过`PeerConnection`的`OnAddStream`回调接口返回一个标识ClientA端音视频流的`MediaStream`对象，在ClientB端渲染出来即可。同样操作也适应ClientB到ClientA的音视频流的传输。

