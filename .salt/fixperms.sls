{% set cfg = opts['ms_project'] %}
{# export macro to callees #}
{% set cfg = salt['mc_usergroup.settings']() %}
{% set locs = salt['mc_locations.settings']() %}
{% set cfg = opts['ms_project'] %}
{% set lsettings = cfg.data.local_settings %}
{{cfg.name}}-restricted-perms:
  file.managed:
    - name: {{cfg.project_dir}}/global-reset-perms.sh
    - mode: 750
    - user: {% if not cfg.no_user%}{{cfg.user}}{% else -%}root{% endif %}
    - group: {{cfg.group}}
    - contents: |
            #!/usr/bin/env bash
            if [ -e "{{cfg.pillar_root}}" ];then
            "{{locs.resetperms}}" -q "${@}" \
              --dmode '0771' --fmode '0770' \
              --user root --group "{{cfg.group}}" \
              --users root \
              --groups "{{cfg.group}}" \
              --paths "{{cfg.pillar_root}}";
            fi
            if [ -e "{{cfg.project_root}}" ];then
             {{locs.resetperms}} -q --no-recursive --only-acls\
              --paths "{{cfg.project_root}}/.."\
              --paths "{{cfg.project_root}}/../.."\
              --users {{cfg.user}}:r-x \
              --groups {{cfg.group}}:r-x \
              --groups {{salt['mc_apache.settings']().httpd_user}}:r-x;
             {{locs.resetperms}} -q\
              --fmode 550 --dmode 771 \
              --paths "{{cfg.project_dir}}/global-reset-perms.sh"\
              --users {{cfg.user}}:rwx \
              --groups {{cfg.group}}:rwx \
              --groups {{salt['mc_apache.settings']().httpd_user}}:r-x;
             {{locs.resetperms}} -q --no-recursive\
              -u {{cfg.user}} -g {{cfg.group}}\
              --fmode 771 --dmode 771 \
              --paths "{{cfg.project_root}}"\
              --users {{cfg.user}}:rwx \
              --groups {{cfg.group}}:rwx \
              --groups {{salt['mc_apache.settings']().httpd_user}}:r-x;
             find "{{cfg.project_root}}" "{{cfg.data_root}}" -name .git|while read f;do
               {{locs.resetperms}} -q\
                --fmode 770 --dmode 771 --paths "${f}"\
                -u {{cfg.user}} -g {{cfg.group}}\
                --users {{cfg.user}}:rwx --groups {{cfg.group}}:rwx;
             done
             chmod o+x "{{cfg.project_root}}/.." "{{cfg.project_root}}/../..";
             find "{{cfg.project_root}}" -maxdepth 1 -mindepth 1|egrep -v "/(bin|lib|www|\.git)"|while read f;do
               {{locs.resetperms}} -q\
                  --fmode 661 --dmode 551 \
                  -u {{cfg.user}} -g {{cfg.group}}\
                  --paths "$f"\
                  --users {{cfg.user}}:rw- \
                  --groups {{cfg.group}}:r-x \
                  --groups {{salt['mc_apache.settings']().httpd_user}}:r-x;
             done
             find "{{cfg.data_root}}/var" "{{cfg.project_root}}" -maxdepth 1 -mindepth 1|\
              egrep "/(bin|lib|www|sites|run|private|tmp|log)"|while read f;do
                {{locs.resetperms}} -q\
                  --fmode 771 --dmode 771 \
                  -u {{cfg.user}} -g {{cfg.group}}\
                  --paths "$f"\
                  --users {{cfg.user}}:rwx \
                  --groups {{cfg.group}}:r-x \
                  --groups {{salt['mc_apache.settings']().httpd_user}}:r-x;
             done
             find "{{cfg.data_root}}/var/run" -type s|while read f;do
                  chmod 771 "${f}"
                  chown {{cfg.user}}:{{cfg.group}} "${f}"
                  setfacl -bR "${f}"
                  setfacl -m u:{{cfg.user}}:rwx "${f}"
                  setfacl -m g:{{cfg.group}}:rwx "${f}"
                  setfacl -m u:{{salt['mc_apache.settings']().httpd_user}}:rwx "${f}"
             done
             {{locs.resetperms}} -q --no-recursive\
               --fmode 771 --dmode 771 \
               -u {{cfg.user}} -g {{cfg.group}}\
               --paths "{{cfg.data_root}}"\
               --paths "{{cfg.data_root}}/var"\
               --users {{cfg.user}}:rwx \
               --groups {{cfg.group}}:rwx \
               --groups {{salt['mc_apache.settings']().httpd_user}}:r-x;
            {{locs.resetperms}} -q --no-recursive\
               --fmode 444 --dmode 661 \
               -u {{cfg.user}} -g {{cfg.group}}\
               --paths "{{cfg.project_root}}"/www/index.php\
               --users {{cfg.user}}:r-- \
               --groups {{cfg.group}}:r-- \
               --groups {{salt['mc_apache.settings']().httpd_user}}:r--;
            fi
  cmd.run:
    - name: {{cfg.project_dir}}/global-reset-perms.sh
    - cwd: {{cfg.project_root}}
    - user: root
    - watch:
      - file: {{cfg.name}}-restricted-perms

{{cfg.name}}-fixperms:
  file.managed:
    - name: /etc/cron.d/{{cfg.name.replace('.', '_')}}-fixperms
    - user: root
    - mode: 744
    - contents: |
                {{cfg.data.cron_periodicity}} root {{cfg.project_dir}}/global-reset-perms.sh

