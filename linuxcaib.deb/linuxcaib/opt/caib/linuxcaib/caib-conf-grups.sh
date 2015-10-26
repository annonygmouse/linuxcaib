#!/bin/sh

# Script fet amb BASH que mostra la llista de grups que te un usuari donat d'alta al SEYCON. 
# Si se li passa el paràmetre "-t" amb un nom de grup, comprova que l'usuari tengui aquest grup.
#

#Importam les funcions auxiliars
#Ruta base scripts
BASEDIR=$(dirname $0)
if [ "$CAIBCONFUTILS" != "SI" ]; then
logger -t "linuxcaib-login-linux($USER)" "Carregam utilitats de $BASEDIR/caib-conf-utils.sh"
. $BASEDIR/caib-conf-utils.sh
fi


#Si debug no està definida, la definim
if [ -z $DEBUG ]; then DEBUG=0; fi
if [ "$DEBUG" -ge 3 ]; then
    # trace output
    set -x
fi

# Initialize our own variables:
output_file=""

show_caib_conf_grups_help () {
cat << EOF
El programa "${0##*/}" obté els grups que l'usuari te donades d'alta al SEYCON.

Ús: ${0##*/} [-chtv] [-u USUARI] [-p PASSWORD]

      -h          mostra aquesta ajuda
      -u USUARI   nom de l'usuari a emprar
      -p PASSWORD contrasenya de l'usuari a emprar
      -c          agafa les credencials del fitxer "credentials". IMPORTANT, l'usuari ha de ser l'usuari de SEYCON.
      -v          mode verbose
      -t ROLE     torna l'string "true" si l'usuari te aquest grup, "false" en cas contrari.

Exemple
    ${0##*/} -u u83511 -p passsword_u83511      Execució emprant usuari i contrasenya

EOF
}

#Fi funcions


if [ $USER = "root"  ]; then
        logger -t "linuxcaib-conf-grups($USER)" "ERROR: no se pot executar com a root!"
        exit 1;
fi

# A POSIX variable
OPTIND=1         # Reset in case getopts has been used previously in the shell.

# Initialize our own variables:
output_file=""
DEBUG=0

while getopts "hcv?u:p:t:" opt; do
    case "$opt" in
    h|\?)
        show_caib_conf_grups_help
        exit 0
        ;;
    c)
        if [ "$seyconSessionUser" != "" ];then
                USERNAME=$seyconSessionUser
                PASSWORD=$seyconSessionPassword
        else
                #Com a backup intentam agafar el nom i contrasenya del fitxer credentials que hi ha dins el home de l'usuari.
                USERNAME=$(grep -i "^username=" $HOME/credentials | tr -d '\r'| tr -d '\n'| cut -f 2 -d "=" --output-delimiter=" ")
                PASSWORD=$(grep -i "^password=" $HOME/credentials | tr -d '\r'| tr -d '\n'| cut -f 2 -d "=" --output-delimiter=" ")
        fi     
        ;;
    v)  DEBUG=1
        ;;
    u)  USERNAME="$OPTARG"
        ;;
    p)  PASSWORD="$OPTARG"
        ;;
    t)  askedRole="$OPTARG"
        ;;    esac
done

shift $((OPTIND-1))

[ "$1" = "--" ] && shift

[ "$DEBUG" -gt "0" ] && logger -t "linuxcaib-conf-grups($USER)" -s "seyconSessionUser=$seyconSessionUser"

if [ -z "$USERNAME" ] || [ -z "$PASSWORD" ] 
then
#Si NO tenim usuari i password no podem obtenir els grups
    echo "ERROR: Se necessita usuari i contrassenya per poder obtenir els grups" >&2
    show_caib_conf_grups_help
    exit 1
fi


if [ "$DEBUG" -gt "0" ];then
        echo "DEBUG=$DEBUG, usuari='$USERNAME', resta parametres no emprats: $@"
fi



if [ "$(dpkg -l|grep xmlstarlet| grep ^.i)" = "" ]; then
        logger -t "linuxcaib-conf-grups($USER)" "ERROR: cal instalar el paquet xmlstarlet (sudo apt-get install xmlstarlet), ho intent"
        sudo apt-get install xmlstarlet
fi



#USER_GRUPS=$(wget -O - -q --http-user=$USERNAME --http-password=$PASSWORD --no-check-certificate https://$SEYCON_SERVER:$SEYCON_PORT/query/user/$USERNAME/grups-v2)
USER_GRUPS=$(cat $HOME/ProjecteFM/sticlin2_caib_es_750_query_user_u83511_groups.xml)

RESULTM=$?
if [ $RESULTM -eq 0 ];then
   if [ "$DEBUG" -gt "0" ];then
        logger -t "linuxcaib-conf-grups($USER)" "Descarregats grups de l'USERNAME"
   fi
else
   logger -t "linuxcaib-conf-grups($USER)" "ERROR: no he pogut accedir als grups de l'usuari. Resultat petició: $RESULTM o l'usuari NO te cap grup assignades."
   logger -t "linuxcaib-conf-grups($USER)" "resultat: $USER_GRUPS"
   exit 1;
fi


NUM_GRUPS=0;

MAX_GRUPS=100

for x in $(seq 1 1 $MAX_GRUPS) ; do
        #echo "x=-$x-"
        xpath="data/row[$x]"
        #echo "xpath=$xpath"
        ROWACTUAL=$ROW$x
        ROWACTUAL=$(echo $USER_GRUPS | xmlstarlet sel  -t -c $xpath )
        #echo "rowactual=$ROWACTUAL"
        if [ "$ROWACTUAL" = "" ] ;then
                break
        else 
                NUM_GRUPS=$(expr $NUM_GRUPS + 1)
        fi
done

NUM_GRUPS=$(echo $USER_GRUPS | xmlstarlet sel -t -v 'count(data/row)')

if [ "$NUM_GRUPS" -gt "$MAX_GRUPS" ];then
        logger -t "linuxcaib-conf-drives($USER)" "WARNING: Massa grups definits al seycon! Només emprare els $MAX_GRUPS primers"
        $NUM_GRUPS=$MAX_IMPRESSORES
fi

if [ $RESULTM -eq 0 ];then
        logger -t "linuxcaib-conf-grups($USER)" "num impressores=$NUM_GRUPS"
fi

if [ -z $askedRole ] && [ $NUM_GRUPS -gt 0 ];then
        echo "Codi grup"
fi

for y in $(seq 1 1 $NUM_GRUPS) ; do
        #echo "processant grup $y"
        xpath="data/row[$y]/GRU_CODI/text()"
        GRUCODI=$(echo $USER_GRUPS | xmlstarlet sel -T -t -c $xpath )
        if [ "$GRUCODI" != "" ] ;then
                if [ ! -z $askedRole ];then
                        if [ "$GRUCODI" = "$askedRole" ];then
                                echo "true"
                                return
                        fi
                else 
                        logger -t "linuxcaib-conf-grups($USER)" "Nom grup: $GRUCODI"
                        echo "$GRUCODI"
                fi
        else
                logger -t "linuxcaib-conf-grups($USER)" "ERROR: llista de grups buida"
        fi
done

if [ ! -z $askedRole ];then
        echo "false"
fi
