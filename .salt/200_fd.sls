{% set cfg = opts['ms_project'] %}
{% set scfg = salt['mc_utils.json_dump'](cfg)%}

fdrepo1:
  pkgrepo.managed:
    - humanname: fd ppa
    - name: deb http://repos.fusiondirectory.org/debian-extra stable main
    - dist: stable
    - file: /etc/apt/sources.list.d/fde.list
    - keyid: E184859262B4981F
    - keyserver: keyserver.ubuntu.com


fdrepo2:
  pkgrepo.managed:
    - humanname: fd ppa
    - name: deb http://repos.fusiondirectory.org/debian stable main
    - dist: stable
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

