#!/bin/sh
#set -x
#Aquest script duu a terme l'alta de la sessió de l'usuari dins del SEYCON
#Com sabem si l'usuari està loguejat a alguna altra màquina?
# Perque en fer login torna error es.caib.sso.TooManySessionsException. Si te permissos de MULTISESSIO aquest error no el dona mai.

#Per si el LANG no estigues ben posat, en emprar accents al zenity, fallaria.
export LANG=C.UTF-8

#Deshabilitam proxy per assegurar-mos que les peticions al seycon van directes.
unset https_proxy
unset http_proxy

#Si debug no està definida, la definim
if [ -z $DEBUG ]; then DEBUG=0; fi
if [ "$DEBUG" -ge 3 ]; then
    # trace output
    set -x
fi

if [ "$(readlink $0)" = "" ];then
        #no es un enllaç, agafam ruta normal
        RUTA_FITXER=$(dirname $0)
        BASEDIR=$RUTA_FITXER
else
        RUTA_FITXER=$(readlink $0)
        BASEDIR=$( dirname $RUTA_FITXER)
fi

#[ "$DEBUG" -gt "0" ] && logger -t "linuxcaib-pam-auth($PAM_SERVICE-$USERNAME)" -s "BASEDIR=$BASEDIR"

if [ "$CAIB_CONF_SETTINGS" != "SI" ]; then
        #logger -t "linuxcaib-conf-drives($USER)" -s "CAIB_CONF_SETTINGS=$CAIB_CONF_SETTINGS Carregam utils de $BASEDIR/caib-conf-utils.sh"
        . $BASEDIR/caib-conf-utils.sh
fi


#echo "Parametres: $@."
#echo "Env= $(env)"

show_caib_conf_seyconsession_help () {
cat << EOF
El programa "${0##*/}" dona d'alta la sessió de l'usuari d'aquesta màquina dins del SEYCON.

Ús: ${0##*/} [-hcv] [-u USUARI] [-p PASSWORD]

      -h          mostra aquesta ajuda
      -u USUARI   nom de l'usuari a emprar
      -p PASSWORD contrasenya de l'usuari a emprar
      -c          agafa les credencials del fitxer "credentials". IMPORTANT, l'usuari ha de ser l'usuari de SEYCON.
      -v          mode verbose

Exemples:
        ${0##*/} -u u83511 -p password_u83511   Execució passant usuari i contrasenya
        ${0##*/} -c     Execució emprant fitxer de credencials
EOF
}

#Fi funcions


# A POSIX variable
OPTIND=1         # Reset in case getopts has been used previously in the shell.

# Initialize our own variables:
output_file=""

while getopts "hcv?u:p:" opt; do
    case "$opt" in
    h|\?)
        show_caib_conf_seyconsession_help
        exit 0
        ;;
    c)
        #echo "emprant fitxer de credencials"
        if [ -z $HOME ];then
                echo "Variable HOME no definida, emprant /home/$USERNAME"
                HOME="/home/$USERNAME"
        else
                echo "HOME=$HOME"
        fi
        USERNAME=$(grep -i "^username=" $HOME/credentials | tr -d '\r'| tr -d '\n'| cut -f 2 -d "=" --output-delimiter=" ")
        PASSWORD=$(grep -i "^password=" $HOME/credentials | tr -d '\r'| tr -d '\n'| cut -f 2 -d "=" --output-delimiter=" ")        
        ;;
    v)  DEBUG=1
        ;;
    u)  USERNAME="$OPTARG"
        ;;
    p)  PASSWORD="$OPTARG"
        ;;
    esac
done

shift $((OPTIND-1))

[ "$1" = "--" ] && shift

if [ -z "$USERNAME" ] || [ -z "$PASSWORD" ] 
then
#Si NO tenim usuari i password no podem configurar les impressores
    echo "ERROR: Se necessita usuari i contrassenya per poder crear la sessió al seycon USERNAME=$USERNAME PASSWORD=$PASSWORD " >&2
    #echo "credentials=$(cat /home/$PAM_USER/credentials)"
    show_caib_conf_seyconsession_help
    exit 1
fi

[ "$DEBUG" -gt "0" ] && logger -t "linuxcaib-conf-seyconsession($PAM_SERVICE-$PAM_USER)" -s "id=$(id $USERNAME)"
[ "$DEBUG" -gt "0" ] && logger -t "linuxcaib-conf-seyconsession($PAM_SERVICE-$PAM_USER)" -s "gid=$(id $USERNAME -gn)"
USER_GID=$(id $USERNAME -gn)


if [ "$DEBUG" -gt "0" ];then
        echo "DEBUG=$DEBUG, usuari='$USERNAME', resta parametres no emprats: $@"
fi


        TMPMEM=$(carpetaTempMemoria)
        #Cream fitxer per l'identificador de sessió (Mazinger sessió) a memòria 
        NOMFITX="MZN_SESSION"
        touch $TMPMEM/$USERNAME/$NOMFITX
        chown $USERNAME:"$USER_GID" $TMPMEM/$USERNAME/$NOMFITX
        chmod 600 $TMPMEM/$USERNAME/$NOMFITX


        #Cream la sessió de mazinger al seycon
        #https://sticlin2.caib.es:750/passwordLogin?action=createSession&user=u83511&port=55555&challengeId=AZWcjA0TRUupZzUlVKa4LhOQyvS0RLoMwffaqet59twePYnvbb&cardValue=
        NOMFITXSESKEY="$TMPMEM/""$USERNAME/""$USERNAME""_seycon_session_key"
        if [ -f $NOMFITXSESKEY ];then        
                USER_SEYCON_SESSION_KEY=$(cat "$TMPMEM/""$USERNAME/""$USERNAME""_seycon_session_key")
                #Port on escoltarem        
                unset https_proxy
                unset http_proxy
                SSODAEMONPORT=$(randomPort)
                echo $SSODAEMONPORT > "$TMPMEM/""$USERNAME/""$USERNAME""_ssodaemonport"
                chown $USERNAME:"$USER_GID" "$TMPMEM/""$USERNAME/""$USERNAME""_ssodaemonport"
                USER_SESSION=$(wget -O - -q --http-user=$USERNAME --http-password=$PASSWORD --no-check-certificate "https://$SEYCON_SERVER:$SEYCON_PORT/passwordLogin?action=createSession&user=$USERNAME&port=$SSODAEMONPORT&challengeId=$USER_SEYCON_SESSION_KEY&cardValue=" )
                SESSION_ID=$(echo $USER_SESSION | cut -f 3 -d "|" )
                USER_SEYCON_LOGIN_ADMIN=$(echo $USER_SESSION | cut -f 4 -d "|" )
                if [ "$USER_SEYCON_SESSION" = "$SESSION_ID" ];then
                        [ "$DEBUG" -gt "0" ] && logger -t "linuxcaib-conf-seyconsession($USERNAME)" "INFO: Sessió del seycon i sessió del mazinger iguals -$USER_SEYCON_SESSION-"
                else
                        logger -t "linuxcaib-conf-seyconsession($USERNAME)" "WARNING: Sessió del seycon i sessió del mazinger NO iguals -$USER_SEYCON_SESSION-"
                fi
                [ "$DEBUG" -gt "0" ] && logger -t "linuxcaib-conf-seyconsession($USERNAME)" "DEBUG: createSession result= $USER_SESSION"
                if [ $( echo $USER_SESSION | cut -f 1 -d "|" ) = "OK" ];then        
                        ln -sf "$TMPMEM/""$USERNAME/""MZN_SESSION" /home/$USERNAME/.caib/MZN_SESSION
                        chown $USERNAME:"$USER_GID" /home/$USERNAME/.caib/MZN_SESSION
                        chown -h $USERNAME:"$USER_GID"E /home/$USERNAME/.caib/MZN_SESSION
                        echo $SESSION_ID > /home/$USERNAME/.caib/MZN_SESSION
                        logger -t "linuxcaib-conf-seyconsession($USERNAME)" "Sessió del mazinger creada al seycon ($SESSION_ID)"
                        if [ "$USER_SEYCON_LOGIN_ADMIN" = "true" ];then
                                #L'usuari té permissos d'administració a la màquina.
                                [ "$DEBUG" -gt "0" ] && logger -t "linuxcaib-conf-seyconsession($USERNAME)" "Usuari és administrador de la màquina assign permissos de sudo"
                                adduser --quiet $USERNAME sudo
                        else
                                [ "$DEBUG" -gt "0" ] && logger -t "linuxcaib-conf-seyconsession($USERNAME)" "Usuari NO és administrador de la màquina revocats permissos de sudo"
                                deluser --quiet $USERNAME sudo
                        fi
                else
                        #Nota el es.caib.sso.TooManySessionsException no el dona mai si l'usuari te multisessió.
                        if [ $( echo $USER_SESSION | cut -f 1 -d "|" ) = "es.caib.sso.TooManySessionsException" ];then 
                                logger -t "linuxcaib-conf-seyconsession($USERNAME)" "ERROR: l'usuari te massa sessions obertes! ($USER_SESSION) (display=$DISPLAY)"
                                #Si la màquina on ja hi ha una sessió oberta es la pròpia
                                hostAmbSessio=$( echo $USER_SESSION | cut -f 2 -d "|" )
                                if [ "$hostAmbSessio" = "$(hostname)" ];then
                                        #WARN: hauriem de tornar a provar de fer login en X segons, per si s'ha reiniciat rapid i encara hi ha sessió anterior. Per ara deixam que surti el missatge i que l'usuari ho torni a intentar ell manualment
                                         if [ "$DISPLAY" != ":0.0" -a  "$DISPLAY" != ":0" ];then
                                                echo "ERROR, ja teniu una altra sessio oberta en aquesta màquina $hostAmbSessio.\nTancau la sessio.\nSi no teniu altre sessio oberta, esperau 5 minuts i tornau-ho a intentar.\n\nSi així i tot vos segueix apareixent aquest missatge, reiniciau l'equip."
                                        else
                                                zenity --timeout 10 --width=400 --warning --title="Accés a la xarxa corporativa" --text="ERROR, ja teniu una altra sessio oberta en aquesta màquina $hostAmbSessio.\nTancau la sessio.\nSi no teniu altre sessio oberta, esperau 5 minuts i tornau-ho a intentar.\n\nSi així i tot vos segueix apareixent aquest missatge, reiniciau l'equip.\n\nAquest dialeg se tancara en 10 segons"
                                        fi
                                else
                                        if [ "$DISPLAY" != ":0.0" -a  "$DISPLAY" != ":0" ];then
                                                echo "ERROR, teniu una altra sessio oberta a la màquina $hostAmbSessio.\nTancau la sessio d'aquesta altra màquina per poder iniciar sessió."
                                        else
                                                zenity --timeout 10 --width=400 --warning --title="Accés a la xarxa corporativa" --text="ERROR, teniu una altra sessio oberta a la màquina $hostAmbSessio.\nTancau la sessio d'aquesta altra màquina per poder iniciar sessió.\n.\n\nAquest dialeg se tancara en 10 segons"
                                        fi
                                #TODO: gestionar altres sessions (tancar la sessió remota etc.)
                                fi
                                exit 1;
                        else
                                logger -t "linuxcaib-conf-seyconsession($USERNAME)" -s "ERROR: no he pogut crear la sessió al seycon, error: ($USER_SESSION)"
                                logger -t "linuxcaib-conf-seyconsession($USERNAME)" "wget -O - -q --http-user=$USERNAME --http-password=XXXXXXX --no-check-certificate https://$SEYCON_SERVER:$SEYCON_PORT/createsession?user=$USERNAME&port=$SSODAEMONPORT"
                        fi
                fi
        else
                logger -t "linuxcaib-conf-seyconsession($USERNAME)" -s "ERROR: clau de sessió seycon inexistent"
        fi

