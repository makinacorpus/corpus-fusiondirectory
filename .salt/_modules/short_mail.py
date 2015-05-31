#!/usr/bin/env python
from __future__ import absolute_import
from __future__ import division
from __future__ import print_function

import copy
import logging
import pprint
import ldap

log = logging.getLogger(__name__)


def query(uri, search=None, retrieve_attributes=None, **kw):
    '''

    '''
    with __salt__['mc_ldap.get_handler'](uri, **kw) as handler:
        results = handler.query(search,
                                retrieve_attributes=retrieve_attributes,
                                base=kw.get('base', None),
                                scope=kw.get('scope', None))
        return results


def main(project='fusiondirectory', **kwargs):
    _s = __salt__
    cfg = copy.deepcopy(_s['mc_project.get_configuration'](project))
    data = cfg['data']
    ldap_uri = data['ldap_client']['uri']
    ldap_kw = data['ldap_client']['kw']
    candidates = query(ldap_uri, 'objectClass=person',
                       retrieve_attributes=[],
                       **ldap_kw)
    deltas = {}
    for dn, data in candidates:
        shortmails = mails = data.get('shortMail', [])
        mails = data.get('mail', []) + data.get('gosaMailAlternateAddress', [])
        if not mails:
            continue
        if True in ['template' in a.lower() for a in data['objectClass']]:
            continue
        if mails and not shortmails:
            shortmail = ["{0}@{1}".format(data['uid'][0],
                                          data['mail'][0].split('@')[1])]
            if shortmail != shortmails:
                with __salt__[
                    'mc_ldap.get_handler'
                ](ldap_uri, **ldap_kw) as handler:
                    conn = handler.connect()
                    modl = ldap.modlist.modifyModlist(
                        {'shortMail': shortmails}, {'shortMail': shortmail})
                    ret = conn.modify_s(dn, modl)
                    log.info('{0} shortmail added'.format(data['uid']))
# vim:set et sts=4 ts=4 tw=80:
