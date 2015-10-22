#!/bin/sh

#Script que crida la configuració del scrensaver actiu

#Importam les funcions auxiliars
#Ruta base scripts
BASEDIR=$(dirname $0)
if [ "$CAIBCONFUTILS" != "SI" ]; then
        logger -t "linuxcaib-conf-screensaver($USER)" -s "CAIBCONFUTILS=$CAIBCONFUTILS Carregam utilitats de $BASEDIR/caib-conf-utils.sh"
        . $BASEDIR/caib-conf-utils.sh
fi

#Si debug no està definida, la definim
if [ -z $DEBUG ]; then DEBUG=0; fi
if [ "$DEBUG" -ge 3 ]; then
    # trace output
    set -x
fi

logger -t "linuxcaib-conf-screensaver($USER)" -s "INFO: Iniciant script comprovació configuració bloqueig d'estació d'usuari"

if [ "$XDG_CURRENT_DESKTOP" = "" ]
then
  desktop=$(echo "$XDG_DATA_DIRS" | sed 's/.*\(xfce\|kde\|gnome\).*/\1/')
else
  desktop=$XDG_CURRENT_DESKTOP
fi
desktop=$(echo $desktop | tr '[:upper:]' '[:lower:]')
case "$desktop" in
    "gnome"|"unity")
        logger -t "linuxcaib-conf-screensaver($USER)" -s "L'escriptori emprat es $desktop, configurant gnome-screensaver"
        if ( paquetInstalat "gnome-screensaver" );then
                . $BASEDIR/caib-conf-gnome-screensaver.sh
        else
                logger -t "linuxcaib-conf-screensaver($USER)" -s "ERROR: gnome-screensaver NO instal·lat."
                zenity --error --title="Configuració bloqueig d'estació d'usuari" --text="ERROR: no teniu instal·lat el paquet 'gnome-screensaver'"
        fi
    ;;
    "kde")
        logger -t "linuxcaib-conf-screensaver($USER)" -s "L'escriptori emprat es $desktop i encara no hi ha suport per aquest entorn."
    ;;
    "xfce"|"*")
        logger -t "linuxcaib-conf-screensaver($USER)" -s "L'escriptori emprat es $desktop configurant xscreensaver."
        if ( paquetInstalat "xscreensaver" );then
                . $BASEDIR/caib-conf-xscreensaver.sh
        else
                logger -t "linuxcaib-conf-screensaver($USER)" -s "ERROR: xscreensaver NO instal·lat."
                zenity --error --title="Configuració bloqueig d'estació d'usuari" --text="ERROR: no teniu instal·lat el paquet 'xscreensaver'"
        fi
    ;;
esac

