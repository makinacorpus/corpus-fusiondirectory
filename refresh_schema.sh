#!/usr/bin/env bash
OVERIDDEN_SCHEMAS="
core.schema
nis.schema
"
CORE_SCHEMAS="
core.schema
cosine.schema
inetorgperson.schema
misc.schema
nis.schema"
FD_SCHEMAS="
samba.schema
core-fd.schema
core-fd-conf.schema
sudo-fd-conf.schema
sudo.schema
service-fd.schema
systems-fd-conf.schema
systems-fd.schema
recovery-fd.schema
mail-fd.schema
mail-fd-conf.schema
gpg-fd.schema
ldapns.schema
openssh-lpk.schema
pgp-keyserver.schema
pgp-recon.schema
pgp-remte-prefs.schema
"

cd /etc/ldap/schema/fusiondirectory
dest=$(mktemp)
rm ${dest}
mkdir ${dest}
cd $dest
VER="${FD_VER:-1.9.0}"
PVER="${FD_PREVER:-1.8.0.9}"
MS="${MS:-/srv/salt/makina-states}"
sdest="$MS/files/etc/ldap/slapd.d/cn=config/cn=schema/$VER"
spdest="$MS/files/etc/ldap/slapd.d/cn=config/cn=schema/$PVER"
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
rsync -azv --delete "${PWD}/o/cn=config/cn=schema/" "${sdest}/"
echo "new schemas in ${PWD}"
echo "ported to $sdest"
# vim:set et sts=4 ts=4 tw=80:
