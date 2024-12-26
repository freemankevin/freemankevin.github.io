## hexo-blog

```shell
# clone project
git clone https://github.com/FreemanKevin/hexo-blog.git
cd hexo-blog

# run project
git clone https://github.com/next-theme/hexo-theme-next themes/next
rm -rf node_modules && npm install --force
hexo cl && hexo g && hexo s

# git push
hexo cl && hexo g && hexo d

# algolia push
hexo cl && hexo g && hexo algolia 

# git commit
git add .
git commit -m "update files"
git push
```