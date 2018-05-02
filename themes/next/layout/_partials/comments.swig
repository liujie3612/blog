{% if page.comments %}
<div class="comments" id="comments">
    {% if (theme.duoshuo and theme.duoshuo.shortname) or theme.duoshuo_shortname %}
    <div class="ds-thread" data-thread-key="{{ page.path }}" data-title="{{ page.title }}" data-url="{{ page.permalink }}">
    </div>
    {% elseif theme.facebook_sdk.enable and theme.facebook_comments_plugin.enable %}
    <div class="fb-comments" data-href="{{ page.permalink }}" data-numposts="{{ theme.facebook_comments_plugin.num_of_posts }}" data-width="{{ theme.facebook_comments_plugin.width }}" data-colorscheme="{{ theme.facebook_comments_plugin.scheme }}">
    </div>
    {% elseif theme.disqus_shortname %}
    <div id="disqus_thread">
        <noscript>
            Please enable JavaScript to view the
            <a href="//disqus.com/?ref_noscript">comments powered by Disqus.</a>
        </noscript>
    </div>
    {% elseif theme.yungentie_shortname %}
    <div id="cloud-tie-wrapper" class="cloud-tie-wrapper"></div>
    <script>
    var cloudTieConfig = {
        url: document.location.href,
        sourceId: "",
        productKey: "aa385535200845f79fb37e9bc46bfeaa",
        target: "cloud-tie-wrapper"
    };

    </script>
    <script src="https://img1.cache.netease.com/f2e/tie/yun/sdk/loader.js"></script>
    {% elseif theme.valine %}
    <script src="//cdn1.lncld.net/static/js/3.0.4/av-min.js"></script>
    <script src='https://cdn.liujiefront.com/scripts/Valine.min.js'></script>
    <script>
    new Hitalk({
        el: '#comments',
        notify: false,
        verify: false,
        appId: 's9kh2bk94vxo4evf1d6m2xvif5el61nb7zk61ohqsvm5mebi',
        appKey: 'eqmmqoc8kq4om4wopea86uqk7eufw7jyeo89s3yow7jhoajj',
        placeholder: '客官，来都来了，说点什么吧~',
        path: window.location.pathname,
        avatar: 'mm'
    });

    </script>
    {% endif %}
</div>
{% endif %}
