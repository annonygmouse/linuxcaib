#!/bin/sh
if [ -z $LANG ]; then 
        export LANG=C.UTF-8
fi
#Importam les funcions auxiliars
#Ruta base scripts
BASEDIRPAM=$(dirname $0)
#echo "\$0 = $0"
#echo "readlink 0 = $(readlink $0)"

if [ "$(readlink $0)" = "" ];then
        #no es un enllaç, agafam ruta normal
  #      echo "fitxer normal"
        RUTA_FITXER=$(dirname $0)
        BASEDIR=$RUTA_FITXER
else
   #     echo "enllaç"
        RUTA_FITXER=$(readlink $0)
        BASEDIR=$( dirname $RUTA_FITXER)
fi

#Si existeix fitxer DEBUG_PAM llegim el valor que conté (0,1,2) i sera el nivell de debug
if [ -r /etc/caib/linuxcaib/DEBUG_PAM ];then
        DEBUG=$(cat /etc/caib/linuxcaib/DEBUG_PAM )
fi

#Si debug no està definida, la definim
if [ -z $DEBUG ]; then DEBUG=0; fi
if [ "$DEBUG" -ge 3 ]; then
    # trace output
    set -x
fi

aturar_seycon_session_daemon () {
        echo "#Aturant daemon-session"; sleep $SLEEP
        PID_SESSION_DAEMON=$(ps aux|grep $PAM_USER | grep tclsh| grep caib-session-daemon| awk '{print $2}')
        [ "$DEBUG" -gt "0" ] && logger -t "linuxcaib-pam-ses_close($PAM_SERVICE-$PAM_USER)" "DEBUG: feim el kill del caib-session-daemon de l'usuari (pid=$PID_SESSION_DAEMON)"

        #kill $PID_SESSION_DAEMON
}

#Aquest script s'ha d'executar en tancar sessió de PAM

#PREREQUISITS: variable $HOME ha d'apuntar a /home/usuari/

# DEPRECATED!!!!!! És millor fer la feina en fer session-cleanup del lightdm, així podem mostrar info a l'usuari.
#  HAURIEM DE CRIDAR EL MATEIX SCRIPT AMB PARAMETRE "SILENT" PER ASSEGURAR-MOS QUE ELIMINAM TOT EL QUE TOCA.

#Si debug no està definida, la definim
if [ -z $DEBUG ]; then DEBUG=0; fi


stamp=`/bin/date +'%Y%m%d%H%M%S %a'`
# get the script name (could be link)
script=`basename $0`
#
LOGFILE=/tmp/pam-script-ses_close.log


EXEUSER=`whoami`
ENV=$(env)
echo $ENV>> $LOGFILE
[ "$DEBUG" -gt "0" ] && echo Tancant sessió usuari PAM_SERVICE=$PAM_SERVICE\
        usu_id=$(id -u)                                \
        user=$PAM_USER des de rhost=$PAM_RHOST        \
        authTok=$PAM_AUTHTOK                        \
        tty=$PAM_TTY                                \
        args=["$@"]                                \
        runnint_user=$EXEUSER                        \
        pwd=$PWD                                \
        env=$ENV                                \
        >> $LOGFILE

chmod 666 $LOGFILE > /dev/null 2>&1
[ "$DEBUG" -gt "0" ] && logger -t "linuxcaib-pam-ses_close($PAM_SERVICE-$PAM_USER)" "Inici script close session caib via ($PAM_SERVICE)"
if [ "$PAM_USER" = "ShiroKabuto" ];then
        logger -t "linuxcaib-pam-ses_close($PAM_SERVICE-$PAM_USER)" "Usuari ShiroKabuto, no cal fer rés"        
        exit 0;
fi

case "$PAM_SERVICE" in
    "lightdm"|"login")
        #logger -t "linuxcaib-pam-ses_close($PAM_SERVICE-$PAM_USER)" -s  "Inici tancar sessió X-Window"
        MZN_SESSION=$(cat $HOME/.caib/MZN_SESSION 2> /dev/null)
        if [ "$MZN_SESSION"  = "" ];then
                logger -t "linuxcaib-pam-ses_close($PAM_SERVICE-$PAM_USER)"  "L'usuari $USER no estava loguejat al SEYCON o ja ha fet logout"
        else 
                logger -t "linuxcaib-pam-ses_close($PAM_SERVICE-$PAM_USER)" -s "L'usuari $USER encara esta loguejat al SEYCON, hem de fer logout"
                logger -t "linuxcaib-pam-ses_close($PAM_SERVICE-$PAM_USER)" -s "user=$PAM_USER TODO: si no s'ha fet logout de lightdm(per exemple perque s'ha donat a apagar en comptes de sortir sessio), fer logout aqui USER_LIGHTDM_LOGOUT_EXECUTAT=$USER_LIGHTDM_LOGOUT_EXECUTAT"
                aturar_seycon_session_daemon
        fi
        #logger -t "linuxcaib-pam-ses_close($PAM_SERVICE)" -s "Fi tancar sessió X-Window"
       ;;
    "sshd")
         [ "$DEBUG" -gt "0" ] && logger -t "linuxcaib-pam-ses_close($PAM_SERVICE-$PAM_USER)" "Tancant sessió de sshd."
        ;;
    "sudo")
        [ "$DEBUG" -gt "1" ] && logger -t "linuxcaib-pam-ses_close($PAM_SERVICE-$PAM_USER)" "Tancant sessió de sudo"
        ;;
    "su")
        [ "$DEBUG" -gt "1" ] && logger -t "linuxcaib-pam-ses_close($PAM_SERVICE-$PAM_USER)" "Tancant sessió de su"
        ;;
    *)
        [ "$DEBUG" -gt "1" ] && logger -t "linuxcaib-pam-ses_close($PAM_SERVICE-$PAM_USER)" "NO executam res en tancar sessió de $PAM_SERVICE "
        ;;
esac

[ "$DEBUG" -gt "0" ] && logger -t "linuxcaib-pam-ses_close($PAM_SERVICE-$PAM_USER)" "Fi script close session caib (success)"

# success
exit 0
