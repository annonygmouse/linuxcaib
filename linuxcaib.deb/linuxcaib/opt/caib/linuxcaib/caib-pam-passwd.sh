#!/bin/sh

# S'executa en canviar la contrasenya. 
# Hem d'actualitzar el temps de expiració del compte local, ja que libpam-krb5 NO ho fa (o hi ha algun error)
#També hem d'actualitzar el fitxer credentials xifrat si hi ha targeta criptografica.
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

#Si debug no està definida, la definim
if [ -z $DEBUG ]; then DEBUG=0; fi
if [ "$DEBUG" -ge 3 ]; then
    # trace output
    set -x
fi



#PREREQUISITS: variable $HOME ha d'apuntar a /home/usuari/

stamp=`/bin/date +'%Y%m%d%H%M%S %a'`
# get the script name (could be link)
script=`basename $0`
#
LOGFILE=/tmp/pam-script-passwd.log


EXEUSER=`whoami`
ENV=$(env)
echo $ENV>> $LOGFILE
echo Canviant passwd de usuari PAM_SERVICE=$PAM_SERVICE\
        usu_id=$(id -u)                                \
        user=$PAM_USER des de rhost=$PAM_RHOST        \
        authTok=$PAM_AUTHTOK                        \
        old_authTok=$PAM_AUTHTOK_OLD            \
        tty=$PAM_TTY                                \
        args=["$@"]                                \
        runnint_user=$EXEUSER                        \
        pwd=$PWD                                \
        env=$ENV                                \
        >> $LOGFILE

chmod 666 $LOGFILE > /dev/null 2>&1
[ "$DEBUG" -gt "0" ] && logger -t "linuxcaib-pam-passwd($PAM_SERVICE)"  "Inici canvi contrasenya de l'usuari $PAM_USER via $PAM_SERVICE."
case "$PAM_SERVICE" in
    "lightdm"|"login"|"passwd")
        #logger -t "linuxcaib-pam-passwd($PAM_SERVICE)" -s  "Inici canviar password des  X-Window"
        if [ -f /home/$PAM_USER/.MZN_SESSION ];then        
                MZN_SESSION=$(cat /home/$PAM_USER/.MZN_SESSION)
        else 
                MZN_SESSION="";
        fi
        if [ "$MZN_SESSION"  = "" -o "$PAM_USER" != "jo" -o "$PAM_USER" != "sebastia" ];then
               [ "$DEBUG" -gt "0" ] && logger -t "linuxcaib-pam-passwd($PAM_SERVICE)" -s "L'usuari $PAM_USER (id=$(id -u)) no esta loguejat al SEYCON no hem de fer res."
        else 
                #cat /etc/shadow
                logger -t "linuxcaib-pam-passwd($PAM_SERVICE)" -s "L'usuari $PAM_USER (id=$(id -u)) esta loguejat al SEYCON"
                logger -t "linuxcaib-pam-passwd($PAM_SERVICE)" -s "Actualitzant caducitat contrasenya local"
                
                [ "$DEBUG" -gt "0" ] && logger -t "linuxcaib-pam-passwd($PAM_SERVICE)" -s "\tData canvi contrasenya: $(date +%F)"
                #No ho podem fer aqui, ja que dona error de "permission denied" chage -d $(date +%F) $PAM_USER   #Format data  yyyy-mm-dd
                [ "$DEBUG" -gt "0" ] && logger -t "linuxcaib-pam-passwd($PAM_SERVICE)" -s "\tDies fins expiració 45, avis d'expiració en faltar 7 dies"
                #No ho podem fer aqui, ja que dona error de "permission denied" chage -M 45 -W 7 $PAM_USER
                #TODO: actualitzar el password del credentials i altres fitxers.
                #TODO: re-executar el caib-conf-proxy-server per a posar la nova credencial al proxy local (cntlm) 
                #TODO: reiniciar el mazinger
                #a lo millor to do: si hi ha targeta criptografica instal·lada i pertany a l'usuari (comprovar-ho), xifrar
                #el fitxer .credentials dins $HOME/.credentials.enc mitjançant la targeta criptogràfica
                #Si no hi ha targeta criptografica i feim canvi password... eliminar el fitxer xifrat!
                #logger -t "linuxcaib-pam-passwd($PAM_SERVICE)" -s "Cercant targeta criptografica"
                #logger -t "linuxcaib-pam-passwd($PAM_SERVICE)" -s "Comprovant que sigui de l'usuari"
                #logger -t "linuxcaib-pam-passwd($PAM_SERVICE)" -s "Xifrant fitxer de credencials (demanarà pin?)"
                #TODO: reiniciar la màquina????
                logger -t "linuxcaib-pam-passwd($PAM_SERVICE)" "contrasenya canviada correctament, tancam sessio/reiniciam?"
                sleep 10
        fi
        #logger -t "linuxcaib-pam-passwd($PAM_SERVICE)" -s "Fi canviar password des  X-Window"
       ;;
    "ssh")
        logger -t "linuxcaib-pam-passwd($PAM_SERVICE)" -s  "NO feim res en canviar password de l'usuari $PAM_USER des de ssh" 
        ;;
    "sudo")
        logger -t "linuxcaib-pam-passwd($PAM_SERVICE)" -s  "NO feim res en canviar password des de sudo"
        ;;
    "su")
        logger -t "linuxcaib-pam-passwd($PAM_SERVICE)" -s  "NO feim res en canviar password des de su"
        ;;
    *)
        logger -t "linuxcaib-pam-passwd($PAM_SERVICE)" -s "NO feim res en canviar password des de $PAM_SERVICE"
        ;;
esac
[ "$DEBUG" -gt "0" ] && logger -t "linuxcaib-pam-passwd($PAM_SERVICE)"  "Fi canvi contrasenya usuari via $PAM_SERVICE (success)."

# success
exit 0
