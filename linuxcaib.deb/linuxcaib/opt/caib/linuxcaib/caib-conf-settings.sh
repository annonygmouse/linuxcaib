
# Catàleg de funcions i utilitats 

# Variables de configuració dels scripts

#Si debug no està definida, la definim
if [ -z $DEBUG ]; then DEBUG=0; fi
if [ "$DEBUG" -ge 3 ]; then
    # trace output
    set -x
fi


TTL=20 #Time to live maxim emprat per comprovar si un servidor es accessible (isHostNear)

if [ "$(readlink $0)" = "" ];then
        #no es un enllaç, agafam ruta normal
#        echo "fitxer normal $0"
        RUTA_FITXER=$(dirname $0)
        BASEDIR_SETTINGS=$RUTA_FITXER
else
#        echo "enllaç"
        RUTA_FITXER=$(readlink $0)
        BASEDIR_SETTINGS=$( dirname $RUTA_FITXER)
fi

if [ ! -d /etc/caib/linuxcaib ];then
        [ "$DEBUG" -gt "1" ] && logger -t "linuxcaib-conf-settings($USER)" -s "Carpeta de configuració no trobada. $BASEDIR, posam BASEDIR=\"/opt/caib/linuxcaib\" ."
        BASEDIR="/opt/caib/linuxcaib";
fi


#BASEDIR_SETTINGS=$(dirname $(readlink $0))
#echo "BASE SETTINGS $BASEDIR_SETTINGS"
#echo "BASEDIR $BASEDIR"
#Si existeix fitxer DebugLevel llegim el valor que conté (0,1,2) i sera el nivell de debug
if [ -f /etc/caib/linuxcaib/DebugLevel ];then
        DEBUG=$(cat /etc/caib/linuxcaib/DebugLevel )
fi
[ "$DEBUG" -gt "1" ] && logger -t "linuxcaib-conf-settings($USER)" -s "Nivell de DEBUG: $DEBUG, BASEDIR=$BASEDIR"


#SEYCON_CERT_FILE ha de ser una ruta completa
if [ -f /etc/caib/linuxcaib/CertificateFile ];then
        SEYCON_CERT_FILE=$(cat /etc/caib/linuxcaib/CertificateFile)
else
        SEYCON_CERT_FILE=$BASEDIR/seycon.cer
fi
[ "$DEBUG" -gt "1" ] && logger -t "linuxcaib-conf-settings($USER)" -s "Certificat del servidor SEYCON emprat: $SEYCON_CERT_FILE"



#Servidor del SEYCON
if [ -f /etc/caib/linuxcaib/SSOServer ];then
        #Agafam el primer
        SEYCON_SERVER=$(cat /etc/caib/linuxcaib/SSOServer|cut -d"," -f 1)
        SEYCON_SERVERS=$(cat /etc/caib/linuxcaib/SSOServer)
else
        SEYCON_SERVER=sticlin2.caib.es 
fi

[ "$DEBUG" -gt "1" ] && logger -t "linuxcaib-conf-settings($USER)" -s "Servidor SEYCON emprat: $SEYCON_SERVER"

#Port del seycon server
if [ -f /etc/caib/linuxcaib/seycon.https.port ];then
        SEYCON_PORT=$(cat /etc/caib/linuxcaib/seycon.https.port)
else
        SEYCON_PORT=750 #Port del servidor seycon
fi
[ "$DEBUG" -gt "1" ] && logger -t "linuxcaib-conf-settings($USER)" -s "Servidor SEYCON emprat: $SEYCON_PORT"

#s'hauria d'emprar wget --ca-certificate=$SEYCON_CERT_FILE pero de totes maneres com que és un certificat autosignat... wget sempre
#se queixa i s'ha d'emprar el --no-check-certificate


#Hostname associat a l'usuari ShiroKabuto
if [ -f /etc/caib/linuxcaib/ShiroHostname ];then
        SHIRO_HOSTNAME=$(cat /etc/caib/linuxcaib/ShiroHostname)
else
        SHIRO_HOSTNAME=""
fi
[ "$DEBUG" -gt "1" ] && logger -t "linuxcaib-conf-settings($USER)" -s "Servidor que ShiroKabuto te associat: $SHIRO_HOSTNAME"


PSERVER="lofiapp1" #Servidor "ofimatica" de P
PSHARE="pcapp"        #Nom del "share" de P

#servidor nfs de lofiapp
if [ -f /etc/caib/linuxcaib/lofiapplinux ];then
        PSERVER_LINUX=$(cat /etc/caib/linuxcaib/lofiapplinux)
        PSHARE_LINUX="pcapplinux"
else
	#Valor per defecte
        PSERVER_LINUX="stmprh6lin1"
        PSHARE_LINUX="pcapplinux"
fi

MAX_DRIVES=20  #Nombre màxim de unitats compartides que pot tenir un usuari
EMPTYDRIVE1="I"  #Lletres lliures de unitats compartides  
EMPTYDRIVE2="J"
EMPTYDRIVE3="K"
EMPTYDRIVE4="L"
EMPTYDRIVE5="M"
EMPTYDRIVE6="N"
EMPTYDRIVE7="O"
EMPTYDRIVE8="Q"
EMPTYDRIVE9="R"
EMPTYDRIVE10="S"
EMPTYDRIVE11="T"
EMPTYDRIVE12="U"
EMPTYDRIVE13="V"
EMPTYDRIVE14="W"
EMPTYDRIVE15="Y"


MAX_IMPRESSORES=10 #Nombre màxim d'impressores que intentarem donar d'alta
DEL_PREVIOUS_PRINTERS="NO" #Defineix si hem d'eliminar les impressores configurades anteriorment. Per defecte NO, ja que les impressores se donen d'alta de manera que només l'usuari pugui emprar-la.

#DRIVER que funciona amb la majoria de les impressores: http://linuxibos.blogspot.com.es/2013/01/driver-that-works-on-allmost-all.html
DEFAULT_PRINTER_DRIVER="foomatic-db-compressed-ppds:0/ppd/foomatic-ppd/Generic-PostScript_Printer-Postscript.ppd"
DEFAULT_PRINTER_OPTIONS=" -o OptionDuplex=True -o PageSize-default=A4 -o PrintoutMode-default=Gray -o OutputMode-default=Grayscale -o Duplexer-default=DuplexNoTumble -o ColorModel=Gray -o PrinterResolution-default=600x600dpi -o sides-default=two-sided-long-edge -o HPOption_Duplexer=true "


[ "$DEBUG" -gt "1" ] && logger -t "linuxcaib-conf-settings($USER)" -s "Variables de configuració dels scripts de login activades"

CAIB_CONF_SETTINGS="SI"

