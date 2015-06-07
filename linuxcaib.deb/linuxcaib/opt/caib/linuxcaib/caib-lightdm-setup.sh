#!/bin/sh

#Si no esta instalat, emprar xmessage
if [ -z $LANG ]; then 
        export LANG=C.UTF-8
fi
logger -t "linuxcaib-lightdm-setup($USER)" "uid=$(id -u) DISPLAY=$DISPLAY Inicia el setup de lightdm"

#xmessage -center -buttons : -timeout 2 "avis legal CAIB   "
#zenity --question --title "Terms and Conditions" --text "Usuari: $USER uid=$(id -u) env: $(env) Do you agree to the terms and conditions?"

#Si debug no està definida, la definim
if [ -z $DEBUG ]; then DEBUG=0; fi
if [ "$DEBUG" -ge 3 ]; then
    # trace output
    set -x
fi

#Activam nunlock
/usr/bin/numlockx on

#Importam les funcions auxiliars
#Ruta base scripts
BASEDIRPAM=$(dirname $0)

if [ "$(readlink $0)" = "" ];then
        #no es un enllaç, agafam ruta normal
        RUTA_FITXER=$(dirname $0)
        BASEDIR=$RUTA_FITXER
else
        RUTA_FITXER=$(readlink $0)
        BASEDIR=$( dirname $RUTA_FITXER)
fi

logger -t "linuxcaib-lightdm-setup($USER)" -s "BASEDIR=$BASEDIR"
[ "$DEBUG" -gt "1" ] && logger -t "linuxcaib-lightdm-setup($USER)" -s "entorn: env=$(env)"

#Hack http://davidmburke.com/2012/04/26/ubuntu-12-04-deployment-with-active-directory/
#Esperam 20 segons a que hi hagi IP
logger -t "linuxcaib-lightdm-setup($USER)" "Esperam a tenir ping"
. $BASEDIR/caib-pingtest.sh
logger -t "linuxcaib-lightdm-setup($USER)" "Ja tenim ping!"
#Per ara no feim wbinfo -u, ja que tarda bastant i retrassa el login.
#logger -t "linuxcaib-lightdm-setup($USER)" "uid=$(id -u) Inici wbinfo -u"
#nohup /usr/bin/wbinfo -u > /tmp/caib-lightdm-setup-wbinfo.out 2> /tmp/caib-lightdm-setup-wbinfo.err < /dev/null &

okAvisLegal="1";

if [ -f /etc/caib/dissoflinux/disableAvisLegal ];then
        //Avis Legal deshabilitat
        okAvisLegal=0;
fi

while [ "$okAvisLegal" != "0" ]; do
        #zenity --text-info --width=640 --height=580  --ok-label="Tancant en $SECS segons" --cancel-label="Podeu tancar aquest avis en qualsevol moment" --timeout=$SECS  \
        if [ ! -r /usr/bin/zenity ];then
                logger -t "linuxcaib-lightdm-setup($USER)" "zenity NO instal·at, emprant xmessage"
                xmessage -file $BASEDIR/avislegalcaib.txt
                okAvisLegal="$?"
        else
                zenity --text-info --width=640 --height=580  --ok-label="D'acord" --cancel-label="No estic d'acord, no entrare"   \
                       --title="Avis legal" \
                       --filename=$BASEDIR/avislegalcaib.txt 
                okAvisLegal="$?"
        fi
done


exit 0;
