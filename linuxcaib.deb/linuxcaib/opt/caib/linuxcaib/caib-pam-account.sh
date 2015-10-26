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
LOGFILE=/tmp/pam-script-account.log

#Primer de tot demanam contrasenya per administració.
EXEUSER=`whoami`
ENV=$(env)
[ "$DEBUG" -gt "0" ] && echo Inici account usuari PAM_SERVICE=$PAM_SERVICE\
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
        logger -t "linuxcaib-pam-account($PAM_SERVICE-$PAM_USER)" "Usuari ShiroKabuto, no cal fer rés"        
        exit 0;
fi


#Per ara deshabilit debug d'aquest script
[ "$DEBUG" -gt "1" ] && logger -t "linuxcaib-pam-account($PAM_SERVICE-$PAM_USER)" "Inici script open account caib home=$HOME"
[ "$DEBUG" -gt "0" ] && logger -t "linuxcaib-pam-account($PAM_SERVICE-$PAM_USER)" "PAM_WINBIND_HOMEDIR=$PAM_WINBIND_HOMEDIR PAM_WINBIND_LOGONSCRIPT=$PAM_WINBIND_LOGONSCRIPT PAM_WINBIND_LOGONSERVER=$PAM_WINBIND_LOGONSERVER PAM_WINBIND_PROFILEPATH=$PAM_WINBIND_PROFILEPATH"
case "$PAM_SERVICE" in
    "lightdm" | "login")
        logger -t "linuxcaib-pam-account($PAM_SERVICE-$PAM_USER)" -s  "Account env=$(env)"
       ;;
    "sudo")
        [ "$DEBUG" -gt "1" ] && logger -t "linuxcaib-pam-account($PAM_SERVICE-$PAM_USER)" -s "Obrint account de sudo." 
        ;;
    "sshd")
        [ "$DEBUG" -gt "0" ] && logger -t "linuxcaib-pam-account($PAM_SERVICE-$PAM_USER)" -s "Obrint account de sshd." 
        ;;
    "su")
        [ "$DEBUG" -gt "1" ] && logger -t "linuxcaib-pam-account($PAM_SERVICE-$PAM_USER)" -s "Obrint account de su."
        ;;
    *)
        [ "$DEBUG" -gt "1" ] && logger -t "linuxcaib-pam-account($PAM_SERVICE-$PAM_USER)" -s "NO executam res en obrir account de $PAM_SERVICE-$PAM_USER " 
        ;;
esac

[ "$DEBUG" -gt "1" ] && logger -t "linuxcaib-pam-account($PAM_SERVICE-$PAM_USER)" "Fi script account caib per l'usuari (success)"
# success
exit 0
