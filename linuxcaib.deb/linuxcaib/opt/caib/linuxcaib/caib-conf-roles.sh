#!/bin/sh

# Script fet amb dash que mostra la llista de roles que te un usuari donat d'alta al SEYCON. 
# Si se li passa el paràmetre "-t" amb un nom de role, comprova que l'usuari tengui aquest role,
# en cas afirmatiu torna "true" en cas negatiu torna "false".
# Primer mira si existeix el fitxer $USERNAME_seycon_roles, si existeix, empra aquests roles com
# a cache (a no ser que se passi per paràmetre "-r" per a que actualitzi el fitxer amb els roles 
# que obtingui del seycon

#Importam les funcions auxiliars
#Ruta base scripts
BASEDIR=$(dirname $0)
if [ "$CAIBCONFUTILS" != "SI" ]; then
logger -t "linuxcaib-login-linux($USER)" "Carregam utilitats de $BASEDIR/caib-conf-utils.sh"
. $BASEDIR/caib-conf-utils.sh
fi

#Carpeta temporal en memòria de l'usuari
tmpFolder=$(carpetaTempMemoria)


#Si debug no està definida, la definim
if [ -z $DEBUG ]; then DEBUG=0; fi
if [ "$DEBUG" -ge 3 ]; then
    # trace output
    set -x
fi

# Initialize our own variables:
output_file=""

show_caib_conf_roles_help () {
cat << EOF
El programa "${0##*/}" obté els roles que l'usuari te donades d'alta al SEYCON.

Ús: ${0##*/} [-hv] [-u USUARI] [-p PASSWORD]

      -h          mostra aquesta ajuda
      -u USUARI   nom de l'usuari a emprar
      -p PASSWORD contrasenya de l'usuari a emprar
      -c          agafa les credencials del fitxer "credentials". IMPORTANT, l'usuari ha de ser l'usuari de SEYCON.
      -v          mode verbose
      -t NOM_ROLE torna l'string "true" si l'usuari te aquest role, "false" en cas contrari.
      -r          refresca els roles (no empra els roles en cache)

Exemples:
        ${0##*/} -u u83511 -p password_u83511   Execució passant usuari i contrasenya
        ${0##*/} -c     Execució emprant fitxer de credencials
EOF
}

#Fi funcions


if [ $USER = "root"  ]; then
        logger -t "linuxcaib-conf-roles($USER)" "ERROR: no se pot executar com a root!"
        exit 1;
fi

# A POSIX variable
OPTIND=1         # Reset in case getopts has been used previously in the shell.

# Initialize our own variables:
output_file=""
DEBUG=0

while getopts "chrv?u:p:t:" opt; do
    case "$opt" in
    h|\?)
        show_caib_conf_roles_help
        exit 0
        ;;
    c)
        USERNAME=$(grep -i "^username=" $HOME/credentials | tr -d '\r'| tr -d '\n'| cut -f 2 -d "=" --output-delimiter=" ")
        PASSWORD=$(grep -i "^password=" $HOME/credentials | tr -d '\r'| tr -d '\n'| cut -f 2 -d "=" --output-delimiter=" ")        
        ;;
    v)  DEBUG=1
        ;;
    u)  USERNAME="$OPTARG"
        ;;
    p)  PASSWORD="$OPTARG"
        ;;
    t)  askedRole="$OPTARG"
        ;;    
    r)  forceRefresh="S"
        ;;    
    esac
done

shift $((OPTIND-1))

[ "$1" = "--" ] && shift

if [ -z "$USERNAME" ] || [ -z "$PASSWORD" ] 
then
#Si NO tenim usuari i password no podem obtenir els roles
    echo "ERROR: Se necessita usuari i contrassenya per poder obtenir els roles" >&2
    show_caib_conf_roles_help
    exit 1
fi


if [ "$DEBUG" -gt "0" ];then
        echo "DEBUG=$DEBUG, usuari='$USERNAME', resta parametres no emprats: $@"
fi



if [ "$(dpkg -l|grep xmlstarlet| grep ^.i)" = "" ]; then
        logger -t "linuxcaib-conf-roles($USER)" "ERROR: cal instalar el paquet xmlstarlet (sudo apt-get install xmlstarlet), ho intent"
        sudo apt-get install xmlstarlet
fi

#La carpeta temporal ha de ser la de l'usuari.
usrtmpFolder=$tmpFolder"/$USERNAME"
if [ ! -d $usrtmpFolder ];then
        mkdir -p $usrtmpFolder
fi


if [ "$forceRefresh" = "S" -o ! -r $usrtmpFolder/"$USERNAME"_seycon_roles ];then
        logger -t "linuxcaib-conf-roles($USER)" -s "INFO: refrescam els roles del seycon"        
        #USER_ROLES=$(wget -O - -q --http-user=$USERNAME --http-password=$PASSWORD --no-check-certificate https://$SEYCON_SERVER:$SEYCON_PORT/query/user/$USERNAME/roles-v2)
        USER_ROLES=$(cat $HOME/ProjecteFM/sticlin2_caib_es_750_query_user_u83511_rolesv2.xml)
        RESULTM=$?
        if [ $RESULTM -eq 0 ];then
           if [ "$DEBUG" -gt "0" ];then
                logger -t "linuxcaib-conf-roles($USER)" "Descarregats roles de l'USERNAME"
           fi
        else
           logger -t "linuxcaib-conf-roles($USER)" "ERROR: no he pogut accedir als roles de l'usuari. Resultat petició: $RESULTM o l'usuari NO te cap role assignades."
           logger -t "linuxcaib-conf-roles($USER)" "resultat: $USER_ROLES"
           exit 1;
        fi
        #Copiam l'xml resultant a la carpeta temporal de l'usuari.
        echo $USER_ROLES > $usrtmpFolder/"$USERNAME"_seycon_roles
else
        logger -t "linuxcaib-conf-roles($USER)" "INFO: empram els roles de cache"        
        USER_ROLES=$(cat $usrtmpFolder/"$USERNAME"_seycon_roles)
fi

NUM_ROLES=0;

MAX_ROLES=1000

for x in $(seq 1 1 $MAX_ROLES) ; do
        #echo "x=-$x-"
        xpath="data/row[$x]"
        #echo "xpath=$xpath"
        ROWACTUAL=$ROW$x
        ROWACTUAL=$(echo $USER_ROLES | xmlstarlet sel  -t -c $xpath )
        #echo "rowactual=$ROWACTUAL"
        if [ "$ROWACTUAL" = "" ] ;then
                break
        else 
                NUM_ROLES=$(expr $NUM_ROLES + 1)
        fi
done

NUM_ROLES=$(echo $USER_ROLES | xmlstarlet sel -t -v 'count(data/row)')

if [ "$NUM_ROLES" -gt "$MAX_ROLES" ];then
        logger -t "linuxcaib-conf-drives($USER)" "WARNING: Massa roles definits al seycon! Només emprare els $MAX_ROLES primers"
        $NUM_ROLES=$MAX_IMPRESSORES
fi

[ "$DEBUG" -gt "0" ] && logger -t "linuxcaib-conf-roles($USER)" "num roles=$NUM_ROLES"

if [ -z $askedRole ] && [ $NUM_ROLES -gt 0 ];then
        echo "Nom role\t\tCodi Aplicació\t\tNom aplicació"
fi

for y in $(seq 1 1 $NUM_ROLES) ; do
        #echo "processant role $y"
        xpath="data/row[$y]/ROL_NOM/text()"
        NOMROLE=$(echo $USER_ROLES | xmlstarlet sel -T -t -c $xpath )
        #xpath="data/row[$y]/ROL_DESCRI/text()"
        #DESCROLE=$(echo $USER_ROLES | xmlstarlet sel -T -t -c $xpath )
        xpath="data/row[$y]/APL_CODI/text()"
        APLCODI=$(echo $USER_ROLES | xmlstarlet sel -T -t -c $xpath )
        xpath="data/row[$y]/APL_NOM/text()"
        APLNOM=$(echo $USER_ROLES | xmlstarlet sel -T -t -c $xpath )
        if [ "$NOMROLE" != "" ] ;then
                if [ ! -z $askedRole ];then
                        if [ "$NOMROLE" = "$askedRole" ];then
                                echo "true"
                                return
                        fi
                else 
                        [ "$DEBUG" -gt "0" ] && logger -t "linuxcaib-conf-roles($USER)" "Nom role: $NOMROLE Codi Aplicació: $APLCODI Nom aplicació: $APLNOM"
                        echo "$NOMROLE\t\t$APLCODI\t\t$APLNOM"
                fi
        else
                logger -t "linuxcaib-conf-roles($USER)" "ERROR: llista de roles buida"
        fi
done

if [ ! -z $askedRole ];then
        echo "false"
fi
