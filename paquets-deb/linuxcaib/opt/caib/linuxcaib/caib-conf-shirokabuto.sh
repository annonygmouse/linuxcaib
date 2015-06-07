#!/bin/sh


#Script que gestiona la contrasenya de l'usuari local "ShiroKabuto".

#Pre-requisits:
#       1. L'usuari local ShiroKabuto _ja ha d'estar creat_ (ho fa linuxcaib.deb).
#       2. L'usuari que executa l'script ha de tenir permissos de root (uid=0) o sudo.
#       3. Cal tenir instal·lat el paquet "whois" que conté el binari mkpasswd i perl

#WARN: estaria bé poder comprovar que encara que no hagin passat els 7 dies, la contrasenya segueixi essent vàlida (per si hem arrancat el windows)?

#MILLORA: MIRAR SI PODEM SIMPLIFICAR AQUEST CODI EMPRANT USERMOD I PASSWD -S   !!!!
#MILLORA: també mirant de emprar "useradd -p passw"


#Miram si el ShiroKabuto ha estat deshabilitat a nivell global
if [ -r /opt/caib/linuxcaib/conf/ShiroDisabled ];then
        logger -t "linuxcaib-conf-shirokabuto($USER)" -s "Gestió de ShiroKabuto deshabilitada"
# WARN: no hauria d'estar dins /opt/caib/linuxcaib/conf/ShiroDisabled
fi

#Importam les funcions auxiliars
#Ruta base scripts
BASEDIR=$(dirname $0)
if [ "$CAIBCONFUTILS" != "SI" ]; then
        logger -t "linuxcaib-conf-shirokabuto($USER)" "CAIBCONFUTILS=$CAIBCONFUTILS Carregam utilitats de $BASEDIR/caib-conf-utils.sh"
        . $BASEDIR/caib-conf-utils.sh
fi

# Initialize our own variables:
output_file=""

show_caib_conf_shirokabuto_help () {
cat << EOF
El programa "${0##*/}" actualitza la contrasenya de shirokabuto (admin local), cal usuari i contrasenya de connexió al SEYCON.

Ús: ${0##*/} [-cfhv] [-u USUARI] [-p PASSWORD]

      -c          agafa les credencials del fitxer "credentials". IMPORTANT, l'usuari ha de ser l'usuari de SEYCON.
      -f          força canvi password
      -h          mostra aquesta ajuda
      -u USUARI   nom de l'usuari a emprar
      -p PASSWORD contrasenya de l'usuari a emprar
      -v          mode verbose

Exemples:
        ${0##*/} -u u83511 -p password_u83511   Execució passant usuari i contrasenya
        ${0##*/} -c     Execució emprant fitxer de credencials
EOF
}

#Fi funcions

if [ $USER = "root"  ]; then
        logger -t "linuxcaib-conf-shirokabuto($USER)" -s "ERROR: no se pot executar com a root!"
        exit 1;
fi

# A POSIX variable
OPTIND=1         # Reset in case getopts has been used previously in the shell.

# Initialize our own variables:
output_file=""

while getopts "hfcv?u:p:" opt; do
    case "$opt" in
    h|\?)
        show_caib_conf_shirokabuto_help
        exit 0
        ;;
    c)
        USERNAME=$(grep -i "^username=" $HOME/credentials | tr -d '\r'| tr -d '\n'| cut -f 2 -d "=" --output-delimiter=" ")
        PASSWORD=$(grep -i "^password=" $HOME/credentials | tr -d '\r'| tr -d '\n'| cut -f 2 -d "=" --output-delimiter=" ")        
        ;;
    f)  FORCE_CHANGE_SHIRO_PASS="s"
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
#Si NO tenim usuari i password no podem actualitzar la contrasenya de ShiroKabuto
    logger -t "linuxcaib-conf-shirokabuto($USER)" -s "ERROR: Se necessita usuari i contrassenya per poder actualitzar la contrasenya de ShiroKabuto" >&2
    show_caib_conf_shirokabuto_help
    exit 1
fi

#Si debug no està definida, la definim
if [ -z $DEBUG ]; then DEBUG=0; fi
if [ "$DEBUG" -ge 3 ]; then
    # trace output
    set -x
fi

if [ "$(echo $(hostname) | sed -e 's/\(^.*\)\(.$\)/\2/')" = "l" ];then
        #Màquina que acaba en "l", suposaré que és un àlies.
        #Als àlies no podem actualitzar la contrasenya de ShiroKabuto
        logger -t "linuxcaib-conf-shirokabuto" "INFO: Contrasenya ShiroKabuto NO actualitzada, màquina és un àlies"
        echo "# Contrasenya ShiroKabuto NO actualitzada, màquina és un àlies";sleep 3;
        exit 0;
fi 
#Actualitzar password ShiroKabuto

#Si no existeix el fitxer de hostname desat, o és diferent al hostname actual, hem de forçar canvi password.
if [  "$SHIRO_HOSTNAME" != "$(hostname)"  -o "$SHIRO_HOSTNAME" = "" ];then
        FORCE_CHANGE_SHIRO_PASS="s";
        [ "$DEBUG" -gt "0" ] && logger -t "linuxcaib-conf-shirokabuto" "DEBUG: hostname changed or first run, updating ShiroKabuto password to seycon forced"
fi
# Si la passwd de ShiroKabuto te més de 7 dies, la canviam.
CURRENT_EPOCH=`grep ShiroKabuto /etc/shadow | cut -d: -f3`
# Find the epoch time since the user's password was last changed
#WARN: Nota, si no volem emprar perl, hem d'emprar ksh + script gymd2uday (scriptss_temps_shell.sh)
#http://stackoverflow.com/questions/1094291/get-current-date-in-epoch-from-unix-shell-script
EPOCH=`perl -e 'print int(time/(60*60*24))'`
AGE=`echo $EPOCH - $CURRENT_EPOCH | bc`
logger -t "linuxcaib-conf-shirokabuto" "INFO: ShiroKabuto's password age $AGE FORCE_CHANGE_SHIRO_PASS=$FORCE_CHANGE_SHIRO_PASS"
OLD_SHIRO_PASS=$(grep ShiroKabuto /etc/shadow | cut -d: -f2)
#Si la contrasenya té més de 7 dies o NO hi ha definida contrasenya, en posam una de nova
if [ $AGE -gt 7 ] || [ "$OLD_SHIRO_PASS" = "\!" ] || [  "$OLD_SHIRO_PASS" = "" ] || [  "$FORCE_CHANGE_SHIRO_PASS" = "s"  ];then
        #Pass de 15 caracters evitant caracters que se poden confondre
        NEW_SHIRO_PASS=$(pwgen -N 1 -B -s 7)
        [ "$DEBUG" -gt "0" ] && logger -t "linuxcaib-conf-shirokabuto" "DEBUG: updating password to seycon... =wget ... \"https://$SEYCON_SERVER:$SEYCON_PORT/sethostadmin?host=$(hostname)&user=ShiroKabuto&pass=$NEW_SHIRO_PASS\""                
        UPDATE_SHIRO_PASSWORD_ANSWER=$(wget -O - -q --http-user=$USERNAME --http-password=$PASSWORD --no-check-certificate "https://$SEYCON_SERVER:$SEYCON_PORT/sethostadmin?host=$(hostname)&user=ShiroKabuto&pass=$NEW_SHIRO_PASS" )
        RESULTAT=$(echo $UPDATE_SHIRO_PASSWORD_ANSWER | cut -d\| -f1)
        [ "$DEBUG" -gt "0" ] && logger -t "linuxcaib-conf-shirokabuto" "DEBUG: updating password to seycon, server response =$RESULTAT"                
        if [ "$RESULTAT" = "OK" ];then
                [ "$DEBUG" -gt "0" ] && logger -t "linuxcaib-conf-shirokabuto" "INFO: ShiroKabuto's password changed successfully on machine $(echo $UPDATE_SHIRO_PASSWORD_ANSWER | cut -d "|" -f2) "
                #Xifram nou pass amb SHA-512 per shadow (a partir glibc 2.7)

                NEW_SHIRO_PASS=$(echo $NEW_SHIRO_PASS |  mkpasswd -m sha-512 -s)
                [ "$DEBUG" -gt "0" ] &&  logger -t "linuxcaib-conf-shirokabuto" "Nou password xifrat de ShiroKabuto $NEW_SHIRO_PASS"
                NEW_SHIRO_PASS_SEDESCAPED=$(echo $NEW_SHIRO_PASS| sed -e 's/[]\/$*.^|[]/\\&/g')
                OLD_SHIRO_PASS_SEDESCAPED=$(echo $OLD_SHIRO_PASS| sed -e 's/[]\/$*.^|[]/\\&/g')
                #Feim copia de seguretat del fitxer shadow per si acas.
                [ "$DEBUG" -gt "0" ] && logger -t "linuxcaib-conf-shirokabuto" "DEBUG: Backing up shadow file to shadow_linuxcaib"      
                cp /etc/shadow /etc/shadow_linuxcaib
                if [ "$OLD_SHIRO_PASS" = "" ];then
                        /bin/sed -i "s/ShiroKabuto::/ShiroKabuto:$NEW_SHIRO_PASS_SEDESCAPED:/g" /etc/shadow
                else
                        /bin/sed -i "s/ShiroKabuto:$OLD_SHIRO_PASS_SEDESCAPED/ShiroKabuto:$NEW_SHIRO_PASS_SEDESCAPED/g" /etc/shadow
                fi
                #Comprovar que no hem romput res. En cas contrari tornar a posar el /etc/shadow anterior.
                if (! pwck -q -r /etc/shadow );then
                        #Hem romput el shadow el recuperam de la copia de seguretat
                        cp /etc/shadow_linuxcaib /etc/shadow
                        logger -t "linuxcaib-conf-shirokabuto" "ERROR: No he pogut canviar el password LOCAL de ShiroKabuto torn a posar el password anterior"
                        wget -O - -q --http-user=$USERNAME --http-password=$PASSWORD --no-check-certificate "https://$SEYCON_SERVER:$SEYCON_PORT/sethostadmin?host=$(hostname)&user=ShiroKabuto&pass=$OLD_SHIRO_PASS"
                fi
                [ "$DEBUG" -gt "0" ] && logger -t "linuxcaib-conf-shirokabuto" "DEBUG: ShiroKabuto password synced"
                #Feim que la contrasenya no caduqui.
                chage -E -1 ShiroKabuto
                [ "$DEBUG" -gt "0" ] && logger -t "linuxcaib-conf-shirokabuto" -s "Data canvi contrasenya: $(date +%F)"
                chage -d $(date +%F) ShiroKabuto   #Format data  yyyy-mm-dd
                #Si està tot bé, actualitzam el hostname associat al ShiroKabuto
                echo $(hostname) | tee $BASEDIR/conf/ShiroHostname > /dev/null
                [ "$DEBUG" -gt "0" ] && logger -t "linuxcaib-conf-shirokabuto" "Actualitzat fitxer $BASEDIR/conf/ShiroHostname amb el hostname actual associat al ShiroKabuto ($(hostname))"
        else
                logger -t "linuxcaib-conf-shirokabuto" "ERROR: ShiroKabuto's password could not be changed Error: $UPDATE_SHIRO_PASSWORD_ANSWER"
                exit 1;
        fi
else
        logger -t "linuxcaib-conf-shirokabuto" "INFO: ShiroKabuto's password does not need to be updated"
fi

exit 0;
