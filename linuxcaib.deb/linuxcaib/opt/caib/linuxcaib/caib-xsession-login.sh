#!/bin/sh

#Script que fa el login de la part d'usuari, ja que 
#aquest script s'executa ja amb permissos de l'usuari que fa el login.

if [ -z $LANG ]; then 
        export LANG=C.UTF-8
fi

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

#Si debug no està definida, la definim
if [ -z $DEBUG ]; then DEBUG=0; fi
if [ "$DEBUG" -ge 3 ]; then
    # trace output
    set -x
fi
[ "$DEBUG" -gt "0" ] && logger -t "linuxcaib-xsession-login($USER)" -s "BASEDIR=$BASEDIR"

#Empram .caib/MZN_SESSION per detectar quin tipus d'usuari és...
[ "$DEBUG" -gt "0" ] && logger -t "linuxcaib-xsession-login($USER)" "Inici (HOME=$HOME)"
MZN_SESSION=$(cat $HOME/.caib/MZN_SESSION)
if [ "$MZN_SESSION"  = "" ];then
        #Usuari amb password... LOCAL
        logger -t "linuxcaib-xsession-login($USER)" "id=$(id -u) usuari local (password: $(cat /etc/shadow | grep $USER: | cut -d: -f2) ), desconnectat de la xarxa" 
        zenity --info --timeout=10 --title="Usuari local"  --text="Avís: els usuaris locals no poden accedir a la xarxa\n\n\nAquest dialeg se tancara en 10 segons" 
        echo "#ATENCIÓ: Sou un usuari LOCAL us trobau desconnectats de la Xarxa...";sleep 2;
else
       #Usuari SENSE password... usuari de AD (seycon)


if [ "$DEBUG" -gt "0" ];then
	SLEEP=0.5
	LONGSLEEP=2
else
	SLEEP=0
	LONGSLEEP=0.5
fi


TMPMEM=$(/bin/df -t tmpfs |grep shm| awk 'BEGIN  { FS=" "} {print $6}')
SSODAEMONPORT=$( cat "$TMPMEM/""$USER/""$USER""_ssodaemonport")

#Carregam les variables d'entorn a l'escript actual.
if [ -r $HOME/.profile_caib_proxy ];then
        . $HOME/.profile_caib_proxy
fi
rm /tmp/"$USER"_forceLogout
(
echo "# Accés a la xarxa corporativa";
sleep $LONGSLEEP;

#NO CAL, se fa via dissof
#Definim configuració directoris XDG (important! s'ha d'executar després de 60xdg-user-dirs-update)
#logger -t "linuxcaib-xsession-login($USER)" "id=$(id -u) login: caib-xdg-userdirs"
# echo "#Mapejant Mis Documentos a H";
# /bin/dash /opt/caib/linuxcaib/caib-xdg-userdirs.sh

#Canvi forsat de contrasenya! S'ha de fer en la fase de xsession ja que s'ha d'executar des de sessió d'usuari!
result=$(dash /opt/caib/linuxcaib/ad-policies/prompt-chgpasswd-before-expiration-account)
logger -t "linuxcaib-xsession-login($USER)" "Resultat /opt/caib/linuxcaib/ad-policies/prompt-chgpasswd-before-expiration-account  $result"
if [ "$result" = "changed" ];then
        logger -t "linuxcaib-xsession-login($USER)" "Canviada contrasenya, hem de tancar la sessió per a que l'usuari se torni a autenticar amb les credencials correctes"
        #REVISAR
        zenity --timeout 20 --width=400 --notification --title="Accés a la xarxa corporativa" --text="Contrasenya canviada satisfactòriament, reiniciant la sessió" &
        gnome-session-quit --logout --no-prompt
        #Ha canviat contrasenya, hem de tornar a fer login!
        echo "1" > /tmp/"$USER"_forceLogout
        exit 1
else 
        if [ "$result" = "" ];then
                logger -t "linuxcaib-xsession-login($USER)" "No cal canviar la contrasenya o l'usuari no l'ha volgut canviar ara."
        else 
                logger -t "linuxcaib-xsession-login($USER)" -s "ERROR canviant contrasenya: $result."
        fi
fi


echo "10" ; echo "# Detectant entorn" ;sleep $SLEEP
#Si l'entorn no és correcte, tornarà 1 i sortirà de l'script.
dash /opt/caib/linuxcaib/caib-conf-entorn-xsession.sh; 
if [ "$?" != "0" ];then
        logger -t "linuxcaib-xsession-login($USER)" "Detectant entorn ha tornat error!"
        echo "1" > /tmp/"$USER"_forceLogout
        exit 1;
fi

echo "15" ; echo "# Configurant Office" ;sleep $SLEEP
dash /opt/caib/linuxcaib/caib-conf-office.sh; 


echo "20" ; echo "# Netejant javaws";sleep $SLEEP
/bin/dash /opt/caib/linuxcaib/caib-clean-javaws.sh
#Configuram la part d'usuari del proxy

#Si hi ha P de linux montada, l'empram, en cas contrari, empram la P de windows
PSHARE=""
if [ -d /media/P_pcapplinux/caib/ ];then
	PSHARE=pcapplinux
else
	if [ -d /media/P_pcapp/caib/dissoflinux ];then
		PSHARE=pcapp
	fi
fi

#Executam el dissof (esteim amb permissos de usuari!)
#NOTA: AQUI CAL TENIR JA MONTADA LA UNITAT P !!!!!!
if [ -d /media/P_"$PSHARE"/caib/dissoflinux ];then
	logger -t "linuxcaib-xsession-login($USER)" "Executam el paquet dissof de proxy"
	#/usr/bin/tclsh /media/P_*/dissoflinux/027970/install.tcl
	caib-dissof-paquet 027970
else
	logger -t "linuxcaib-xsession-login($USER)" "dissoflinux NO accessible, emprant script  caib-conf-proxy-user de linuxcaib"
	/bin/sh /opt/caib/linuxcaib/caib-conf-proxy-user.sh -c
fi
#OLD executam script de proxy com el mazinger. 
#echo "40" ; sleep $SLEEP

if [ ! -f /etc/caib/linuxcaib/disablesessiondaemon ];then 
        echo "60";echo "# Iniciant session daemon"; sleep $SLEEP
        logger -t "linuxcaib-xsession-login($USER)" "iniciant caib-session-daemon"
        caib-session-daemon $SSODAEMONPORT $(cat $HOME/.caib/MZN_SESSION) $(cat $HOME/.caib/seycon_session_id) &
else
        logger -t "linuxcaib-xsession-login($USER)" "ALERTA: caib-session-daemon deshabilitat (/etc/caib/linuxcaib/disablesessiondaemon)!"
fi

if [ ! -f /etc/caib/linuxcaib/disableperfilmobil ] && [ ! -f ~/.caib/linuxcaib/disableperfilmobil ];then 
        echo "70";echo "# Sincronitzant perfil mobil"; sleep $SLEEP
        logger -t "linuxcaib-xsession-login($USER)" "iniciant sincronització perfil mobil"
        /bin/sh /opt/caib/linuxcaib/caib-perfil-mobil.sh -c -i
else
        logger -t "linuxcaib-xsession-login($USER)" "Perfil mobil deshabilitat"
fi

echo "80" ; sleep $SLEEP
if [ ! -f /etc/caib/mazinger/disablemazinger ] && [ ! -f ~/.caib/mazinger/disablemazinger ];then 
   if [ -f /usr/bin/mazinger ];then 
           logger -t "linuxcaib-xsession-login($USER)" "Actualitzant regles mazinger"
           echo "75" ; sleep $SLEEP
           dash /opt/caib/linuxcaib/caib-conf-mazinger.sh -c
           if [ -f ~/.caib/mazinger.mzn ];then
              echo "# Iniciant mazinger"; sleep $SLEEP
              #Paràmetres del Mazinger: Fitxer de credencials i fitxer de configuració
              tmpMem=$(/bin/df -t tmpfs |grep shm| awk 'BEGIN  { FS=" "} {print $6}')
              mazinger start -credentials $tmpMem/""$USER""/""$USER""_caib_credentials_mazinger $HOME/.caib/mazinger.mzn
           else
                logger -t "linuxcaib-xsession-login($USER)" "ERROR: no he pogut iniciar el Mazinger, falta fitxer de configuració"
           fi
   else
           logger -t "linuxcaib-xsession-login($USER)" "Mazinger no instal·lat"
   fi
else
        logger -t "linuxcaib-xsession-login($USER)"  "Mazinger deshabilitat"
fi

logger -t "linuxcaib-xsession-login($USER)"  "Iniciant politiques grup"
echo "90"; echo "# Carregant polítiques de grup"; 
nohup dash /opt/caib/linuxcaib/caib-ad-policies.sh -c >> /tmp/caib-ad-policies-$USER.log 2>> /tmp/caib-ad-policies-$USER.log < /dev/null &
sleep $SLEEP

echo "#Fi"
echo "100" ; sleep $SLEEP
) | /usr/bin/zenity --no-cancel --progress --title="Accés a la xarxa corporativa" --percentage=0  --auto-close --text "Accés a la xarxa corporativa"

if [ -r /tmp/"$USER"_forceLogout ];then
        /usr/bin/zenity  --error --title="Accés a la xarxa corporativa" --text="S'ha produit un error que impedeix iniciar sessió.\n\n Telefonau al vostre CAU."
        logger -t "linuxcaib-xsession-login($USER)"  "ForceLogout"
        exit 1;
else
        logger -t "linuxcaib-xsession-login($USER)"  "ForceLogout=$forceLogout"
fi

#Forçam la càrrega del .profile_caib_proxy per definir les variables d'entorn PROXY fora del bucle de zenity per a que inicialment la sessió X tengui les variables d'entorn del proxy.
#Posteriorment el bash llegirà .profile
#Carregam les variables d'entorn a l'escript actual.
logger -t "linuxcaib-xsession-login($USER)"  "Carregant .profile_caib_proxy"
if [ -r "$HOME/.profile_caib_proxy" ]; then
        . $HOME/.profile_caib_proxy
else
        logger -t "linuxcaib-xsession-login($USER)"  "ERROR: fitxer .profile_caib_proxy NO GENERAT!"
fi

#Executam altres tasques

#Executam el control de càrrega (com usuari) [Per defecte està deshabilitat]
if [ ! -f /etc/caib/linuxcaib/enableloadmonitor ] && [ ! -f ~/.caib/linuxcaib/enableloadmonitor ];then
        logger -t "linuxcaib-xsession-login($USER)" "Monitor de càrrega deshabilitat"
else
        nohup /usr/bin/caib-load-monitor > /dev/null 2> /dev/null < /dev/null &
fi
#Obrim el navegador per defecte amb la intranet feim l'sleep per a que tengui temps de carregar-se el window manager
nohup sh -c 'sleep 2 ; /usr/bin/x-www-browser https://intranet.caib.es' > /dev/null 2> /dev/null < /dev/null &
[ "$DEBUG" -gt "0" ] && logger -t "linuxcaib-xsession-login($USER)" "ID procés firefox intranet: $(jobs -l|awk 'BEGIN {} { print $2}')"
#Executam configuració de bloqueig de pantalla d'usuari (salvapantalles) també feim un poc d'sleep
nohup sh -c 'sleep 20 ; /bin/dash /opt/caib/linuxcaib/caib-conf-screensaver.sh' > /dev/null 2> /dev/null < /dev/null &

#Executam el dissof (com usuari)
if [ ! -f /etc/caib/dissoflinux/disabledissofuser ] && [ ! -f ~/.caib/dissoflinux/disabledissofuser ];then 
        nohup xterm -T "Instal·lant components d'usuari" -e "/usr/bin/caib-dissof | tee /tmp/caib-dissof-usuari-$(date +%Y%m%d_%H%M%S).log ; sleep 2" > /dev/null 2> /dev/null < /dev/null &
        #Minimitzam la finestra del dissof d'usuari
        xdotool windowminimize $(xdotool search --name "Instal·lant components d'usuari")
else
        logger -t "linuxcaib-xsession-login($USER)" "dissof d'usuari deshabilitat"
fi
#Activam nunlock
/usr/bin/numlockx on

fi #Comprovació si usuari te password... si te password és un usuari LOCAL

if [ "$LANG" = "C.UTF-8" ];then
        unset LANG
fi

