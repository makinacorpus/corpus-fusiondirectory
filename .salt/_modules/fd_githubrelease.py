#!/usr/bin/env python
from __future__ import absolute_import
from __future__ import division
from __future__ import print_function


import json
import copy
import logging
import re
import pprint
import os
import requests
from requests.auth import HTTPBasicAuth

log = logging.getLogger(__name__)
J = os.path.join


def main(project='fusiondirectory',
         version='1.0.9',
         download=True,
         github_release=True,
         **kwargs):
    _s = __salt__
    cfg = copy.deepcopy(_s['mc_project.get_configuration'](project))
    data = cfg['data']
    root = J(cfg['project_root'], 'release')
    tok = HTTPBasicAuth(data['gh_user'], data['gh_pw'])
    fdv = data['fd_ver']
    if not os.path.exists(root):
        os.makedirs(root)
    if download:
        for i in data['fdpkgs']:
            cmd = "wget -c '{0}/{1}/{2}_{3}.deb'".format(
                data['fd_mirror'],
                data['fd_mirror_path'],
                i,
                data['deb_ver'])
            cret = __salt__['cmd.run_all'](cmd, use_vt=True, cwd=root)
            if cret['retcode'] != 0:
                pprint(cret)
                raise Exception('{0} failed'.format(cmd))
    if github_release:
        u = "https://api.github.com/repos/{0}".format(data['fd_gh'])
        releases = requests.get("{0}/releases".format(u), auth=tok)
        pub = releases.json()
        if fdv not in [a['name'] for a in pub]:
            cret = requests.post(
                "{0}/releases".format(u),
                auth=tok,
                data=json.dumps({'tag_name': fdv,
                                 'name': fdv,
                                 'body': fdv}))
            if 'created_at' not in cret.json():
                pprint(cret)
                raise ValueError('error creating release')
            pub = requests.get("{0}/releases".format(u), auth=tok).json()
            if fdv not in [a['name'] for a in pub]:
                raise ValueError('error getting release')
        release = [a for a in pub if a['name'] == fdv][0]
        for i in data['fdpkgs']:
            assets = requests.get("{0}/releases/{1}/assets".format(
                u, release['id']), auth=tok).json()
            toup = "{0}_{1}.deb".format(i, data['deb_ver'])
            if toup not in [a['name'] for a in assets]:
                fpath = J(root, toup)
                size = os.stat(fpath).st_size
                with open(fpath) as fup:
                    fcontent = fup.read()
                    upurl = re.sub(
                        '{.*', '', release['upload_url']
                    )+'?name={0}&size={1}'.format(toup, size)
                    cret = requests.post(
                        upurl, auth=tok,
                        data=fcontent,
                        headers={
                            'Content-Type':
                            'application/vnd.debian.binary'})
                    jret = cret.json()
                    if jret.get('size', '') != size:
                        pprint(jret)
                        raise ValueError('upload failed')
# vim:set et sts=4 ts=4 tw=80:
