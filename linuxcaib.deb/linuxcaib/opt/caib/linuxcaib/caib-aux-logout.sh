#!/bin/sh

#Logout, aquí se executen les accions comunes de tancament de sessio
#Accions independents de qui tanca la sessió, ja sigui el lightdm com el PAM (ambdos scripts criden aquest).
#En particular se fa totes les tasques de tancament de sessió per les que no cal ser root.

BASEDIRPAM=$(dirname $0)

if [ "$(readlink $0)" = "" ];then
        #no es un enllaç, agafam ruta normal
        #echo "fitxer normal"
        RUTA_FITXER=$(dirname $0)
        BASEDIR=$RUTA_FITXER
else
        #echo "enllaç"
        RUTA_FITXER=$(readlink $0)
        BASEDIR=$( dirname $RUTA_FITXER)
fi

if [ "$CAIB_CONF_SETTINGS" != "SI" ]; then
        logger -t "linuxcaib-aux-logout($USER)" -s "CAIB_CONF_SETTINGS=$CAIB_CONF_SETTINGS Carregam utils de $BASEDIR/caib-conf-utils.sh"
        #Carregam utils i settings !!!!!
        /opt/caib/linuxcaib/caib-conf-utils.sh
fi


SLEEP=0.3
LONGSLEEP=1

#Si debug no està definida, la definim
if [ -z $DEBUG ]; then DEBUG=0; fi
if [ "$DEBUG" -ge 3 ]; then
    # trace output
    set -x
fi


if [ "$USER" = "" ];then
        logger -t "linuxcaib-aux-logout($USER)" -s " no hi ha usuari definit, no feim res."
        exit 0; #Si no hi ha usuari és un canvi dins del greeter que no cal fer res. 
fi
ZENITYUNAVAILABLE=false
#Si no hi ha sessió de SEYCON/Mazinger significa que esteim desconnectats de la xarxa i no hem de fer res!
logger -t "linuxcaib-aux-logout($USER)" "Inici"
MZN_SESSION=$(cat $HOME/.caib/MZN_SESSION)
if [ "$MZN_SESSION"  = "" ];then
        logger -t "linuxcaib-aux-logout($USER)" -s "L'usuari $USER no estava loguejat al SEYCON, no feim logout de sessió"
else
        logger -t "linuxcaib-aux-logout($USER)" -s "uid=$(id -u) Logout de user=$USER"
         
        if [ -z $LANG ]; then 
                export LANG=C.UTF-8
        fi
        TIMEOUT=5
        if [ "$(zenity --width=0 --height=0 --timeout=1 --info --text "comprovant zenity..." 2>&1 | grep -v warning)" != "" ];then
                ZENITYUNAVAILABLE=true
        fi
        (
        SEC=$TIMEOUT;
        #Començam pel valor inicial que ha deixat el caib-aux-logout.sh.
        echo "30"
        echo "#Tancam sessió de seycon"
        unset https_proxy
        unset http_proxy
        
        [ "$DEBUG" -gt "0" ] && logger -t "linuxcaib-aux-logout($USER)" -s "seyconSessionUser=$seyconSessionUser"

        if [ "$seyconSessionUser" != "" ];then
                USUSEYCON=$seyconSessionUser
                PASSWORD=$seyconSessionPassword
        else
                #Com a backup intentam agafar el nom i contrasenya del fitxer credentials que hi ha dins el home de l'usuari.
                USUSEYCON=$(grep -i "^username=" $HOME/credentials | tr -d '\r'| tr -d '\n'| cut -f 2 -d "=" --output-delimiter=" ")
                PASSWORD=$(grep -i "^password=" $HOME/credentials | tr -d '\r'| tr -d '\n'| cut -f 2 -d "=" --output-delimiter=" ")
        fi     

        logger -t "linuxcaib-aux-logout($USER)" "Feim logout de l'usuari $USUSEYCON amb sessió de seycon $MZN_SESSION contra el servidor $SEYCON_SERVER"
        USER_SEYCON_LOGOUT=$(wget -O - -q --http-user=$USUSEYCON --http-password=$PASSWORD --no-check-certificate https://$SEYCON_SERVER:$SEYCON_PORT/logout?sessionId=$MZN_SESSION)
        #El logout no torna rés si va bé.
        if [ "$USER_SEYCON_LOGOUT_STATUS" = "" ];then
                rm $HOME/.caib/.MZN_SESSION
                logger -t "linuxcaib-aux-logout($USER)" "Sessió $MZN_SESSION dins SEYCON tancada"
        else
                [ "$DEBUG" -gt "0" ] && logger -t "linuxcaib-aux-logout($USER)" "ERROR: no he pogut tancar la sessió dins SEYCON emprant: https://$SEYCON_SERVER:$SEYCON_PORT/logout?sessionId=$MZN_SESSION"
                logger -t "linuxcaib-aux-logout($USER)" "ERROR: no he pogut tancar la sessió dins SEYCON! (error=$USER_SEYCON_LOGOUT)"        
        fi
        echo "40";
        echo "#Aturant daemon-session";
        PID_SESSION_DAEMON=$(ps aux|grep tclsh| grep caib-session-daemon| awk '{print $2}')
        [ "$DEBUG" -gt "0" ] && logger -t "linuxcaib-aux-logout($USER)" "DEBUG: feim el kill del caib-session-daemon de l'usuari (pid=$PID_SESSION_DAEMON)"
        kill $PID_SESSION_DAEMON
        echo "50";
        echo "60" ;echo "#Aturam el proxy local";sleep $SLEEP;
        TMPMEM=$(carpetaTempMemoria)
        RUTAPIDCNTLM="$TMPMEM/""$USER/""$USER""_cntlm.pid"
        [ "$DEBUG" -gt "0" ] && logger -t "linuxcaib-aux-logout($USER)" "DEBUG: feim el kill del cntlm de l'usuari (pid=$(cat $RUTAPIDCNTLM))"
        kill $(cat $RUTAPIDCNTLM)
        if [ "$?" != "0" ];then
                logger -t "linuxcaib-aux-logout($USER)" "ERROR: no he pogut fer el kill del cntlm ($(kill $(cat $RUTAPIDCNTLM)) ), provaré fent killall"
                killall -u $USER cntlm;
        fi
        [ "$DEBUG" -gt "0" ] && logger -t "linuxcaib-aux-logout($USER)" "DEBUG: aturam mazinger: $(mazinger stop)" 
        echo "#Aturant mazinger"
        if [ "$(mazinger status|grep -q 'Mazinger started' && echo SI)" = "SI" ];then
                echo "#Aturant mazinger"
                mazinger stop
        fi
        echo "70" ; sleep $SLEEP
        #Elimin de memòria els fitxers amb credencials, clau de sessió seycon, identificador de sessió seycon etc.
        TMPMEM=$(/bin/df -t tmpfs |grep shm| awk 'BEGIN  { FS=" "} {print $6}')
        CARPETACREDENCIALSETC="$TMPMEM/""$USER/"
        rm -fr $CARPETACREDENCIALSETC
        echo "80" ; echo "#Eliminant contrasenyes...";sleep $SLEEP
        logger -t "linuxcaib-aux-logout($USER)" "Eliminant contrasenyes"
        #Esborram usuaris i passwords en clar
        if [ -f $HOME/.wgetrc ];then
                sed '/user=/d' $HOME/.wgetrc -i
                sed '/password=/d' $HOME/.wgetrc -i
        fi
        if [ -f /etc/cntlm.conf ];then
                sed '/Username/d' /etc/cntlm.conf -i
                sed '/Password/d' /etc/cntlm.conf -i        
        fi
        
        echo "100"
        echo "# Fi"
        ) | ( [ "$ZENITYUNAVAILABLE" = false ] && /usr/bin/zenity --no-cancel --progress --title="Accés a la xarxa corporativa" --auto-close --text "Tancant la sessió CAIB." )

        USER_LIGHTDM_LOGOUT_EXECUTAT="S"
        export USER_LIGHTDM_LOGOUT_EXECUTAT

fi # de [ "$MZN_SESSION"  = ""
