
# Catàleg de funcions i utilitats 
# Te com a PRE-requisit les variables de configuració (caib-conf-settings.sh)

#Importam les funcions auxiliars
#Ruta base scripts
called=$_
#echo "called= $called"
#echo "dolar_=$_"
#echo "dollar0=$0"
#echo "BASH_SOURCE=$BASH_SOURCE"
#echo "DASH_SOURCE=$DASH_SOURCE"
#echo "readlink 0 = $(readlink $0)"
if [ "$(readlink $0)" = "" ];then
        #no es un enllaç, agafam ruta normal
        #echo "fitxer normal $0"
        RUTA_FITXER=$(dirname $0)
        BASEDIR=$RUTA_FITXER
else
        #echo "enllaç"
        RUTA_FITXER=$(readlink $0)
        BASEDIR=$( dirname $RUTA_FITXER)
fi

#Dash no te la variable d'entorn HOSTNAME
HOSTNAME=$(hostname)

#Si debug no està definida, la definim
if [ -z $DEBUG ]; then DEBUG=0; fi


if [ -f $BASEDIR/caib-conf-settings.sh ];then
[ "$DEBUG" -gt "1" ] && logger -t "linuxcaib-conf-utils($USER)" -s "Carregam variables de configuració de $BASEDIR/caib-conf-settings.sh"
. $BASEDIR/caib-conf-settings.sh
else
[ "$DEBUG" -gt "1" ] && logger -t "linuxcaib-conf-utils($USER)" -s "Carregam variables de configuració directament de /opt/caib/linuxcaib/caib-conf-settings.sh"
. /opt/caib/linuxcaib/caib-conf-settings.sh
fi




CAIBCONFUTILS="SI" #Per saber si s'ha carregat aquest fitxer


#Si no esteim executant amb permissos de root, haurem d'emprar sudo per executar les comandes administratives.
if [ ! $(id -u) -eq 0 ];then
        SUDO="sudo "
        [ "$DEBUG" -gt "0" ] && logger -t "linuxcaib-conf-utils($USER)" -s "Usuari no té id=0 (id=$(id -u)), definim variable SUDO per poder executar amb permissos d'administrador"
fi




#Funció que torna 0 si el host està dins d'una xarxa normalitzada.
isNormalized () {
maquina=$1
echo $maquina | sed -e 's/\(^.*\)\(.$\)/\2/'
if [ "$(echo $maquina | sed -e 's/\(^.*\)\(.$\)/\2/')" = "l" ];then
        #Màquina que acaba en "l", suposaré que és un àlies.
        logger -t "linuxcaib-conf-utils($USER)" -s "INFO: el nom de maquina acaba en 'l', suposaré que és un àlies de la màquina: $maquina"
        maquina=$(echo $maquina | sed -e 's/\(.*\)./\1/')
        echo "$maquina"
fi 
HOST_DATA=$(wget -O - -q --http-user=$USERNAME --http-password=$PASSWORD --no-check-certificate https://$SEYCON_SERVER:$SEYCON_PORT/query/host/$maquina )
RESULTM=$?
if [ ! $RESULTM -eq 0 ];then
        [ "$DEBUG" -gt "0" ] && logger -t "linuxcaib-conf-utils($USER)" -s "ERROR: verificant https://$SEYCON_SERVER:$SEYCON_PORT/query/host/$maquina  màquina codi error wget $RESULTM, resultat petició: $HOST_DATA"
        return 0;
fi

xpath="data/row[1]/XAR_CODI"
HOST_NETWORK_CODE=$(echo $HOST_DATA | xmlstarlet sel -T -t -c $xpath )

NETWORK_DATA=$(wget -O - -q --http-user=$USERNAME --http-password=$PASSWORD --no-check-certificate https://$SEYCON_SERVER:$SEYCON_PORT/query/network/$HOST_NETWORK_CODE )
xpath="data/row[1]/XAR_NORM"
NORMALIZED_NETWORK=$(echo $NETWORK_DATA | xmlstarlet sel -T -t -c $xpath )

if [ "$NORMALIZED_NETWORK" = "S" ]; then
        [ "$DEBUG" -gt "0" ] && logger -t "linuxcaib-conf-utils($USER)" -s "isNormalized la màquina $maquina esta normalitzada"
        return 0;
else
        [ "$DEBUG" -gt "0" ] && logger -t "linuxcaib-conf-utils($USER)" -s "isNormalized la màquina $maquina NO esta normalitzada"
        return 1;
fi

}




#Consulta dades del seycon
#Si troba la url dins la cache de l'usuari, empra la de cache
#en cas contrari, se connecta al seycon amb les credencials de l'usuari per descarregar-se
#les dades de la URL i les desa en cache

SeyconQuery() {
        USERNAME=$(grep -i "^username=" /home/$USER/credentials | tr -d '\r'| tr -d '\n'| cut -f 2 -d "=" --output-delimiter=" ")
        PASSWORD=$(grep -i "^password=" /home/$USER/credentials | tr -d '\r'| tr -d '\n'| cut -f 2 -d "=" --output-delimiter=" ")
        URL=$1
        URLCACHE=$(echo $URL|sed 's/\//_/g')
        SEYCON_SERVER=$(cat $BASEDIR/conf/SSOServer|cut -d"," -f 1)
        SEYCON_SERVERS=$(cat $BASEDIR/conf/SSOServer)
 
#        SEYCON_SERVER="sticlin2.caib.es"
#        SEYCON_SERVERS="sticlin2.caib.es,stsmlin3.caib.es"

        # S'ha de posar el resultat din SEYCON_ANSWER
        SEYCON_ANSWER=""        
        SEYCON_ANSWERED="N"

        #Primer miram si ho tenim en cache
        SEYCON_ANSWER=$(cat /tmp/$USER/$URLCACHE)
        if [ "$SEYCON_ANSWER" != "" ];then
                logger -t "linuxcaib-conf-utils($USERNAME)" "SeyconQuery: Emprant resposta en cache de /tmp/$USER/$URLCACHE"
                return
        else
                logger -t "linuxcaib-conf-utils($USERNAME)" "SeyconQuery: Url no en cache, la davallarem del servidor"
        fi

        #Bucle amb els servidors, el primer servidor que va be fa sortir del bucle. 
        for SEYCON_SERVER in $(echo $SEYCON_SERVERS |sed "s/,/ /g");do
                SEYCON_ANSWER=$(wget -O - -q --http-user=$USERNAME --http-password=$PASSWORD --no-check-certificate "https://$SEYCON_SERVER:$SEYCON_PORT/query/$URL" )
                RESULTM=$?
                
                #Tractam el "return codes" de wget                        
#        0   No problems occurred.
#       1   Generic error code.
#       2   Parse error---for instance, when parsing command-line options, the .wgetrc or .netrc...
#       3   File I/O error.
#       4   Network failure.
#       5   SSL verification failure.
#       6   Username/password authentication failure.
#       7   Protocol errors.
#       8   Server issued an error response.
                case "$RESULTM" in
                        "0")
                                #Ha anat bé, torn el valor
                                SEYCON_ANSWERED="S"
                                echo "Surt del for"
                                break
                        ;;
                        "4")
                                logger -t "linuxcaib-conf-utils($USERNAME)" "SeyconQuery: ERROR de xarxa."
                        ;;
                        "5")
                                logger -t "linuxcaib-conf-utils($USERNAME)" "SeyconQuery: ERROR de SSL."
                        ;;
                        "6")
                                logger -t "linuxcaib-conf-utils($USERNAME)" "SeyconQuery: ERROR: Usuari/password incorrectes."
                        ;;
                        "8")
                                logger -t "linuxcaib-conf-utils($USERNAME)" "SeyconQuery: ERROR el servidor ha tornar un missatge d'error intern."
                        ;;
                esac
                logger -t "linuxcaib-conf-utils($USERNAME)" -s "SeyconQuery: ERROR: no he pogut accedir al seycon amb l'usuari $USERNAME. URL emprada: https://$SEYCON_SERVER:$SEYCON_PORT/query/$URL wget ha tornat codi=$RESULTM, i la resposta http ha estat: $(echo $SEYCON_ANSWER| awk '{print substr($0,0,15)"..."}')"
        done
         if [ "$SEYCON_ANSWERED" = "S" ];then
                logger -t "linuxcaib-conf-utils($USERNAME)" "SeyconQuery: Resposta seycon: "$SEYCON_ANSWER
                logger -t "linuxcaib-conf-utils($USERNAME)" "SeyconQuery: Desant el resultat dins /tmp/$USER/$URLCACHE"
                echo $SEYCON_ANSWER > /tmp/$USER/$URLCACHE
        else
                logger -t "linuxcaib-conf-utils($USERNAME)" "SeyconQuery: UNAVAILABLE"
        fi  
}

#URL
#Etiqueta
getSeyconCol() {
        URL=$1
        ETIQUETA=$2
        SeyconQuery $URL
        SEYCON_ANSWER=$(cat /tmp/$USER/$URLCACHE)
        if [ "$SEYCON_ANSWER" = "" ];then
                echo "getSeyconCol ERROR en obtenir la url $URL"
        else
                echo "Resposta seycon: "$SEYCON_ANSWER
                echo "Processant etiqueta:"
                xpath="data/row[1]/$ETIQUETA"
                valorEtiqueta=$(echo $SEYCON_ANSWER | xmlstarlet sel -T -t -c $xpath )
                echo "Valor $ETIQUETA = $valorEtiqueta"
        fi  
}




#EN PROCES 
#Funció que interactua amb el seycon. Li passam una URL i torna el resultat
#Parametres:
#   1 - codi d'usuari que fa la petició
#   2 - contrasenya d'usuari que fa la petició
#   3 - URL que es vol obtenir (sense nom servidor ni port)
#Si no aconsegueix connectar-se a un servidor, ho intenta a l'altre
#Si no aconsegueix resposta de cap servidor, torna "UNAVAILABLE"
getSeyconUrl() {
        USERNAME=$1
        PASSWORD=$1
        URL=$3
        SEYCON_SERVER=$(cat $BASEDIR/conf/SSOServer|cut -d"," -f 1)
        SEYCON_SERVERS=$(cat $BASEDIR/conf/SSOServer)
        #obtenir return value i desar output a una variable
        #segons codi return intentar tornar a intentar-ho contra l'altre servidor seycon
        #fer echo del resultat del seycon
        
        #Bucle amb els servidors, el primer servidor que va be fa sortir del bucle. Ha de posar el resultat din SEYCON_ANSWER
        SEYCON_ANSWER=""        
        SEYCON_ANSWERED="N"
        for SEYCON_SERVER in $(echo $SEYCON_SERVERS |sed "s/,/ /g");do
                SEYCON_ANSWER=$(wget -O - -q --http-user=$USERNAME --http-password=$PASSWORD --no-check-certificate "https://$SEYCON_SERVER:$SEYCON_PORT/$URL" )
                RESULTM=$?
                
                #Tractam el "return codes" de wget                        
#        0   No problems occurred.
#       1   Generic error code.
#       2   Parse error---for instance, when parsing command-line options, the .wgetrc or .netrc...
#       3   File I/O error.
#       4   Network failure.
#       5   SSL verification failure.
#       6   Username/password authentication failure.
#       7   Protocol errors.
#       8   Server issued an error response.
                case "$RESULTM" in
                        "0")
                                #Ha anat bé, torn el valor
                                SEYCON_ANSWERED="s"
                                #Surt del for
                                return
                        ;;
                        "4")
                                logger -t "linuxcaib-conf-utils($USERNAME)" "ERROR de xarxa."
                        ;;
                        "5")
                                logger -t "linuxcaib-conf-utils($USERNAME)" "ERROR de SSL."
                        ;;
                        "6")
                                logger -t "linuxcaib-conf-utils($USERNAME)" "ERROR: Usuari/password incorrectes."
                        ;;
                        "8")
                                logger -t "linuxcaib-conf-utils($USERNAME)" "ERROR el servidor ha tornar un missatge d'error intern."
                        ;;
                esac
                logger -t "linuxcaib-conf-utils($USERNAME)" "ERROR: no he pogut accedir al seycon amb l'usuari $USERNAME. URL emprada: https://$SEYCON_SERVER:$SEYCON_PORT/$URL wget ha tornat codi=$RESULTM, i la resposta http ha estat: $(echo $SEYCON_ANSWER| awk '{print substr($0,0,15)"..."}')"
        done
        if [ "$SEYCON_ANSWERED" = "s" ];then
                echo $SEYCON_ANSWER
        else
                echo "UNAVAILABLE"
        fi        
}



#Mira si el host passat esta a una xarxa normalitzada.
#La funció torna "0" en els següents casos:
#   - Si servidor i client estan a la mateixa xarxa
#   - Si el client NO esta al seycon. Pero el servidor SI esta a una xarxa normalitzada
#   - Si el host i el client estan a una xarxa normalitzada
isHostNear () {
SERVIDOR=$1

HOST_DATA=$(wget -O - -q --http-user=$USERNAME --http-password=$PASSWORD --no-check-certificate https://$SEYCON_SERVER:$SEYCON_PORT/query/host/$SERVIDOR )
RESULTM=$?
if [ ! $RESULTM -eq 0 ];then
   logger -t "linuxcaib-conf-utils($USER)" -s "Servidor $SERVIDOR NO està al SEYCON."
   return 1
fi

xpath="data/row[1]/XAR_CODI"
HOST_NETWORK_CODE=$(echo $HOST_DATA | xmlstarlet sel -T -t -c $xpath )

if [ "$DEBUG" -gt "0" ];then
        logger -t "linuxcaib-conf-utils($USER)" -s "isHostNear el servidor $SERVIDOR esta a la xarxa $HOST_NETWORK_CODE"
fi

HOSTNAME_DATA=$(wget -O - -q --http-user=$USERNAME --http-password=$PASSWORD --no-check-certificate https://$SEYCON_SERVER:$SEYCON_PORT/query/host/$(hostname) )
RESULTM=$?
if [ ! $RESULTM -eq 0 ];then
        logger -t "linuxcaib-conf-utils($USER)" -s "La màquina client $(hostname) NO està al SEYCON."
         isNormalized $SERVIDOR
        normalitzats=$?
        return $normalitzat
fi

xpath="data/row[1]/XAR_CODI"
HOSTNAME_NETWORK_CODE=$(echo $HOSTNAME_DATA | xmlstarlet sel -T -t -c $xpath )
if [ "$DEBUG" -gt "0" ];then
        logger -t "linuxcaib-conf-utils($USER)" -s "isHostNear el client $(hostname) esta a la xarxa $HOSTNAME_NETWORK_CODE"
fi

if [ "$HOST_NETWORK_CODE" = "$HOSTNAME_NETWORK_CODE" ]; then
        if [ "$DEBUG" -gt "0" ];then
                logger -t "linuxcaib-conf-utils($USER)" -s "isHostNear el servidor $SERVIDOR esta a prop ja que estan a la mateixa xarxa."
        fi
        return 0;
else
        isNormalized $SERVIDOR && isNormalized $(hostname)
        normalitzats=$?
        if [ "$normalitzats" ]; then
                if [ "$DEBUG" -gt "0" ];then
                        logger -t "linuxcaib-conf-utils($USER)" -s "isHostNear el servidor $SERVIDOR esta a prop ja que client i servidor estan normalitzats."
                fi
        else
                if [ "$DEBUG" -gt "0" ];then
                        logger -t "linuxcaib-conf-utils($USER)" -s "isHostNear el servidor $SERVIDOR NO esta a prop ja que o el servidor o el client NO estan normalitzats."
                fi
        fi

        return $normalitzats
fi
}


#Mira si el host passat és accessible via ping.
#La funció torna "0" si el servidor és accessible 
isHostNearPing () {
SERVIDOR=$1
ping -t $TTL -c 1 -W 0.2 -w 0.2 -q $SERVIDOR  > /dev/null
RESULTM=$?
if [ $RESULTM -eq 0 ];then
        logger  -t "linuxcaib-conf-utils($USER)" "Servidor $SERVIDOR accessible"
        return 0
else
        logger  -t "linuxcaib-conf-utils($USER)" "Servidor $SERVIDOR NO accessible"
        return 1
fi
}


#Instala la aplicació passada per paràmetre al sistema Debian
DebInstalPackage () {
PACKAGENAME=$1
case "echo "${FILE##*.}"" in
    deb)
         return dpkg -i $PACKAGENAME 
        ;;
    rpm)
        logger -t "linuxcaib-conf-utils($USER)" "Mirar si paquet esta a llista blanca de rpm instalable via alien?"
        logger -t "linuxcaib-conf-utils($USER)" -s "No puc instalar paquets rpm a una distribucio basada en debian"
        return 1
        ;;
     *)
        [ "$DEBUG" -gt "0" ] && logger -t "linuxcaib-conf-utils($USER)" -s "DebInstalPackage: s'instal·lara el paquet $PACKAGENAME."
        $SUDO apt-get -qq install $PACKAGENAME 
        if [ "$?" != "0" ];then
                logger -t "linuxcaib-conf-utils($USER)" -s "DebInstalPackage: ERROR instal·lant el paquet $PACKAGENAME, mirar els logs!"
        else
                [ "$DEBUG" -gt "0" ] && logger -t "linuxcaib-conf-utils($USER)" -s "DebInstalPackage: paquet $PACKAGENAME instal·lat correctament."
        fi 
        ;;        
esac
}

#Instala la aplicació passada per paràmetre al sistema basat en RPM
RPMInstalPackage () {
PACKAGENAME=$1

case "echo "${FILE##*.}"" in
    rpm)
         return rpm -i $PACKAGENAME
        ;;
    deb)
        logger "Mirar si paquet esta a llista blanca de rpm instalable via alien."
        logger -s "No puc instalar paquets rpm a una distribucio basada en debian"
        return 1
        ;;
     *)
        $SUDO yum install $PACKAGENAME
        ;;        
esac

}

#Instala la aplicació passada per paràmetre
instalarPaquet () {
PACKAGENAME=$1

#Detectar el SO (Debian 7.5, ubuntu 12.04, ubuntu 14.04, redhat,  ...)
DISTRIB=$(lsb_release -i|cut -f 2)
DIST_RELEASE=$(lsb_release -r|cut -f 2)

       
#Si sistema basat en dpkg
#Si acaba en .deb
DebInstalPackage $PACKAGENAME
return $?

#Si sistema basat en rpm
instalarRPMPackage $PACKAGENAME
return $?
#en tots els altres casos
logger -s "ERROR: no puc instal·lar aquest tipus de paquet"
return 1
}


#Torna les distribucions soportades per linuxcaib:
#       UBUNTU si es una distribució ubuntu i DEBIAN si és Debian
#       En cas contrari torna "UNKNOWN"
quinaDistribucio() {

        case $(lsb_release -i| cut -c 17-) in
                "Debian")
                        echo "DEBIAN"
                        ;;
                "Ubuntu")
                        echo "UBUNTU"
                        ;;  
                *)
                        echo "UNKNOWN"
                        ;;  
        esac
}

#Torna la versió (release) de la distribució:
quinaRelease() {
        release=$(lsb_release -r | cut -c 10-)
        echo $release
}

#Indica si la distribució està soportada per linuxcaib
#       Torna "SI" si la distribució/release estan soportades
#       Torna "NO" en cas contrari
# A mida que vagi provant a diferents distribucions actualitzaré aquesta funció.
distribucioSoportada () {

        if [ "$(quinaDistribucio)" = "UNKNOWN" ];then
                echo "NO"
                return
        fi
        release=$(quinaRelease)
        case $(quinaDistribucio) in
                "DEBIAN")
                        case $release in
                                testing)
                                        echo "SI"
                                        ;;
                                *)
                                        echo "NO"
                                        ;;
                        esac
                        ;;
                "UBUNTU")
                        case $release in
                                "12.04") # 14,.04 ?
                                        echo "SI"
                                        ;;
                                *)
                                        echo "NO"
                                        ;;
                        esac
                        ;;  
                *)
                        echo "NO"
                        ;;  
        esac
}




#Activa el mode debug de pam_mount
#Se passa per paràmetre el nivell de debug que es vol
activarDebugPAMMount () {
NIVELL_DEBUG=2 #Per defecte logejar a syslog

if [ -z "$1" ]; then
        NIVELL_DEBUG=$1
fi

DEBUG_PAM_MOUNT=$(xmlstarlet sel  -t -v "/pam_mount/debug/@enable" /etc/security/pam_mount.conf.xml )
case "$DEBUG_PAM_MOUNT" in
    "")
         #Debug esta comentat, l'hem de descomentar.
        echo "El debug esta comentat dins /etc/security/pam_mount.conf.xml, no el puc activar"
        $SUDO sed -e 's/<!--\n<debug/<debug/g' /etc/security/pam_mount.conf.xml
        
        ;;
    "0")
        $SUDO sed -i -e 's/debug enable=\"0\"/debug enable=\"2\"/g' /etc/security/pam_mount.conf.xml                
        return 1
        ;;
    "1")
        $SUDO sed -i -e 's/debug enable=\"1\"/debug enable=\"2\"/g' /etc/security/pam_mount.conf.xml
        return 1
        ;;
     *)
        echo "ERROR: no he pogut activar el debu del pam_mount"
        ;;        
esac
}


#Torna l'usuari que hi ha loguejat a les X.
#Si no hi ha cap usuari loguetat a les X torna cadena buida.
#RESTRICCIÓ: l'usuari ha d'estar loguejat a :0 !!!!
XWindowsLoggedUser () {
#DEBIAN! who -u --ips|awk '{print $1" "$2}'|grep :0|awk '{print $1}'

#Ubuntu!
LANG=C who -u --ips|awk '{print $1" "$8}'|grep :0|awk '{print $1}'|head -1
}

#Torna 0 si el paquet passat està instal·lat al sistema
paquetInstalat () {
        nomPaquet=$1
        #Debian
        versioPaquet=$(dpkg -l| grep ^.i| grep -w "\s$nomPaquet\s"  |   awk 'BEGIN { FS = " " } ; { print $3 }')
        if [ "$versioPaquet" != "" ];then
                [ "$DEBUG" -gt "0" ] && logger -t "linuxcaib-conf-utils($USER)" -s "paquetInstalat: el paquet $nomPaquet està instal·lat amb la versió $versioPaquet."
                return 0
        else        
                [ "$DEBUG" -gt "0" ] && logger -t "linuxcaib-conf-utils($USER)" -s "paquetInstalat: el paquet $nomPaquet NO instal·lat."
                return 1
        fi
}


#Torna la versió del paquet instal·lat o buid si no està instal·lat
versioPaquetInstalat () {
        nomPaquet=$1
        #Debian
        versioPaquet=$(dpkg -l| grep ^.i| grep -w "\s$nomPaquet\s"  |   awk 'BEGIN { FS = " " } ; { print $3 }')
        if [ "$versioPaquet" != "" ];then
                [ "$DEBUG" -gt "0" ] && logger -t "linuxcaib-conf-utils($USER)" -s "paquetInstalat: el paquet $nomPaquet està instal·lat amb la versió $versioPaquet."
                echo $versioPaquet
        else        
                [ "$DEBUG" -gt "0" ] && logger -t "linuxcaib-conf-utils($USER)" -s "paquetInstalat: el paquet $nomPaquet NO instal·lat."
                echo ""
        fi
}



#Elimina les impressores de tipus LPD i IPP donades d'alta a la màquina
eliminarImpressores () {

#Eliminam les lpd
NETPRINTER=""
lpstat -s|grep lpd | while read NETPRINTER
do
   #echo "NETPRINTER=$NETPRINTER"
   PRINTERNAME=$(echo $NETPRINTER| awk 'BEGIN  { FS=":\/\/"} {print $2}'|awk 'BEGIN  { FS="\/"} {print $2}')
   #echo "hem d'eliminar la impressora: $NETPRINTER amb nom $PRINTERNAME"
   $SUDO lpadmin -x $PRINTERNAME
RESULTM=$?
if [ $RESULTM -eq 0 ];then
   logger -t "linuxcaib-conf-printers($USER)" -s  "Eliminada impressora: $PRINTERNAME"
else
   logger -t "linuxcaib-conf-printers($USER)" -s "ERROR: no he pogut eliminar la impressora $PRINTERNAME"
fi
done

#Eliminam les ipp
NETPRINTER=""
lpstat -s|grep ipp | while read NETPRINTER
do
   #echo "NETPRINTER=$NETPRINTER"
   PRINTERNAME=$(echo "$NETPRINTER"| awk 'BEGIN  { FS=":\/\/"} {print $2}'|awk 'BEGIN  { FS="\/"} {print $1}')
   #echo "hem d'eliminar la impressora: -$NETPRINTER- amb nom -$PRINTERNAME-"
   #echo "sudo lpadmin -x -$PRINTERNAME-"
   $SUDO lpadmin -x $PRINTERNAME
RESULTM=$?
if [ $RESULTM -eq 0 ];then
   logger -t "linuxcaib-conf-printers($USER)" -s  "Eliminada impressora: $PRINTERNAME"
else
   logger -t "linuxcaib-conf-printers($USER)" -s "ERROR: no he pogut eliminar la impressora $PRINTERNAME"
fi
done
} 

#Torna 0 si l'usuari passat per paràmetre té un ticket kerberos actiu
ticketKerberosActiu () {
usuari=$1
krbTicket=$(klist|grep "$usuari" >/dev/null && echo "SI")
if [ "$krbTicket" = "SI" ];then
[ "$DEBUG" -gt "0" ] && logger -t "linuxcaib-conf-utils($USER)" -s "ticketKerberosActiu: l'usuari $USER té ticket actiu."
return 0
else        
[ "$DEBUG" -gt "0" ] && logger -t "linuxcaib-conf-utils($USER)" -s "ticketKerberosActiu: l'usuari $USER NO té ticket actiu."
return 1
fi
}

#Funció que torna un nombre random de 0 a 32768
random () {
echo $(( $(hexdump -n 2 -e '/2 "%u"' /dev/urandom) % 32768 ))
}

#Funció que torna un nombre random de 1025 a 32768 (per a que un usuari el pugui obrir)
randomPort() {
FLOOR=1024
number=0   #initialize
while [ "$number" -le $FLOOR ]
do
  number=$(random)
done
#echo "Random number greater than $FLOOR ---  $number"
echo $number
}

#Funció que torna una carpeta temporal de memòria
carpetaTempMemoria() {
     /bin/df -t tmpfs |grep shm| awk 'BEGIN  { FS=" "} {print $6}'
}

#Funció que crea els fitxers de credencials necessaris a la carpeta en memoria (tmpfs)
#param1: codi d'ususari
#param2: contrasenya
crear_fitxers_credencials () {
        codiUsuari=$1
        password=$2
        carpeta=$(carpetaTempMemoria)

[ "$DEBUG" -gt "0" ] && logger -t "linuxcaib-conf-utils(crear_fitxers_credencials)" -s "id=$(id $codiUsuari)"
[ "$DEBUG" -gt "0" ] && logger -t "linuxcaib-conf-utils(crear_fitxers_credencials)" -s "gid=$(id $codiUsuari -gn)"
USER_GID=$(id $codiUsuari -gn)
                NOMFITXCREDS="$codiUsuari""_caib_credentials"
                [ "$DEBUG" -gt "0" ] && logger -t "crear_fitxers_credencials" "Creant fitxers credentials dins memoria $carpeta/$codiUsuari/$NOMFITXCREDS."
                touch $carpeta/$codiUsuari/$NOMFITXCREDS
                chown $codiUsuari:"$USER_GID" $carpeta/$codiUsuari/$NOMFITXCREDS
                chmod 600 $carpeta/$codiUsuari/$NOMFITXCREDS
                cat > $carpeta/$codiUsuari/$NOMFITXCREDS << EOF
username=$codiUsuari
password=$password
EOF

                #Cream fitxer credentials per mazinger
                NOMFITXCREDS=$NOMFITXCREDS"_mazinger"
                [ "$DEBUG" -gt "0" ] && logger -t "crear_fitxers_credencials" "Creant fitxers credentials dins memoria $carpeta/$codiUsuari/$NOMFITXCREDS."
                touch $carpeta/$codiUsuari/$NOMFITXCREDS
                chown $codiUsuari:"$USER_GID" $carpeta/$codiUsuari/$NOMFITXCREDS
                chmod 600 $carpeta/$codiUsuari/$NOMFITXCREDS
                cat > $carpeta/$codiUsuari/$NOMFITXCREDS << EOF
user=$codiUsuari
password=$password
EOF

} #Fi crear_fitxers_credencials


#Funció que enllaça els fitxers de credencials de la carpeta
#temporal a la carpeta del home.
#param1: carpeta temporal on hi ha els fitxers de credencials
#param2: carpeta din home on enllaçar els fitxers de credencials
enllacar_fitxers_credencials () {
seycon_usu=$1
carpetaTmp=$2
carpetaHome=$3

[ "$DEBUG" -gt "0" ] && logger -t "linuxcaib-conf-utils(crear_fitxers_credencials)" -s "id=$(id $seycon_usu)"
[ "$DEBUG" -gt "0" ] && logger -t "linuxcaib-conf-utils(crear_fitxers_credencials)" -s "gid=$(id $seycon_usu -gn)"
USER_GID=$(id $seycon_usu -gn)
       #1. enllaçar $HOME/credentials cap a /tmpfs/$USER_caib_credentials
        TMPMEM=$carpetaTmp
        NOMFITXCREDS="$TMPMEM/""$seycon_usu/""$seycon_usu""_caib_credentials"
        [ "$DEBUG" -gt "0" ] && logger -t "linuxcaib-pam-util" "NOMFITXCREDS: $NOMFITXCREDS"
        if [ -f $NOMFITXCREDS  ];then
                #Si existeix fitxer credencials a la particio en memoria
                [ "$DEBUG" -gt "0" ] && logger -t "linuxcaib-pam-util" "Trobat fitxer de credentials a la particio temporal en memoria enllaçam"
                ln -fs $NOMFITXCREDS $carpetaHome/credentials
                chown $seycon_usu:"$USER_GID" $carpetaHome/credentials                
                chown -fh $seycon_usu:"$USER_GID" $carpetaHome/credentials
                PASSWORD=$(grep -i "^password=" $carpetaHome/credentials | tr -d '\r'| tr -d '\n'| cut -f 2 -d "=" --output-delimiter=" ")
                #Ídem amb fitxer credencials pel mazinger
                #ln -fs $NOMFITXCREDS"_mazinger" $carpetaHome/credentials_mazinger
                #chown $seycon_usu:"$USER_GID" $carpetaHome/credentials_mazinger
                #chown -fh $seycon_usu:"$USER_GID" $carpetaHome/credentials_mazinger                
        else
                logger -t "linuxcaib-pam-util" "ERROR: no he trobat fitxer de credentials a la particio temporal en memoria! Usuari LOCAL"
        fi
}

#WARN (no ho emprarem): Funció que xifra el fitxer de credencials
xifrar_fitxers_credencials () {
        echo "stub: per ara no ho empram"

} #Fi xifrar_fitxers_credencials


#Funció que torna la arquitectura del sistema
#x86_64 si és de 64bits
#i386 si és de 32bits (independentment de si es i386, i586 o i686))
MachineArch () {

arch=`uname -m`
case "$arch" in
    i?86) arch=i386 ;;
    x86_64) arch="x86_64" ;;
#    ppc64) arch="ppc64 ppc" ;;
esac
echo $arch
}



#Funció que redirecciona el port PORT_ALT al PORT_BAIX, essent el port ALT un port
#que l'usuari pot obrir i BAIX el port < 1024 que l'usuari vol obrir
#Requisits: que l'usuari tengui permisos d'administrador via $SUDO
#           que NOMES tengui una interfície de xarxa amb adreça IP assignada
#param1: port alt 
#param2: port baix
RedireccionarPort() {
        portAlt=$1
        portBaix=$2
IP=$(/sbin/ifconfig | grep "inet addr:" | grep -v 127.0.0.1 | sed -e 's/Bcast//' | cut -d: -f2)
$SUDO iptables -t nat -A PREROUTING -p tcp --dport $portBaix -j REDIRECT --to-port $portAlt
$SUDO iptables -t nat -I OUTPUT -p tcp -d $IP --dport $portBaix -j REDIRECT --to-ports $portAlt
echo "ATENCIÓ: Port $portAlt redireccionat al port $portBaix !"
}

#Funció que redirecciona el port de VNC (5900) cap al port 80 per evitar firewalls 
RedireccionarPortVNC() {
        RedireccionarPort 5900 80
}


#Evita que s'actualitzi el paquet passat per paràmetre
#Parametres funcio: { nomPaquet }
#WARN: funciona només per distribucions tipus debian.
posarPaquetHold () {
paquet=$1
echo "$paquet hold" | dpkg --set-selections
}


#Suposam que l'usuari esta a la variable $PAM_USER
#Demana la contrasenya a l'usuari i la desa dins la variable PASSWORD
introduir_nou_password() {


        CREDENTIALENTRY=$(zenity --width=680 --height=480 --password --title="$PAM_USER: La vostra contrasenya ha canviat des del darrer login amb certificat digital. Cal que introduiu la vostra contrasenya de login" )
        case $? in
                 0)
                        echo "Contraseña: `echo $CREDENTIALENTRY | cut -d'|' -f2`"
                        DIALOGPASSWORD=$(echo $CREDENTIALENTRY | cut -d'|' -f2)         
                        if [ "$DIALOGPASSWORD" != "" ];then
                                #Actualitzam password
                                PASSWORD=$DIALOGPASSWORD
                        else
                                /usr/bin/zenity  --error --title="Accés a la xarxa corporativa" --text="ERROR: Contrasenya buida, NO iniciam sessió."
                                echo "Contrasenya buida, NO iniciam sessió.";
                                exit 1
                        fi
                
                        ;;
                 1)
                        /usr/bin/zenity  --error --title="Accés a la xarxa corporativa" --text="ERROR: Contrasenya buida, NO iniciam sessió."
                        exit 1
                        ;;
                -1)
                        echo "Ha ocurrido un error inesperado."
                        /usr/bin/zenity  --error --title="Accés a la xarxa corporativa" --text="ERROR:  error inesperat, NO iniciam sessió."
                        exit 1
                        ;;
        
        esac
}



#Funció per saber si el nom de màquina passat és un servidor d'impressió linux o no.
#Torna "SI" si el servidor passat per paràmetre és un servidor d'impressio Linux
#Torna "NO" en cas contrari
esServImprLinux() {
        prntSrvr=$1
        #Per ara no tenim servior d'impressió Linux.
        #Quan en tenguem un s'haurà de dir simprlinX
        $(echo $prntSrvr | grep -q simprlin && echo "SI")
}


#Torna "true" si la unitat H de l'usuari esta montada.
unitatHMontada () {

if [ "$(df |grep unitat_H)" != "" ];then
        echo "true"
else
        echo "false"
fi


}



instalaCertChrome () {
rutaCert=$1
nomCert=$2
tipusCert=$3
#Google chrome empra NSSDB per gestionar els certificats: $HOME/.pki/nssdb
certDir="$HOME/.pki/nssdb"

if [ ! -d $certDir ];then
        logger -t "linuxcaib-conf-utils(instalaCertChrome-$USER)" -s "No hi ha repositori de certificats de google-chrome ($certDir)"
        return
fi
#logger -t "linuxcaib-conf-utils($USER)" -s "google-chrome certificate installing '${nomCert}' in $HOME/.pki/nssdb"
  #echo "openssl x509 -in $rutaCert  -inform der -outform pem  | certutil -A -n \"${nomCert}\" -t \"$tipusCert\" -d sql:$HOME/.pki/nssdb"
  if [ "$(certutil -L -d sql:${certDir} | grep -c "${nomCert}")" -eq "1" ];then
        logger -t "linuxcaib-conf-utils(instalaCertChrome-$USER)" -s "certificat '${nomCert}' ja instalat a '$certDir"
        return        
  fi  

  if ( ! openssl x509 -in $rutaCert -inform der -outform pem | certutil -A -n "${nomCert}" -t "$tipusCert" -d sql:${certDir} );then
       #echo "2 certutil -A -n \"${nomCert}\" -t \"$tipusCert\" -d sql:${certDir} -i $rutaCert"
       cat $rutaCert | certutil -A -n "${nomCert}" -t "$tipusCert" -d sql:${certDir} 
  fi
  if [ "$(certutil -L -d sql:${certDir} | grep -c "${nomCert}")" -eq "1" ];then
        logger -t "linuxcaib-conf-utils(instalaCertChrome-$USER)" -s "google-chrome certificate installation '${nomCert}' in $HOME/.pki/nssdb done"        
  else
        logger -t "linuxcaib-conf-utils(instalaCertChrome-$USER)" -s "google-chrome certificate installation '${nomCert}' in $HOME/.pki/nssdb ERROR"
  fi  
}

# Eliminar certificat:
# certutil -D -n "FNMT-CLASSE2-ROOT"  -d sql:/home/u83511/.mozilla/firefox/d6urde6h.default

instalaCertMozillacert9 () {
rutaCert=$1
nomCert=$2
tipusCert=$3

for certDB in $(find  $HOME/.mozilla* ~/.thunderbird -name "cert9.db")
do
  certDir=$(dirname ${certDB});
  #logger -t "linuxcaib-conf-utils($USER)" -s "mozilla certificate installing '${nomCert}' in ${certDir}/cert9.db done"
  #echo "openssl x509 -in $rutaCert -inform der -outform pem | certutil -A -n \"${nomCert}\" -t \"$tipusCert\" -d sql:${certDir}"
  if [ "$(certutil -L -d sql:${certDir} | grep -c "${nomCert}")" -eq "1" ];then
        logger -t "linuxcaib-conf-utils(instalaCertMozillacert9-$USER)" -s "certificat '${nomCert}' ja instalat a '${certDir}'/cert9.db"
        return        
  fi

  if ( ! openssl x509 -in $rutaCert -inform der -outform pem | certutil -A -n "${nomCert}" -t "$tipusCert" -d sql:${certDir} );then
       #echo "2 certutil -A -n \"${nomCert}\" -t \"$tipusCert\" -d sql:${certDir} -i $rutaCert"
       cat $rutaCert | certutil -A -n "${nomCert}" -t "$tipusCert" -d sql:${certDir}
  fi
  if [ "$(certutil -L -d sql:${certDir} | grep -c "${nomCert}")" -eq "1" ];then
        logger -t "linuxcaib-conf-utils(instalaCertMozillacert9-$USER)" -s "mozilla certificat installation '${nomCert}' in '${certDir}'/cert9.db done"        
  else
        logger -t "linuxcaib-conf-utils(instalaCertMozillacert9-$USER)" -s "mozilla certificate installation '${nomCert}' in '${certDir}'/cert9.db ERROR"
  fi
done
}

instalaCertMozillacert8 () {
rutaCert=$1
nomCert=$2
tipusCert=$3

for certDB in $(find  $HOME/.mozilla* ~/.thunderbird -name "cert8.db")
do
  certDir=$(dirname ${certDB});
  #logger -t "linuxcaib-conf-utils($USER)" -s "mozilla certificate installing '${nomCert}' in '${certDir}'/cert8.db"
  #echo "openssl x509 -in $rutaCert -inform der -outform pem | certutil -A -n \"${nomCert}\" -t \"$tipusCert\" -d ${certDir}"
  if [ "$(certutil -L -d ${certDir} | grep -c "${nomCert}")" -eq "1" ];then
        logger -t "linuxcaib-conf-utils(instalaCertMozillacert8-$USER)" -s "certificat '${nomCert}' ja instalat a '${certDir}'/cert8.db"
        return        
  fi

  if ( ! openssl x509 -in $rutaCert -inform der -outform pem | certutil -A -n "${nomCert}" -t "$tipusCert" -d ${certDir} );then
       #echo "2 certutil -A -n \"${nomCert}\" -t \"$tipusCert\" -d ${certDir} -i $rutaCert"
       cat $rutaCert | certutil -A -n "${nomCert}" -t "$tipusCert" -d ${certDir}
  fi
  if [ "$(certutil -L -d ${certDir} | grep -c "${nomCert}")" -eq "1" ];then
        logger -t "linuxcaib-conf-utils(instalaCertMozillacert8-$USER)" -s "mozilla certificate installation '${nomCert}' in '${certDir}'/cert8.db done"        
  else
        logger -t "linuxcaib-conf-utils(instalaCertMozillacert8-$USER)" -s "mozilla certificate installation '${nomCert}' in '${certDir}'/cert8.db ERROR"
  fi
done
}


#Wrapper per instal·lar els certificats tant a la BBDD antiga NSS com a la nova.
instalaCertMozilla () {
rutaCert=$1
nomCert=$2
tipusCert=$3

instalaCertMozillacert8 $rutaCert $nomCert $tipusCert

instalaCertMozillacert9 $rutaCert $nomCert $tipusCert

}


# Script que instal·la el certificat proporcionat (.cer) amb l'alias
# l'instal·la dins dels navegadors firefox i google-chrome i dins del jssecerts de l'usuari (JAVA)
instalaCertificat () {
rutaCert=$1
nomCert=$2

instalaCertMozilla $rutaCert  $nomCert "C,,"
instalaCertChrome $rutaCert  $nomCert "C,,"

#Afageixo els certificats del proxy dins del jssecerts de l'usuari ja que dins JAVA no es poden afegir aquí, ja que cal ser root per poder canviar el keystore
if [ -r $HOME/.java/deployment/security/trusted.jssecerts ];then
        keytool -import -noprompt -trustcacerts -alias $nomCert -file $rutaCert -keystore "$HOME/.java/deployment/security/trusted.jssecerts" -storepass ""
else
        logger -t "linuxcaib-conf-utils(instalaCertificat-$USER)" -s "WARN: no he pogut afegir els certificats dels proxies al trusted.jssecerts) de l'usuari"
fi

}



#TODO: replicar les utilitats de vitalinux (vx-utils): https://github.com/vitalinux/vx-utils/tree/master/usr/bin



