{%
    set js_commons = [
      'https://cdn.liujiefront.com/js/fundebug/fundebug.2.0.0.min.js'
    ]
%}

{% for common in js_commons %}
<script type="text/javascript" src="{{ common }}?v={{ theme.version }}" apikey="bb1521f6307a600cba20a62702bc6a28a7a3ba83590f3d671ec403dcd04f198f" crossorigin="anonymous"></script>
<script type="text/javascript" src="https://cdn.liujiefront.com/js/fundebug/fundebug.revideo.0.6.0.min.js"></script>
{% endfor %}