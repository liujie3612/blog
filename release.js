#!/usr/local/bin/node

const exec = require('child_process').execSync
const paramType = process.argv[2] || 'mod'
const paramCommit = process.argv[3] || '提交'


const commitType = {
  add: '新增：',
  feat: '功能：',
  mod: '修改：'
}

const commit = commitType[paramType]

exec(
  `hexo clean && hexo g -d && git add . && git commit -m${commit}${paramCommit} && git push origin master`,
  { stdio: [0, 1, 2] }
)