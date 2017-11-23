---
title: OpenCart介绍和安装
date: 2017-11-23 21:07:36
tags:
- OpenCart
- php
- mysql
---

# 介绍
OpenCart也是国外的一款很受欢迎的在线**B2C**网店开源系统，由英国人Daniel一人独立开发，其社区非常活跃。OpenCart的优势在于前台界面的设计非常适合欧美购物者的浏览习惯：简洁，直观，唯美。后台也非常的简洁明了，而且功能强大，对于初学者来说非常容易上手，对于大多数经验丰富的网店经营者来说，OpenCart的后台管理功能也基本能满足其需求。OpenCart和Zen Cart有点相似，但OpenCart的后台设置界面比Zen Cart简洁些，设置也容易些。另外OpenCart的在线支持文件很详细，英文比较好的网友可以通过OpenCart的在线支持文件 http://docs.opencart.com/ 学习OpenCart的安装，设置等。

OpenCart也是基于PHP+MySQL，安装和Zen Cart，WordPress等都大同小异，都是下载程序，解压，把需要的网站安装文件上传到网站对应的根目录下，然后输入网址，填写预先建立的数据库信息，网店信息等等一步步安装；

<!--more-->

# 安装过程

## 安装PHP7
我自己的服务器是CentOS 7系统，这里就安装了PHP7的最新版本。这里有一篇[教程](http://www.jianshu.com/p/6d3b688cd0be)，我就是按照这个教程来安装，其中比较重要的点是一定要安装php的相关插件，不然在OpenCart检测页面中不能通过，没办法进行下一步。其中第五步为这样

``` bash
# ./configure \
--prefix=/usr/local/php \
--with-config-file-path=/etc \
--enable-fpm \
--enable-inline-optimization \
--disable-debug \
--disable-rpath \
--enable-shared  \
--enable-soap \
--with-libxml-dir \
--with-xmlrpc \
--with-openssl \
--with-mcrypt \
--with-mhash \
--with-pcre-regex \
--with-sqlite3 \
--with-zlib \
--enable-bcmath \
--with-iconv \
--with-bz2 \
--enable-calendar \
--with-curl \
--with-cdb \
--enable-dom \
--enable-exif \
--enable-fileinfo \
--enable-filter \
--with-pcre-dir \
--enable-ftp \
--with-gd \
--with-openssl-dir \
--with-jpeg-dir \
--with-png-dir \
--with-zlib-dir  \
--with-freetype-dir \
--enable-gd-native-ttf \
--enable-gd-jis-conv \
--with-gettext \
--with-gmp \
--with-mhash \
--enable-json \
--enable-mbstring \
--enable-mbregex \
--enable-mbregex-backtrack \
--with-libmbfl \
--with-onig \
--enable-pdo \
--with-mysqli=mysqlnd \
--with-pdo-mysql=mysqlnd \
--with-zlib-dir \
--with-pdo-sqlite \
--with-readline \
--enable-session \
--enable-shmop \
--enable-simplexml \
--enable-sockets  \
--enable-sysvmsg \
--enable-sysvsem \
--enable-sysvshm \
--enable-wddx \
--with-libxml-dir \
--with-xsl \
--enable-zip \
--enable-mysqlnd-compression-support \
--with-pear \
--enable-opcache
```
我去掉了`fpm-user`和`fpm-group`,默认为nobody。

## 安装mysql
也是源码包安装，这里可以google下方法，不多赘述。

## 搭建nginx
源码包安装，这里需要强调下的就是nginx的配置

``` bash
server {
        listen      80;
        server_name shop.liujiefront.com;
        root /data/www/shop;
        index index.php index.html index.htm;
        charset UTF-8;
        resolver 8.8.8.8 8.8.4.4 valid=300s;
        resolver_timeout 5s;
        etag on;
        expires max;

        access_log  /data/logs/nginx/shop.log  main;

        location / {
            proxy_set_header    Host            $host;
            proxy_set_header    X-Real-IP       $remote_addr;
            proxy_set_header    X-Forwarded-for $remote_addr;
            proxy_set_header X-Forwarded-Proto  $scheme;
            proxy_set_header X-Forwarded-Port $server_port;
            proxy_connect_timeout 300;
            add_header 'Access-Control-Allow-Origin' '*';
            add_header 'Access-Control-Allow-Credentials' 'true';
        }

        location ~* \.php$ {
           fastcgi_index   index.php;
           fastcgi_pass    127.0.0.1:9000;
           include         fastcgi_params;
           fastcgi_param   SCRIPT_FILENAME    $document_root$fastcgi_script_name;
           fastcgi_param   SCRIPT_NAME        $fastcgi_script_name;
        }

}
```

## mysql建表
可以用工具，熟悉sql语句的话也可以登录到mysql自己建。

## 下载php文件
我下载的[地址](https://www.opencart.cn/demo/),里面有各种各样的模板，我下载了两个，一个中文，一个英文，分别放到www目录下，`nginx`然后分别去指。到这里，访问你的域名地址应该就可以了，默认会出现带有`install`的`url`,一步步进行，要权限就加权限，中文php项目下没有文件的就从英文里拷，这里有个坑说下。

在`install`第三步的时候，填完信息，一直报错，显示的
`No such file or directory`，各种百度，google也无济于事，后来在stackoverflow找到了[答案](https://stackoverflow.com/questions/4219970/warning-mysql-connect-2002-no-such-file-or-directory-trying-to-connect-vi)
```
cd tmp
sudo ln -s /var/lib/mysql/mysql.sock mysql.sock
cd /var
sudo mkdir mysql
sudo chmod 755 mysql
cd mysql
sudo ln -s /tmp/mysql.sock mysql.sock
```
继续填写信息，成功之后把www下OpenCart php目录里的install改个名字，或者直接删除，不然访问域名会一直进到install目录下，php.config这时应该有了数据库的一些信息。

## 清缓存，重启浏览器，输入域名。
