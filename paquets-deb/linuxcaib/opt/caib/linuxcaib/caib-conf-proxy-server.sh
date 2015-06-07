#! /bin/sh

# Aquest script configura la part de del proxy que necessita permissos de administrador.
# és a dir: 
#       1. mira si el servidor CNTLM està instal·lat.
#       2. Si no està instal·lat l'intenta instal·lar
#       3. Proxifica les aplicacions de sistema per a que vagin via el proxy
#       NO autenticat que s'ha preparat (stmprh6lin1).
#
#       Sa idea és que tota aplicació d'usuari, vagi via el proxy autenticat amb les credencials d'usuari.
#       En canvi tota aplicació de sistema, vagi via el proxy NO autenticat.

# L'script caib-conf-proxy-user.sh és qui s'encarrega de configurar les aplicacions d'usuari per a que apuntin al proxy/PACCAIB_LINUX.txt
# i surtin a internet via el proxy local cntlm (autenticat contra el proxy de la CAIB).

PROXYSERVER_PAC=http://proxy.caib.es/PACCAIB.txt
PROXYSERVER_PAC_LINUX=file:///$HOME/.caib/PACCAIB_LINUX.txt
PROXYSERVER_LOCAL="PROXYLOCALNOCONFIGURAT"
PROXYSERVER_NOM=rproxy1.caib.es
PROXYSERVER_PORT=3128

#Hi ha un proxy NO AUTENTICAT que permet accés a actualitzacions de seguretat (apt, antivirus, etc.)
UNAUTH_PROXYSERVER_NAME=stmprh6lin1.caib.es
UNAUTH_PROXYSERVER_PORT=3128


#Si debug no està definida, la definim
if [ -z $DEBUG ]; then DEBUG=0; fi
if [ "$DEBUG" -ge 3 ]; then
    # trace output
    set -x
fi


#Importam les funcions auxiliars
#Ruta base scripts
BASEDIR=$(dirname $0)
if [ "$CAIBCONFUTILS" != "SI" ]; then
        [ "$DEBUG" -gt "0" ] && logger -t "linuxcaib-conf-drives($USER)" "CAIBCONFUTILS=$CAIBCONFUTILS Carregam utilitats de $BASEDIR/caib-conf-utils.sh"
        . $BASEDIR/caib-conf-utils.sh
fi


CNTLMVERSION="" #Indica si el servidor cntlm està instalat i quina versió per distingir
#si hi ha instalada la versió de debian o la tunejada amb autenticació BASIC

# A dash NO existeis la variable d'entorn HOSTNAME
HOSTNAME=$(hostname)


if [ -z $LONGSLEEP ]; then LONGSLEEP=1; fi


#Feim les comprovacions inicials i inicialitzam les variables que es necessitaran a l'script
proxy_init () {
[ "$DEBUG" -gt "0" ] && logger -t "linuxcaib-conf-proxy-server($LOCALUSERNAME)" "proxy_init"

#Desactivam tot el que sigui de proxy
proxyOff

CNTLMVERSION=`dpkg -l| grep cntlm | grep ^.i |   awk 'BEGIN { FS = " " } ; { print $3 }'`
ARCH=$(dpkg --print-architecture)
if [ "$CNTLMVERSION" = "" ];then
    echo ""
    logger -t "linuxcaib-conf-proxy-server($LOCALUSERNAME)" -s "ALERTA: intentare instal·lar el paquet CNTLM de la caib"

    # Detectar arquitectura del sistema i baixar el cntlm_i386 o cntlm_amd64 de la ruta corresponent.
        if [ "$ARCH" = "amd64" ];then
                ruta="160";
        else
                ruta="140";
        fi
    #Agafa el paquet deb de cntlm des de NFS si la P de linux està montada.
    if [ -f /media/P_$PSHARE/caib/dissoflinux/027970/cntlm_0.92.3-caib_"$ARCH".deb ]; then
            cp /media/P_$PSHARE/caib/dissoflinux/027970/cntlm_0.92.3-caib_"$ARCH".deb /tmp/cntlm_0.92.3-caib_$ARCH.deb
    else 
            #Sinó s'ho descarrega del gforge
            wget -q http://gforge.caib.es/docman/view.php/160/$ruta/cntlm_0.92.3-caib_i386.deb -O /tmp/cntlm_0.92.3-caib_$ARCH.deb
    fi

    if [ -f  /tmp/cntlm_0.92.3-caib_"$ARCH".deb ]; then
        [ "$DEBUG" -gt "0" ] && logger -t "linuxcaib-conf-proxy-server($LOCALUSERNAME)" -s "Copiat cntlm dins /tmp/cntlm_0.92.3-caib_"$ARCH".deb"
        [ "$DEBUG" -gt "0" ] && logger -t "linuxcaib-conf-proxy-server($LOCALUSERNAME)" -s "Instal·lant cntlm_0.92.3-caib_$ARCH.deb"
        dpkg -i /tmp/cntlm_0.92.3-caib_i386.deb
        [ "$DEBUG" -gt "0" ] && logger -t "linuxcaib-conf-proxy-server($LOCALUSERNAME)" -s "cntlm caib instal·lat, deshabilitam el servei de cntlm (s'iniciarà manualment)"
        update-rc.d cntlm disable
        posarPaquetHold "cntlm"     
        exit 1;
    else
        logger -t "linuxcaib-conf-proxy-server($LOCALUSERNAME)" -s "ERROR: No he pogut obtenir el cntlm ni de la unitat P ni de http://gforge.caib.es/docman/view.php/160/140/cntlm_0.92.3-caib_"$ARCH".deb dins /tmp/cntlm_0.92.3-caib_"$ARCH".deb"
        echo "60" ; echo "# ERROR instal·lant CNTLM"; sleep $LONGSLEEP  
    fi

    echo ""
else
	logger -t "linuxcaib-conf-proxy-server($LOCALUSERNAME)" -s "Versió detectada del cntlm: $CNTLMVERSION, deshabilitam el servei de cntlm (s'iniciarà manualment)"
        update-rc.d cntlm disable
fi

}


#Mostram ajuda script
show_proxy_conf_help () {
cat << EOF
El programa "${0##*/}" instala el servidor proxy local (cntlm) i configura les aplicacions de sistema per a que emprin el proxy no autenticat stmprh6lin1.

Ús: ${0##*/} [-chlv] [-u USUARI] [-p PASSWORD] [-l USU_LOCAL]
      -c          agafa les credencials del fitxer "credentials". IMPORTANT, l'usuari ha de ser l'usuari de SEYCON.
      -h          mostra aquesta ajuda
      -l USUARI   nom de l'usuari local que s'emprarà (si es diferent al de seycon), necessari quan s'ha d'emprar via sudo
      -u USUARI   nom de l'usuari de seycon a emprar
      -p PASSWORD contrasenya de l'usuari de seycon a emprar
      -v          mode verbose

Exemples:
    ${0##*/} -c         Emprant fitxer de credencials
    sudo ${0##*/} -l sebastia -u u8351 -p contrasenya_u83511            Executant via sudo
EOF
}


# A POSIX variable
OPTIND=1         # Reset in case getopts has been used previously in the shell.

# Initialize our own variables:
output_file=""



while getopts "hcv?u:p:l:" opt; do
    case "$opt" in
    h|\?)
        show_proxy_conf_help
        exit 0
        ;;
    c)
        USERNAME=$(grep -i "^username=" $HOME/credentials | tr -d '\r'| tr -d '\n'| cut -f 2 -d "=" --output-delimiter=" ")
        PASSWORD=$(grep -i "^password=" $HOME/credentials | tr -d '\r'| tr -d '\n'| cut -f 2 -d "=" --output-delimiter=" ")        
        ;;
    l)  LOCALUSERNAME="$OPTARG"
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


if [ $USER = "root"  ]; then
        echo "localusername=$LOCALUSERNAME"
        if [ -z "$LOCALUSERNAME" ];then 
                logger -t "linuxcaib-conf-proxy-server($USER)" -s "ERROR: no se pot executar com a root!"
                show_proxy_conf_help
                logger -t "linuxcaib-conf-proxy-server($USER)" -s "Si estas executant via sudo, has d'emprar el paràmetre -l!"
                exit 1;
        fi
        if [ ! -d /home/$LOCALUSERNAME  ];then
                logger -t "linuxcaib-conf-proxy-server($LOCALUSERNAME)" "ERROR: l'usuari local no te home! Avortant..."
                exit 1;
        else 
                HOME=/home/$LOCALUSERNAME
        fi
        PROXYSERVER_PAC_LINUX=file:///$HOME/.caib/PACCAIB_LINUX.txt
fi

if [ -z "$LOCALUSERNAME" ];then
        logger -t "linuxcaib-conf-proxy-server($USER)" "WARNING: LOCALUSERNAME no definit, serà \$USER ($USER) "
        LOCALUSERNAME=$USER
fi
[ "$DEBUG" -gt "0" ] && logger -t "linuxcaib-conf-proxy-server($LOCALUSERNAME)" " (user=$LOCALUSERNAME home=$HOME) "


if [ -z "$USERNAME" ] || [ -z "$PASSWORD" ] 
then
#Si NO tenim usuari i password no podem configurar el proxy local
    logger -t "linuxcaib-conf-proxy-server($LOCALUSERNAME)" "ERROR: Se necessita usuari i contrassenya del seycon per poder configurar el proxy local"
    show_proxy_conf_help
    exit 1
fi

if [ "$DEBUG" -gt "0" ];then
        echo "DEBUG=$DEBUG, usuari='$USERNAME', resta parametres no emprats: $@"
fi

echo "# Configurant proxy al sistema"






#Funció que defineix les variables d'entorn
envProxyOn () {

#Afegim http_proxy="http://stmprh6lin1:3128" a /etc/environment si no hi és, per a que polkit funcioni.
sed -i '/^http_proxy/d' /etc/environment
sed -i '/^https_proxy/d' /etc/environment
sed -i '/^ftp_proxy/d' /etc/environment
sed -i '/^no_proxy/d' /etc/environment
#sed -i '/^all_proxy/d' /etc/environment
echo "http_proxy=\"http://stmprh6lin1:3128/\"" >> /etc/environment
echo "https_proxy=\"http://stmprh6lin1:3128/\"" >> /etc/environment
echo "ftp_proxy=\"http://stmprh6lin1:3128/\"" >> /etc/environment
#echo "all_proxy=\"http://stmprh6lin1:3128/\"" >> /etc/environment
echo "no_proxy=\"localhost, 127.0.0.1, localaddress, 10.215.0.0, .localdomain.com, .caib.es\"" >> /etc/environment

#Variables entorn proxy CAIB NO autenticat
export http_proxy="http://stmprh6lin1:3128/"
export https_proxy="https://stmprh6lin1:3128/"
export ftp_proxy="ftp://stmprh6lin1:3128/"
export HTTP_PROXY="http://stmprh6lin1:3128/"
export HTTPS_PROXY="https://stmprh6lin1:3128/"
export FTP_PROXY="ftp://stmprh6lin1:3128/"
export no_proxy="localhost, 127.0.0.1, localaddress, 10.215.0.0, .localdomain.com, .caib.es"
export NO_PROXY="localhost, 127.0.0.1, localaddress, 10.215.0.0, .localdomain.com, .caib.es"

}



proxyOff () {
unset http_proxy
unset HTTP_PROXY
unset https_proxy
unset HTTPS_PROXY
unset ftp_proxy
unset FTP_proxy
unset no_proxy
unset NO_proxy
}



proxyficarClamav () {
# Configuram freschclam (actualitzador de clamav)
if [ -f "/etc/clamav/freschlam.conf" ];then

        #Eliminar propietats de proxy antigues (HTTPProxy*)
        sed -i '/^HTTPProxy/d' /etc/clamav/freschlam.conf
        #echo "FRESHCLAM amb proxy local"
        FRESHCLAM_PROXY_HOSTNAME=$UNAUTH_PROXYSERVER_NAME
        FRESHCLAM_PROXY_PORT=$UNAUTH_PROXYSERVER_PORT
        #Afegim propietats noves!
        echo "HTTPProxyServer $FRESHCLAM_PROXY_HOSTNAME, HTTPProxyPort $FRESHCLAM_PROXY_PORT" >> /etc/clamav/freschlam.conf
        if [ ! -z $FRESHCLAM_USERNAME ];then
                        echo "HTTPProxyUsername $FRESHCLAM_USERNAME,HTTPProxyPassword $FRESHCLAM_PASSWORD" >> /etc/clamav/freschlam.conf
        fi
        logger -t "linuxcaib-conf-proxy-server($LOCALUSERNAME):" -s "Freshclam proxificat"
else
        [ "$DEBUG" -gt "0" ] && logger -t "linuxcaib-conf-proxy-server($LOCALUSERNAME)" -s "WARN: freshclam possiblement NO instal·lat.";
fi

}


proxyficarClamav_auth () {
# Configuram freschclam (actualitzador de clamav)
if [ -f "/etc/clamav/freschlam.conf" ];then

        #Eliminar propietats de proxy antigues (HTTPProxy*)
        sed -i '/^HTTPProxy/d' /etc/clamav/freschlam.conf

        if [  "$PROXYSERVER_LOCAL" = "PROXYLOCALNOCONFIGURAT" ];then
                #echo "FRESHCLAM amb proxy usupass $USERNAME:$PASSWORD@$PROXYSERVER_NOM:$PROXYSERVER_PORT"
                FRESHCLAM_PROXY_HOSTNAME=$PROXYSERVER_NOM
                FRESHCLAM_USERNAME=$USERNAME
                FRESHCLAM_PASSWORD=$PASSWORD
                FRESHCLAM_PROXY_PORT=$PROXYSERVER_PORT
        else 
                #echo "FRESHCLAM amb proxy local"
                FRESHCLAM_PROXY_HOSTNAME=localhost
                FRESHCLAM_PROXY_PORT=3128
        fi
        #Afegim propietats noves!
        echo "HTTPProxyServer $FRESHCLAM_PROXY_HOSTNAME, HTTPProxyPort $FRESHCLAM_PROXY_PORT" >> /etc/clamav/freschlam.conf
        if [ ! -z $FRESHCLAM_USERNAME ];then
                        echo "HTTPProxyUsername $FRESHCLAM_USERNAME,HTTPProxyPassword $FRESHCLAM_PASSWORD" >> /etc/clamav/freschlam.conf
        fi
        logger -t "linuxcaib-conf-proxy-server($LOCALUSERNAME):" -s "Freshclam proxificat"
else
        [ "$DEBUG" -gt "0" ] && logger -t "linuxcaib-conf-proxy-server($LOCALUSERNAME)" -s "WARN: freshclam possiblement NO instal·lat.";
fi

}



proxificarAPT () {
# Configuram APT  (si l'usuari te permissos)
touch /etc/apt/apt.conf.d/05proxycaib > /dev/null 2>&1
if [ -f "/etc/apt/apt.conf.d/05proxycaib" ]; then

        APT_PROXY=$UNAUTH_PROXYSERVER_NAME:$UNAUTH_PROXYSERVER_PORT
        echo "// Configuración para utilizar un proxy
Acquire {
  http {
    Proxy \"http://$APT_PROXY\";
    //Si empram un repositori intern de la caib (http::Proxy::<host>)
    //Proxy::servidorrepositori.caib.es \"DIRECT\";
    Proxy::weib.caib.es "DIRECT";
  }
  https {
    Proxy \"http://$APT_PROXY\";
    Proxy::weib.caib.es "DIRECT";
  }

}
" | tee /etc/apt/apt.conf.d/05proxycaib > /dev/null

[ "$DEBUG" -gt "0" ] && logger -t "linuxcaib-conf-proxy-user($LOCALUSERNAME):" -s "APT proxificat contra proxy NO autenticat"

else
        [ "$DEBUG" -gt "0" ] && logger -t "linuxcaib-conf-proxy-user($LOCALUSERNAME)" -s "WARN: No tens prou permissos locals per actualitzar la configuració d'APT. No podràs actualitzar el sistema.";
fi
}


proxificarAPT_auth () {
# Configuram APT  (si l'usuari te permissos)
touch /etc/apt/apt.conf.d/05proxycaib > /dev/null 2>&1
if [ -f "/etc/apt/apt.conf.d/05proxycaib" ]; then
        if [  "$PROXYSERVER_LOCAL" = "PROXYLOCALNOCONFIGURAT" ]; 
        then
                #echo "APT amb proxy usupass $USERNAME:$PASSWORD@$PROXYSERVER_NOM:$PROXYSERVER_PORT"
                APT_PROXY="$USERNAME:$PASSWORD@$PROXYSERVER_NOM:$PROXYSERVER_PORT"
        else 
                #echo "APT amb proxy local"
                APT_PROXY=$PROXYSERVER_LOCAL
        fi

echo "// Configuración para utilizar un proxy
Acquire {
  http {
    Proxy \"http://$APT_PROXY\";
    //Si empram un repositori intern de la caib (http::Proxy::<host>)
    //Proxy::servidorrepositori.caib.es \"DIRECT\";
    Proxy::weib.caib.es "DIRECT";
  }
  https {
    Proxy \"http://$APT_PROXY\";
    Proxy::weib.caib.es "DIRECT";
  }

}
" | tee /etc/apt/apt.conf.d/05proxycaib > /dev/null

logger -t "linuxcaib-conf-proxy-user($LOCALUSERNAME):" -s "APT proxificat"

else
        [ "$DEBUG" -gt "0" ] && logger -t "linuxcaib-conf-proxy-user($LOCALUSERNAME)" -s "WARN: No tens prou permissos locals per actualitzar la configuració d'APT. No podràs actualitzar el sistema.";
fi
}


#echo "Inici configuracio proxy-server"


proxy_init

# Configuram CNTLM
if [ "$CNTLMVERSION" != "" ]; then
        #El CNTLM està instal·lat
#        actualitzaPasswordCNTLM
        PROXYSERVER_LOCAL="localhost:3128"
else 
        # Si no hi ha instalat el proxy local o no l'hem pogut configurar
        logger -t "linuxcaib-conf-proxy-server($LOCALUSERNAME)" -s "ERROR: no hi ha instal·lat el cntlm."
        logger -t "linuxcaib-conf-proxy-server($LOCALUSERNAME)" -s "ERROR: Com que no es pot emprar el cntlm es veura el password a les variables d'entorn i a la configuració de proxy del sistema."
        PROXYSERVER_LOCAL=PROXYLOCALNOCONFIGURAT
fi


#Si existeix el servidor de proxy intermedi no autenticat, l'empram, en cas contrari hem d'emprar el proxy autenticat.
if ( isHostNearPing $UNAUTH_PROXYSERVER_NAME );then
	#Proxificam les aplicacions amb el proxy no autenticat (stmprh6lin1).
	proxificarAPT
	proxyficarClamav
else
	#Proxificam les aplicacions amb el proxy autenticat.
	proxificarAPT_auth
	proxyficarClamav_auth
fi


envProxyOn

echo "# Proxy configurat."
logger -t "linuxcaib-conf-proxy-server($LOCALUSERNAME)" -s "Fi."
exit 0;
