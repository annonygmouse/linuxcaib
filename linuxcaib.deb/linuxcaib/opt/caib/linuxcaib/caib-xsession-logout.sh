#!/bin/sh

#Aquest script s'executa en fer Xreset.
#Aquest script s'executa com a root posant el codi de l'usuari dins la variable USER 

if [ -z $LANG ]; then 
        export LANG=C.UTF-8
fi

#Si debug no està definida, la definim
if [ -z $DEBUG ]; then DEBUG=0; fi
if [ "$DEBUG" -ge 3 ]; then
    # trace output
    set -x
fi

logger -t "linuxcaib-xsession-logout($USER)"  "uid=$(id -u) Feim Xreset"

if [ "$USER" = "" ];then
        exit 0; #Si no hi ha usuari és un canvi dins del greeter que no cal fer res. 
fi

BASEDIR=$(dirname $0)
if [ "$CAIBCONFUTILS" != "SI" ]; then
        [ "$DEBUG" -gt "0" ] && logger -t "linuxcaib-conf-drives($USER)" -s "CAIBCONFUTILS=$CAIBCONFUTILS Carregam utilitats de $BASEDIR/caib-conf-utils.sh"
        . $BASEDIR/caib-conf-utils.sh
fi

ZENITYUNAVAILABLE=false
MZN_SESSION=$(cat $HOME/.caib./MZN_SESSION)
if [ "$MZN_SESSION"  = "" ];then
        #Si no hi ha sessió de SEYCON/Mazinger significa que esteim desconnectats de la xarxa i no hem de fer res!
        logger -t "linuxcaib-xsession-logout($USER)" "L'usuari $USER no estava loguejat al SEYCON, no feim logout de sessió"

        zenity --notification --timeout=3 --title="desconnectat de la xarxa"  --text="Sortint de sessió d'usuari local"

        sleep 10 
        logger -t "linuxcaib-xsession-logout($USER)" "despres de mostrar missatge zenity de logout de sessió"
                
else
        logger -t "linuxcaib-xsession-logout($USER)" "uid=$(id -u) Logout de xsession de usuari $USER amb sessió de seycon"
        export LANG=C.UTF-8
        if [ "$(zenity --width=0 --height=0 --timeout=1 --info --text "comprovant zenity..." 2>&1 | grep -v warning)" != "" ];then
                ZENITYUNAVAILABLE=true
        fi
        TIMEOUT=5
        (
        SEC=$TIMEOUT;
        echo "#Tancant la sessió CAIB...";
        echo 10
        barra=10
        for unitat in $(/bin/df -P  | grep $USER | grep -v $PSERVER_LINUX | grep -v $PSERVER | awk 'BEGIN  { FS=" "} {print $6}');do
                echo "# Desmontant unitat ($unitat)"
                umount $unitat
                sync
                #TODO: comprovar que el umount ha anat bé i podem esborrar el directori.
                barra=$((barra=barra+1)) 
                sleep 0.5
        done;
        logger -t "linuxcaib-xsession-logout($USER)" "Unitats de xarxa de l'usuari desmontades"
        echo 30
        echo "# Fi"
        ) | ( [ "$ZENITYUNAVAILABLE" = false ] && /usr/bin/zenity --no-cancel --progress --title="Accés a la xarxa corporativa" --auto-close --text "Tancant la sessió CAIB." )
        #Tancament comu de sessió (coses que se poden fer sense ser root!)
        #Fa fora de la barra de progrés anterior perque te la seva propia barra de progres, ja que potser se cridi des de PAM.       
        . $BASEDIR/caib-aux-logout.sh
fi
export USER_LIGHTDM_LOGOUT_EXECUTAT="S"

