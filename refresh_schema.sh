#!/usr/bin/env bash
OVERIDDEN_SCHEMAS="core.schema nis.schema"
CORE_SCHEMAS="core.schema cosine.schema inetorgperson.schema misc.schema nis.schema"
FD_SCHEMAS="
samba.schema core-fd.schema core-fd-conf.schema sudo-fd-conf.schema sudo.schema
service-fd.schema systems-fd-conf.schema systems-fd.schema recovery-fd.schema
mail-fd.schema mail-fd-conf.schema gpg-fd.schema ldapns.schema
openssh-lpk.schema pgp-keyserver.schema pgp-recon.schema pgp-remte-prefs.schema"
cd /etc/ldap/schema/fusiondirectory
dest=$(mktemp)
rm ${dest}
mkdir ${dest}
cd $dest
VER="${FDVER:-1.8.0.6}"
MS="${MS:-/srv/salt/makina-states}"
for i in $OVERIDDEN_SCHEMAS;do
    cp -fv $MS/files/etc/ldap/schema/$i /etc/ldap/schema/$i
done
for i in $CORE_SCHEMAS;do
    echo "include /etc/ldap/schema/$i">> fd.cfg
done
for i in $FD_SCHEMAS;do
    echo "include /etc/ldap/schema/fusiondirectory/$i">>fd.cfg
done
echo "">>fd.cfg
mkdir o
slaptest -f fd.cfg -F $PWD/o
echo "new schemas in ${PWD}"
for i in $CORE_SCHEMAS $FD_SCHEMAS;do
    set -e
    j="$(basename $i .schema).ldif"
    if [ ! -e $MS/files/etc/ldap/slapd.d/cn=config/cn=schema/$VER/cn=*"${j}" ];then
        echo "$j is not inited in $MS/files/etc/ldap/slapd.d/cn=config/cn=schema/$VER"
    fi
    fdest="$(ls $MS/files/etc/ldap/slapd.d/cn=config/cn=schema/$VER/cn=*"${j}")"
    dn=$(basename $fdest .ldif)
    cn=$(echo $dn|sed "s/^cn=//g")
    cp -fv $dest/o/cn=config/cn=schema/cn=*"${j}" ${fdest}
    sed -i -re "s/dn: .*/dn: $dn/g" $fdest
    sed -i -re "s/cn: .*/cn: $cn/g" $fdest
    set +e
done
# vim:set et sts=4 ts=4 tw=80:
