<div class="eevee">
  <div class="body">
    <div class="head">
      <div class="ears">
        <div class="ear">
          <div class="lobe"></div>
        </div>
        <div class="ear">
          <div class="lobe"></div>
        </div>
      </div>
      <div class="face">
        <div class="eyes">
          <div class="eye">
            <div class="eyelid"></div>
          </div>
          <div class="eye">
            <div class="eyelid"></div>
          </div>
        </div>
        <div class="nose"></div>
        <div class="mouth"></div>
      </div>
    </div>
    <div class="chest">
      <div class="fur">
        <div class="patch"></div>
      </div>
      <div class="fur">
        <div class="patch"></div>
      </div>
      <div class="fur">
        <div class="patch"></div>
      </div>
    </div>
    <div class="legs">
      <div class="leg">
        <div class="inner-leg"></div>
      </div>
      <div class="leg">
        <div class="inner-leg"></div>
      </div>
      <div class="leg">
        <div class="inner-leg"></div>
      </div>
      <div class="leg">
        <div class="inner-leg"></div>
      </div>
    </div>
    <div class="tail">
      <div class="tail">
        <div class="tail">
          <div class="tail">
            <div class="tail">
              <div class="tail -end"></div>
            </div>
          </div>
        </div>
      </div>
    </div>
  </div>
</div>

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
  {# <a class="theme-link" href="https://github.com/iissnan/hexo-theme-next" rel="external nofollow"> #}
    NexT.{{ theme.scheme }}
  </a>
</div>

{# <iframe frameborder="no" border="0" marginwidth="0" marginheight="0" width=330 height=86 src="http://music.163.com/outchain/player?type=2&id=64634&auto=1&height=66"></iframe> #}
<script async src="https://busuanzi.ibruce.info/busuanzi/2.3/busuanzi.pure.mini.js"></script>
本站总访问量 <span id="busuanzi_value_site_pv"></span> &nbsp;&nbsp;&nbsp;
您是第<span id="busuanzi_value_site_uv"></span>个来到的小伙伴
