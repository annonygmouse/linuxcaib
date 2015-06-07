#!/bin/sh

#Script que actualitza les regles del Mazinger
# Descarregla el fitxer de regles del Mazinger a $HOME/.caib/mazinger.mzn

if [ $USER = "root"  ]; then
        logger -t "linuxcaib-conf-mazinger($USER)" "ERROR: no se pot executar com a root!"
        echo "#Error configurant mazinger (usuari root)"
        exit 1;
fi

#Importam les funcions auxiliars
#Ruta base scripts
BASEDIR=$(dirname $0)
if [ "$CAIBCONFUTILS" != "SI" ]; then
        logger -t "linuxcaib-conf-mazinger($USER)" "CAIBCONFUTILS=$CAIBCONFUTILS Carregam utilitats de $BASEDIR/caib-conf-utils.sh"
        . $BASEDIR/caib-conf-utils.sh
fi

#Si debug no està definida, la definim
if [ -z $DEBUG ]; then DEBUG=0; fi
if [ "$DEBUG" -ge 3 ]; then
    # trace output
    set -x
fi

show_caib_conf_mazinger_help () {
cat << EOF
El programa "${0##*/}" actualitza la configuració del mazinger. 

Ús: ${0##*/} [-hcv] [-u USUARI] [-p PASSWORD]

      -h          mostra aquesta ajuda
      -u USUARI   nom de l'usuari a emprar
      -p PASSWORD contrasenya de l'usuari a emprar
      -c          agafa les credencials del fitxer "credentials". IMPORTANT, l'usuari ha de ser l'usuari de SEYCON.
      -v          mode verbose
EOF
}

# A POSIX variable
OPTIND=1         # Reset in case getopts has been used previously in the shell.

# Initialize our own variables:
output_file=""

while getopts "hmcv?u:p:" opt; do
    case "$opt" in
    h|\?)
        show_caib_conf_mazinger_help
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
    esac
done

shift $((OPTIND-1))

[ "$1" = "--" ] && shift

if [ -z "$USERNAME" ] || [ -z "$PASSWORD" ] 
then
#Si NO tenim usuari i password no podem descarregar les regles
    echo "ERROR: Se necessita usuari i contrassenya per poder montar les unitats compartides" >&2
    show_caib_conf_mazinger_help
    exit 1
fi


if [ "$DEBUG" -gt "0" ];then
        echo "DEBUG=$DEBUG, usuari='$USERNAME', resta parametres no emprats: $@"
fi

echo "#Actualitzant regles de Mazinger"

#Actualitzam fitxer configuració mazinger
wget -q --http-user=$USERNAME --http-password=$PASSWORD --no-check-certificate "https://$SEYCON_SERVER:$SEYCON_PORT/getmazingerconfig?user=$USERNAME&version=2" -O $HOME/.caib/mazinger.mzn
RESULTM=$?

if [ $RESULTM -eq 0 ];then
   logger -t "linuxcaib-conf-mazinger($USER)" "Actualitzat fitxer de regles de Mazinger"
   echo "# Regles de Mazinger actualitzades"
else
   logger -t "linuxcaib-conf-mazinger($USER)" "ERROR: fitxer de regles de Mazinger NO actualitzat. Resultat de wget: $RESULTM"
   echo "# ERROR: Regles de Mazinger NO actualitzades."
fi

exit 0;
