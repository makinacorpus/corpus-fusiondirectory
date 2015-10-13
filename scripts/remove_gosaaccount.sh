#!/usr/bin/env bash
password=$(salt-call --local mc_slapd.settings --out=yaml|grep " root_pw:"|awk '{print $2}')
rdn=$(salt-call --local mc_slapd.settings --out=yaml|grep " dn:"|awk '{print $2}')
ldapsearch -Y EXTERNAL -H ldapi:/// -b $rdn objectClass=gosaAccount dn|egrep "^dn: "|sed -re "s/^dn: //g"|while read i;do
    echo $i
    rm -f ldif.ldif
    echo "
dn: $i
changetype: modify
delete: objectClass
objectClass: gosaAccount
-
delete: sambaNTPassword
-
delete: sambaBadPasswordCount
-
delete: sambaBadPasswordTime
-
delete: sambaPwdLastSet
-
add: objectClass
objectClass: fdPersonalInfo
-

" > ldif.ldif
    #cat ldif.ldif
    ldapmodify -Y EXTERNAL -H ldapi:/// -f ldif.ldif -c
done
