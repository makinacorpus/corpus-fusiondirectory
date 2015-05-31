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
    candidates = query(ldap_uri, 'objectClass=posixGroup',
                       retrieve_attributes=['memberUid', 
                                            'objectClass',
                                            'member'],
                       **ldap_kw)
    deltas = {}
    for dn, data in candidates:
        members = data.get('member', [])
        memberuids = data.get('memberUid', [])
        for m in memberuids:
            found = False
            for n in members:
                if n.startswith('uid=' + m):
                    found = True
            if not found:
                delta = deltas.setdefault(dn, [])
                if m not in delta:
                    delta.append(m)
    log.error('those are even dangling memberuids not attached to members')
    log.error(pprint.pformat(deltas))
# vim:set et sts=4 ts=4 tw=80:
