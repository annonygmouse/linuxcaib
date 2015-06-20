#!/bin/sh

#Script que gestiona el perfil mobil a GNU/Linux dins l'entorn de la CAIB

#Funciona en base a una llista blanca de fitxers que es copiaran al "share" del perfil de l'usuari.

#Funcionament:
#  Necessita un paràmetre login|logout, de manera que en fer:
#       -i (login)[defecte]: copia (mitjançant rsync) del perfil (ja ha d'estar montat) els fitxers/directoris 
#                de la llista blanca al $HOME de l'usuari
#
#       -o (logout): copia (mitjançant rsync) els fitxers/directoris 
#                de la llista blanca del $HOME de l'usuari al perfil mobil de l'usuari.
#
#Restriccions:
#       - màxim 20mb per fitxer
#
#  Aquest script s'ha de cridar dins la seva pròpia shell (no fer-ne un source)
#  Tot els fitxers de la llista blanca es sincronitzen dins la carpeta ($perfilmontat/$(lsb_release -ir | md5sum -|cut -d" " -f1)
#      de manera que cada distribució té el seu propi perfil.
#  Per eliminar TOTS els perfils de Linux basta eliminar la carpeta $perfil/linux_profile/.
#  Per eliminar el perfil de Linux DE LA DISTRIBUCIÓ ACTUAL s'ha d'eliminar la carpeta $perfil/inux_profile/$(lsb_release -ir | md5sum -|cut -d" " -f1).


#Debian: lsb_release -ri
#Distributor ID:	Debian
#Release:	8.0

#Ubuntu?: lsb_release -ri


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

echo "BASEDIRPAM=$BASEDIRPAM  BASEDIR: $BASEDIR , RUTA_FITXER=$RUTA_FITXER"
if [ "$CAIB_CONF_SETTINGS" != "SI" ]; then
        #logger -t "linuxcaib-perfil-mobil($USER)" -s "CAIB_CONF_SETTINGS=$CAIB_CONF_SETTINGS Carregam utils de $BASEDIR/caib-conf-utils.sh"
        . $BASEDIR/caib-conf-utils.sh
fi


#Si debug no està definida, la definim
if [ -z $DEBUG ]; then DEBUG=0; fi
if [ "$DEBUG" -ge 3 ]; then
    # trace output
    set -x
fi

echo "# Sincronitzant perfil mobil..."
if [ $USER = "root"  ]; then
        logger -t "linuxcaib-perfil-mobil($USER)" "ERROR: no se pot executar com a root!"
        echo "#Error sincronitzant perfil mobil  (usuari root)"
        sleep 20;
        exit 1;
fi

#ALERTA! la carpeta perfilmontat ha de ser una carpeta DINS la share del perfil, per evitar col·lisons de noms entre MS-Windows i Linux.
perfilmontat="/media/$USER/.unitat_perfil"
if [ $(/bin/df -P  | grep unitat_perfil | grep -v unitat_P | awk 'BEGIN  { FS=" "} {print $6}') != "$perfilmontat" ];then
        logger -t "linuxcaib-perfil-mobil($USER)" "ERROR: unitat del perfil NO montada a $perfilmontat"
        return 1;
else
        logger -t "linuxcaib-perfil-mobil($USER)" "Unitat del perfil mobil montada a $perfilmontat"
fi

if [ ! -d $perfilmontat/perfil-linux ];then
        mkdir -p $perfilmontat/linux_profile
fi
perfilmontat=$perfilmontat/linux_profile

#Si P: esta montada, agafam rsync-perfil-mobil*.rules de P: així se poden actualitzar les regles remotament
#Detectam la carpeta P
if [ -d /media/P_pcapplinux/caib/ ];then
	PSHARE=pcapplinux
else
	if [ -d /media/P_pcapp/caib/dissoflinux ];then
		PSHARE=pcapp
	fi
fi

if [ -d /media/P_$PSHARE/caib/linuxcaib/ ];then
        rutaRsyncRules="/media/P_$PSHARE/caib/linuxcaib/conf"
else
        rutaRsyncRules="/opt/caib/linuxcaib/conf"
fi
includerules="$rutaRsyncRules/rsync-perfil-mobil-include.rules"
excluderules="$rutaRsyncRules/rsync-perfil-mobil-exclude.rules"

#guanabana
#mkdir -p /tmp/.perfil_mobil/
#perfilmontat="/tmp/.perfil_mobil"
#includerules="$HOME/ProjecteFM/linuxcaib/opt/caib/linuxcaib/conf/rsync-perfil-mobil-include.rules"
#excluderules="$HOME/ProjecteFM/linuxcaib/opt/caib/linuxcaib/conf/rsync-perfil-mobil-exclude.rules"

origen=$perfilmontat
desti=$HOME

# Initialize our own variables:
output_file=""

show_caib_perfil_mobil_help () {
cat << EOF
El programa "${0##*/}" sincronitza el perfil de l'usuari.

Ús: ${0##*/} [-hiocv] [-u USUARI] [-p PASSWORD]
      -c           Agafa les credencials del fitxer "credentials". IMPORTANT, l'usuari ha de ser l'usuari de SEYCON.
      -h          mostra aquesta ajuda
      -i          login [defecte]
      -o          logout
      -u USUARI   nom de l'usuari a emprar
      -p PASSWORD contrasenya de l'usuari a emprar
      -v          mode verbose
EOF
}

[ "$DEBUG" -gt "0" ] && logger -t "linuxcaib-perfil-mobil($USER)" -s "INFO: inici HOME=$HOME"

#Fi funcions

# A POSIX variable
OPTIND=1         # Reset in case getopts has been used previously in the shell.

# Initialize our own variables:
output_file=""

while getopts "hiocv?u:p:" opt; do
    case "$opt" in
    h|\?)
        show_caib_perfil_mobil_help
        exit 0
        ;;
    c)
        USERNAME=$(grep -i "^username=" $HOME/credentials | tr -d '\r'| tr -d '\n'| cut -f 2 -d "=" --output-delimiter=" ")
        PASSWORD=$(grep -i "^password=" $HOME/credentials | tr -d '\r'| tr -d '\n'| cut -f 2 -d "=" --output-delimiter=" ")        
        ;;
    i)  origen=$perfilmontat
        desti=$HOME
        ;;
    o)  origen=$HOME
        desti=$perfilmontat
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
#Si NO tenim usuari i password no podem configurar perfil mobil
    logger -t "linuxcaib-perfil-mobil($USER)" -s "ERROR: Se necessita usuari i contrassenya per poder sincronitzar el perfil mobil"
    show_caib_perfil_mobil_help
    exit 1
fi

if [ "$desti" != "$HOME" ];then
        #El destí és el share (esteim fent logout)
        #Miram si existeix un md5sum de la distribució actual dins la unitat de perfil mobil
        dirPerfilDist=$perfilmontat/$(lsb_release -ir | md5sum -|cut -d" " -f1)
        if [ ! -d "$dirPerfilDist" ];then
                #No existeix carpeta, l'hem de crear ja que esteim fent logout 
                mkdir  $dirPerfilDist
                logger -t "linuxcaib-perfil-mobil($USER)" -s "INFO: no hi ha perfil mòbil per la vostra distribució. O bé és la primera vegada que feis login o heu canviat de distribució!"
                logger -t "linuxcaib-perfil-mobil($USER)" -s "INFO: creada carpeta de perfil per a la distribució ($dirPerfilDist)!"
        fi
        #Actualitzam desti
        desti=$dirPerfilDist

else
        #El destí és el home (esteim fent login)
        #Miram si existeix un md5sum de la distribució actual dins la unitat de perfil mobil
        dirPerfilDist=$perfilmontat/$(lsb_release -ir | md5sum -|cut -d" " -f1)
        if [ -d "$dirPerfilDist" ];then
                #Existeix carpeta, actualitzam desti i perfilmontat
                origen=$perfilmontat/$(lsb_release -ir | md5sum -|cut -d" " -f1);
        else
                #No existeix carpeta de perfil específica per a la distribució... que feim????
                #Potser sigui la primera vegada que feim login...
                #Podem intentar importar llista blanca de una altra distribució (si n'hi ha)
                #Però per ara simplement no feim res.
                logger -t "linuxcaib-perfil-mobil($USER)" -s "WARNING: no hi ha perfil mòbil ($dirPerfilDist) per la vostra distribució. O bé és la primera vegada que feis login o heu canviat de distribució!"
                echo "#WARNING: no hi ha perfil mòbil per la vostra distribució. O bé és la primera vegada que feis login o heu canviat de distribució!"
                sleep 20;
                exit 0;
        fi
fi


[ "$DEBUG" -gt "0" ] && logger -t "linuxcaib-perfil-mobil($USER)" -s "Executant: rsync  --verbose --delete -rto -O --max-size=20mb --include-from=$includerules --exclude-from=$excluderules $origen"/" $desti"/" "
[ "$DEBUG" -gt "0" ] && logger -t "linuxcaib-perfil-mobil($USER)" -s "includerules=$(cat $includerules)"
[ "$DEBUG" -gt "0" ] && logger -t "linuxcaib-perfil-mobil($USER)" -s "excluderules=$(cat $excluderules)"

#La opció -O és necessària perquè el perfil està en xarxa
#Per ara llev --delete
RESULTEXEC=$(rsync  -v -r -O --max-size=20mb --include-from=$includerules --exclude-from=$excluderules $origen"/" $desti"/")

RESULT=$?
[ "$DEBUG" -gt "0" ] && logger -t "linuxcaib-perfil-mobil($USER)" -s "resultat sincronització: $RESULT"
if [ ! $RESULT -eq 0 ];then
        logger -t "linuxcaib-perfil-mobil($USER)" -s "Error sincronitzant el perfil mobil"
        logger -t "linuxcaib-perfil-mobil($USER)" -s "RESULT=$RESULT"
        logger -t "linuxcaib-perfil-mobil($USER)" -s "Resultat rsync: $RESULTEXEC"
        if [ "$DISPLAY" = ":0.0" ];then
                zenity --height=300 --timeout=20 --error --title="Sincronitzant Perfil Mobil"  --text="\nERROR: la sincronització del vostre perfil mòbil ha fallat\n\n\n\nAviseu a a SUPORT.\n\n Aquest dialeg se tancara en 20 segons" &
        fi
        exit 1;
else
        [ "$DEBUG" -gt "0" ] && logger -t "linuxcaib-perfil-mobil($USER)" -s "Perfil mobil sincronitzat correctament $RESULTEXEC"
        if [ "$DISPLAY" = ":0.0" ];then
                zenity --height=300 --timeout=2 --info --title="Sincronitzant Perfil Mobil"  --text="Perfil mòbil sincronitzat correctament."
        fi
fi

echo "# Sincronitzant perfil mobil... OK";sleep 1;
exit 0
