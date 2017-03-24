#!/bin/sh
hexo clean && hexo g -d
git add .
git commit -m"update doc"
git push origin master
