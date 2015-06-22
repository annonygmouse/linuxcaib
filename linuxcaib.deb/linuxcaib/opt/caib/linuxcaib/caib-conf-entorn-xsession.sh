#!/bin/sh

#Script que detecta l'entorn de l'usuari.
#Tasques que fa:
#   1. Mira si la màquina està normalitzada (intranet, extranet, internet)
#   2. Comprova que l'usuari pugui crear carpetes i fitxers al seu home.

BASEDIR=$(dirname $0)
if [ "$CAIBCONFUTILS" != "SI" ]; then
        logger -t "linuxcaib-conf-entorn-xsession($USER)" "Carregam utilitats de $BASEDIR/caib-conf-utils.sh"
        . $BASEDIR/caib-conf-utils.sh
fi

#Si debug no està definida, la definim
if [ -z $DEBUG ]; then DEBUG=0; fi
if [ "$DEBUG" -ge 3 ]; then
    # trace output
    set -x
fi


## DETECCIÓ ENTORN

#Miram si pot crear carpetes dins del seu HOME de filesystem
result_mkdir=$(mktemp -d -p $HOME)
if [ $? -eq 0 ];then
        [ "$DEBUG" -gt "0" ] && logger -t "linuxcaib-conf-entorn-xsession($USER)" "Usuari pot crear carpetes dins el seu home ($result_mkdir)"
        rm -fr $result_mkdir 
        
else
        logger -t "linuxcaib-conf-entorn-xsession($USER)" "ERROR: Usuari NO pot crear carpetes dins el seu home"
        /usr/bin/zenity  --error --title="Accés a la xarxa corporativa" --text="ERROR: No podeu crear carpetes vostre HOME\n\nNo podeu entrar a aquest equip.\n\n Telefonau al vostre CAU."
fi

#Miram si pot crear fitxers dins del seu HOME de filesystem
result_mkfile=$(mktemp -p $HOME)
if [ $? -eq 0 ];then
        [ "$DEBUG" -gt "0" ] && logger -t "linuxcaib-conf-entorn-xsession($USER)" "Usuari pot crear fitxer dins el seu home"
        rm -fr $result_mkfile;
else
        logger -t "linuxcaib-conf-entorn-xsession($USER)" "ERROR: Usuari NO pot crear fitxer dins el seu home"
        /usr/bin/zenity --timeout 20  --error --title="Accés a la xarxa corporativa" --text="ERROR: No podeu crear fitxers al vostre HOME.\n\nNo podeu entrar a aquest equip.\n\n Telefonau al vostre CAU." 
        exit 1;
fi

#Miram si pot crear fitxers dins la carpeta temporal
result_mkfile=$(mktemp -p /tmp )
if [ "$?" = "0" ];then
        [ "$DEBUG" -gt "0" ] && logger -t "linuxcaib-conf-entorn-xsession($USER)" "Usuari pot crear carpetes dins la carpeta /tmp ($result_mkdir)"
        rm -fr $result_mkdir       
else
        logger -t "linuxcaib-conf-entorn-xsession($USER)" "ERROR: Usuari NO pot crear fitxer dins la carpeta temporal"
        /usr/bin/zenity --timeout 20  --error --title="Accés a la xarxa corporativa" --text="ERROR: No podeu crear fitxers a la carpeta temporal (/tmp).\n\nNo podeu entrar a aquest equip.\n\n Telefonau al vostre CAU." 
        exit 1;
fi

#Comprovam que el login hagi estat contra l'active directory (que te els roles agafats de l'AD)

if [ ! -f /etc/caib/linuxcaib/allowKerberosUsers ];then
        if [ "$(id |grep "domain users")" = "" ];then
                logger -t "linuxcaib-conf-entorn-xsession($USER)" "ALERTA: Usuari NO te ID de active directory! Potser ja tengui usuari local creat? O no s'ha fet login mitjançant winbind, sinó només via kerberos. Potser no hi hagi winbind dins /etc/nsswitch."
                /usr/bin/zenity --timeout 10  --error --title="Accés a la xarxa corporativa" --text="ALERTA: Usuari NO te ID de active directory! No continuam."
                exit 1;
        fi
fi

## FI DETECCIÓ ENTORN

