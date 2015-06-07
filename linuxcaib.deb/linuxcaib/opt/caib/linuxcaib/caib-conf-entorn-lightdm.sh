#!/bin/sh

#Script que detecta l'entorn de l'usuari.
#Tasques que fa:
#   1. Mira si la màquina està normalitzada (intranet, extranet, internet)
#   2. Comprova que l'usuari pugui crear carpetes i fitxers al seu home.

BASEDIR=$(dirname $0)
if [ "$CAIBCONFUTILS" != "SI" ]; then
        logger -t "linuxcaib-conf-entorn($USER)" "Carregam utilitats de $BASEDIR/caib-conf-utils.sh"
        . $BASEDIR/caib-conf-utils.sh
fi

#Si debug no està definida, la definim
if [ -z $DEBUG ]; then DEBUG=0; fi
if [ "$DEBUG" -ge 3 ]; then
    # trace output
    set -x
fi


## DETECCIÓ ENTORN - lightdm

#Miram si esteim dins una màquina normalitzada.
HOSTNAME=$(hostname)
if ( isNormalized $HOSTNAME );then
        logger -t "linuxcaib-conf-entorn-lightdm($USER)" "Màquina ($HOSTNAME) normalitzada -> INTRANET"
else
        logger -t "linuxcaib-conf-entorn-lightdm($USER)" "Màquina ($HOSTNAME) NO normalitzada -> EXTRANET"
        /usr/bin/zenity --timeout 5 --warning --title="Accés a la xarxa corporativa" --text="Màquina ($HOSTNAME) NO normalitzada -> EXTRANET\n\n Si és un error, telefonau al vostre CAU."
fi

#Miram si /tmp te els permissos correctes
permissosTemp=$(stat -c "%a %n" /tmp |cut -d" " -f1)
if [ "$permissosTemp" != "1777" ];then
        chmod 1777 /tmp
fi

permissosTemp=$(stat -c "%a %n" /tmp |cut -d" " -f1)
if [ "$permissosTemp" != "1777" ];then
                 logger -t "linuxcaib-conf-entorn-lightdm($USER)" "ERROR: Usuari NO pot crear fitxer dins la carpeta temporal"
                 /usr/bin/zenity  --error --title="Accés a la xarxa corporativa" --text="ERROR: No podeu crear fitxers a la carpeta temporal (/tmp)!\n\nNo podeu entrar a aquest equip.\n\n Telefonau al vostre CAU." 
        exit 1;
fi

#Comprovam que la carpeta HOME de l'usuari existeixi i NO sigui propietat de root!
if [ ! -d /home/$USER ];then
        logger -t "linuxcaib-conf-entorn-lightdm($USER)" "ERROR: No existeix el home de l'usuari!"
        /usr/bin/zenity  --error --title="Accés a la xarxa corporativa" --text="ERROR: No existeix el home de l'usuari!\n\nNo podeu entrar a aquest equip.\n\n Telefonau al vostre CAU." 
        exit 1;     
else
        
        if [ "$(stat -c "%U" /home/$USER)" != "$USER" ];then
                logger -t "linuxcaib-conf-entorn-lightdm($USER)" "ERROR: El propietari del home de l'usuari no és l'usuari sinó $(stat -c "%U" /home/$USER)"
                /usr/bin/zenity  --error --title="Accés a la xarxa corporativa" --text="ERROR: El propietari del home de l'usuari no és l'usuari sinó $(stat -c "%U" /home/$USER)!\n\nNo podeu entrar a aquest equip.\n\n Telefonau al vostre CAU." 
                exit 1;     
        fi
fi


exit 0;
## FI DETECCIÓ ENTORN - lightdm


