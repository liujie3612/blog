#!/bin/sh
hexo clean && hexo g -d
git add .
git commit -m"update"
git push origin master