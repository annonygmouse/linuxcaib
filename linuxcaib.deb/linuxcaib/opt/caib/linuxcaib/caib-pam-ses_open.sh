#! /bin/sh

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
        #echo "fitxer normal"
        RUTA_FITXER=$(dirname $0)
        BASEDIR=$RUTA_FITXER
else
        #echo "enllaç"
        RUTA_FITXER=$(readlink $0)
        BASEDIR=$( dirname $RUTA_FITXER)
fi

#echo "BASEDIRPAM=$BASEDIRPAM  BASEDIR: $BASEDIR , RUTA_FITXER=$RUTA_FITXER"
if [ "$CAIB_CONF_SETTINGS" != "SI" ]; then
        #logger -t "linuxcaib-conf-drives($USER)" -s "CAIB_CONF_SETTINGS=$CAIB_CONF_SETTINGS Carregam utils de $BASEDIR/caib-conf-utils.sh"
        . $BASEDIR/caib-conf-utils.sh
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


stamp=`/bin/date +'%Y%m%d%H%M%S %a'`
# get the script name (could be link)
script=`basename $0`
#
LOGFILE=/tmp/pam-script-ses_open.log

#Primer de tot demanam contrasenya per administració.
EXEUSER=`whoami`
ENV=$(env)
[ "$DEBUG" -gt "0" ] && echo Inici sessió usuari PAM_SERVICE=$PAM_SERVICE\
        DEBUG=$DEBUG \
        usu_id=$(id -u)                                \
        user=$PAM_USER des de rhost=$PAM_RHOST        \
        authTok=$PAM_AUTHTOK                        \
        tty=$PAM_TTY                                \
        args=["$@"]                                \
        runnint_user=$EXEUSER                        \
        pwd=$PWD                                \
        env=$ENV  FI ENV                              \
        >> $LOGFILE

#Alerta! la variable d'entorn HOME apunta a root (/). No al home de l'usuari!
chmod 666 $LOGFILE > /dev/null 2>&1

#SEYCON_SERVER=sticlin2.caib.es #Servidor de seycon a emprar emprar tant sticlin2.caib.es com stsmlin3.caib.es
#SEYCON_PORT=750 #Port del servidor seycon

if [ "$PAM_USER" = "ShiroKabuto" ];then
        logger -t "linuxcaib-pam-ses_open($PAM_SERVICE-$PAM_USER)" "Usuari ShiroKabuto, no cal fer rés"        
        exit 0;
fi

arrancar_seycon_session_daemon () { 
        TMPMEM=$(/bin/df -t tmpfs |grep shm| awk 'BEGIN  { FS=" "} {print $6}')
        SSODAEMONPORT=$( cat "$TMPMEM/""$PAM_USER/""$PAM_USER""_ssodaemonport")
        logger -t "linuxcaib-pam-ses_open($PAM_SERVICE-$PAM_USER)" "iniciant caib-session-daemon"
        logger -t "linuxcaib-pam-ses_open($PAM_SERVICE-$PAM_USER)" "SSODAEMONPORT=$SSODAEMONPORT"
        logger -t "linuxcaib-pam-ses_open($PAM_SERVICE-$PAM_USER)" "MZN_SESSION=$(cat /home/$PAM_USER/.caib/MZN_SESSION)"
        logger -t "linuxcaib-pam-ses_open($PAM_SERVICE-$PAM_USER)" "seycon_session_id=$(cat /home/$PAM_USER/.caib/seycon_session_id)"
        #su -c "tclsh /opt/caib/linuxcaib/caib-session-daemon.tcl $SSODAEMONPORT $(cat $HOME/.caib/MZN_SESSION) $(cat $HOME/.caib/seycon_session_id) &" $PAM_USER
}


#Per ara deshabilit debug d'aquest script
[ "$DEBUG" -gt "0" ] && logger -t "linuxcaib-pam-ses_open($PAM_SERVICE-$PAM_USER)" "Inici script open session caib home=$HOME"

case "$PAM_SERVICE" in
    "lightdm" | "login")
               #logger -t "linuxcaib-pam-ses_open($PAM_SERVICE-$PAM_USER)" -s  "Inici obrir sessió"
        if [ -f /var/run/lightdm/root/:0 ];then
                export XAUTHORITY=/var/run/lightdm/root/:0
                export DISPLAY=$PAM_TTY
        else
                logger -t "linuxcaib-pam-ses_open($PAM_SERVICE-$PAM_USER)" "No hi ha X11 disponible (o DM no és ligthdm)."
        fi
        #zenity --height=300 --timeout 3 --info --title=" 0.0 "  --text="\n\n\n\n0\n\n\n\nAquest dialeg se tancara en 3 segons"

        [ "$DEBUG" -gt "0" ] && logger -t "linuxcaib-pam-ses_open($PAM_SERVICE-$PAM_USER)" "Rés a fer per ara"
        if [ "$(cat /home/$PAM_USER/.caib/MZN_SESSION 2> /dev/null)" != "" ];then        
                arrancar_seycon_session_daemon
        else
                logger -t "linuxcaib-pam-ses_open($PAM_SERVICE-$PAM_USER)" "Usuari local"        
        fi
        #logger -t "linuxcaib-pam-ses_open($PAM_SERVICE-$PAM_USER)" -s "Fi obrir sessió"
       ;;
    "sudo")
        [ "$DEBUG" -gt "1" ] && logger -t "linuxcaib-pam-ses_open($PAM_SERVICE-$PAM_USER)" -s "Obrint sessió de sudo." 
        ;;
    "sshd")
        [ "$DEBUG" -gt "0" ] && logger -t "linuxcaib-pam-ses_open($PAM_SERVICE-$PAM_USER)" -s "Obrint sessió de sshd." 
        if [ "$PAM_USER" = "ShiroKabuto" ];then
               [ "$DEBUG" -gt "0" ] && logger -t "linuxcaib-pam-passwd($PAM_SERVICE-$PAM_USER)" -s "ERROR: L'usuari ShiroKabuto és un usuari per accés exclusivament LOCAL."
               echo "ERROR: L'usuari ShiroKabuto és un usuari per accés exclusivament LOCAL................"
               exit 1;
        fi
        ;;
    "su")
        [ "$DEBUG" -gt "1" ] && logger -t "linuxcaib-pam-ses_open($PAM_SERVICE-$PAM_USER)" -s "Obrint sessió de su."
        ;;
    *)
        [ "$DEBUG" -gt "1" ] && logger -t "linuxcaib-pam-ses_open($PAM_SERVICE-$PAM_USER)" -s "NO executam res en obrir sessió de $PAM_SERVICE-$PAM_USER " 
        ;;
esac

[ "$DEBUG" -gt "0" ] && logger -t "linuxcaib-pam-ses_open($PAM_SERVICE-$PAM_USER)" "Fi script open session caib per l'usuari (success)"
# success
exit 0
