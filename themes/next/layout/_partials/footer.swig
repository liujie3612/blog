<!-- <div class="ds-share flat" data-thread-key="此处请替换为当前文章的thread-key" data-title="此处请替换为分享时显示的标题" data-images="此处请替换为分享时显示的图片的链接地址" data-content="此处请替换为分享时显示的内容" data-url="此处请替换为分享时显示的链接地址">
    <div class="ds-share-aside-right">
      <div class="ds-share-aside-inner">
      </div>
      <div class="ds-share-aside-toggle">分享到</div>
    </div>
</div> -->
<div class="copyright" >
  {% set current = date(Date.now(), "YYYY") %}
  &copy; {% if theme.since and theme.since != current %} {{ theme.since }} - {% endif %}
  <span itemprop="copyrightYear">{{ current }}</span>
  <span class="with-love">
    <i class="fa fa-heart"></i>
  </span>
  <span class="author" itemprop="copyrightHolder">{{ config.author }}</span>
</div>
<div class="powered-by">
  {# {{ __('footer.powered', '<a class="theme-link" href="https://hexo.io">Hexo</a>') }} #}
  {{ __('footer.powered', '<a class="theme-link" href="http://hexo.io" rel="external nofollow">Hexo</a>') }}

</div>
<div class="theme-info">
  {{ __('footer.theme') }} -
  {# <a class="theme-link" href="https://github.com/iissnan/hexo-theme-next"> #}
  <a class="theme-link" href="https://github.com/iissnan/hexo-theme-next" rel="external nofollow">
    NexT.{{ theme.scheme }}
  </a>
</div>
<br>
<br>
<iframe frameborder="no" border="0" marginwidth="0" marginheight="0" width=330 height=86 src="http://music.163.com/outchain/player?type=2&id=64634&auto=1&height=66"></iframe>
<br>
<script async src="https://dn-lbstatics.qbox.me/busuanzi/2.3/busuanzi.pure.mini.js"></script>
本站总访问量 <span id="busuanzi_value_site_pv"></span> &nbsp;&nbsp;&nbsp;
您是第<span id="busuanzi_value_site_uv"></span>个来到的小伙伴
