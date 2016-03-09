#!/bin/bash


# Script fet amb BASH que monta les unitats compartides mirjançant gvfs-mount de l'usuari donades d'alta dins 
# del SEYCON: unitats H i les unitats de grup. NO se monten les unitats P.

# L'script detecta si l'unitat ja està montada i no la torna a montar.

# 1- Comprovar que esteim loguejats via winbind
# 2- obtenir les unitats i montar-les via gvfs-mount 
# gvfs-mount smb://SERVIDOR/[SHARE]
# http://stackoverflow.com/questions/483460/how-to-mount-from-command-line-like-the-nautilus-does
# TODO: enllaçar cap a la carpetes montades: /var/run/user/94891/gvfs/smb-share\:server\=lofihom3.caib.es\,share\=u83511/

# Aquest script s'ha d'executar amb permissos d'usuari

# Pre-requisits: wget, xmlstarlet

#Aquesta variable ha de ser el nom del HOME de l'usuari, pel cas que sigui diferent de l'usuari CAIB.
USU_LINUX=$USER

#Si debug no està definida, la definim
if [ -z $DEBUG ]; then DEBUG=0; fi
if [ "$DEBUG" -ge 3 ]; then
    # trace output
    set -x
fi

PROGRESSBAR=20


#Importam les funcions auxiliars
#Ruta base scripts
BASEDIR=$(dirname $0)
if [ "$CAIBCONFUTILS" != "SI" ]; then
        logger -t "linuxcaib-conf-drives-user($USER)"  "CAIBCONFUTILS=$CAIBCONFUTILS Carregam utilitats de $BASEDIR/caib-conf-utils.sh"
        . $BASEDIR/caib-conf-utils.sh
fi


MOUNTOUTPUT=""
#Funcions

#Funció que monta una unitat compartida (windows share) mitjanant gvfs
# parametres funcio (usuariSeycon, password, unitatCompartida, puntMontatge)
montaUnitatCompartidagvfs () {
usuariSeycon=$1
password=$2
unitatCompartida=$3
puntMontatge=$4
group_id=$5



#Primer comprovam si ja esta montat

if ( gvfs-mount  --list|grep -q "smb://"$unitatCompartida  );then
        #Esta montat, no hem de tornar a montar
        logger -t "linuxcaib-conf-drives-user($USER)" -s  "Unitat $unitatCompartida ja montada via gvfs."
        [ "$DEBUG" -gt "0" ] && logger -t "linuxcaib-conf-drives-user($USER)" -s  "Línia del gvfs-mount --list : $(gvfs-mount  --list|grep -q smb://$unitatCompartida)"
        return 0;
else
	logger -t "linuxcaib-conf-drives-user($USER)" -s  "Unitat $unitatCompartida NO montada, la intentam montar."
fi

        { MOUNTOUTPUT=$(gvfs-mount smb://$unitatCompartida 2>&1 1>&3-) ;} 3>&1
RESULTM=$?

if [ $RESULTM -eq 0 ];then
   #TODO: llegir via gvfs-mount --list la informacio que vulguem mostrar per log
   logger -t "linuxcaib-conf-drives-user($USER)" -s  "Montada Unitat $unitatCompartida via gvfs"
   return 0
else
        logger -t "linuxcaib-conf-drives-user($USER)" -s "Error ($RESULTM) en montar la unitat smb://$unitatCompartida text error: $MOUNTOUTPUT"                
        if [ "$DEBUG" -gt "0" ];then
                logger -t "linuxcaib-conf-drives-user($USER)" -s "Parametres:"
                logger -t "linuxcaib-conf-drives-user($USER)" -s "Usuari seycon $usuariSeycon"
                logger -t "linuxcaib-conf-drives-user($USER)" -s "Unitat compartida SMB $unitatCompartida"
                logger -t "linuxcaib-conf-drives-user($USER)" -s "Punt montatge al filesystem $puntMontatge"
                logger -t "linuxcaib-conf-drives-user($USER)" -s "execucio: gvfs-mount -m smb://$unitatCompartida "
        fi
   return 1
fi
} #fi montaUnitatCompartidagvfs


# Initialize our own variables:
output_file=""

show_caib_conf_drives_help () {
cat << EOF
El programa "${0##*/}" monta les unitats compartides que l'usuari té assignades al SEYCON
Call que l'usuari estigui loguejat dins l'Active Directory mitjançant winbind-pam!

Ús: ${0##*/} [-hv]
    
      -h          mostra aquesta ajuda
      -c          agafa les credencials del fitxer "credentials". IMPORTANT, l'usuari ha de ser l'usuari de SEYCON.
      -v          mode verbose

Exemples:
        ${0##*/} -c     Execució emprant fitxer de credencials
EOF
}

#Fi funcions

# A POSIX variable
OPTIND=1         # Reset in case getopts has been used previously in the shell.

# Initialize our own variables:
output_file=""
while getopts "hmcv?l:u:p:" opt; do
    case "$opt" in
    h|\?)
        show_caib_conf_drives_help
        exit 0
        ;;
    c)
        if [ "$seyconSessionUser" != "" ];then
                USERNAME=$seyconSessionUser
                PASSWORD=$seyconSessionPassword
                [ "$DEBUG" -gt "1" ] && logger -t "linuxcaib-conf-drives($USER)" -s "INFO: emprant seyconSessionUser i seyconSessionPassword ($USERNAME - amb password de $(echo -n $PASSWORD | wc -c ) caràcters )"
        else
                #Com a backup intentam agafar el nom i contrasenya del fitxer credentials que hi ha dins el home de l'usuari.
                USERNAME=$(grep -i "^username=" $HOME/credentials | tr -d '\r'| tr -d '\n'| cut -f 2 -d "=" --output-delimiter=" ")
                PASSWORD=$(grep -i "^password=" $HOME/credentials | tr -d '\r'| tr -d '\n'| cut -f 2 -d "=" --output-delimiter=" ")
        fi     
        ;;
    v)  DEBUG=1
        ;;
    esac
done

shift $((OPTIND-1))

[ "$1" = "--" ] && shift


if [ -z "$USERNAME" ] || [ -z "$PASSWORD" ] 
then
#Si NO tenim usuari i password no podem configurar el proxy local
    logger -t "linuxcaib-conf-drives-user($USER)" -s "ERROR: Se necessita usuari i contrassenya per poder montar les unitats compartides" >&2
    show_caib_conf_drives_help
    exit 1
fi


if [ $USER = "root"  ]; then
        logger -t "linuxcaib-conf-drives-user($USER)" -s "ERROR: no se pot executar com a root!"
        show_caib_conf_drives_help
        exit 1;
fi

logger -t "linuxcaib-login-drives($USER)" -s "#Carregam unitats compartides"
#Aplicacions pre-requerides
if ( ! paquetInstalat "xmlstarlet" ); then
        logger -t "linuxcaib-conf-drives-user($USER)" -s "ERROR: cal instalar el paquet xmlstarlet (sudo apt-get install xmlstarlet)."
        exit 1;
fi

#Aplicacions pre-requerides
if ( ! paquetInstalat "wget" ); then
        logger -t "linuxcaib-conf-drives-user($USER)" -s "ERROR: cal instalar el paquet wget (sudo apt-get install wget)"
        exit 1;
fi


[ "$DEBUG" -gt "0" ] && logger -t "linuxcaib-conf-drives-user($USER)" -s "DEBUG=$DEBUG, usuari='$USERNAME', resta parametres no emprats: $@"

#Montam la unitat H
logger -t "linuxcaib-conf-drives-user($USER)" -s "#Montant unitat H"
USER_DATA=$(wget -O - -q --http-user=$USERNAME --http-password=$PASSWORD --no-check-certificate https://$SEYCON_SERVER:$SEYCON_PORT/query/user/$USERNAME )
RESULTM=$?
[ "$DEBUG" -gt "0" ] && logger -t "linuxcaib-conf-drives-user($USER)" -s "DEBUG: dades de l'usuari al seycon: $USER_DATA. USUARI de connexió: $USERNAME"

if [ $RESULTM -eq 0 ];then
        #<data><row> *   <MAQUSU_NOM>lofihom2</MAQUSU_NOM>  </row></data>
        xpath="data/row[1]/MAQUSU_NOM"
        HOME_DRIVE_SERVER=$(echo $USER_DATA | xmlstarlet sel -T -t -c $xpath )
        
        [ "$DEBUG" -gt "0" ] && logger -t "linuxcaib-conf-drives-user($USER)" -s "Unitat home de l'usuari esta al servidor: $HOME_DRIVE_SERVER -> montar: //$HOME_DRIVE_SERVER/$USERNAME a la unitat /home/$USU_LINUX/unitat_H"

        if  ( isHostNear "$HOME_DRIVE_SERVER" ) ; then

                RESULTM=$(montaUnitatCompartidagvfs $USERNAME $PASSWORD $HOME_DRIVE_SERVER.caib.es/$USERNAME /home/$USU_LINUX/unitat_H $(id $USERNAME -u) )
                RESULT=$?
                [ "$DEBUG" -gt "0" ] && logger -t "linuxcaib-conf-drives-user($USER)" -s "resultat montar: $RESULTM"
                if [ ! $RESULT -eq 0 ];then
                        logger -t "linuxcaib-conf-drives-user($USER)" -s "Error montant unitat h, no montam la resta"
                        logger -t "linuxcaib-conf-drives-user($USER)" -s "RESULT=$RESULT"                
                        logger -t "linuxcaib-conf-drives-user($USER)" -s "RESULTM=$RESULTM"
                        exit 1;
                else
                        [ "$DEBUG" -gt "0" ] && logger -t "linuxcaib-conf-drives-user($USER)" -s "Unitat H montada: $RESULTM"
                fi
        else
                logger -t "linuxcaib-conf-drives-user($USER)" -s "No he pogut montar la unitat H, el servidor ($HOME_DRIVE_SERVER) no és accessible."
        fi


        #MONTAR UNITAT PERFIL
        [ "$DEBUG" -gt "0" ] && logger -t "linuxcaib-conf-drives-user($USER)" "Montam la unitat amb el perfil mobil"
        # El perfil esta a: caib.es/profiles/$USERNAME   o caib.es/profiles/$USERNAME.V2 (a partir de windows 7)
        # PREGUNTA: L'AD crea el directori?
        #Montar dins /media/$USER/.unitat_perfil per a que no aparegui dins el nautilus.
        xpath="data/row[1]/MAQPRO_NOM"
        PROFILE_DRIVE_SERVER=$(echo $USER_DATA | xmlstarlet sel -T -t -c $xpath )
        if  ( isHostNear "$PROFILE_DRIVE_SERVER" ) ; then
                #mkdir -p /media/$USU_LINUX/.unitat_perfil
                #chown $USER:$USER /media/$USU_LINUX/.unitat_perfil
        RESULTM=$(montaUnitatCompartidagvfs $USERNAME $PASSWORD $PROFILE_DRIVE_SERVER.caib.es/profiles/$USERNAME /media/$USU_LINUX/.unitat_perfil $(id $USERNAME -u))
                RESULT=$?
                [ "$DEBUG" -gt "0" ] && logger -t "linuxcaib-conf-drives-user($USER)" -s "resultat montar perfil: $RESULTM"
                if [ ! $RESULT -eq 0 ];then
                        logger -t "linuxcaib-conf-drives-user($USER)" -s "Error montant unitat perfil"
                        logger -t "linuxcaib-conf-drives-user($USER)" -s "RESULT=$RESULT"                
                        logger -t "linuxcaib-conf-drives-user($USER)" -s "RESULTM=$RESULTM"
                        echo "# Error montant unitat perfil!!! "; sleep 10;
                     
                else
                        [ "$DEBUG" -gt "0" ] && logger -t "linuxcaib-conf-drives-user($USER)" -s "Perfil montat: $RESULTM"
                fi
        else
                logger -t "linuxcaib-conf-drives-user($USER)" -s "No he pogut montar la unitat del perfil, el servidor ($PROFILE_DRIVE_SERVER) no és accessible."
        fi
        #Hauriem de montar dins una carpeta oculta per a que l'usuari no la pugui tocar gaire.
        #Consultar amb la gent de windows si els hi pareix bé que el perfil sigui online.
        # Així s'haurien de crear els links simbolics del que es vulgui desar al perfil.
        #Si es vol un perfil offline, s'haurà de fer el procés de sincronització tant de baixada com pujada.... rsync????
else
        logger -t "linuxcaib-conf-drives-user($USER)" -s "ERROR: no he pogut accedir a les dades de l'usuari ($USERNAME): URL emprada: (https://$SEYCON_SERVER:$SEYCON_PORT/query/user/$USERNAME) raó: $(wget -O - --http-user=$USERNAME --http-password=$PASSWORD --no-check-certificate https://$SEYCON_SERVER:$SEYCON_PORT/query/user/$USERNAME)"
fi


#Si montar la primera unitat va bé, feim la resta, en cas contrari no n'intentam montar cap més.
#Configuram unitats compartides de xarxa
[ "$DEBUG" -gt "0" ] && logger -t "linuxcaib-conf-drives-user($USER)" "Montant altres unitats"

USER_DRIVES=$(wget -O - -q --http-user=$USERNAME --http-password=$PASSWORD --no-check-certificate https://$SEYCON_SERVER:$SEYCON_PORT/query/user/$USERNAME/drives )
RESULTM=$?
if [ ! $RESULTM -eq 0 ];then
   logger -t "linuxcaib-conf-drives-user($USER)" -s "# ERROR: no he pogut accedir a les unitats compartides de l'usuari $USERNAME (o no en te)."
   logger -t "linuxcaib-conf-drives-user($USER)" -s "\tCodi d'error (wget): $RESULTM. Resultat d'obtenir les unitats compartides del seycon: $USER_DRIVES."
   exit 1
fi
[ "$DEBUG" -gt "0" ] && logger -t "linuxcaib-conf-drives-user($USER)" -s "Unitats compartides de l'USERNAME: $USER_DRIVES"

#<row><GRU_UNIOFI>G:</GRU_UNIOFI><MAQ_NOM>lofigrp1</MAQ_NOM><GRU_CODI>dgtic</GRU_CODI></row>


NUM_DRIVES_USER=0;
xpath=""
NUM_DRIVES_USER=$(echo $USER_DRIVES | xmlstarlet sel -t -v "count(data/row)")

#el nombre de rows és el nombre de unitats compartides
NUM_DRIVES_USER=$(echo $USER_DRIVES | xmlstarlet sel -t -v "count(data/row)")

if [ "$NUM_DRIVES_USER" -gt "$MAX_DRIVES" ];then
        logger -t "linuxcaib-conf-drives-user($USER)" -s "WARNING: Massa unitats compartides definides al seycon! Només montaré les $MAX_DRIVES primeres"
        $NUM_DRIVES_USER=$MAX_DRIVES
fi

INDEXUNLETTEREDDRIVE=1
for y in $(seq 1 1 $NUM_DRIVES_USER) ; do
        #echo "processant unitat compartida $y"
        #<row><GRU_UNIOFI>G:</GRU_UNIOFI><MAQ_NOM>lofigrp1</MAQ_NOM><GRU_CODI>dgtic</GRU_CODI></row>
        xpath="data/row[$y]/GRU_UNIOFI/text()"
        UNIT_LETTER=$(echo $USER_DRIVES | xmlstarlet sel -T -t -c $xpath | tr -d ':') #Eliminam els ":"
        xpath="data/row[$y]/MAQ_NOM/text()"
        UNITSERVER=$(echo $USER_DRIVES | xmlstarlet sel -T -t -c $xpath )
        xpath="data/row[$y]/GRU_CODI/text()"
        GROUPCODE=$(echo $USER_DRIVES | xmlstarlet sel -T -t -c $xpath )
        if [ "$UNIT_LETTER" = "*" ] ; then
                #No s'ha definit una lletra per a la unitat. Hem d'agafar la següent lletra lliure de EMPTYDRIVE[INDEXUNLETTEREDDRIVE]
                EMPTYDRIVETMP="EMPTYDRIVE"$INDEXUNLETTEREDDRIVE
                UNIT_LETTER=${!EMPTYDRIVETMP} #TODO (migrar a sh): canviar aquest bashishm per alguna cosa de l'estil: eval "echo \$$EMPTYDRIVETMP"
                if [ "$DEBUG" -gt "0" ];then
                        logger -t "linuxcaib-conf-drives-user($USER)" -s "EMPTYDRIVE=$EMPTYDRIVE"
                        logger -t "linuxcaib-conf-drives-user($USER)" -s "INDEXUNLETTEREDDRIVE=$INDEXUNLETTEREDDRIVE"
                        logger -t "linuxcaib-conf-drives-user($USER)" -s "Assignam la següent lletra lliure: $UNIT_LETTER"
                fi        
                INDEXUNLETTEREDDRIVE=$(expr $INDEXUNLETTEREDDRIVE + 1)
        else
                [ "$DEBUG" -gt "0" ] && logger -t "linuxcaib-conf-drives-user($USER)" -s "La lletra a montar es: $UNIT_LETTER";
        fi
        [ "$DEBUG" -gt "0" ] && logger -t "linuxcaib-conf-drives-user($USER)" -s "Unitat: $UNIT_LETTER servidor: $UNITSERVER codi de grup $GROUPCODE  -> montar: //$UNITSERVER/$GROUPCODE a la unitat /media/$USER/unitatscompartides/$UNIT_LETTER_$GROUPCODE"

        #Agafam l'id del GROUPCODE de l'usuari.
        #       Agafar el ,143710(dgticadmdigital) identificador del grup amb nom groupcode mitjançant expressió regular.        
        # id|sed -r 's/.*,(.*)\(plugdev.*/\1/'
        #El mazinger fa aquesta comprovació abans de montar: if (isHostNear (host)) {
        GROUP_ID=$(id $USERNAME | sed -r 's/.*,(.*)\('"$GROUPCODE"'.*/\1/');
        logger -t "linuxcaib-conf-drives-user($USER)" -s "group_id=$GROUP_ID "
        if  ( isHostNear "$UNITSERVER" ) ; then        
                echo "# Montant unitat ("$UNIT_LETTER"_"$GROUPCODE")"                
                RESULTM=$(montaUnitatCompartidagvfs $USERNAME $PASSWORD $UNITSERVER/$GROUPCODE /media/$USU_LINUX/unitatscompartides/"$UNIT_LETTER"_"$GROUPCODE" $GROUP_ID)
        else
                logger -t "linuxcaib-conf-drives-user($USER)" -s "No he pogut montar la unitat compartida $GROUPCODE, el servidor ($UNITSERVER) no és accessible."
        fi
done

#Si arribam aquí és que tot ha anat bé.
exit 0
