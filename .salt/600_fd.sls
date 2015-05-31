{% import "makina-states/_macros/h.jinja" as h with context %}
{% set cfg = opts['ms_project'] %}

fdrepo1:
  pkgrepo.managed:
    - humanname: fd ppa
    - name: deb http://repos.fusiondirectory.org/debian-extra wheezy main
    - dist: wheezy
    - file: /etc/apt/sources.list.d/fde.list
    - keyid: E184859262B4981F
    - keyserver: keyserver.ubuntu.com


fdrepo2:
  pkgrepo.managed:
    - humanname: fd ppa
    - name: deb http://repos.fusiondirectory.org/debian wheezy main
    - dist: wheezy
    - file: /etc/apt/sources.list.d/fd.list
    - keyid: ADD3A1B88B29AE4A
    - keyserver: keyserver.ubuntu.com
    - require:
      - pkgrepo: fdrepo1
fd-pre-pkgs:
  pkg.latest:
    - watch:
      - pkgrepo: fdrepo1
      - pkgrepo: fdrepo2
    - pkgs:
      - fusiondirectory-archive-keyring

fd-pkgs:
  pkg.latest:
    - watch:
      - pkg: fd-pre-pkgs
    - pkgs:
      {% for package in cfg.data.packages %}
      - {{package}}
      {% endfor %}

fd-activatemods:
  cmd.run:
    - watch:
      - pkg: fd-pkgs
    - name: for i in imap imagick readline json ldap recode curl;do php5enmod  -s cli $i;php5enmod  -s cli $i;done


{{ h.deliver_config_files(
     cfg.data.get('configs', {}),
     user='root',
     group='root',
     mode='640', prefix='fd-')}}

{% if cfg.data.get('short_mail', False) %}
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
                */10 * * * * * root su root -c "{{cfg.data_root}}/scron.sh"
{% endif %}
