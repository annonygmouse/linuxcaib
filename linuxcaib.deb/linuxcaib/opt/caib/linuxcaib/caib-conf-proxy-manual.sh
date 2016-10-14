#!/bin/sh

#Prerequisits: caib-conf-proxy-server.sh i caib-conf-proxy-user.sh
#       L'usuari que l'executa ha de tenir permissos d'administrador
#       L'usuari ha de tenir fitxer de credencials creat al seu home.



#Mostram ajuda script
show_proxy_conf_manual_help () {
cat << EOF
El programa "${0##*/}" instala el servidor proxy local (cntlm) i configura les aplicacions de sistema per a que emprin el proxy no autenticat stmprh6lin1.

Ús: ${0##*/} [-hlv] [-u USUARI] [-p PASSWORD] [-l USU_LOCAL]
      -h          mostra aquesta ajuda
      -l USUARI   nom de l'usuari local que s'emprarà (si es diferent al de seycon), necessari quan s'ha d'emprar via sudo
      -u USUARI   nom de l'usuari de seycon a emprar
      -p PASSWORD contrasenya de l'usuari de seycon a emprar
      -v          mode verbose

Exemples:
    sudo ${0##*/} -u u8351 -p contrasenya_u83511 -l usuarilocalu83511           Executant via sudo amb l'usuari "usuarilocalu83511"
EOF
}

# A POSIX variable
OPTIND=1         # Reset in case getopts has been used previously in the shell.

# Initialize our own variables:
output_file=""



while getopts "hcv?u:p:l:" opt; do
    case "$opt" in
    h|\?)
        show_proxy_conf_manual_help
        exit 0
        ;;
    l)  LOCALUSERNAME="$OPTARG"
        ;;
    v)  DEBUG=$(($DEBUG + 1))
        ;;
    u)  USERNAME="$OPTARG"
        ;;
    p)  PASSWORD="$OPTARG"
        ;;
    esac
done

shift $((OPTIND-1))

[ "$1" = "--" ] && shift

if [ "$DEBUG" -ge 3 ]; then
    # trace output
    set -x
fi

[ "$DEBUG" -gt "0" ] && logger -t "linuxcaib-conf-proxy-server($USER)" -s "seyconSessionUser=$seyconSessionUser"


#Primer executam caib-conf-proxy-server.sh com a sudo
sudo caib-conf-proxy-server.sh -u $USERNAME -p $PASSWORD -l $USER
caib-conf-proxy-user.sh -u $USERNAME -p $PASSWORD 

exit 0;
