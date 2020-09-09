{%
  set boot_scripts = [
    'https://cdn.liujiefront.com/hexo/js/bootstrap.js'
  ]
%}

{% for bs in boot_scripts %}
  <script type="text/javascript" src="{{ bs }}?v={{ theme.version }}"></script>
{% endfor %}
