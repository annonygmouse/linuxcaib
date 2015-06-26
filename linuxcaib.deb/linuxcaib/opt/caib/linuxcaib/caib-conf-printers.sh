#!/bin/sh

# Script fet amb dash que dona d'alta les impressores que l'usuari te donades d'alta dins 
# del SEYCON. 
# NOTA: Com que per poder emprar els servidors d'impressió (lofiprn2 és el nom virtual dels
# servidors d'impressió redundants. 
# Cada impressora està compartida via SMB. 
# Els usuaris poden montar les impressores mentre tenguin usuari i contrasenya de domini (com unitat compartida)
# NO cal que la màquina cient tengui
# una relació de confiança amb els servidors d'impressió (estigui dins del domini). 
# Com que no podem fer cap canvi d'infraestructura i els servidors d'impressió windows NO poden proporcionar
# el driver als clients linux, s'ha d'emprar avahi per detectar el nom de la impressora i cercar un driver local.
# Si avahi no detecta la impressora (perque impressora vella o no suport mDNS/DNS-SD), s'emprarà el driver genèric configurat per defecte dins caib-settings
# Com que hi ha màquines que potser tenguin problemes per carregar les impressores (per avahi), se pot crear el fitxer buid 
# /etc/caib/dissoflinux/disableprinters 
# si aquest fitxer existeix, aquest script no fa rés.
# Pre-requisits: cups, cups-utils, cups-pdf, hplip, cups-driver-gutenprint, libgutenprint2, printer-driver-postscript-hp, hpijs-ppds, printer-driver-all, wget, xmlstarlet

#Nota2: Ubuntu 14.04 detecta i configura automàticament totes les impressores de xarxa que troba. Cosa que fa aquest script
#gairebé obsolet. Tan sols és imprescindible per les impressores compartides des de PCs d'usuari ( impressores del tipus epreinf149p ).

#Variables de configuració:
# DEL_PREVIOUS_PRINTERS (NO) Defineix si hem d'eliminar les impressores configurades anteriorment. Per defecte NO, ja que encara
# que hi hagi impressores donades d'alta anteriorment, si l'usuari no la té, no hi podrà imprimir per manca de permissos.


#TODO: 
# gestionar impressores USB de tipus HP? hp-probe --bus usb.... a ubuntu 14.04 en teoria no fa falta, les hauria de detectar 
#automàticament.
# Cal provar compartir una impressora via SMB.
# detectar si les impressores de xarxa de l'usuari son de HP (hp-makeuri 10.215.3.253)
# i així emprar sempre el driver de HP ja que son els millors suportats.

#Exemple de resultat avahi
#=;eth0;IPv4;HP\032Color\032LaserJet\032CP3505\032\09117BD33\093;Internet Printer;local;ipreinf8.local;10.215.3.253;631;"adminurl=http://ipreinf8.local." "priority=60" "product=(HP Color LaserJet CP3505)" "ty=HP Color LaserJet CP3505" "rp=ipreinf8" "pdl=application/postscript,application/vnd.hp-PCL,application/vnd.hp-PCLXL" "qtotal=1" "txtvers=1"

#=;eth0;IPv4;HP\032Color\032LaserJet\032CP3505\032\09117BD33\093;PDL Printer;local;ipreinf8.local;10.215.3.253;9100;"adminurl=http://ipreinf8.local." "priority=40" "product=(HP Color LaserJet CP3505)" "ty=HP Color LaserJet CP3505" "pdl=application/postscript,application/vnd.hp-PCL,application/vnd.hp-PCLXL" "qtotal=1" "txtvers=1"

#=;eth0;IPv4;HP\032Color\032LaserJet\032CP3505\032\09117BD33\093;UNIX Printer;local;ipreinf8.local;10.215.3.253;515;"Binary=T" "Transparent=T" "adminurl=http://ipreinf8.local." "priority=30" "product=(HP Color LaserJet CP3505)" "ty=HP Color LaserJet CP3505" "pdl=application/postscript" "rp=BINPS" "qtotal=4" "txtvers=1"





#Si debug no està definida, la definim
if [ -z $DEBUG ]; then DEBUG=0; fi
if [ "$DEBUG" -ge 3 ]; then
    # trace output
    set -x
fi



if [ -f /etc/caib/linuxcaib/disableconfprinters ];then
        logger -t "linuxcaib-login-printers($USER)" "Configuració de impressores deshabilitatda! (/etc/caib/linuxcaib/disableconfprinters)"
        exit 1;
fi

#Importam les funcions auxiliars
#Ruta base scripts
BASEDIR=$(dirname $0)
if [ "$CAIBCONFUTILS" != "SI" ]; then
[ "$DEBUG" -gt "0" ] && logger -t "linuxcaib-conf-printers($USER)" "Carregam utilitats de $BASEDIR/caib-conf-utils.sh"
. $BASEDIR/caib-conf-utils.sh
fi


#Aplicacions pre-requerides
#if ( ! paquetInstalat "printer-driver-all" ); then
#        instalarPaquet "printer-driver-all"
#fi


# Initialize our own variables:
output_file=""


show_caib_conf_impressores_help () {
cat << EOF
El programa "${0##*/}" dona d'alta i configura les impressores que l'usuari te donades d'alta al SEYCON.

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


if [ $USER = "root"  ]; then
        logger -t "linuxcaib-conf-printers($USER)" -s "ERROR: no se pot executar com a root!"
        exit 1;
fi

# A POSIX variable
OPTIND=1         # Reset in case getopts has been used previously in the shell.

# Initialize our own variables:
output_file=""

while getopts "hcv?u:p:" opt; do
    case "$opt" in
    h|\?)
        show_caib_conf_impressores_help
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
#Si NO tenim usuari i password no podem configurar les impressores
    echo "ERROR: Se necessita usuari i contrassenya per poder crear les impressores" >&2
    show_caib_conf_impressores_help
    exit 1
fi

#Si debug no està definida, la definim
if [ -z $DEBUG ]; then DEBUG=0; fi
if [ "$DEBUG" -ge 3 ]; then
    # trace output
    set -x
fi

if [ "$DEBUG" -gt "0" ];then
        echo "DEBUG=$DEBUG, usuari='$USERNAME', resta parametres no emprats: $@"
fi



if [ "$(dpkg -l|grep xmlstarlet| grep ^.i)" = "" ]; then
        logger -t "linuxcaib-conf-printers($USER)" -s "ERROR: cal instalar el paquet xmlstarlet ($SUDO apt-get install xmlstarlet), ho intent"
        $SUDO apt-get install xmlstarlet
fi

if [ "$(which gethostip)" = "" ]; then
        logger -t "linuxcaib-conf-printers($USER)" -s "ERROR: cal instalar l'executable 'gethostip', està al paquet syslinux (a partir de ubuntu 14.10 a syslinux-utilsº), ho intent"
        $SUDO apt-get install syslinux syslinux-utils
fi

#Configuram impressores

#Primer eliminam les impressores de xarxa pre-existents
# Hem de agafar les impressores de tipus: lpd
# mitjançat: sudo lpadmin -x printer-name

#Proves
# donar alta impressora lpd: lpadmin -p epreinf8 -v lpd://lofiprn2/ipreinf8 -E
# donar alta impressora ipp: lpadmin -p epreinf8 -v ipp://epreinf8/ipp -E
# eliminar impressora: lpadmin -x epreinf8


USER_PRINTERS=$(wget -O - -q --http-user=$USERNAME --http-password=$PASSWORD --no-check-certificate https://$SEYCON_SERVER:$SEYCON_PORT/query/user/$USERNAME/printers-v2)
RESULTM=$?
if [ $RESULTM -eq 0 ];then
   if [ "$DEBUG" -gt "0" ];then
        logger -t "linuxcaib-conf-printers($USER)" -s  "Descarregades impressores de l'usuari: $USERNAME"
   fi
else
   logger -t "linuxcaib-conf-printers($USER)" -s "ERROR: no he pogut accedir a les impressores de l'usuari $USERNAME error: $RESULTM o l'usuari NO te impressores assignades."
   logger -t "linuxcaib-conf-printers($USER)" -s "resultat: $USER_PRINTERS"
   exit 1;
fi



if [ "$DEL_PREVIOUS_PRINTERS" = "SI" ];then
        eliminarImpressores
fi



NUM_PRINTERS=0;


for x in $(seq 1 1 $MAX_IMPRESSORES) ; do
        #echo "x=-$x-"
        xpath="data/row[$x]"
        #echo "xpath=$xpath"
        ROWACTUAL=$ROW$x
#EMPRAM xmlstarlet ja que xmllint falla a ubuntu 12.04!!!!
#xmlstarlet sel  -t -m '/data/row[1]' -v '.' -n bin/sticlin2_caib_es_750_query_user_u83511_printers-v2_dues_impressores.xml
#        ROWACTUAL=$(xmllint --xpath $xpath $HOME/bin/sticlin2_caib_es_750_query_user_u83511_printers-v2_dues_impressores.xml 2>/dev/null)
        ROWACTUAL=$(echo $USER_PRINTERS | xmlstarlet sel  -t -c $xpath )
        #echo "rowactual=$ROWACTUAL"
        if [ "$ROWACTUAL" = "" ] ;then
                break
        else 
                NUM_PRINTERS=$(expr $NUM_PRINTERS + 1)
        fi
done

NUM_PRINTERS=$(echo $USER_PRINTERS | xmlstarlet sel -t -v 'count(data/row)')

if [ "$NUM_PRINTERS" -gt "$MAX_IMPRESSORES" ];then
        logger -t "linuxcaib-conf-drives($USER)" -s "WARNING: Massa unitats compartides definides al seycon! Només montaré les $MAX_IMPRESSORES primeres"
        $NUM_PRINTERS=$MAX_IMPRESSORES
fi

if [ $RESULTM -eq 0 ];then
        logger -t "linuxcaib-conf-printers($USER)" "num impressores=$NUM_PRINTERS"
fi


avahiCache=""
if [ $NUM_PRINTERS -gt 0 ];then
        #Cercam el _nom_ de la impressora mitjançant dnsds i si és accessible per IPP o LPD (unix printer)
        #Valorar si afegir -c a avahi-browse, per emprar la cache... seria mes ràpid.
        logger -t "linuxcaib-conf-printers($USER)" "Iniciant avahi-browse.";                
        avahi-browse -a $avahiCache -t -v -r -p 2>/dev/null > /tmp/avahi
        logger -t "linuxcaib-conf-printers($USER)" "Fi avahi-browse.";

fi

for y in $(seq 1 1 $NUM_PRINTERS) ; do
        #echo "processant impressora $y"
        xpath="data/row[$y]/MAQ_NOM/text()"
#MAQ_NOM><IMP_CODI>ipreinf8</IMP_CODI><UIM_ORDRE>
        PRINTSERVER=$(echo $USER_PRINTERS | xmlstarlet sel -T -t -c $xpath )
        xpath="data/row[$y]/IMP_CODI/text()"
        PRINTERNAME=$(echo $USER_PRINTERS | xmlstarlet sel -T -t -c $xpath )
        xpath="data/row[$y]/UIM_ORDRE/text()"
        PRINTERORDER=$(echo $USER_PRINTERS | xmlstarlet sel -T -t -c $xpath )
        if [ "$PRINTERORDER" != "" ] ;then
                logger -t "linuxcaib-conf-printers($USER)" "Servidor: $PRINTSERVER Impressora: $PRINTERNAME Ordre: $PRINTERORDER"
                
                #TODO: separar les impressores que son dels servidors de impressió de windows (lofiprn?) de les impressores
                #dels servidors d'impressio linux (simprlin?)
                #Si la impressora està a un servidor d'impressió windows, intentarem accedir directament a la impressora.
                #En cas contrari donarem d'alta la impressora via el servidor cups directament.
                servImpresioLinux=$(esServImprLinux $PRINTSERVER)
                #$(echo $PRINTSERVER | grep -q simprlin && echo linux)
                if [ "$servImpresioLinux" = "SI" ];then
                        logger -t "linuxcaib-conf-printers($USER)" "Impressora: $PRINTERNAME està al servidor d'impressió $PRINTSERVER Linux (simprlinXXX)"
                        #TODO: configurar aquesta coa d'impresssió
                else
                        logger -t "linuxcaib-conf-printers($USER)" "Impressora: $PRINTERNAME està al servidor d'impressió $PRINTSERVER windows (o màquina client windows)"

                        #Ara la casuística de servidor d'impressió windows

                        #sudo lpadmin -p $PRINTERNAME -v lpd://$PRINTSERVER/$PRINTERNAME -E
                        # NOMÉS FUNCIONA ACCEDINT DIRECTAMENT A LA IMPRESSORA AMB: ipp://ipreinf8.caib.es/ipp
                        # ja que el PC ha de tenir relació de confiança de ActiveDirectory (ha d'estar en domini) per a que lofiprn2 accepti els treballs).
                        #Per ara configuram les impressores accedint-hi directament
                        #Abans de donar d'alta comprovam que la impressora estigui accessible

                        #WARNING: que passa si la impressora és una impressora compartida d'un PC i no dels servidors d'impressió? (ie epreinf8p)
                        #      crec que no passaria res, simplement no se detectaria mitjançant avahi.
                        if ( isHostNear $PRINTERNAME ); then
                                #Tenim visibilitat amb el 
                                PRINTERIP=$(gethostip -d "$PRINTERNAME")
                                #echo "printerIP=$PRINTERIP"
                                logger -t "linuxcaib-conf-printers($USER)" "Impressora $PRINTERNAME te IP: $PRINTERIP."; 

                                #TODO: mentre no se defineixi infraestructura per donar suport a linux (per exemple
                                #definint PPDs corporatius penjats a algun servidor per cada impressora/nom d'impressora,
                                #El que se fa és emprar el driver recomanat si aconseguim detectar la impressora via dns-ds (avahi).
                                # Si no podem detectar la marca i model (i el seu driver), emprarem un driver genèric.
                                UNIX_PRINTER_MAKE_AND_MODEL=$(cat /tmp/avahi|grep "$PRINTERIP" | grep IPv4 |grep "UNIX Printer" | awk 'BEGIN  { FS=";"} {print $10}'| awk 'BEGIN  { FS="\""} {print $10}'| awk 'BEGIN  { FS="("} {print $2}' | awk 'BEGIN  { FS=")"} {print $1}')
                                IPP_PRINTER_MAKE_AND_MODEL=$(cat /tmp/avahi| grep "$PRINTERIP" | grep IPv4 |grep "Internet" | awk 'BEGIN  { FS=";"} {print $10}'| awk 'BEGIN  { FS="\""} {print $6}'| awk 'BEGIN  { FS="("} {print $2}' | awk 'BEGIN  { FS=")"} {print $1}')

                                logger -t "linuxcaib-conf-printers($USER)" -s "Impressora $PRINTERNAME es model $IPP_PRINTER_MAKE_AND_MODEL."; 
                        
#jetdirect! PDL_PRINTER_MAKE_AND_MODEL=$(cat /tmp/avahi| grep "$PRINTERIP" | grep IPv4 |grep "PDL Printer" | awk 'BEGIN  { FS=";"} {print $10}'| awk 'BEGIN  { FS="\""} {print $6}'| awk 'BEGIN  { FS="("} {print $2}' | awk 'BEGIN  { FS=")"} {print $1}')
#hp-makeuri ipreinf8 2>/dev/null|grep CUPS|awk '{ print $3}'


                                PRINTER_DRIVER=$DEFAULT_PRINTER_DRIVER #Empram el driver per defecte.
                                if [ "$IPP_PRINTER_MAKE_AND_MODEL" != "" ];then
                                        PRINTER_TYPE="IPP" 
                                        PRINTER_MAKE_AND_MODEL=$IPP_PRINTER_MAKE_AND_MODEL
                                         #Obtenim el driver recomanat (agaf la darrera opció que sol ser la recomanada)
                                        #WARN: a debian apareix el text "recommended", a ubuntu no, per això agaf la darrera linia.
                                        PRINTER_DRIVER=$($SUDO lpinfo --make-and-model "$PRINTER_MAKE_AND_MODEL" --timeout 5  -m|tail -n 1 | awk 'BEGIN  { FS=" "} {print $1}')
                                else
                                        if [ "$UNIX_PRINTER_MAKE_AND_MODEL" != "" ];then
                                                PRINTER_TYPE="LPD"
                                                PRINTER_MAKE_AND_MODEL=$UNIX_PRINTER_MAKE_AND_MODEL
                                                 #Obtenim el driver recomanat (agaf la darrera opció que sol ser la recomanada)
                                                #WARN: a debian apareix el text "recommended", a ubuntu no, per això agaf la darrera linia.
                                                PRINTER_DRIVER=$($SUDO lpinfo --make-and-model "$PRINTER_MAKE_AND_MODEL" --timeout 5  -m|tail -n 1 | awk 'BEGIN  { FS=" "} {print $1}')
                                        else
                                                logger -t "linuxcaib-conf-printers($USER)" "Impressora no publica informació via dns-ds."; 
                                                #No trobam impressora a la xarxa local via dns-ds.
                                                #Comprovam si és accessible via ping.
                                                if ( isHostNearPing $PRINTERNAME ); then
                                                        #Hi arribam via ping, ens hi podem connectar directament. Com que no sabem quin protocol empra, empram LPD.
                                                        PRINTER_TYPE="LPD"
                                                else
                                                        # No és accessible la configurarem via el servidor d'impressió (SMB)
                                                               PRINTER_TYPE="SMB"                
                                                fi
                                        fi
                                fi
                                logger -t "linuxcaib-conf-printers($USER)" "Impressora $PRINTERNAME de tipus $PRINTER_TYPE i driver $PRINTER_DRIVER."; 
                        
                                case "$PRINTER_TYPE" in
                                            "IPP")
                                                #La impressora és de tipus IPP
                                                logger -t "linuxcaib-conf-printers($USER)" -s "Configurant impressora IPP -$PRINTER_MAKE_AND_MODEL- ($PRINTERNAME) amb driver $PRINTER_DRIVER i opcions $DEFAULT_PRINTER_OPTIONS "; 
                                                #Primer la donam d'alta.
                                                # Després hi definim les opcions per defecte (sino no se posen totes les opcions (duplexer per exemple)

                                                if ( $(LANG=C lpstat -p $PRINTERNAME -l|grep -q enabled) ); then
                                                        logger -t "linuxcaib-conf-printers($USER)" "Impressora JA configurada, simplement ens asseguram que l'usuari hi pugui imprimir."
                                                        $SUDO lpadmin -u allow:$USERNAME -p $PRINTERNAME 
                                                else
                                                        resultAddPrinter=$($SUDO lpadmin -u allow:$USERNAME -p $PRINTERNAME -v ipp://$PRINTERNAME/ipp -E -m $PRINTER_DRIVER -o printer-is-shared=false )
                                                        
                                                        #TERROR: system-config-printer NO agafa les opcions definides... (excepte habilitació de duplex)
                                                        $SUDO lpadmin -p $PRINTERNAME $DEFAULT_PRINTER_OPTIONS > /dev/null
                                                fi
                                                ;;
                                            "LPD")
                                                logger -t "linuxcaib-conf-printers($USER)" "Configurant impressora LPD -$PRINTER_MAKE_AND_MODEL- ($PRINTERNAME) amb driver $PRINTER_DRIVER  i opcions $DEFAULT_PRINTER_OPTIONS"; 
                                                if ( $(LANG=C lpstat -p $PRINTERNAME -l|grep -q enabled) ); then
                                                        logger -t "linuxcaib-conf-printers($USER)" "Impressora JA configurada, simplement ens asseguram que l'usuari hi pugui imprimir.".
                                                        $SUDO lpadmin -u allow:$USERNAME -p $PRINTERNAME 
                                                else
                                                        resultAddPrinter=$($SUDO lpadmin -u allow:$USERNAME -p $PRINTERNAME -v  lpd://$PRINTERNAME/ -E -m $PRINTER_DRIVER -o printer-is-shared=false > /dev/null)
                                                        #ERROR: system-config-printer NO agafa les opcions definides... (excepte habilitació de duplex)
                                                        $SUDO lpadmin -p $PRINTERNAME $DEFAULT_PRINTER_OPTIONS > /dev/null
                                                fi
                                                ;;
                                        "SMB")
                                                logger -t "linuxcaib-conf-printers($USER)" "Configurant impressora SMB -$PRINTER_MAKE_AND_MODEL- ($PRINTERNAME) amb driver $PRINTER_DRIVER  i opcions $DEFAULT_PRINTER_OPTIONS"; 
                                                #smb://username:password@workgroup/server/printer
                                                if ( $(LANG=C lpstat -p $PRINTERNAME -l|grep -q enabled) ); then
                                                        logger -t "linuxcaib-conf-printers($USER)" "Impressora JA configurada, simplement ens asseguram que l'usuari hi pugui imprimir."
                                                        $SUDO lpadmin -u allow:$USERNAME -p $PRINTERNAME 
                                                else
                                                        resultAddPrinter=$($SUDO lpadmin -u allow:$USERNAME -p $PRINTERNAME -v smb://$USERNAME:$PASSWORD@CAIB/$PRINTSERVER/$PRINTERNAME/ -E -m $PRINTER_DRIVER -o printer-is-shared=false > /dev/null)
                                                        #ERROR: system-config-printer NO agafa les opcions definides... (excepte habilitació de duplex)
                                                        $SUDO lpadmin -p $PRINTERNAME $DEFAULT_PRINTER_OPTIONS > /dev/null
                                                fi
                                                ;;
                                         *)        
                                                logger -t "linuxcaib-conf-printers($USER)" -s "Impressora $PRINTERNAME de tipus desconegut."; 
                                                ;;
                                esac
                                logger -t "linuxcaib-conf-printers($USER)" -s " Resultat afegir impressora=$resultAddPrinter";
                                #Verificar que sa impressora estigui ben configurada:
                                if ( $(LANG=C lpstat -p $PRINTERNAME -l|grep -q enabled) ); then 
                                        logger -t "linuxcaib-conf-printers($USER)" -s "Impressora $PRINTERNAME -$PRINTER_MAKE_AND_MODEL- afegida amb driver $PRINTER_DRIVER."; 
                                        if [ $PRINTERORDER -eq 1 ]; then
                                                #La impressora amb nombre d'ordre 1 és la impressora per defecte
                                                logger -t "linuxcaib-conf-printers($USER)" -s "Impressora $PRINTERNAME definida com impressora per defecte.";                                         
                                                $SUDO lpadmin -d $PRINTERNAME > /dev/null
                                        fi
                                else 
                                        logger -t "linuxcaib-conf-printers($USER)" -s "ERROR: no s'ha pogut afegir la impressora $PRINTERNAME. ERROR: $resultAddPrinter"; 
                                fi
                        else
                                logger -t "linuxcaib-conf-printers($USER)" -s "ERROR: Impressora: $PRINTERNAME no accessible, no la donam d'alta"
                        fi
                fi
        else
                logger -t "linuxcaib-conf-printers($USER)" -s "ERROR: llista de impressores NO ordenada"
        fi
done


