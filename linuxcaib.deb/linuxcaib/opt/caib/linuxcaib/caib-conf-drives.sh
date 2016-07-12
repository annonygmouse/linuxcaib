#!/bin/bash


# Script fet amb BASH que monta les unitats compartides de l'usuari donades d'alta dins 
# del SEYCON. Monta les unitats H, P i les unitats de grup.
# Per defecte les unitats H i perfil se monten a "/home/$USU_LINUX/unitatscompartides/unitat_H i /media/$USU_LINUX/unitatscompartides/.unitat_perfil respectivament"
# Les altres unitats compartides (G,I,J,....) se monten dins /media/$USU_LINUX/lletra_nomshare
# La unitat P (de windows) es monta dins /media/P_pcapp/
# La unitat P (de LINUX) es monta dins /media/P_pcapplinux

# L'script detecta si l'unitat ja està montada i no la torna a montar.

# TODO: DIVIDIR AQUEST SCRIPT EN DOS un per montar les unitats que no s'han de desmontar en fer logout i 
# que només pot montar root 
# i un altre (caib-conf-drives-user.sh) que empri gvfs-mount per les unitats compartides windows de l'usuari (si esteim loguejats amb winbind)
# gvfs-mount smb://SERVIDOR/[SHARE]
# http://stackoverflow.com/questions/483460/how-to-mount-from-command-line-like-the-nautilus-does

# Aquest script s'ha d'executar amb permissos de administrador ( o mitjançant sudo).

# L'script empra usuari/password agafats del fitxer credentials o passats per paràmetre.

# Pre-requisits: wget, xmlstarlet

#El PAM_MOUNT no s'empra, però deix el codi per si acàs.
#Variables per ".pam_mount.conf.xml".
#A /etc/security/pam_mount.conf.xml ha d'estar habilitat
#<luserconf name=".pam_mount.conf.xml" />

LUSERCONF_PAM_MOUNT="NO" #Inicialització de variable.

PAM_MOUNT_LUSER_CONF_HEAD="
<?xml version=\"1.0\" encoding=\"utf-8\" ?>
<!DOCTYPE pam_mount SYSTEM \"pam_mount.conf.xml.dtd\">
<pam_mount>
";

PAM_MOUNT_LUSER_CONF_FOOT="</pam_mount>"

PAM_MOUNT_H_VOLUME="" #Unitat H
PAM_MOUNT_P_VOLUME="" #Unitat P
PAM_MOUNT_OTHER_VOLUME="" #Altres unitats compartides

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
        logger -t "linuxcaib-conf-drives($USER)"  "CAIBCONFUTILS=$CAIBCONFUTILS Carregam utilitats de $BASEDIR/caib-conf-utils.sh"
        . $BASEDIR/caib-conf-utils.sh
fi


MOUNTOUTPUT=""
#Funcions

#Funció que monta una unitat compartida (windows share) al punt de montatge passat
# parametres funcio (usuariSeycon, password, unitatCompartida, puntMontatge)
montaUnitatCompartida () {
usuariSeycon=$1
password=$2
unitatCompartida=$3
puntMontatge=$4
group_id=$5

if [ "$group_id" = "" ];then
        logger -t "linuxcaib-conf-drives($USER)" -s "ERROR: montaUnitatCompartida group_id no proporcionat, emprant -domain users- com a fallback"
#        group_id=$(id $usuariSeycon | sed -r 's/.*=(.*)\('"domain\ users"'.*/\1/');
        group_id=$(id u83511 -g);
        logger -t "linuxcaib-conf-drives($USER)" -s "group_id=$group_id"
fi

if [ "$LUSERCONF_PAM_MOUNT" = "SI" ];then
        logger -t "linuxcaib-conf-drives($USER)" -s "No mont la unitat perque estic creant el fitxer de configuració .pam_mount.conf.xml"
        return 0;
fi


#Primer comprovam si ja esta montat
if ( df | grep "$(echo $unitatCompartida | sed -e 's/\//\\\//g')">/dev/null );then
        #Esta montat, no hem de tornar a montar
        logger -t "linuxcaib-conf-drives($USER)" -s  "Unitat $unitatCompartida ja montada a $puntMontatge."
        [ "$DEBUG" -gt "0" ] && logger -t "linuxcaib-conf-drives($USER)" -s  "Línia del fstab: $(df | grep "$(echo $puntMontatge | sed -e 's/\//\\\//g')")"
        return 1
fi

#Cream la carpeta de montatge si no existeix
if [ ! -d $puntMontatge ];then
        mkdir -p $puntMontatge
        chown $USER:$group_id $puntMontatge
        [ "$DEBUG" -gt "0" ] && logger -t "linuxcaib-conf-drives($USER)" -s  "creada carpeta de montatge $puntMontatge"
fi

#NO FUNCIONA: crec que hauriem d'estar dins domini per obtenir tickets mitjançant el TicketGrantingTicket. TEST: mirar si hi ha kerberos activat (amb ticket actiu mitjançant klist) mount -t cifs //lofiapp/pcapp /media/P_pcapplinux/ -o username=u83511,sec=krb5,domain=CAIB.ES,cruid=1003,uid=1003,gid=1003,rw,dmask=0700
#if ( ticketKerberosActiu $USER );then
#        { MOUNTOUTPUT=$(sudo mount -t cifs $unitatCompartida $puntMontatge  -o iocharset=utf8,rw,krb5,domain=CAIB.ES,file_mode=0777,dir_mode=0777,nobrl 2>&1 1>&3-) ;} 3>&1
#else
#Opcions que empra el mazinger a linux: sprintf(opts,"unc=%s,uid=%d,gid=%d,file_mode=0700,dir_mode=0700,ver=1,iocharset=utf8",
#A jo amb els mode=0700 me dona un error.

# TODO: afegir el gid i uid per cada unitat!  
# Exemple per l'usuari u83511:
#       id:
#uid=94891(u83511) gid=10513(domain users) grups=10513(domain users),27(sudo),108(lpadmin),131(vboxusers),2001(BUILTIN\users),11065(dgtic),14232(punitot2),106751(dgticseg),109321(client_notes),129580(dgticfax),143710(dgticadmdigital),152103(int_usuari2)
#       
#        mount -t cifs //lofigrp1/dgticadmdigital /media/test_i/  -o iocharset=utf8,rw,username=u83511,password=XXXXXXXXX,gid=143710,uid=94891,file_mode=0777,dir_mode=0777,nobrl

#Seria una cosa aixi: mount -t cifs //lofigrp1/dgticadmdigital /media/test_i/  -o iocharset=utf8,rw,username=u83511,password=XXXXXXXXX,gid=$PARAM_GID,uid=$(id -u),file_mode=0770,dir_mode=0770,nobrl
        { MOUNTOUTPUT=$( mount -t cifs $unitatCompartida $puntMontatge  -o iocharset=utf8,rw,username=$usuariSeycon,password=$password,uid=$(id -u $usuariSeycon),gid=$group_id,nobrl 2>&1 1>&3-) ;} 3>&1
#fi
RESULTM=$?

if [ $RESULTM -eq 0 ];then
   logger -t "linuxcaib-conf-drives($USER)" -s  "Montada Unitat $unitatCompartida a $puntMontatge, amb uid=$(id -u $usuariSeycon) i gid=$group_id"
   return 0
else

        if [ $RESULTM -eq 32 ];then
                logger -t "linuxcaib-conf-drives($USER)" -s "Error ($RESULTM) en montar: $MOUNTOUTPUT"                
                logger -t "linuxcaib-conf-drives($USER)" -s "Si l'error és: \"Permission denied\" és que la contrasenya no és vàlida o l'usuari està bloquejat, telefonau al 77070 per a que vos desbloquegin l'usuari"
                logger -t "linuxcaib-conf-drives($USER)" -s "Si l'error és: \"Device or resource busy\" és que a aquest punt ja hi ha algun dispositiu montat"
        else
                logger -t "linuxcaib-conf-drives($USER)" -s "No he pogut montar unitat compartida $unitatCompartida a $puntMontatge, error: $MOUNTOUTPUT"
        fi        
        if [ "$DEBUG" -gt "0" ];then
                logger -t "linuxcaib-conf-drives($USER)" -s "Parametres:"
                logger -t "linuxcaib-conf-drives($USER)" -s "Usuari seycon $usuariSeycon"
                logger -t "linuxcaib-conf-drives($USER)" -s "Unitat compartida SMB $unitatCompartida"
                [ "$DEBUG" -gt "2" ] && logger -t "linuxcaib-conf-drives($USER)" -s "Password $password"
                logger -t "linuxcaib-conf-drives($USER)" -s "Punt montatge al filesystem $puntMontatge"
                logger -t "linuxcaib-conf-drives($USER)" -s "execucio: sudo mount -t cifs $unitatCompartida $puntMontatge  -o iocharset=utf8,rw,username=$usuariSeycon,password=$password,file_mode=0777,dir_mode=0777,nobrl"
        fi
   return 1
fi
} #fi montaUnitatCompartida


# Initialize our own variables:
output_file=""

show_caib_conf_drives_help () {
cat << EOF
El programa "${0##*/}" monta les unitats compartides que l'usuari té assignades al SEYCON

Ús: ${0##*/} [-chmv] [-u USUARI] [-p PASSWORD] [-l USU_LOCAL]
    
      -c          agafa les credencials del fitxer "credentials". IMPORTANT, l'usuari ha de ser l'usuari de SEYCON.
      -h          mostra aquesta ajuda
      -l USUARI   nom de l'usuari local que s'emprarà (si es diferent al de seycon), necessari quan s'ha d'emprar via sudo
      -m          mode pam_mount. No monta les unitats, tan sols genera el .pam_mount.conf.xml (deprecat)
      -u USUARI   nom de l'usuari a emprar
      -p PASSWORD contrasenya de l'usuari a emprar
      -v          mode verbose

Exemples:
        ${0##*/} -u u83511 -p password_u83511   Execució passant usuari i contrasenya
        ${0##*/} -c     Execució emprant fitxer de credencials
        sudo ${0##*/} -l sebastia -u u8351 -p contrasenya_u83511            Executant via sudo amb l'usuari "sebastia"
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
    l)  LOCALUSERNAME="$OPTARG"
        USU_LINUX=$LOCALUSERNAME
        ;;
    v)  DEBUG=$(($DEBUG + 1))
        ;;
    m)  LUSERCONF_PAM_MOUNT="SI"
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
#Si NO tenim usuari i password no podem montar les unitats compartides
    logger -t "linuxcaib-conf-drives($USER)" -s "ERROR: Se necessita usuari i contrassenya per poder montar les unitats compartides" >&2
    show_caib_conf_drives_help
    exit 1
fi


if [ $USER = "root"  ]; then
        echo "localusername=$LOCALUSERNAME"
        if [ -z "$LOCALUSERNAME" ];then 
                logger -t "linuxcaib-conf-drives($USER)" -s "ERROR: no se pot executar com a root!"
                show_caib_conf_drives_help
                logger -t "linuxcaib-conf-drives($USER)" -s "Si estas executant via sudo, has d'emprar el paràmetre -l!"
                exit 1;
        fi
        if [ ! -d /home/$LOCALUSERNAME  ];then
                logger -t "linuxcaib-conf-drives($LOCALUSERNAME)" "ERROR: l'usuari local no te home! Avortant..."
                exit 1;
        else 
                HOME=/home/$LOCALUSERNAME
        fi
fi

if [ -z "$LOCALUSERNAME" ];then
        logger -t "linuxcaib-conf-drives($USER)" "WARNING: LOCALUSERNAME no definit, serà \$USER ($USER) "
        LOCALUSERNAME=$USER
fi

logger -t "linuxcaib-login-drives($USER)" -s "#Carregam unitats compartides"
#Aplicacions pre-requerides
if ( ! paquetInstalat "xmlstarlet" ); then
        logger -t "linuxcaib-conf-drives($USER)" -s "ERROR: cal instalar el paquet xmlstarlet (sudo apt-get install xmlstarlet)."
        exit 1;
fi

#Aplicacions pre-requerides
if ( ! paquetInstalat "wget" ); then
        logger -t "linuxcaib-conf-drives($USER)" -s "ERROR: cal instalar el paquet wget (sudo apt-get install wget)"
        exit 1;
fi


[ "$DEBUG" -gt "0" ] && logger -t "linuxcaib-conf-drives($USER)" -s "DEBUG=$DEBUG, usuari='$USERNAME', resta parametres no emprats: $@"

#Montam la unitat H
logger -t "linuxcaib-conf-drives($USER)" -s "#Montant unitat H"
#logger -t "linuxcaib-conf-drives($USER)" -f $HOME/.wgetrc
USER_DATA=$(wget -O - -q --http-user=$USERNAME --http-password=$PASSWORD --no-check-certificate https://$SEYCON_SERVER:$SEYCON_PORT/query/user/$USERNAME )
RESULTM=$?
[ "$DEBUG" -gt "0" ] && logger -t "linuxcaib-conf-drives($USER)" -s "DEBUG: dades de l'usuari al seycon: $USER_DATA. USUARI de connexió: $USERNAME"

if [ $RESULTM -eq 0 ];then
        #<data><row> *   <MAQUSU_NOM>lofihom2</MAQUSU_NOM>  </row></data>
        xpath="data/row[1]/MAQUSU_NOM"
        HOME_DRIVE_SERVER=$(echo $USER_DATA | xmlstarlet sel -T -t -c $xpath )
	#Exportam info recuperada del seycon per a que l'empri posteriorment caib-conf-drives-user.sh         
	echo $USER_DATA > /var/run/user/$(id -u)/seycon_query_user	
        [ "$DEBUG" -gt "0" ] && logger -t "linuxcaib-conf-drives($USER)" -s "Unitat home de l'usuari esta al servidor: $HOME_DRIVE_SERVER -> montar: //$HOME_DRIVE_SERVER/$USERNAME a la unitat /home/$USU_LINUX/unitat_H"

        if  ( isHostNear "$HOME_DRIVE_SERVER" ) ; then
                mkdir -p /home/$USU_LINUX/unitat_H
                chown $USER:$USER /home/$USU_LINUX/unitat_H

# Cream mount.conf local:
#<volume options="uid=%(USER),gid=10000,dmask=0700" user="*" mountpoint="/home/%(USER)" path="%(USER)" server="servername" fstype="smbfs" /> 
                PAM_MOUNT_H_VOLUME="<volume options=\"uid=%(USER),gid=10000,dmask=0700\" user=\"%(USER)\" mountpoint=\"/home/%(USER)/unitat_H\" path=\"%(USER)/\" server=\"$HOME_DRIVE_SERVER\" fstype=\"cifs\" />"
                RESULTM=$(montaUnitatCompartida $USERNAME $PASSWORD //$HOME_DRIVE_SERVER.caib.es/$USERNAME /home/$USU_LINUX/unitat_H $(id $USERNAME -u) )
                RESULT=$?
                [ "$DEBUG" -gt "0" ] && logger -t "linuxcaib-conf-drives($USER)" -s "resultat montar: $RESULTM"
                if [ ! $RESULT -eq 0 ];then
                        logger -t "linuxcaib-conf-drives($USER)" -s "Error montant unitat h, no montam la resta"
                        logger -t "linuxcaib-conf-drives($USER)" -s "RESULT=$RESULT"                
                        logger -t "linuxcaib-conf-drives($USER)" -s "RESULTM=$RESULTM"
                        exit 1;
                else
                        [ "$DEBUG" -gt "0" ] && logger -t "linuxcaib-conf-drives($USER)" -s "Unitat H montada: $RESULTM"
                fi
        else
                logger -t "linuxcaib-conf-drives($USER)" -s "No he pogut montar la unitat H, el servidor ($HOME_DRIVE_SERVER) no és accessible."
        fi


        #MONTAR UNITAT PERFIL
        [ "$DEBUG" -gt "0" ] && logger -t "linuxcaib-conf-drives($USER)" "Montam la unitat amb el perfil mobil"
        # El perfil esta a: caib.es/profiles/$USERNAME   o caib.es/profiles/$USERNAME.V2 (a partir de windows 7)
        # PREGUNTA: L'AD crea el directori?
        #Montar dins /media/$USER/.unitat_perfil per a que no aparegui dins el nautilus.
        xpath="data/row[1]/MAQPRO_NOM"
        PROFILE_DRIVE_SERVER=$(echo $USER_DATA | xmlstarlet sel -T -t -c $xpath )
        if  ( isHostNear "$PROFILE_DRIVE_SERVER" ) ; then
                #mkdir -p /media/$USU_LINUX/.unitat_perfil
                #chown $USER:$USER /media/$USU_LINUX/.unitat_perfil
        RESULTM=$(montaUnitatCompartida $USERNAME $PASSWORD //$PROFILE_DRIVE_SERVER.caib.es/profiles/$USERNAME /media/$USU_LINUX/.unitat_perfil $(id $USERNAME -u))
                RESULT=$?
                [ "$DEBUG" -gt "0" ] && logger -t "linuxcaib-conf-drives($USER)" -s "resultat montar perfil: $RESULTM"
                if [ ! $RESULT -eq 0 ];then
                        logger -t "linuxcaib-conf-drives($USER)" -s "Error montant unitat perfil"
                        logger -t "linuxcaib-conf-drives($USER)" -s "RESULT=$RESULT"                
                        logger -t "linuxcaib-conf-drives($USER)" -s "RESULTM=$RESULTM"
                        echo "# Error montant unitat perfil!!! "; sleep 10;
                     
                else
                        [ "$DEBUG" -gt "0" ] && logger -t "linuxcaib-conf-drives($USER)" -s "Perfil montat: $RESULTM"
                fi
        else
                logger -t "linuxcaib-conf-drives($USER)" -s "No he pogut montar la unitat del perfil, el servidor ($PROFILE_DRIVE_SERVER) no és accessible."
        fi
        #Hauriem de montar dins una carpeta oculta per a que l'usuari no la pugui tocar gaire.
        #Consultar amb la gent de windows si els hi pareix bé que el perfil sigui online.
        # Així s'haurien de crear els links simbolics del que es vulgui desar al perfil.
        #Si es vol un perfil offline, s'haurà de fer el procés de sincronització tant de baixada com pujada.... rsync????
        #PAM_MOUNT_H_VOLUME="<volume options="uid=%(USER),gid=10000,dmask=0700" user="*" mountpoint="/home/%(USER)/unitatscompartides/unitat_H" path="%(USER)" server="$HOME_DRIVE_SERVER" fstype="cifs" />"

   
else
        logger -t "linuxcaib-conf-drives($USER)" -s "ERROR: no he pogut accedir a les dades de l'usuari ($USERNAME): URL emprada: (https://$SEYCON_SERVER:$SEYCON_PORT/query/user/$USERNAME) raó: $(wget -O - --http-user=$USERNAME --http-password=$PASSWORD --no-check-certificate https://$SEYCON_SERVER:$SEYCON_PORT/query/user/$USERNAME)"
fi


#Montam la unitat P
echo "# Montant unitat ofimatica (P)"
[ "$DEBUG" -gt "0" ] && logger -t "linuxcaib-conf-drives($USER)" -s "Montant unitat P"
if  ( isHostNear "$PSERVER" ) ; then        
        RESULTM=$(montaUnitatCompartida $USERNAME $PASSWORD //$PSERVER.caib.es/$PSHARE /media/P_$PSHARE)
        #sudo mount -t cifs //lofiapp1/pcapp /home/$USU_LINUX/unitatscompartides/unitat_p -o iocharset=utf8,rw,username=$USU,password=$PASS,file_mode=0777,dir_mode=0777,nobrl
        #PAM_MOUNT_P_VOLUME="<volume options=\"uid=%(USER),gid=10000,dmask=0700\" user=\"*\" mountpoint=\"/home/%(USER)/unitatscompartides/unitat_P\" path=\"$PSHARE/\" server=\"$PSERVER\" fstype=\"cifs\" />"
        #ln -s /media/unitat_P /home/$USU_LINUX/unitatscompartides/unitat_P
else
        logger -t "linuxcaib-conf-drives($USER)" -s "No he pogut montar la unitat P, el servidor ($PSERVER) no és a prop."
fi


#Montam la unitat P de linux
if  ( isHostNear "$PSERVER" ) ; then   
	echo "# Montant unitat ofimatica (P) (linux)"
        if [ ! -d /media/P_$PSHARE_LINUX ];then
                mkdir -p /media/P_$PSHARE_LINUX
        fi
        mount -t nfs -o timeo=10,soft $PSERVER_LINUX.caib.es:/app/lofiapp/ /media/P_$PSHARE_LINUX
else
        logger -t "linuxcaib-conf-drives($USER)" -s "No he pogut montar la unitat P, el servidor ($PSERVER) no és a prop."
fi

#Si montar la primera unitat va bé, feim la resta, en cas contrari no n'intentam montar cap més.
#Configuram unitats compartides de xarxa
[ "$DEBUG" -gt "0" ] && logger -t "linuxcaib-conf-drives($USER)" "Montant altres unitats"

USER_DRIVES=$(wget -O - -q --http-user=$USERNAME --http-password=$PASSWORD --no-check-certificate https://$SEYCON_SERVER:$SEYCON_PORT/query/user/$USERNAME/drives )
RESULTM=$?
if [ ! $RESULTM -eq 0 ];then
   logger -t "linuxcaib-conf-drives($USER)" -s "# ERROR: no he pogut accedir a les unitats compartides de l'usuari $USERNAME (o no en te)."
   logger -t "linuxcaib-conf-drives($USER)" -s "\tCodi d'error (wget): $RESULTM. Resultat d'obtenir les unitats compartides del seycon: $USER_DRIVES."
   exit 1
fi

[ "$DEBUG" -gt "0" ] && logger -t "linuxcaib-conf-drives($USER)" -s "Unitats compartides de l'USERNAME: $USER_DRIVES"
#Exportam info recuperada del seycon per a que l'empri posteriorment caib-conf-drives-user.sh         
echo $USER_DRIVES > /var/run/user/$(id -u)/seycon_query_user_drives	

#<row><GRU_UNIOFI>G:</GRU_UNIOFI><MAQ_NOM>lofigrp1</MAQ_NOM><GRU_CODI>dgtic</GRU_CODI></row>


mkdir -p /media/$USERNAME/
chown $USERNAME:$USERNAME /media/$USERNAME/
mkdir -p /media/$USERNAME/unitatscompartides/
chown $USERNAME:$USERNAME /media/$USERNAME/unitatscompartides/

NUM_DRIVES_USER=0;
xpath=""
NUM_DRIVES_USER=$(echo $USER_DRIVES | xmlstarlet sel -t -v "count(data/row)")

#el nombre de rows és el nombre de unitats compartides
NUM_DRIVES_USER=$(echo $USER_DRIVES | xmlstarlet sel -t -v "count(data/row)")

if [ "$NUM_DRIVES_USER" -gt "$MAX_DRIVES" ];then
        logger -t "linuxcaib-conf-drives($USER)" -s "WARNING: Massa unitats compartides definides al seycon! Només montaré les $MAX_DRIVES primeres"
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
                        logger -t "linuxcaib-conf-drives($USER)" -s "EMPTYDRIVE=$EMPTYDRIVE"
                        logger -t "linuxcaib-conf-drives($USER)" -s "INDEXUNLETTEREDDRIVE=$INDEXUNLETTEREDDRIVE"
                        logger -t "linuxcaib-conf-drives($USER)" -s "Assignam la següent lletra lliure: $UNIT_LETTER"
                fi        
                INDEXUNLETTEREDDRIVE=$(expr $INDEXUNLETTEREDDRIVE + 1)
        else
                [ "$DEBUG" -gt "0" ] && logger -t "linuxcaib-conf-drives($USER)" -s "La lletra a montar es: $UNIT_LETTER";
        fi
        [ "$DEBUG" -gt "0" ] && logger -t "linuxcaib-conf-drives($USER)" -s "Unitat: $UNIT_LETTER servidor: $UNITSERVER codi de grup $GROUPCODE  -> montar: //$UNITSERVER/$GROUPCODE a la unitat /media/$USER/unitatscompartides/$UNIT_LETTER_$GROUPCODE"

        #TODO: agafar l'id del GROUPCODE de l'usuari.
        #       Agafar el ,143710(dgticadmdigital) identificador del grup amb nom groupcode mitjançant expressió regular.        
        # id|sed -r 's/.*,(.*)\(plugdev.*/\1/'
        #El mazinger fa aquesta comprovació abans de montar: if (isHostNear (host)) {
        GROUP_ID=""
        if [ id u83511 | grep -q dgticfax ];then
                GROUP_ID=$(id $USERNAME | sed -r 's/.*,(.*)\('"$GROUPCODE"'.*/\1/');
        fi
        logger -t "linuxcaib-conf-drives($USER)" -s "groupcode=$GROUPCODE group_id=$GROUP_ID "
        if  ( isHostNear "$UNITSERVER" ) ; then        
                echo "# Montant unitat ("$UNIT_LETTER"_"$GROUPCODE")"                
                #mkdir -p /media/$USU_LINUX/unitatscompartides/"$UNIT_LETTER"_"$GROUPCODE"
                #chown $USER:$ID_GROUP /media/$USU_LINUX/unitatscompartides/"$UNIT_LETTER"_"$GROUPCODE"
                RESULTM=$(montaUnitatCompartida $USERNAME $PASSWORD //$UNITSERVER/$GROUPCODE /media/$USU_LINUX/unitatscompartides/"$UNIT_LETTER"_"$GROUPCODE" $GROUP_ID)

                RESULT=$?
                [ "$DEBUG" -gt "0" ] && logger -t "linuxcaib-conf-drives($USER)" -s "resultat montar unitat $UNIT_LETTER _ $GROUPCODE : $RESULTM"
                if [ ! $RESULT -eq 0 ];then
                        logger -t "linuxcaib-conf-drives($USER)" -s "Error montant unitat $UNIT_LETTER"_"$GROUPCODE"
                        logger -t "linuxcaib-conf-drives($USER)" -s "RESULT=$RESULT"                
                        logger -t "linuxcaib-conf-drives($USER)" -s "RESULTM=$RESULTM"
                        echo "# Error montant unitat $UNIT_LETTER _ $GROUPCODE!!! "; sleep 10;
                     
                else
                        [ "$DEBUG" -gt "0" ] && logger -t "linuxcaib-conf-drives($USER)" -s "Unitat $UNIT_LETTER _ $GROUPCODE  montada a : /media/$USU_LINUX unitatscompartides/$UNIT_LETTER _ $GROUPCODE"
                fi                
                PAM_MOUNT_OTHER_VOLUME="$PAM_MOUNT_OTHER_VOLUME 
<volume options=\"uid=%(USER),gid=10000,dmask=0700\" user=\"*\" mountpoint=\"/home/%(USER)/unitatscompartides/"$UNIT_LETTER"_"$GROUPCODE"\" path=\"$GROUPCODE/\" server=\"$UNITSERVER\" fstype=\"cifs\" />"
        else
                logger -t "linuxcaib-conf-drives($USER)" -s "No he pogut montar la unitat compartida $GROUPCODE, el servidor ($UNITSERVER) no és accessible."
        fi
done

if [ "$LUSERCONF_PAM_MOUNT" = "SI" ];then
        #Cream el fitxer de configuració local de pam_mount
        PAM_MOUNT_LUSER_CONF="$PAM_MOUNT_LUSER_CONF_HEAD $PAM_MOUNT_H_VOLUME $PAM_MOUNT_P_VOLUME $PAM_MOUNT_OTHER_VOLUME $PAM_MOUNT_LUSER_CONF_FOOT"
        echo "Fitxer .pam_mount.conf.xml = $PAM_MOUNT_LUSER_CONF"
        echo $PAM_MOUNT_LUSER_CONF > $HOME/.pam_mount.conf.xml
        logger -t "linuxcaib-conf-drives($USER)" -s "Fitxer de configuració .pam_mount.conf.xml creat."
        xmlstarlet fo --indent-tab --omit-decl .pam_mount.conf.xml
        [ "$DEBUG" -gt "0" ] && logger -t "linuxcaib-conf-drives($USER)" -f $HOME/.pam_mount.conf.xml
fi

#TODO: amagar totes les particions/disks que NO siguin de xarxa ( a no ser que l'usuari tengui role punitot2)
#Aquesta funcionalitat la duu a terme l'script "caib-conf-hide-drives"
#. ./ad-policies/caib-conf-hide-drives

#Si arribam aquí és que tot ha anat bé.
exit 0
