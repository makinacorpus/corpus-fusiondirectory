{% set cfg = opts['ms_project'] %}
{% set scfg = salt['mc_utils.json_dump'](cfg)%}
{% set php = salt['mc_php.settings']() %}
{% set data = cfg.data %}
include:
  - makina-states.services.dns.slapd
