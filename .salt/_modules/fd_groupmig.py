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
    candidates = query(ldap_uri, 'objectClass=gosaMailAccount',
                       retrieve_attributes=[],
                       **ldap_kw)
    deltas = ""
    for dn, data in candidates:
        if 'posixGroup' not in data['objectClass']:
            continue
        udata = copy.deepcopy(data)
        if 'fdGroupMailLocalOnly' not in data:
            udata['fdGroupMailLocalOnly'] = ["FALSE"]
        if 'fdGroupMail' not in udata['objectClass']:
            udata['objectClass'].append('fdGroupMail')
        modl = ldap.modlist.modifyModlist(data, udata)
        #if True in ['template' in a.lower() for a in data['objectClass']]:
        #    continue
        if modl:
            with __salt__[
                'mc_ldap.get_handler'
            ](ldap_uri, **ldap_kw) as handler:
                conn = handler.connect()
                ret = conn.modify_s(dn, modl)
                log.info('{0} group migrated to fdGroupMail'.format(data['cn']))
                deltas += "{0}".format(modl)
    return deltas
# vim:set et sts=4 ts=4 tw=80:
