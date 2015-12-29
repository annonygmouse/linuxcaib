#! /bin/sh

#Per si el LANG no estigues ben posat, en emprar accents al zenity, fallaria.
#TODO: mirar d'emprar C.UTF-8 !!!!
if [ -z $LANG ]; then 
        export LANG=C.UTF-8
fi

#Deshabilitam proxy per assegurar-mos que les peticions al seycon van directes.
unset https_proxy
unset http_proxy

#En procés: independitzar mostrar missatges de error i warning de l'entorn (q funcioni tant a X com a terminal)
#Restricció: posicionar missatges (amb zenity pareix que no se pot...)

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


#[ "$DEBUG" -gt "0" ] && logger -t "linuxcaib-pam-auth($PAM_SERVICE-$PAM_USER)" -s "BASEDIR=$BASEDIR"
stamp=`/bin/date +'%Y%m%d%H%M%S %a'`
# get the script name (could be link)
script=`basename $0`
LOGFILE=/tmp/pam-script-auth.log

#Els usuaris locals no executen aquest script.
#Aquest script només s'executa després que la autenticació kerberos hagi anat bé.

#Si ja hi ha un usuari (seycon) loguejat (:0.0) NO hem de permetre altres logins de usuaris seycon???


EXEUSER=`whoami`
ENV=$(env)
echo $stamp Autenticació usuari \
        usu_id=$(id -u)                                \
        user=$PAM_USER des de rhost=$PAM_RHOST        \
        tty=$PAM_TTY                                \
        args=["$@"]                                \
        runnint_user=$EXEUSER                        \
        pwd=$PWD                                \
        env=$ENV  FI ENV                         \
        >> $LOGFILE

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

obte_info_usuari () {

       USER_DATA=$(wget -O - -q --http-user=$PAM_USER --http-password=$PAM_AUTHTOK --no-check-certificate https://$SEYCON_SERVER:$SEYCON_PORT/query/user/$PAM_USER )
        RESULTM=$?
        if [ ! $RESULTM -eq 0 ];then
                logger -t "linuxcaib-pam-auth($PAM_SERVICE-$PAM_USER)" -s "ERROR: dades de l'usuari ($USER) no existeixen, possiblement usuari no dins SEYCON o hi ha un error en la sincronització de contrasenyes."
                [ "$DEBUG" -gt "0" ] && logger -t "linuxcaib-pam-auth($PAM_SERVICE-$PAM_USER)"  "https://s$SEYCON_SERVER:$SEYCON_PORT/query/user/$PAM_USER userdata=$USER_DATA"
                #No donam d'alta un credentials, se crearà en fer login de lightdm
                zenity --timeout 10 --width=200 --warning --title="Accés a la xarxa corporativa" --text="ERROR, l'usuari no és un usuari de SEYCON o hi ha un error en la sincronització de contrasenyes.\nEsperau 5 minuts i tornau-ho a provar.\n\nAquest dialeg se tancara en 10 segons"
                exit 1;
        fi

        #Si és un usuari de seycon, hem de crear el credentials
        xpath="data/row[1]/USU_NOM"
        NOM_USU=$(echo $USER_DATA | xmlstarlet sel -T -t -c $xpath )
        xpath="data/row[1]/USU_PRILLI"
        PRILLI_USU=$(echo $USER_DATA | xmlstarlet sel -T -t -c $xpath )
        xpath="data/row[1]/USU_SEGLLI"
        SEGLLI_USU=$(echo $USER_DATA | xmlstarlet sel -T -t -c $xpath )
        xpath="data/row[1]/USU_NOMCUR"
        NOMCURT_USU=$(echo $USER_DATA | xmlstarlet sel -T -t -c $xpath )
        NOM_USUARI=$NOMCURT_USU
        xpath="data/row[1]/USU_ACTIU"
        USU_ACTIU=$(echo $USER_DATA | xmlstarlet sel -T -t -c $xpath )
        xpath="data/row[1]/DCO_CODI"
        DEP_USU=$(echo $USER_DATA | xmlstarlet sel -T -t -c $xpath )
        logger -t "linuxcaib-pam-auth($PAM_SERVICE-$PAM_USER)"  "Usuari actiu dins del seycon=$USU_ACTIU."
 

}

#Funció que crea l'usuari local
crear_usuari_local () {

        #També hem de donar-lo d'alta com usuari local si no existeix
        #El winbind hauria de trobar l'usuari via getent, això és només per si winbind falla.
        if [ "$(getent passwd $PAM_USER)" = "" ];then
                #Verificam que l'usuari estigui actiu
                resultAdduser=$(adduser --disabled-password --gecos "$NOMCURT_USU, $DEP_USU,,," $PAM_USER)
                [ "$DEBUG" -gt "0" ] && logger -t "linuxcaib-pam-auth($PAM_SERVICE-$PAM_USER)"  "Resultat creació usuari $PAM_USER amb adduser resultAdduser=$resultAdduser."
                if [ "$(getent passwd $PAM_USER)" = "" ];then
                        logger -t "linuxcaib-pam-auth($PAM_SERVICE-$PAM_USER)" -s "ERROR: en crear usuari amb adduser resultAdduser=$resultAdduser. "
                        zenity --timeout 20 --width=200 --error --title="Accés a la xarxa corporativa" --text="ERROR: en crear usuari amb adduser resultAdduser=$resultAdduser.\nNo es pot fer login.\n\nAquest dialeg se tancara en 20 segons"
                        exit 1;
                fi
                #DUBTE: cal definir mitjançant chage el temps validesa password etc. ????
                #Definim els groups als que pertanyara l'usuari
                adduser $PAM_USER sambashare
                adduser $PAM_USER cdrom 
                adduser $PAM_USER floppy 
                adduser $PAM_USER audio
                adduser $PAM_USER dip
                adduser $PAM_USER video
                adduser $PAM_USER plugdev 
                adduser $PAM_USER netdev 
                adduser $PAM_USER scanner 
                adduser $PAM_USER bluetooth

                #Comprovacions
                if [ ! -d /home/$PAM_USER/ ];then
                        [ "$DEBUG" -gt "0" ] && logger -t "linuxcaib-pam-auth($PAM_SERVICE-$PAM_USER)" "ERROR: no hi ha carpeta HOME de l'usuari!, el cream"
                        mkdir -p /home/$PAM_USER
                        chown $PAM_USER:"$USER_GID" /home/$PAM_USER
                fi
        else
                #Usuari ja existeix al sistema
                [ "$DEBUG" -gt "0" ] && logger -t "linuxcaib-pam-auth($PAM_SERVICE-$PAM_USER)"  "Compte d'usuari ja existent al sistema."
        fi

        if [ ! -d /home/$PAM_USER/.caib ];then
                mkdir -p /home/$PAM_USER/.caib
                #echo ".caib"
                chown $PAM_USER:"$USER_GID" /home/$PAM_USER/.caib
                [ "$DEBUG" -gt "0" ] && logger -t "linuxcaib-pam-auth($PAM_SERVICE-$PAM_USER)" "INFO: creada carpeta /home/$PAM_USER/.caib"
        fi


} #Fi crear_usuari_local


#Funció que fa el login de l'usuari al seycon. El seycon torna un identificador de sessió
#que se desa dins: /home/$PAM_USER/.caib/seycon_session_id
seycon_login () { 
        #Feim el login al seycon
        #https://sticlin2.caib.es:750/passwordLogin?action=start&user=u83511&password=PASSSWORD&clientIP=&cardSupport=NO
        USER_SEYCON_LOGIN=$(wget -O - -q --http-user=$PAM_USER --http-password=$PAM_AUTHTOK --no-check-certificate "https://$SEYCON_SERVER:$SEYCON_PORT/passwordLogin?action=start&user=$PAM_USER&password=$PAM_AUTHTOK&clientIP=&cardSupport=no" )
        [ "$DEBUG" -gt "0" ] && logger -t "linuxcaib-pam-auth($PAM_SERVICE-$PAM_USER)" "DEBUG: Resultat de passwordLogin start ($USER_SEYCON_LOGIN)"
        case $USER_SEYCON_LOGIN in
        "ERROR")        
                        if [ "$DISPLAY" != ":0.0" -a  "$DISPLAY" != ":0" ];then
                                logger -t "linuxcaib-pam-auth($PAM_SERVICE-$PAM_USER)" -s  "ERROR: el seycon no permet el login. Usuari deshabilitat?"
                        else
                                zenity --timeout 10 --width=200 --error --title="Accés a la xarxa corporativa" --text="ERROR: el seycon no permet el login. Usuari deshabilitat?\nAquest dialeg se tancara en 10 segons"
                        fi
                        exit 1;
                ;; 
        "EXPIRED")     #En teoria aquí no hauria d'entrar mai, ja que qui realment valida la contrasenya és l'AD.
		       #ERROR / BUG si la contrasenya expira avui (encara que expiri a una hora més tard, el seycon ens diu que la contrasenya ha expirat!
		       #Dins del PAM ho hem d'ignorar!
		       if [ "$DISPLAY" != ":0.0" -a  "$DISPLAY" != ":0" ];then
				logger -t "linuxcaib-pam-auth($PAM_SERVICE-$PAM_USER)" -s  "ERROR: La contrasenya expira avui, per canviar-la heu de executar \"caib-chpasswd\". Un cop canviada la contrasenya, heu de reiniciar la sessió"
				exit;
		       else 
				zenity --timeout 20 --width=400 --notification --title="Accés a la xarxa corporativa" --text="La contrasenya caduca AVUI, l'haureu de canviar i reiniciar la sessió" &
				logger -t "linuxcaib-pam-auth($PAM_SERVICE-$PAM_USER)" -s "ERROR/TODO: si la contrasenya caduca avui no podem fer login via seycon (si via AD) pero no puc canviar la contrasesnya aqui, cal fer-ho dins xsession!"
				exit;
			fi
                ;;
        esac


        USER_SEYCON_LOGIN_STATUS=$(echo $USER_SEYCON_LOGIN | cut -f 1 -d "|" )
        USER_SEYCON_LOGIN_SESSION_KEY=$(echo $USER_SEYCON_LOGIN | cut -f 2 -d "|" )
        [ "$DEBUG" -gt "0" ] && logger -t "linuxcaib-pam-auth($PAM_SERVICE-$PAM_USER)" "DEBUG: passwordLogin action=start  $USER_SEYCON_LOGIN"
        if [ "$USER_SEYCON_LOGIN_STATUS" = "OK" ];then        
                #Es OK, hem de desar clau de sessió seycon
                NOMFITXSESSIONKEY="$PAM_USER""_seycon_session_key"
                #echo "1 $USER_SEYCON_LOGIN_SESSION_KEY   $TMPMEM/$PAM_USER/$NOMFITXSESSIONKEY"                
                echo $USER_SEYCON_LOGIN_SESSION_KEY > $TMPMEM/$PAM_USER/$NOMFITXSESSIONKEY
                chown -f $PAM_USER:"$USER_GID" $TMPMEM/$PAM_USER/$NOMFITXSESSIONKEY
                chmod 600 $TMPMEM/$PAM_USER/$NOMFITXSESSIONKEY
                ln -fs $TMPMEM/$PAM_USER/$NOMFITXSESSIONKEY /home/$PAM_USER/.caib/seycon_session_id
                chown -fh $PAM_USER:"$USER_GID" /home/$PAM_USER/.caib/seycon_session_id
                [ "$DEBUG" -gt "0" ] && logger -t "linuxcaib-pam-auth($PAM_SERVICE-$PAM_USER)" "DEBUG: Fet login i creada sessió al seycon. Desada dins $TMPMEM/$PAM_USER/$NOMFITXSESSIONKEY ($USER_SEYCON_LOGIN_SESSION_KEY)"
        else
                if [ "$DISPLAY" != ":0.0" -a  "$DISPLAY" != ":0" ];then
                        logger -t "linuxcaib-pam-auth($PAM_SERVICE-$PAM_USER)" -s "ERROR: usuari/password no vàlids dins SEYCON! (error=$USER_SEYCON_LOGIN_STATUS) Esperau 5 minuts per si es un problema de sincronització de contrasenyes"
                else
                        zenity --timeout 10 --width=200 --warning --title="Accés a la xarxa corporativa" --text="ERROR: usuari/password no vàlids dins SEYCON\nError=$USER_SEYCON_LOGIN_STATUS)\nEsperau 5 minuts per si es un problema de sincronització de contrasenyes\nAquest dialeg se tancara en 10 segons"
                fi
                exit 1; 
        fi
} #Fi seycon_login


[ "$DEBUG" -gt "0" ] && logger -t "linuxcaib-pam-auth($PAM_SERVICE-$PAM_USER)"  "Inici autenticació caib"
[ "$DEBUG" -gt "0" ] && logger -t "linuxcaib-pam-auth($PAM_SERVICE-$PAM_USER)" "PAM_WINBIND_HOMEDIR=$PAM_WINBIND_HOMEDIR PAM_WINBIND_LOGONSCRIPT=$PAM_WINBIND_LOGONSCRIPT PAM_WINBIND_LOGONSERVER=$PAM_WINBIND_LOGONSERVER PAM_WINBIND_PROFILEPATH=$PAM_WINBIND_PROFILEPATH"
#Si usuari existeix i te contrasenya local NO es usuari de seycon!

if [ "$PAM_USER" = "" ];then
        logger -t "linuxcaib-pam-auth($PAM_SERVICE-$PAM_USER)" "ERROR: no tenim el PAM_USER definit! Executar \"sudo pam-auth-update\" i assegurar-se la la configuració és correcte!"
        zenity --error --timeout=10 --title="ERROR configuració autenticació"  --text="ERROR: no tenim el PAM_USER definit! Executar \"sudo pam-auth-update\" i assegurar-se la la configuració és correcte!\n\n\nAquest dialeg se tancara en 10 segons" &
        return 1;
fi
if [ "$(cat /etc/shadow | grep $PAM_USER: )"  != "" ] && [ "$(cat /etc/shadow | grep $PAM_USER: | cut -d: -f2)" != "*" ];then
        #Usuari amb password... LOCAL
        logger -t "linuxcaib-pam-auth($PAM_SERVICE-$PAM_USER)" "id=$(id -u) usuari local, desconnectat de la xarxa" 
        if [ "$DISPLAY" != ":0.0" -a  "$DISPLAY" != ":0" ];then
                echo "#ATENCIÓ: Sou un usuari LOCAL us trobau desconnectats de la Xarxa...";sleep 2;        
        else
                zenity --warning --timeout=3 --title="Usuari local"  --text="Avís: els usuaris locals no poden accedir a la xarxa\n\n\nAquest dialeg se tancara en 3 segons" &
        fi        
fi

[ "$DEBUG" -gt "0" ] && logger -t "linuxcaib-pam-auth($PAM_SERVICE-$PAM_USER)" "id=$(id $PAM_USER)"
[ "$DEBUG" -gt "0" ] && logger -t "linuxcaib-pam-auth($PAM_SERVICE-$PAM_USER)" "gid=$(id $PAM_USER -gn)"
USER_GID=$(id $PAM_USER -gn)



#MILLORAR: Mirar rhost per quan se fa login des de SSH!!!!!
if [ "$PAM_RHOST" != "" ];then
        logger -t "linuxcaib-pam-auth($PAM_SERVICE-$PAM_USER)" "PAM_RHOST=$PAM_RHOST"
fi
if [ "$PAM_RUSER" != "" ];then
        logger -t "linuxcaib-pam-auth($PAM_SERVICE-$PAM_USER)" "PAM_RUSER=$PAM_RUSER"
fi

if [ "$PAM_USER" = "ShiroKabuto" ];then
        logger -t "linuxcaib-pam-auth($PAM_SERVICE-$PAM_USER)" "Usuari ShiroKabuto, no cal fer rés"        
        exit 0;
fi


case "$PAM_SERVICE" in
    "lightdm" | "login")
         #TODO: MILLORAR HACK...
        #El lock screen de ubuntu 14.04 (compiz) empra el sevei "lightdm" per intentar fer login de nou... aleshorem hem de detectar si l'usuari ja esta 
        #loguejat... 
        if [ "$(env | grep -q COMPIZ_CONFIG_PROFILE && echo SI)" = "SI" ];then
                [ "$DEBUG" -gt "0" ] && logger -t "linuxcaib-pam-auth($PAM_SERVICE-$PAM_USER)" "Hi ha variable d'entorn de COMPIZ: $COMPIZ_CONFIG_PROFILE, no feim res, donam el login per bo."
                exit 0;
        else 
                [ "$DEBUG" -gt "0" ] && logger -t "linuxcaib-pam-auth($PAM_SERVICE-$PAM_USER)" "NO hi ha variable d'entorn de COMPIZ"

        fi
        if [ "$PAM_SERVICE" = "lightdm" ];then
                if [ -f /var/run/lightdm/root/:0 ];then
                        #Exportam XAUTHORITY i DISPLAY per a poder interactuar amb l'usuari
                        export XAUTHORITY=/var/run/lightdm/root/:0
                        export DISPLAY=$PAM_TTY
                        logger -t "linuxcaib-pam-auth($PAM_SERVICE-$PAM_USER)" -s "X11 disponible a :0"
                else
                        logger -t "linuxcaib-pam-auth($PAM_SERVICE-$PAM_USER)" -s "No hi ha X11 disponible (o DM no és ligthdm)."
                fi
                [ "$DEBUG" -gt "0" ] && logger -t "linuxcaib-pam-auth($PAM_SERVICE-$PAM_USER)"  "DEBUG: Autenticació usuari via X-Windows"
        fi

        
        TMPMEM=$(carpetaTempMemoria)
        if [ "$TMPMEM" != "" ];then
                if [ ! -d $TMPMEM/$PAM_USER ];then
                        [ "$DEBUG" -gt "0" ] && logger -t "linuxcaib-pam-auth($PAM_SERVICE-$PAM_USER)" "creant directori $TMPMEM/$NOMFITXCREDS"
                        mkdir -p $TMPMEM/$PAM_USER
                        echo "3"
                        chown $PAM_USER:"$USER_GID" $TMPMEM/$PAM_USER        
                else
                        [ "$DEBUG" -gt "0" ] && logger -t "linuxcaib-pam-auth($PAM_SERVICE-$PAM_USER)" "WARNING: Directori $TMPMEM/$NOMFITXCREDS ja existeix!"
                fi
        else
                logger -t "linuxcaib-pam-auth($PAM_SERVICE-$PAM_USER)" "No hi ha montada unitat temporal en memoria. No puc desar les credencials de l'usuari $Fitxer de credentials no trobat, en crei un amb password buid."
                zenity --timeout 10 --width=200 --warning --title="Accés a la xarxa corporativa" --text="ERROR, no hi ha disponible una partició de memòria al sistema (tmpfs).\nNo es pot fer login.\n\nAquest dialeg se tancara en 10 segons"
                exit 1;
        fi

        obte_info_usuari
        crear_usuari_local
        crear_fitxers_credencials $PAM_USER $PAM_AUTHTOK
        #enllacar_fitxers_credencials $PAM_USER $TMPMEM /home/$PAM_USER
        seycon_login 
        
        if [ "$PAM_SERVICE" = "lightdm" ];then
                #Només cream sessió al seycon si entram a les X.... ALERTA si ho movem a pam_open_session en executar-se caib-lightdm-login no hi haura donada l'alta la sessió de Mazinger!!!!   
                sh $BASEDIR/caib-conf-seyconsession.sh -u $PAM_USER -c -v
                [ "$?" != 0 ] && exit 1; #Si seyconsession torna != 0 és un error i no hem de continuar amb el login
        fi

        [ "$DEBUG" -gt "0" ] && logger -t "linuxcaib-pam-auth($PAM_SERVICE-$PAM_USER)"  "DEBUG: xauth -f /var/lib/lightdm/.Xauthority -i list  --> $(xauth -f /var/lib/lightdm/.Xauthority -i list 2>&1 | tee) "

        [ "$DEBUG" -gt "0" ] && logger -t "linuxcaib-pam-auth($PAM_SERVICE-$PAM_USER)" "Nom i cognoms usuari: $NOM_USU $PRILLI_USU $SEGLLI_USU "

        if [ "$DISPLAY" != ":0.0" -a  "$DISPLAY" != ":0" ];then
                logger -t "linuxcaib-pam-auth($PAM_SERVICE-$PAM_USER)" -s  "login de xarxa sense X (DISPLAY=$DISPLAY)"
                echo "\nBenvingut/da $NOM_USU $PRILLI_USU $SEGLLI_USU, heu entrat a la intranet de la CAIB amb l'usuari $PAM_USER\n";
          else
                logger -t "linuxcaib-pam-auth($PAM_SERVICE-$PAM_USER)" -s  "login de xarxa amb X (DISPLAY=$DISPLAY)"
                zenity --height=300 --timeout 3 --info --title="Accés a la xarxa corporativa"  --text="\n\n\n\nBenvingut/da $NOM_USU $PRILLI_USU $SEGLLI_USU, heu entrat a la intranet de la CAIB amb l'usuari $PAM_USER\n\n\n\nAquest dialeg se tancara en 3 segons" &
        fi
       ;;
    "sudo")
        [ "$DEBUG" -gt "0" ] && logger -t "linuxcaib-pam-auth($PAM_SERVICE-$PAM_USER)" "Escalant privilegis mitjançant sudo"
        ;;
    "sshd")
        logger -t "linuxcaib-pam-auth($PAM_SERVICE-$PAM_USER)" -s  "Que fer en obrir sessió de ssh? 1. Identificar si ve de la pròpia màquina (prova usuari) 2. Identificar si ve de una altra màquina (operador?? si es operador logejar-ho i fer su ShiroKabuto??). Usuari se vol connectar des de $rhost "
        if [ "$PAM_RHOST" != "" ];then
                logger -t "linuxcaib-pam-auth($PAM_SERVICE-$PAM_USER)" -s "PAM_RHOST=$PAM_RHOST."
        fi
        if [ "$PAM_RUSER" != "" ];then
                logger -t "linuxcaib-pam-auth($PAM_SERVICE-$PAM_USER)" -s "PAM_RUSER=$PAM_RUSER."
        fi
                usuariLoggedInXWindow=$(XWindowsLoggedUser)
                logger -t "linuxcaib-pam-auth($PAM_SERVICE-$PAM_USER)" "Hi ha Usuari loguejat a les X? usuariLoggedInXWindow=$usuariLoggedInXWindow "
                if [ "$usuariLoggedInXWindow" != "" ];then
                        #Hi ha un usuari loguejat.
                        logger -t "linuxcaib-pam-auth($PAM_SERVICE-$PAM_USER)" "L'usuari $usuariLoggedInXWindow esta loguejat a les X!"
                        if [ "$usuariLoggedInXWindow" != "$PAM_USER" ];then
                                #usuari que vol entrar per ssh NO es el mateix que hi ha loguejat!
                                #hem de demanar a l'usuari si autoritza aquesta entrada
                                #TODO: L'usuari que entra ha de ser administrador de la màquina (o tenir permissos vnc) o accedir des de sticlin1
                                #Per poder saber si es admin de la màquina, hem de fer el session login al seycon.
                                obte_info_usuari
                                crear_usuari_local
                                crear_fitxers_credencials $PAM_USER $PAM_AUTHTOK
                                #enllacar_fitxers_credencials $PAM_USER $TMPMEM /home/$PAM_USER
                                seycon_login 
                                #Cream sessió al seycon.... ALERTA si ho movem a pam_open_session en executar-se caib-lightdm-login no hi haura donada l'alta la sessió de Mazinger!!!!   
                                sh $BASEDIR/caib-conf-seyconsession.sh -u $PAM_USER -c -v
                                [ "$?" != 0 ] && exit 1; #Si seyconsession torna != 0 és un error i no hem de continuar amb el login
                                if [ "$(groups | grep sudo)" = "" ];then
                                        logger -t "linuxcaib-pam-auth($PAM_SERVICE-$PAM_USER)" -s  "ERROR: l'usuari NO té permissos de sudo. Significa que no és administrador de la màquina. NO li permetem l'accés";
                                        echo "ERROR: l'usuari $PAM_USER NO és administrador de la màquina. Accés denegat"
                                        exit 1;
                                fi
                                export XAUTHORITY=/home/$usuariLoggedInXWindow/.Xauthority
                                export DISPLAY
                                zenity --height=300 --question --title="Avís d'accés a la màquina"  --text="\n\n\n\nATENCIÓ: l'usuari $PAM_USER sol·licita autorització per accedir a la vostra màquina.\n" --ok-label="Autoritzar" --cancel-label="NO autoritzar" 
                                case $? in 
                                        (0) logger -t "linuxcaib-pam-auth($PAM_SERVICE-$PAM_USER)" -s  "L'usuari $usuariLoggedInXWindowNom ha autoritzat a l'usuari $PAM_USER a accedir a la màquina";
                                                exit 0;
                                                ;; 
                                        (1)     logger -t "linuxcaib-pam-auth($PAM_SERVICE-$PAM_USER)" -s  "L'usuari $usuariLoggedInXWindowNom NO ha autoritzat a l'usuari $PAM_USER a accedir a la màquina";
                                                exit 1;
                                                ;;
                                esac
                        fi
                else
                        logger -t "linuxcaib-pam-auth($PAM_SERVICE-$PAM_USER)" -s "No es permet el login via ssh si no hi ha un usuari loguejat a les X!"
                        exit 1;
                fi
        ;;
    "su")
        [ "$DEBUG" -gt "0" ] && logger -t "linuxcaib-pam-auth($PAM_SERVICE-$PAM_USER)" -s  "Que fer en autenticarse via su? "
        ;;
    *)
        [ "$DEBUG" -gt "0" ] && logger -t "linuxcaib-pam-auth($PAM_SERVICE-$PAM_USER)" -s  "NO executam res en autenticarse via $PAM_SERVICE-$PAM_USER"
        ;;
esac

logger -t "linuxcaib-pam-auth($PAM_SERVICE-$PAM_USER)" "Fi script autenticació caib (success)"
# success
exit 0
