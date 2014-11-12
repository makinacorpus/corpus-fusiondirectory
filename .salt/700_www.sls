{% set cfg = opts['ms_project'] %}
{% import "makina-states/services/http/apache/init.sls" as apache with context %}
{% import "makina-states/services/php/init.sls" as php with context %}
include:
  - makina-states.services.php.phpfpm_with_apache
{% set data = cfg.data %}
# the fcgi sock is meaned to be at docroot/../var/fcgi/fpm.sock;

# incondentionnaly reboot nginx & fpm upon deployments
echo reboot:
  cmd.run:
    - watch_in:
      - mc_proxy: makina-apache-pre-restart
      - mc_proxy: makina-apache-php-pre-restart

{{apache.virtualhost(cfg.data.domain, cfg.data.www_dir, **cfg.data.apache_vhost)}}
{{php.fpm_pool(cfg.data.domain, cfg.data.www_dir, **cfg.data.fpm_pool)}}
