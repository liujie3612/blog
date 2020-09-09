{%
  set js_commons = [
    'https://cdn.liujiefront.com/hexo/js/utils.js',
    'https://cdn.liujiefront.com/hexo/js/motion.js'
  ]
%}

{% for common in js_commons %}
  <script type="text/javascript" src="{{ common }}?v={{ theme.version }}"></script>
{% endfor %}
