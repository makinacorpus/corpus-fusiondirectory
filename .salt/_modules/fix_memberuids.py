#!/usr/bin/env python
from __future__ import absolute_import
from __future__ import division
from __future__ import print_function

import copy
import logging
import traceback
import pprint
import ldap
import ldap.modlist

log = logging.getLogger(__name__)

import re

def natural_sort(l):
    convert = lambda text: int(text) if text.isdigit() else text.lower()
    alphanum_key = lambda key: [ convert(c) for c in re.split('([0-9]+)', key) ]
    return sorted(l, key = alphanum_key)


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
    '''
    Synchronnise groups towards their memberuids/members
    '''
    _s = __salt__
    cfg = copy.deepcopy(_s['mc_project.get_configuration'](project))
    data = cfg['data']
    ldap_uri = data['ldap_client']['uri']
    ldap_kw = data['ldap_client']['kw']
    groups = data['groups_dn']
    users = data['users_dn']
    groups_search = ldap_kw.copy()
    groups_search['base'] = groups
    users_search = ldap_kw.copy()
    users_search['base'] = users
    bkw = ldap_kw.copy()
    bkw.pop('base')
    candidates = query(
        ldap_uri,
        '(&(objectClass=groupOfNames)(objectClass=posixGroup))',
        scope='onelevel',
        retrieve_attributes=[],
        **groups_search)
    for dn, data in candidates:
        modlists = []
        memberuids = data.get('memberUid', [])
        members = data.get('member', [])
        memberuids.sort(key=natural_sort)
        members.sort(key=natural_sort)
        nmembers = members[:]
        nmemberuids = memberuids[:]
        for uid in memberuids:
            if not uid:
                continue
            lusers = query(ldap_uri,
                           'uid={0}'.format(uid, users),
                           scope='onelevel',
                           retrieve_attributes=[],
                           **users_search)
            for luser in lusers:
                if luser[0] not in members:
                    log.info('UID: Adding {0} to {1}'.format(uid, dn))
                    nmembers.append(luser[0])


        for member in members:
            bkw['base'] = member
            try:
                users = query(ldap_uri,
                              'objectClass=*',
                              scope='base',
                              retrieve_attributes=[],
                              **bkw)
            except ldap.NO_SUCH_OBJECT:
                log.error('{0} does not exists'.format(member))
                continue
            for luser in users:
                uids = luser[1].get('uid', [])
                for uid in uids:
                    if uid not in nmemberuids:
                        log.info('MEMBER: Adding {0} to {1}'.format(uid, dn))
                        nmemberuids.append(uid)
        mold = {}
        mmod = {}
        for a, new, old in (
            ('memberUid', nmemberuids, memberuids),
            ('member', nmembers, members),
        ):
            if new != old:
                mold[a] = old
                mmod[a] = new
        if mmod:
            modlists.append((dn,
                             ldap.modlist.modifyModlist(mold, mmod)))
        for dn, modlist in modlists:
            with __salt__[
                'mc_ldap.get_handler'
            ](ldap_uri, **ldap_kw) as handler:
                conn = handler.connect()
                try:
                    conn.modify_s(dn, modlist)
                    log.info('{0} group modified'.format(dn))
                except Exception:
                    trace = traceback.format_exc()
                    log.error('{0} group NOT modified'.format(dn))
                    log.error(trace)
# vim:set et sts=4 ts=4 tw=80:
