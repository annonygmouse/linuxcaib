#! /bin/sh

 Script de libpam-script per fer login mitjançant certificat digital

if [ -z $LANG ]; then 
        export LANG=C.UTF-8
fi
#Importam les funcions auxiliars
#Ruta base scripts
BASEDIRPAM=$(dirname $0)
echo "\$0 = $0"
echo "readlink 0 = $(readlink $0)"

if [ "$(readlink $0)" = ""];then
        #no es un enllaç, agafam ruta normal
        echo "fitxer normal"
        RUTA_FITXER=$(dirname $0)
        BASEDIR=$RUTA_FITXER
else
        echo "enllaç"
        RUTA_FITXER=$(readlink $0)
        BASEDIR=$( dirname $RUTA_FITXER)
fi
#basedir es /usr/share/...pamscripts/


stamp=`/bin/date +'%Y%m%d%H%M%S %a'`
# get the script name (could be link)
script=`basename $0`
#
LOGFILE=/tmp/pam-script-auth.log

#Els usuaris locals no executen aquest script.
#Aquest script només s'executa després que la autenticació kerberos hagi anat bé.

#Si ja hi ha un usuari (seycon) loguejat (:0.0) NO hem de permetre altres logins de usuaris seycon???


EXEUSER=`whoami`
ENV=$(env)
echo Autenticació amb certificat digital \
        usu_id=$(id -u)                                \
        user=$PAM_USER des de rhost=$PAM_RHOST        \
        authTok=$PAM_AUTHTOK                        \
        tty=$PAM_TTY                                \
        args=["$@"]                                \
        runnint_user=$EXEUSER                        \
        pwd=$PWD                                \
        env=$ENV                                \
        >> $LOGFILE



echo "BASEDIRPAM=$BASEDIRPAM  BASEDIR: $BASEDIR , RUTA_FITXER=$RUTA_FITXER"
if [ "$CAIB_CONF_SETTINGS" != "SI" ]; then
        logger -t "linuxcaib-conf-drives($USER)" -s "CAIB_CONF_SETTINGS=$CAIB_CONF_SETTINGS Carregam utils de $BASEDIR/caib-conf-utils.sh"
        . $BASEDIR/caib-conf-utils.sh
fi

#Si existeix fitxer DEBUG_PAM llegim el valor que conté (0,1,2) i sera el nivell de debug
if [ -f $BASEDIR/DEBUG_PAM ];then
        DEBUG=$(cat $BASEDIR/DEBUG_PAM )
fi

#Si debug no està definida, la definim
if [ -z $DEBUG ]; then DEBUG=0; fi


#Obté el seyconsessionid 
iniciar_cert_login_seycon () {

        certLoginResponse=$(wget -O - -q --no-check-certificate https://$SEYCON_SERVER:$SEYCON_PORT/certificateLogin?actiona=start )
        RESULTM=$?
        if [ ! $RESULTM -eq 0 ];then
                logger -t "linuxcaib-pam-certauth($USER)" -s "ERROR: no he pogut iniciar sessió al servidor SEYCON  https://$SEYCON_SERVER:$SEYCON_PORT/certificateLogin?actiona=start response=$certLoginResponse"
                zenity --timeout 10 --width=200 --warning --title="Accés a la xarxa corporativa" --text="ERROR: no he pogut iniciar sessió al servidor SEYCON"
                exit 1;
        fi

        USER_SEYCON_LOGIN_STATUS=$(echo $certLoginResponse | cut -f 1 -d "|" )
        CERT_SEYCON_LOGIN_SESSION_KEY=$(echo $certLoginResponse | cut -f 2 -d "|" )
        [ "$DEBUG" -gt "0" ] && logger -t "linuxcaib-pam-certauth($PAM_SERVICE)" "DEBUG: qasswordLogin action=start  $USER_SEYCON_LOGIN"
        if [ "$USER_SEYCON_LOGIN_STATUS" = "OK" ];then        
                echo $CERT_SEYCON_LOGIN_SESSION_KEY
        else
                logger -t "linuxcaib-pam-certauth($PAM_SERVICE)" -s "ERROR: iniciant sessió al servidor SEYCON"
                zenity --timeout 10 --width=200 --warning --title="Accés a la xarxa corporativa" --text="ERROR: no he pogut iniciar sessió al servidor SEYCON\nAquest dialeg se tancara en 10 segons"
                exit 1; 
        fi
} #Fi Obté el seyconsessionid




stamp=`/bin/date +'%Y%m%d%H%M%S %a'`
# get the script name (could be link)
script=`basename $0`
#
LOGFILE=/tmp/pam-script-auth.log

EXEUSER=`whoami`
ENV=$(env)
[ "$DEBUG" -gt "0" ] && echo Autenticació usuari PAM_SERVICE=$PAM_SERVICE\
        usu_id=$(id -u)                                \
        user=$PAM_USER des de rhost=$PAM_RHOST        \
#        authTok=$PAM_AUTHTOK                        \
        tty=$PAM_TTY                                \
        args=["$@"]                                \
        runnint_user=$EXEUSER                        \
        pwd=$PWD                                \
        env=$ENV                                \
        >> $LOGFILE
#echo "entorn: $ENV" >> $LOGFILE

chmod 666 $LOGFILE > /dev/null 2>&1



[ "$DEBUG" -gt "0" ] && logger -t "linuxcaib-pam-certauth($PAM_SERVICE)"  "Inici autenticació usuari via $PAM_SERVICE."
case "$PAM_SERVICE" in
    "lightdm"|"login")

        if [ -f /var/run/lightdm/root/:0 ];then
                #Exportam XAUTHORITY i DISPLAY per a poder interactuar amb l'usuari
                export XAUTHORITY=/var/run/lightdm/root/:0
                export DISPLAY=$PAM_TTY
        else
                logger -t "linuxcaib-pam-ses_open($PAM_SERVICE)" -s "No hi ha X11 disponible (o DM no és ligthdm)."
        fi

        [ "$DEBUG" -gt "0" ] && logger -t "linuxcaib-pam-certauth($PAM_SERVICE)"  "Autenticació usuari via X-Windows ($PAM_SERVICE)"
        #TODO:
        #1. emprar/montar un disk a memoria (tempfs) | disk encriptat
        #2. crear fitxer $USER_caib_credentials dins disk a memoria

        unset https_proxy
        unset http_proxy

        CERT_SEYCON_SESSION=$(iniciar_cert_login_seycon)
        #Es OK, hem de xifrar la clau de sessió seycon i enviar la clau publica del certificat
        [ "$DEBUG" -gt "0" ] && logger -t "linuxcaib-pam-certauth($PAM_SERVICE)" -s "DEBUG: Fet login i creada sessió al seycon. Desada dins $TMPMEM/$PAM_USER/$NOMFITXSESSIONKEY ($USER_SEYCON_LOGIN_SESSION_KEY)"


      zenity --height=300 --timeout 3 --info --title="Accés a la xarxa corporativa"  --text="\n\n\n\nBenvingut/da $NOM_USU $PRILLI_USU $SEGLLI_USU, heu entrat a la intranet de la CAIB amb l'usuari $PAM_USER\n\n\n\nAquest dialeg se tancara en 3 segons" &
  
       ;;
    "sudo")
        [ "$DEBUG" -gt "0" ] && echo "TODO: que fer en autenticarse via sudo? " >> $LOGFILE
        ;;
    "ssh")
        [ "$DEBUG" -gt "0" ] && echo "TODO: que fer en obrir sessió de ssh? 1. Identificar si ve de la pròpia màquina (prova usuari) 2. Identificar si ve de una altra màquina (operador?? si es operador logejar-ho i fer su ShiroKabuto). " >> $LOGFILE
        ;;
    "su")
        [ "$DEBUG" -gt "0" ] && echo "TODO: que fer en autenticarse via su? " >> $LOGFILE
        ;;
    *)
        [ "$DEBUG" -gt "0" ] && echo "NO executam res en autenticarse via $PAM_SERVICE " >> $LOGFILE
        ;;
esac

[ "$DEBUG" -gt "0" ] && echo "Fi script autenticació caib via ($PAM_SERVICE)"
# success
exit 0
