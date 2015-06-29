#! /bin/sh
#REQUISITS: Aquest script necessita que l'script "caib-conf-proxy-server.sh" hagi anat bé.

# 1. Descarrega el fitxer PAC de http://proxy.caib.es/PACCAIB.txt
# 2. Transforma el PACCAIB.txt en PACCAIB_LINUX.txt substituint tots els proxies pel proxy local.
# 3. Genera el fitxer de configuració pel CNTLM. Desant-lo a la carpeta temporal en memòria de l'usuari.
# 4. Inicia el procés de CNTLM
# 5. Configura el proxy local al sistema (configuració d'usuari) entre altres:
#    - configuració de proxy a nivell de gnome (org.gnome.system.proxy).
#    - configuració de proxy a nivell de firefox
#    - a nivell de java
#    - a nivell de Lotus Notes
#    - a nivell de variables d'entorn (http_proxy, https_proxy etc.)
# 6. Afageix els certificats SSL dels proxies a java i aplicacions mozilla. 


#Configura totes les aplicacions per a que empring el servidor CNTLM.
PROXYSERVER_PAC=http://proxy.caib.es/PACCAIB.txt
PROXYSERVER_PAC_LINUX=file:///$HOME/.caib/PACCAIB_LINUX.txt
PROXYSERVER_LOCAL="PROXYLOCALNOCONFIGURAT"
PROXYSERVER_IP=10.215.9.52
PROXYSERVER_PORT=3128
CNTLMVERSION="" #Indica si el servidor cntlm està instalat i quina versió per distingir
#Dash no te la variable d'entorn HOSTNAME
HOSTNAME=$(hostname)

#User agent que emprara el CNTLM de la distribució (imprescindible per a que l'autenticació pugui ser NTLM).
CNTLM_USERAGENT="Mozilla/5.0 (Windows NT 6.1; Win64; x64; rv:25.0) Gecko/20100101 Firefox/29.0" 

#Agafam les excepcions que hi ha dins PACCAIB.txt i haurem de posar dins els "noproxy".
#Aquest codi està duplicat de caib-conf-proxy-user.sh (actualitzarPAC) TODO: treure a funció comu???
#hostnamesDirectes=`grep DIRECT $HOME/.caib/PACCAIB_LINUX.txt  | grep host== | awk 'BEGIN {FIELDWIDTHS = "2 1"} {print $2}' | awk 'BEGIN { FS = "\"" } ; { print $2"," }' | sed ':a;N;$!ba;s/\n/ /g'`
#networksDirectes=`grep DIRECT $HOME/.caib/PACCAIB_LINUX.txt | grep isInNet | awk 'BEGIN { FS = "\"" } ; { print $2"," }' | sed ':a;N;$!ba;s/\n/ /g'`
#dominisDirectes=`grep DIRECT $HOME/.caib/PACCAIB_LINUX.txt  | grep dnsDomain |  awk 'BEGIN { FS = "\"" } ; { print $2"," }' | sed ':a;N;$!ba;s/\n/ /g'`



#Importam les funcions auxiliars
#Ruta base scripts
BASEDIR=$(dirname $0)
if [ "$CAIBCONFUTILS" != "SI" ]; then
        logger -t "linuxcaib-conf-drives($USER)" "CAIBCONFUTILS=$CAIBCONFUTILS Carregam utilitats de $BASEDIR/caib-conf-utils.sh"
        . $BASEDIR/caib-conf-utils.sh
fi


# Actualitza el fitxer de configuració de cntlm
actualitzaConfigCNTLM() {

logger -t "linuxcaib-conf-proxy-user($USERNAME)" -s "CNTLM: Substituim password antic pel nou"

#calculam el nom del fitxer cntlm.conf dins l'espai segur de l'usuari que tendra contrasenya en clar.
TMPMEM=$(carpetaTempMemoria)
NOMFITXCNTLMCONF="$TMPMEM/""$USERNAME/""$USERNAME""_cntlm.conf"
if [ ! -d $TMPMEM/$USERNAME/ ];then
        mkdir -p $TMPMEM/$USERNAME/
        logger -t "linuxcaib-conf-proxy-user($USERNAME)" -s "Creada carpeta temporal en memòria: $TMPMEM/$USERNAME/ "
fi
RUTAPIDCNTLM="$TMPMEM/""$USERNAME/""$USERNAME""_cntlm.pid"

logger -t "linuxcaib-conf-proxy-user($USERNAME)" -s "CNTLM: RUTAPIDCNTLM=$RUTAPIDCNTLM"

if [ "$CNTLMVERSION" = "0.92.3-caib" ];then
        #Versió de cntlm amb autenticació BASIC i forçant user agent linux
echo "#
#IMPORTANT, hi ha una regla a l'ironport que si dins user-agent hi ha \"linux\" obliga a autenticar via BASIC que amb CNTLM estàndard NO funciona. S'ha d'emprar el cntlm-0.92.3.httpauth de la CAIB ja que afageix sempre la paraula linux a l'User-Agent de les peticions
Allow 127.0.0.1
Username        $USERNAME 
#Domain NO cal, sempre es AUTH-BASIC no NTLM
#Domain        CAIB 
Password        $PASSWORD
Workstation     $HOSTNAME 
Proxy           $SERVIDORPROXYCAIB 
NoProxy         $hostnamesDirectes $networksDirectes $dominisDirectes localhost
Listen                3128 
#S'ha d'afegir el header linux-cntlm per quan la petició NO té user agent.
Header        User-Agent: linux-cntlm
# cntlm-0.92.3.httpauth: Parametre HTTPAUTH força que la autenticació sigui NOMÉS BASIC
HTTPAUTH        1
" | tee $NOMFITXCNTLMCONF > /dev/null

else
        #Versió de cntlm estàndard de la distribució
CNTLMPASSWORD=`echo $PASSWORD | cntlm -H |grep PassNTLMv2 | awk 'BEGIN { } {print $2}' `
if [ "$CNTLMPASSWORD" = "FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF" ];then
        logger -t "linuxcaib-conf-proxy-user($USER)" -s "ERROR: la contrasenya és buida!" 
fi

echo "Allow 127.0.0.1
Username        $USERNAME 
Domain        CAIB 
Workstation        $HOSTNAME 
Auth NLTMv2
PassNTLMv2      $CNTLMPASSWORD
Proxy                $SERVIDORPROXYCAIB 
NoProxy        $hostnamesDirectes $networksDirectes $dominisDirectes  localhost
Listen                3128
Header        \"$CNTLM_USERAGENT\"
" | tee $NOMFITXCNTLMCONF > /dev/null
fi

#Proves proxy: cntlm -vI -u u83511 -B -c /dev/null -M http://i.kinja-img.com/gawker-media/image/upload/s--POFzlbXe--/c_fit,fl_progressive,q_80,w_636/vujhvleqexxkuaqvpeu9.jpg -r "User-Agent: linux" rproxy1.caib.es 3128

#Canviam permissos fitxer per a que l'usuari el pugui veure
#chown $USERNAME:$USERNAME $NOMFITXCNTLMCONF
#chmod 600 $NOMFITXCNTLMCONF

#Enllaçam el fitxer de configuració on l'espera el programa.
#ln -fs $NOMFITXCNTLMCONF /etc/cntlm.conf

 
}


#Actualitzam el fitxer PAC local amb la versió de proxy.caib.es/PACCAIB.txt
actualitzarPAC () {

http_proxy="" wget -q $PROXYSERVER_PAC -O $HOME/.caib/PACCAIB.txt
RESULTM=$?
if [ $RESULTM -eq 0 ];then
   logger -t "linuxcaib-conf-proxy-user($USERNAME)" "Descarregat PACCAIB.txt en local"
   #Substituim tots els proxys pel nostre proxy local
   sed s/10.215.9.5[2,3,4]/localhost/g $HOME/.caib/PACCAIB.txt > $HOME/.caib/PACCAIB_LINUX.txt
   logger -t "linuxcaib-conf-proxy-user($USERNAME)" "Creat $HOME/.caib/PACCAIB_LINUX.txt"
   #Agafam les excepcions que hi ha dins PACCAIB.txt i haurem de posar dins els "noproxy".
   hostnamesDirectes=`grep DIRECT $HOME/.caib/PACCAIB_LINUX.txt  | grep host== | awk 'BEGIN { } {print $2}' | awk 'BEGIN { FS = "\"" } ; { print $2"," }' | sed ':a;N;$!ba;s/\n/ /g'`
   hostnamesDirectes="$hostnamesDirectes $(hostname), "
        #nota: miip es per la gent de ibsalut que té la seva pròpia sortida a internet.
   networksDirectes=`grep DIRECT $HOME/.caib/PACCAIB_LINUX.txt | grep isInNet | grep -v miip | awk 'BEGIN { FS = "\"" } ; { print $2"," }' | sed ':a;N;$!ba;s/\n/ /g'`
   dominisDirectes=`grep DIRECT $HOME/.caib/PACCAIB_LINUX.txt  | grep dnsDomain |  awk 'BEGIN { FS = "\"" } ; { print $2"," }' | sed ':a;N;$!ba;s/\n/ /g'`
   #Els shExpMat no els pos ja que només son per JAVA i java empra el PACCAIB
else
   #No hem pogut descarregar fitxer PACCAIB.txt.
   logger -t "linuxcaib-conf-proxy-user($USERNAME)" -s  "ERROR: No he pogut descarregar PACCAIB.txt no hi ha accés a internet"
   exit 1;
fi

}


#Feim les comprovacions inicials i inicialitzam les variables que es necessitaran a l'script
proxy_init () {

[ "$DEBUG" -gt "0" ] && logger -t "linuxcaib-conf-proxy-user($USER)" "proxy_init"
#Desactivam tot el que sigui de proxy per si hi ha alguna configuració antiga malament
proxyOff

CNTLMVERSION=`dpkg -l| grep cntlm | grep ^.i |   awk 'BEGIN { FS = " " } ; { print $3 }'`
logger -t "linuxcaib-conf-proxy-user($USERNAME)" -s "Versió detectada del cntlm: $CNTLMVERSION"
#WARNING: hauriem d'emprar rproxy1, rproxy2 o rproxy3 segons la IP local (per balancejar càrrega).
#Però per ara empram rproxy1 ja que així podem fer que tota aplicació que empri cntlm surti per rproxy1
#amb autenticació BASIC. I les aplicacions que necessitin autenticació NTLM surtin per rproxy2.
#Així no hi ha conflicte de tipus d'autenticació.
SERVIDORPROXYCAIB=10.215.9.52:3128

#Cream la carpeta amb la configuració de CAIB si no existeix.
if [ ! -d "$HOME/.caib/" ] ; then
        [ "$DEBUG" -gt "0" ] && logger -t "linuxcaib-conf-proxy-user($USERNAME)" "Cream carpeta $HOME/.caib/"
        mkdir -p $HOME/.caib/
fi

touch $HOME/.caib/PACCAIB.txt > /dev/null 2>&1

if [ -w "$HOME/.caib/PACCAIB.txt" ]; then
        #Si podem sobreescriure PACCAIB.txt 
        actualitzarPAC
else 
        logger -t "linuxcaib-conf-proxy-user($USERNAME)" -s "ERROR: Calen permissos per escriure a $HOME/.caib/, avortam."
        zenity --error --timeout=10 --title="Configuració PROXY"  --text="ERROR: Calen permissos per escriure a $HOME/.caib/, avortam." &
        exit 1;
fi

#Actualitzam configuracio cntlm
actualitzaConfigCNTLM

#echo "Reiniciam el servei cntlm!!!!!"
#Hem de fer un restart del servei cntlm!!!!!
#service cntlm restart

#Arrancam cntlm com usuari manualment 
if  [ "$(cat $RUTAPIDCNTLM)" != "" ];then
        #Hi ha un cntlm anterior d'aquest usuari JA en marxa, el tancam.
        logger -t "linuxcaib-conf-proxy-user($USERNAME)" -s "WARN: Ja hi ha un procés cntlm d'aquest usuari en marxa (pid=$(cat $RUTAPIDCNTLM)). El tancam."
        kill $(cat $RUTAPIDCNTLM)  
        rm $RUTAPIDCNTLM
fi

if  [ "$(ps aux|grep cntlm|grep -v grep|awk '{ print $2 }')" != "" ];then
        #Hi ha un cntlm anterior d'aquest usuari JA en marxa, el tancam.
        logger -t "linuxcaib-conf-proxy-user($USERNAME)" -s "WARN: Ja hi ha un procés cntlm en marxa (pid=$(ps aux|grep cntlm|grep -v grep|awk '{ print $2 }')). El tancam."
        kill $(ps aux|grep cntlm|grep -v grep|awk '{ print $2 }')
        if [ "$?" != "0" ];then
                logger -t "linuxcaib-conf-proxy-user($USERNAME)" -s "ERROR: no he pogut aturar el procés cntlm anterior! amb pid=$(ps aux|grep cntlm|grep -v grep|awk '{ print $2 }'))."
                exit 1;
        fi  
fi

#No cal nohup, el propi cntlm se posa en background
logger -t "linuxcaib-conf-proxy-user($USERNAME)" -s "cntlm  -U $USERNAME -c $NOMFITXCNTLMCONF -P $RUTAPIDCNTLM"
cntlm  -U $USERNAME -c $NOMFITXCNTLMCONF -P $RUTAPIDCNTLM
if [ "$?" != "0" ];then
        logger -t "linuxcaib-conf-proxy-user($USERNAME)" -s "ERROR: NO s'ha pogut iniciar el cntlm"
        exit 1;
fi


#Dormim un segon per donar temps al cntlm a iniciar-se.
sleep 1;
}



#Mostram ajuda script
show_proxy_conf_help () {
cat << EOF
El programa "${0##*/}" proxifica les aplicacions de GNU/Linux per a que emprin el proxy local cntlm.

Ús: ${0##*/} [-hv] [-u USUARI] [-p PASSWORD]

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

if [ $USER = "root"  ]; then
        logger -t "linuxcaib-conf-proxy-user($USER)" logger -s "ERROR: no se pot executar com a root!"
        exit 1;
fi

# A POSIX variable
OPTIND=1         # Reset in case getopts has been used previously in the shell.


# Initialize our own variables:
output_file=""
#Si debug no està definida, la definim
if [ -z $DEBUG ]; then DEBUG=0; fi
if [ "$DEBUG" -ge 3 ]; then
    # trace output
    set -x
fi


while getopts "hcv?u:p:" opt; do
    case "$opt" in
    h|\?)
        show_proxy_conf_help
        exit 0
        ;;
    c)
        if [ "$seyconSessionUser" != "" ];then
                USERNAME=$seyconSessionUser
                PASSWORD=$seyconSessionPassword
        else
                #Com a backup intentam agafar el nom i contrasenya del fitxer credentials que hi ha dins el home de l'usuari.
                USERNAME=$(grep -i "^username=" $HOME/credentials | tr -d '\r'| tr -d '\n'| cut -f 2 -d "=" --output-delimiter=" ")
                PASSWORD=$(grep -i "^password=" $HOME/credentials | tr -d '\r'| tr -d '\n'| cut -f 2 -d "=" --output-delimiter=" ")
        fi     
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
#Si NO tenim usuari i password no podem configurar el proxy local
    echo "ERROR: Se necessita usuari i contrassenya per poder configurar el proxy local" >&2
    show_proxy_conf_help
    exit 1
fi


if [ "$DEBUG" -gt "0" ];then
        [ "$DEBUG" -gt "0" ] && echo "DEBUG=$DEBUG, usuari='$USERNAME', resta parametres no emprats: $@"
fi

echo "# Proxificant aplicacions..."
if [ $USER = "root"  ]; then
        logger -t "linuxcaib-conf-proxy-user($USER)" "ERROR: no se pot executar com a root!"
        echo "#Error configurant proxy (usuari root)"
        exit 1;
fi



cntlmActiu() {
#Si existeix el fitxer del PID és que cntlm està aixecat.
if [ -r $RUTAPIDCNTLM ];
then
   logger -t "linuxcaib-conf-proxy-user($USER)" "Proxy local cntlm executantse"
   echo "0"
else
   logger -t "linuxcaib-conf-proxy-user($USER)" "Execucio del proxy local cntlm no detectada ($RUTAPIDCNTLM)"
   echo "1"
fi
}


kdeProxyOn() {
echo "MILLORA: Configurar proxy al kde"
}

gnomeProxyOn () {
# gsettings list-recursively org.gnome.system.proxy

if [  "$PROXYSERVER_LOCAL" = "PROXYLOCALNOCONFIGURAT" ]; 
then
        gsettings set org.gnome.system.proxy mode 'manual' # ' manual / none / automatic '
        gsettings set org.gnome.system.proxy.http host '$USERNAME:$PASSWORD@$PROXYSERVER_IP'
        gsettings set org.gnome.system.proxy.http port $PROXYSERVER_PORT
        gsettings set org.gnome.system.proxy.https host '$USERNAME:$PASSWORD@$PROXYSERVER_IP'
        gsettings set org.gnome.system.proxy.https port $PROXYSERVER_PORT
        gsettings set org.gnome.system.proxy.ftp host '$USERNAME:$PASSWORD@$PROXYSERVER_IP'
        gsettings set org.gnome.system.proxy.ftp port $PROXYSERVER_PORT
	#TODO: adecuar el contingut de les variables $hostnamesDirectes,$networksDirectes,$dominisDirectes al format que espera gsettings
	#Aquesta clau conté una llista d'ordinadors als quals es connectarà directament en lloc d'utilitzar el servidor intermediari (en cas que s'hagi activat). Els valors poden ser noms d'ordinadors, dominis (amb comodins com ara *.exemple.cat), adreces IP d'ordinadors (tant IPv4 com IPv6) i adreces de xarxa amb màscara de xarxa (com per exemple 192.168.0.0/24).
	gsettings set org.gnome.system.proxy ignore-hosts "['localhost', '127.0.0.0/8', '10.0.0.0/8', '192.168.0.0/16', '172.16.0.0/12' , '*.localdomain.com', '*.caib.es' ]"

else 
        #echo "gnome amb fitxer PAC local"
        gsettings set org.gnome.system.proxy autoconfig-url $PROXYSERVER_PAC_LINUX
        gsettings set org.gnome.system.proxy mode auto
        gsettings set org.gnome.system.proxy use-same-proxy false
fi



logger -t "linuxcaib-conf-proxy-user($USER)" -s "Configurat proxy gnome"
#Nomes pot ser proxy NO autenticat?????? 

}

gnomeProxyOff () {
gsettings set org.gnome.system.proxy mode 'none' # ' manual / none / automatic '
logger -t "linuxcaib-conf-proxy-user($USER)" -s "Gnome: llevant configuració proxy: 'none'."
}


#Llevam la configuració de proxy del deployment.properties
javaProxyOff () {
if [ -f .java/deployment/deployment.properties ]; then
        #Esborram només el tipus de proxy per no eliminar configuracions posteriors de l'usuari.
        sed '/\.proxy.type/d' .java/deployment/deployment.properties
else 
        #Si no existeix, el cream buid.
        logger -t "linuxcaib-conf-proxy-user($USER)" "Creat fitxer de configuració de java de l'usuari."
        mkdir -p .java/deployment/
        touch .java/deployment/deployment.properties
fi
}

javaProxyOn () {
#les propietats estan dins $HOME/.java/deployment/deployment.properties
#TODO: NO SE SI java accepta file:/// .....  !!!!comprovar!!!!!

if [ -f .java/deployment/deployment.properties ]; then

        #Primer de tot llevam el que hi pugui haver de configuració del proxy a java
        javaProxyOff

        #TODO: si hi ha instalada la 1.6 el PACCAIB no funciona! S'ha d'emprar "use browser settings".
        #es a dir, no hi ha d'haver "deployment.proxy.type"

        versioJava=$(cat ~/.java/deployment/deployment.properties|grep jre.0.platform|cut -d= -f 2)

        if [ "$versioJava" = "1.6" ];then
                logger -t "linuxcaib-conf-proxy-user($USER)" "Detectat Java 1.6, basta emprar la configuració del navegador."
        else
                #Cal configuració completa personalitzada. Primer esborram TOTA la configuració de proxy que hi pugui haver
                sed '/\.proxy\./d' .java/deployment/deployment.properties
                if [  "$PROXYSERVER_LOCAL" = "PROXYLOCALNOCONFIGURAT" ]; 
                then
                        noproxy="localhost,127.0.0.1,"$hostnamesDirectes""$networksDirectes""$dominisDirecteslocaladdress".localdomain.com"
                        noproxyJava=$(echo $noproxy | tr '[,]' '[;]') #Java empra el separador ; en comptes de ,
                        cat >> $HOME/.java/deployment/deployment.properties << EOF
deployment.proxy.same=true
deployment.proxy.https.port=3128
deployment.proxy.bypass.list=$noproxyJava
deployment.proxy.bypass.local=true
deployment.proxy.http.port=$PROXYSERVER_PORT
deployment.proxy.http.host=$USERNAME:$PASSWORD@$PROXYSERVER_IP
deployment.proxy.type=1
EOF
                else 
                        if [ "$versioJava" = "1.8" ];then
                                logger -t "linuxcaib-conf-proxy-user($USER)" "Detectat Java 1.8 NO funciona el PAC."
                                #A java 1.8 NO FUNCIONA el PAC
                                cat >> $HOME/.java/deployment/deployment.properties << EOF
deployment.proxy.same=true
deployment.proxy.https.port=3128
deployment.proxy.bypass.list=$noproxyJava
deployment.proxy.bypass.local=true
deployment.proxy.http.port=$PROXYSERVER_PORT
deployment.proxy.http.host=$PROXYSERVER_IP
deployment.proxy.type=1
EOF
                        else
                        cat >> $HOME/.java/deployment/deployment.properties << EOF
deployment.proxy.type=2
deployment.proxy.auto.config.url=$PROXYSERVER_PAC_LINUX
EOF

                        fi
                fi
        fi
        logger -t "linuxcaib-conf-proxy-user($USER)" -s "Java proxificat."

else
        logger -t "linuxcaib-conf-proxy-user($USER)" -s "No hi ha fitxer de configuració de java de l'usuari, Java no proxificat."
fi
}


instalaCertChrome () {
rutaCert=$1
nomCert=$2
tipusCert=$3
#Google chrome empra NSSDB per gestionar els certificats: $HOME/.pki/nssdb
certDir="$HOME/.pki/nssdb"

if [ ! -f $certDir ];then
        logger -t "linuxcaib-conf-proxy-user($USER)" -s "No hi ha repositori de certificats de google-chrome ($certDir)"
        return
fi
#logger -t "linuxcaib-conf-proxy-user($USER)" -s "google-chrome certificate installing '${nomCert}' in $HOME/.pki/nssdb"
  #echo "openssl x509 -in $rutaCert  -inform der -outform pem  | certutil -A -n \"${nomCert}\" -t \"$tipusCert\" -d sql:$HOME/.pki/nssdb"
  if [ "$(certutil -L -d sql:${certDir} | grep -c "${nomCert}")" -eq "1" ];then
        [ "$DEBUG" -gt "0" ] && logger -t "linuxcaib-conf-proxy-user($USER)" "certificat '${nomCert}' ja instalat a '$certDir"
        return        
  fi  

  if ( ! openssl x509 -in $rutaCert -inform der -outform pem | certutil -A -n "${nomCert}" -t "$tipusCert" -d sql:${certDir} );then
       #echo "2 certutil -A -n \"${nomCert}\" -t \"$tipusCert\" -d sql:${certDir} -i $rutaCert"
       cat $rutaCert | certutil -A -n "${nomCert}" -t "$tipusCert" -d sql:${certDir} 
  fi
  if [ "$(certutil -L -d sql:${certDir} | grep -c "${nomCert}")" -eq "1" ];then
        [ "$DEBUG" -gt "0" ] && logger -t "linuxcaib-conf-proxy-user($USER)" -s "google-chrome certificate installation '${nomCert}' in $HOME/.pki/nssdb done"        
  else
        [ "$DEBUG" -gt "0" ] && logger -t "linuxcaib-conf-proxy-user($USER)" -s "google-chrome certificate installation '${nomCert}' in $HOME/.pki/nssdb ERROR"
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
  #logger -t "linuxcaib-conf-proxy-user($USER)" -s "mozilla certificate installing '${nomCert}' in ${certDir}/cert9.db done"
  #echo "openssl x509 -in $rutaCert -inform der -outform pem | certutil -A -n \"${nomCert}\" -t \"$tipusCert\" -d sql:${certDir}"
  if [ "$(certutil -L -d sql:${certDir} | grep -c "${nomCert}")" -eq "1" ];then
        [ "$DEBUG" -gt "0" ] && logger -t "linuxcaib-conf-proxy-user($USER)"  "certificat '${nomCert}' ja instalat a '${certDir}'/cert9.db"
        return        
  fi

  if ( ! openssl x509 -in $rutaCert -inform der -outform pem | certutil -A -n "${nomCert}" -t "$tipusCert" -d sql:${certDir} );then
       #echo "2 certutil -A -n \"${nomCert}\" -t \"$tipusCert\" -d sql:${certDir} -i $rutaCert"
       cat $rutaCert | certutil -A -n "${nomCert}" -t "$tipusCert" -d sql:${certDir}
  fi
  if [ "$(certutil -L -d sql:${certDir} | grep -c "${nomCert}")" -eq "1" ];then
        [ "$DEBUG" -gt "0" ] && logger -t "linuxcaib-conf-proxy-user($USER)" -s "mozilla certificat installation '${nomCert}' in '${certDir}'/cert9.db done"        
  else
        logger -t "linuxcaib-conf-proxy-user($USER)" -s "mozilla certificate installation '${nomCert}' in '${certDir}'/cert9.db ERROR"
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
  #logger -t "linuxcaib-conf-proxy-user($USER)" -s "mozilla certificate installing '${nomCert}' in '${certDir}'/cert8.db"
  #echo "openssl x509 -in $rutaCert -inform der -outform pem | certutil -A -n \"${nomCert}\" -t \"$tipusCert\" -d ${certDir}"
  if [ "$(certutil -L -d ${certDir} | grep -c "${nomCert}")" -eq "1" ];then
        [ "$DEBUG" -gt "0" ] && logger -t "linuxcaib-conf-proxy-user($USER)" "certificat '${nomCert}' ja instalat a '${certDir}'/cert8.db"
        return        
  fi

  if ( ! openssl x509 -in $rutaCert -inform der -outform pem | certutil -A -n "${nomCert}" -t "$tipusCert" -d ${certDir} );then
       #echo "2 certutil -A -n \"${nomCert}\" -t \"$tipusCert\" -d ${certDir} -i $rutaCert"
       cat $rutaCert | certutil -A -n "${nomCert}" -t "$tipusCert" -d ${certDir}
  fi
  if [ "$(certutil -L -d ${certDir} | grep -c "${nomCert}")" -eq "1" ];then
        [ "$DEBUG" -gt "0" ] && logger -t "linuxcaib-conf-proxy-user($USER)" -s "mozilla certificate installation '${nomCert}' in '${certDir}'/cert8.db done"        
  else
       logger -t "linuxcaib-conf-proxy-user($USER)" -s "mozilla certificate installation '${nomCert}' in '${certDir}'/cert8.db ERROR"
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


#Configura el chrome per a que empri la url del PAC passat per paràmetre
configChromePAC () {
#Si el sistema no te configuració proxy (xfce) s'ha de:
#crear un alias per passar-li al chrome el fitxer PAC per paràmetre

cat >> $HOME/.profile_caib_proxy << EOF
#Alies per google chrome
alias google-chrome="google-chrome --proxy-pac-url=$1"
alias google-chrome-stable="google-chrome-stable --proxy-pac-url=$1"
alias chromium="chromium --proxy-pac-url=$1"
EOF
}

configMozillaPAC () {
#Si el sistema no te configuració proxy (xfce) s'ha de:
# Crear fitxer $mozilla_profile/user.js
for certDB in $(find  $HOME/.mozilla* ~/.thunderbird -name "cert8.db")
do
  certDir=$(dirname ${certDB});
  [ "$DEBUG" -gt "0" ] && logger -t "linuxcaib-conf-proxy-user($USER)" "Configuram el proxy dins $certDir"
cat > $certDir/user.js << EOF
# Mozilla User Preferences
user_pref("network.proxy.autoconfig_url", "$1");
user_pref("network.proxy.type", 2);
user_pref("pref.advanced.proxies.disable_button.reload", false);
EOF
done
}


#Funció que configura la el PACCAIB_LINUX directament als navegadors (per quan no s'ha pogut configurar el PACCAIB_LINUX a nivell de sistema)
#Passam per paràmetre el PAC
configNavegadorsPAC () {

configMozillaPAC $1
configChromePAC $1
#el navegador intern lotus notes no permet PAC

}


instalarCertificatsProxy () {

if [ -f /media/P_$PSHARE/caib/dissoflinux/027970/cert_RPROXY1.CER ];then
        instalaCertMozilla "/media/P_$PSHARE/caib/dissoflinux/027970/cert_RPROXY1.CER"  "CAIB-RPROXY1" "C,,"
        instalaCertMozilla "/media/P_$PSHARE/caib/dissoflinux/027970/cert_RPROXY2.CER"  "CAIB-RPROXY2" "C,,"
        instalaCertMozilla "/media/P_$PSHARE/caib/dissoflinux/027970/cert_RPROXY3.CER"  "CAIB-RPROXY3" "C,,"
        instalaCertChrome "/media/P_$PSHARE/caib/dissoflinux/027970/cert_RPROXY1.CER"  "CAIB-RPROXY1" "C,,"
        instalaCertChrome "/media/P_$PSHARE/caib/dissoflinux/027970/cert_RPROXY2.CER"  "CAIB-RPROXY2" "C,,"
        instalaCertChrome "/media/P_$PSHARE/caib/dissoflinux/027970/cert_RPROXY3.CER"  "CAIB-RPROXY3" "C,,"
        #Afageixo els certificats del proxy dins del jssecerts de l'usuari ja que dins JAVA no es poden afegir aquí, ja que cal ser root per poder canviar el keystore
        if [ -r $HOME/.java/deployment/security/trusted.jssecerts ];then
                keytool -import -noprompt -trustcacerts -alias "CAIB-RPROXY1" -file "/media/P_$PSHARE/caib/dissoflinux/027970/cert_RPROXY1.CER" -keystore "$HOME/.java/deployment/security/trusted.jssecerts" -storepass ""
                keytool -import -noprompt -trustcacerts -alias "CAIB-RPROXY2" -file "/media/P_$PSHARE/caib/dissoflinux/027970/cert_RPROXY2.CER" -keystore "$HOME/.java/deployment/security/trusted.jssecerts" -storepass ""
                keytool -import -noprompt -trustcacerts -alias "CAIB-RPROXY3" -file "/media/P_$PSHARE/caib/dissoflinux/027970/cert_RPROXY3.CER" -keystore "$HOME/.java/deployment/security/trusted.jssecerts" -storepass ""
        else
                logger -t "linuxcaib-conf-proxy-user($USER)" -s "WARN: no he pogut afegir els certificats dels proxies al keystore de l'usuari"
        fi
else
        logger -t "linuxcaib-conf-proxy-user($USER)" -s "WARN: per poder instal·lar els certificats dels proxies cal que la unitat P de linux estigui montada (o enllaçada) a: /media/P_$PSHARE"
fi

}



#Llevam la configuració de proxy de la configuració del notes
#IMPORTANT, EL NOTES HA D'ESTAR ATURAT!
configNavegadorNotesOff () {

if [ -f $HOME/ibm/notes/data/workspace/BrowserProfile/prefs.js ]; then
        sed '/\.proxy\./d' $HOME/ibm/notes/data/workspace/BrowserProfile/prefs.js -i
fi

sed '/\.proxy\./d' $HOME/ibm/notes/data/workspace/BrowserProfile/prefs.js -i
}


#Configuració del proxy per notes
configNavegadorNotes () {
#IMPORTANT, EL NOTES HA D'ESTAR ATURAT!
#La configuració del notes esta a:
# $HOME/ibm/notes/data/workspace/BrowserProfile/prefs.js


#Primer eliminam la configuració anterior
configNavegadorNotesOff

if [ -f $HOME/ibm/notes/data/workspace/BrowserProfile/prefs.js ]; then

if [  "$PROXYSERVER_LOCAL" = "PROXYLOCALNOCONFIGURAT" ]; 
then
        logger -t "linuxcaib-conf-proxy-user($USER)" -s "WARNING: No podem configurar el notes amb proxy posant usuari i contrasenya" 
else 
        [ "$DEBUG" -gt "0" ] && logger -t "linuxcaib-conf-proxy-user($USER)" "configNavegadorNotes: configuram proxy local" 
cat >> $HOME/ibm/notes/data/workspace/BrowserProfile/prefs.js << EOF
user_pref("network.proxy.ftp", "$PROXYSERVER_LOCAL");
user_pref("network.proxy.ftp_port", 3128);
user_pref("network.proxy.gopher", "$PROXYSERVER_LOCAL");
user_pref("network.proxy.gopher_port", 3128);
user_pref("network.proxy.http", "$PROXYSERVER_LOCAL");
user_pref("network.proxy.http_port", 3128);
user_pref("network.proxy.no_proxies_on", "localhost,127.0.0.1,$hostnamesDirectes $networksDirectes $dominisDirectes localaddress, .localdomain.com");
user_pref("network.proxy.ssl", "$PROXYSERVER_LOCAL");
user_pref("network.proxy.ssl_port", 3128);
user_pref("network.proxy.type", 1);
EOF
fi
logger -t "linuxcaib-conf-proxy-user($USER)" -s "Lotus Notes proxificat." 
fi
}

#Funció que defineix les variables d'entorn
envProxyOn () {
if [  "$PROXYSERVER_LOCAL" = "PROXYLOCALNOCONFIGURAT" ];then
        logger -t "linuxcaib-conf-proxy-user($USER)" -s "envProxyOn: configuram variables d'entorn del proxy caib amb usuari password" 
        export http_proxy="http://$USERNAME:$PASSWORD@$PROXYSERVER_NOM:$PROXYSERVER_PORT/"
        export https_proxy="http://$USERNAME:$PASSWORD@$PROXYSERVER_NOM:$PROXYSERVER_PORT/"
        export HTTPS_PROXY="http://$USERNAME:$PASSWORD@$PROXYSERVER_NOM:$PROXYSERVER_PORT/"
        export ftp_proxy="http://$USERNAME:$PASSWORD@$PROXYSERVER_NOM:$PROXYSERVER_PORT/"
        export FTP_PROXY="http://$USERNAME:$PASSWORD@$PROXYSERVER_NOM:$PROXYSERVER_PORT/"
        export FTPS_PROXY="http://$USERNAME:$PASSWORD@$PROXYSERVER_NOM:$PROXYSERVER_PORT/"

#Cream fitxer .profile_caib_proxy (esborram si existeix)
cat > $HOME/.profile_caib_proxy << EOF
#Variables entorn proxy CAIB
export http_proxy="http://$USERNAME:$PASSWORD@$PROXYSERVER_NOM:$PROXYSERVER_PORT/"
export https_proxy="http://$USERNAME:$PASSWORD@$PROXYSERVER_NOM:$PROXYSERVER_PORT/"
export HTTPS_PROXY="http://$USERNAME:$PASSWORD@$PROXYSERVER_NOM:$PROXYSERVER_PORT/"
export ftp_proxy="http://$USERNAME:$PASSWORD@$PROXYSERVER_NOM:$PROXYSERVER_PORT/"
export FTP_PROXY="http://$USERNAME:$PASSWORD@$PROXYSERVER_NOM:$PROXYSERVER_PORT/"
export FTPS_PROXY="http://$USERNAME:$PASSWORD@$PROXYSERVER_NOM:$PROXYSERVER_PORT/"
EOF
else
        logger -t "linuxcaib-conf-proxy-user($USERNAME)" -s "envProxyOn: configuram variables d'entorn del proxy local" 
        export http_proxy="http://$PROXYSERVER_LOCAL/"
        export https_proxy="https://$PROXYSERVER_LOCAL/"
        export ftp_proxy="ftp://$PROXYSERVER_LOCAL/"
        export HTTP_PROXY="http://$PROXYSERVER_LOCAL/"
        export HTTPS_PROXY="https://$PROXYSERVER_LOCAL/"
        export FTP_PROXY="ftp://$PROXYSERVER_LOCAL/"

        #Cream fitxer .profile_caib_proxy (esborram si existeix)
        cat > $HOME/.profile_caib_proxy << EOF
#Variables entorn proxy CAIB
export http_proxy="http://$PROXYSERVER_LOCAL/"
export https_proxy="https://$PROXYSERVER_LOCAL/"
export ftp_proxy="ftp://$PROXYSERVER_LOCAL/"
export HTTP_PROXY="http://$PROXYSERVER_LOCAL/"
export HTTPS_PROXY="https://$PROXYSERVER_LOCAL/"
export FTP_PROXY="ftp://$PROXYSERVER_LOCAL/"
EOF

fi



#NOTA: no_proxy espera només NOMS DE DOMINIS!!! les IPs que se donin d'alta les ignora! SI HI HA ALGUN DOMINI DEL TIPUS XXXX.CAIB.ES amb IP externa 
# per exemple ibestat.caib.es WGET la intentarà accedir directament i potser no funcioni.
#Per exemple la web ibestat.caib.es sí que funciona, però altres no n'estic segur.
export no_proxy="localhost, 127.0.0.1, $hostnamesDirectes $networksDirectes $dominisDirectes localaddress, .localdomain.com, .caib.es"
export NO_PROXY="localhost, 127.0.0.1, $hostnamesDirectes $networksDirectes $dominisDirectes localaddress, .localdomain.com, .caib.es"

#Afegim al final del fitxer .profile_caib_proxy (esborram si existeix)
cat >> $HOME/.profile_caib_proxy << EOF
export no_proxy="localhost, 127.0.0.1, $hostnamesDirectes $networksDirectes $dominisDirectes localaddress, .localdomain.com, .caib.es"
export NO_PROXY="localhost, 127.0.0.1, $hostnamesDirectes $networksDirectes $dominisDirectes localaddress, .localdomain.com, .caib.es"
EOF

if  [ "$(grep 'profile_caib_proxy$' $HOME/.profile)" != ". $HOME/.profile_caib_proxy" ]; then
        [ "$DEBUG" -gt "0" ] && logger -t "linuxcaib-conf-proxy-user($USERNAME)" "NO se carrega el profile_caib_proxy al profile, afegim configuració per a que se faci"
cat >> $HOME/.profile << EOF
#Carregam variables entorn del proxy de la CAIB. Important, si no existeix no s'executa, que si peta no deixa fer login de X11 !!!!
if [ -r "$HOME/.profile_caib_proxy" ];then
. $HOME/.profile_caib_proxy
fi
EOF
fi

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




#IMPORTANT, el proxy s'ha de configurar només a les màquines que toquen (hi ha llocs com ibsalut que no surten pel nostre proxy)
#Agafada llista de noms de màquines del paquet dissof 27970.

if [ -f /media/P_pcapp/caib/dissof/027970/install.tcl ];then
        MAQUINES_A_PROXIFICAR=$(grep "set grups" /media/P_pcapp/caib/dissof/027970/install.tcl | sed "s/set grups \[list //g"| sed "s/ /|/g" | sed "s/\]//g"| sed "s/\^M/\n/g")
        logger -t "linuxcaib-conf-proxy-user($USER)" -s "INFO: Actualitzat llista de noms de maquines que s'han de proxificar $MAQUINES_A_PROXIFICAR "
else
        MAQUINES_A_PROXIFICAR="e*"
        logger -t "linuxcaib-conf-proxy-user($USER)" -s "DEBUG: No he pogut actualitzar la llista de noms de maquines que s'han de proxificar (del paquet 027970) emprant la llista següent: $MAQUINES_A_PROXIFICAR"
fi

MAQUINES_A_PROXIFICAR=$(echo "$MAQUINES_A_PROXIFICAR"|sed 's/*/.*/g')
#Miram si el hostname es una de les maquines a proxificar
#TODO: NO funciona echo $HOSTNAME | egrep "^$MAQUINES_A_PROXIFICAR"
if true ; then
        echo "Máquina: $HOSTNAME"
        echo "Se instala en esta maquina"
        logger -t "linuxcaib-conf-proxy-user($USER)" -s "INFO: La maquina $HOSTNAME esta en la llista de maquines a proxificar"
        #Excepció... màquina de Victoria
        if [ "$HOSTNAME" = "epreinf3" ];then
                logger -t "linuxcaib-conf-proxy-user($USER)" -s "INFO: La maquina $HOSTNAME es una excepció, no se proxifica"        
                exit 0;
        fi
else
        logger -t "linuxcaib-conf-proxy-user($USER)" -s "INFO: La maquina $HOSTNAME no esta en la lista $MAQUINES_A_PROXIFICAR"
        [ "$DEBUG" -gt "0" ] && logger -t "linuxcaib-conf-proxy-user($USER)" -s "DEBUG: resultat egrep: $(echo $HOSTNAME | egrep "^$MAQUINES_A_PROXIFICAR")"
        logger -t "linuxcaib-conf-proxy-user($USER)" -s "INFO: No s'aplica a aquesta maquina"
        exit 0;
fi

#echo "Inici configuracio PROXY"
proxy_init


# Configuram CNTLM
if [ "$(cntlmActiu)" = "0" ]; then
        logger -t "linuxcaib-conf-proxy-user($USER)" -s "CNTLM actiu."
        PROXYSERVER_LOCAL="localhost:3128"
else 
        # Si no hi ha instalat el proxy local o no l'hem pogut configurar
        logger -t "linuxcaib-conf-proxy-user($USER)" -s "ERROR: no hi ha instal·lat el cntlm. ($(cntlmActiu))"
        logger -t "linuxcaib-conf-proxy-user($USER)" -s "ERROR: Com que no es pot emprar el cntlm hi es veura el password a les variables d'entorn i a la configuració de proxy del sistema."
        PROXYSERVER_LOCAL="PROXYLOCALNOCONFIGURAT"
fi


#Els navegadors poden mostrar la pantalla d'autenticació "BASIC" que sol·licita el proxy de la caib.
#aleshores se pot emprar el PAC del proxy. 
#en canvi altres aplicacions han d'emprar directament el proxy en format USU@PASS:IP:PORT
if [  "$PROXYSERVER_LOCAL" = "PROXYLOCALNOCONFIGURAT" ]; then
        #Si cntlm no està configurat, als navegadors empram el PAC directe del proxy
        PROXYBROWSERPAC=$PROXYSERVER_PAC
else
        #Si cntlm està configurat, al navegador empram el PAC_LINUX
        PROXYBROWSERPAC=$PROXYSERVER_PAC_LINUX
fi 

# Configuram PAC firefox
# No cal, per defecte agafa valor del sistema (gnome).

# Configuram PAC gnome/kde/xfce
if [ "$XDG_CURRENT_DESKTOP" = "" ]
then
  desktop=$(echo "$XDG_DATA_DIRS" | sed 's/.*\(xfce\|kde\|gnome\).*/\1/')
else
  desktop=$XDG_CURRENT_DESKTOP
fi
desktop=$(echo $desktop | tr '[:upper:]' '[:lower:]')
case "$desktop" in
    "gnome"|"unity")
        logger -t "linuxcaib-conf-proxy-user($USER)" -s "L'escriptori emprat es $desktop"
        gnomeProxyOn
    ;;
    "kde")
        logger -t "linuxcaib-conf-proxy-user($USER)" -s "L'escriptori emprat es $desktop i encara no hi ha suport per aquest entorn."
        #kdeProxyOn
        configNavegadorsPAC $PROXYBROWSERPAC
    ;;
    "xfce")
        logger -t "linuxcaib-conf-proxy-user($USER)" -s "L'escriptori emprat es $desktop i encara no hi ha suport per aquest entorn."
        configNavegadorsPAC $PROXYBROWSERPAC
    ;;
    *)
        logger -t "linuxcaib-conf-proxy-user($USER)" -s "Escriptori emprat és $desktop (desconegut) i no hi ha suport per aquest entorn."
        configNavegadorsPAC $PROXYBROWSERPAC
    ;;
esac


#Configuram PAC JAVA
javaProxyOn

# Configuram variables d'entorn
# NO LES CONFIGURAM, JA HAURIEN D'ESTAR CONFIGURADES EN CONFIGURAR EL SERVER
envProxyOn

#No cal afegir els certificats dels proxies al sistema. Son self-signed
echo "# Instal·lant certificats pel PROXY"
instalarCertificatsProxy 

#TODO:  canviar a config firefox (a partir firefox 31): security.use_mozillapkix_verification = false
#TODO: tests. Fer tests per comprovar que podem accedir a internet i que les excepcions de PACCAIB estan ben posades.
# env

echo "# Aplicacions proxificades"

exit 0;
