{% import "makina-states/_macros/h.jinja" as h with context %}
{% set cfg = opts['ms_project'] %}
{% set data = cfg.data %}

fdpin:
  file.absent:
    - names:
      - /etc/apt/preferences.d/fd.pref
      - /etc/apt/sources.list.d/fde.list
      - /etc/apt/sources.list.d/fde.list

fd-pkgs:
  pkg.{{data.installmode}}:
    - watch:
      - file: fdpin
    - pkgs:
      {% for package in cfg.data.packages %}
      - {{package}}
      {% endfor %}

{% set fd_ver = data.fd_ver %}

{% set oprepkg = ''%}
{% set prepkg = ''%}

{% set dv =  data['deb_ver'][fd_ver] %}

{% for i in data.fdpkgs %}
{% set fn = '{0}_{1}_all.deb'.format(i, dv) %}
{% set oprepkg = prepkg %}
{% set prepkg = 'fd-{i}-pkg-fd'.format(i=i) %}

{# circular dep#}
{% set dpkg_arg='' %}
{% if 'argonaut' in i %}
{% set dpkg_arg = '--force-all' %}
{% endif %}
{{prepkg}}:
  file.managed:
    - name: "{{cfg.project_root}}/dl{{fd_ver}}/{{fn}}"
    - source: "https://github.com/makinacorpus/corpus-fusiondirectory/releases/download/{{fd_ver}}/{{fn}}"
    - source_hash: "md5={{data.files[fn]}}"
    - user: root
    - makedirs: true
    - group: root
    - mode: 644
    - watch:
      - pkg: fd-pkgs
      {% if oprepkg %}
      - file: {{oprepkg}}
      {% endif %}
  cmd.run:
    - name: dpkg -i {{dpkg_arg}} "{{cfg.project_root}}/dl{{fd_ver}}/{{fn}}"
    - use_vt: true
    - unless: dpkg -l|egrep ^ii|awk '{print $2 "___" $3}'|egrep '^{{i}}___'|grep  $(echo "{{dv}}"|sed -re "s/(_(all|amd64|i386))?$//g")
    - watch_in:
      - mc_proxy: fd-pkgs-release-hook
    - watch:
      - pkg: fd-pkgs
      - file: {{prepkg}}
      {% if oprepkg %}
      - file: {{oprepkg}}
      {% endif %}
{% endfor %}

fd-pkgs-release-hook:
  mc_proxy.hook: []

{% set exts='imap imagick readline json ldap recode curl'%}
fd-activatemods:
  cmd.run:
    - watch:
      - mc_proxy: fd-pkgs-release-hook
    - name: for i in {{exts}};do php5enmod  -s $i $i;php5enmod  -s cli $i;done
    - onlyif: |
              for i in {{exts}};do if [ ! -e "/etc/php5/fpm/conf.d/"*"${i}"* ];then exit 0;fi;done
              exit 1

{{ h.deliver_config_files(
     cfg.data.get('configs', {}),
     user='root',
     group='root',
     mode='640', prefix='fd-')}}

{% if not cfg.data.get('short_mail', False) %}
make-short-cron-2:
  file.absent:
    - names:
      - "{{cfg.data_root}}/scron.sh"
      - "/etc/cron.d/{{cfg.name}}scron"
{%else %}
make-short-cron-2:
  file.managed:
    - name: "{{cfg.data_root}}/scron.sh"
    - mode: 700
    - user: root
    - group: root
    - contents: |
                #!/bin/bash
                salt-call --local -lall short_mail.main >log 2>&1
                if [ "x$?" != "x0" ];then
                cat log
                fi
                rm -f log

make-short-cron-1:
  file.managed:
    - name: "/etc/cron.d/{{cfg.name}}scron"
    - mode: 700
    - user: root
    - group: root
    - contents: |
                */10 * * * * root su root -c "{{cfg.data_root}}/scron.sh"
{% endif %}

{# NOMOREUSED: we have too much patches, easier to track with git #}
{% set patches = data['patches'].get(fd_ver, []) + data['extra_patches'].get('fd_ver', []) %}
{% set opatch = '' %}
{% for patch in patches %}
{% set patch = '{0}/.salt/files/patches/{1}'.format(cfg.project_root, patch)%}
{% set patchid = 'apply-group-patch-' + patch %}
{{patchid}}:
  cmd.run:
    - name: patch -Np1 < "{{patch}}"
    - onlyif: patch -Np1 --dry-run  < "{{patch}}"
    - cwd: /usr/share/fusiondirectory
    - require:
      - mc_proxy: fd-pkgs-release-hook
      {% if opatch %}
      - cmd: {{opatch}}
      {% endif%}
{% set opatch = patchid %}
{% endfor %}

git-checkout:
  file.directory:
    - name: "{{cfg.data_root}}/noacls"
    - user: root
    - group: root
    - mode: 750
    - require:
      - mc_proxy: fd-pkgs-release-hook
  cmd.run:
    - name: setfacl -b -k "{{cfg.data_root}}/noacls"
    - require:
      - file: git-checkout
  git.latest:
    - name: "{{data.fd_overrides.git}}"
    - target: "{{cfg.data_root}}/noacls/fusiondirectory"
    - rev: "{{data.fd_overrides.rev}}"
    - require:
      - cmd: git-checkout

git_deploy:
  cmd.run:
    - name: rsync -aAzv --delete "{{cfg.data_root}}/noacls/fusiondirectory/" "/usr/share/fusiondirectory/"
    - require:
      - git: git-checkout

