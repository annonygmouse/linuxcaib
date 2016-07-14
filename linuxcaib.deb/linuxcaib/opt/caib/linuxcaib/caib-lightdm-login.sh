#!/bin/sh

#Script que fa el login de la part que necessita ser executada
#amb permissos de root (uid=0)

#ALERTA!: s'executa ABANS del pam_ses_open!

#Durant l'execució mostra el progrés.
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

#BASEDIR=$(dirname $0)
if [ "$CAIBCONFUTILS" != "SI" ]; then
        [ "$DEBUG" -gt "0" ] && logger -t "linuxcaib-lightdm-login($USER)" -s "CAIBCONFUTILS=$CAIBCONFUTILS Carregam utilitats de $BASEDIR/caib-conf-utils.sh"
        #. /opt/caib/linuxcaib/caib-conf-utils.sh
fi

export PATH=$PATH:/usr/sbin

#Si debug no està definida, la definim
if [ -z $DEBUG ]; then DEBUG=0; fi
if [ "$DEBUG" -ge 3 ]; then
    # trace output
    set -x
fi


[ "$DEBUG" -gt "0" ] && logger -t "linuxcaib-lightdm-login($USER)" -s "BASEDIR=$BASEDIR DISPLAY=$DISPLAY"
[ "$DEBUG" -gt "1" ] && logger -t "linuxcaib-lightdm-login($USER)" -s "entorn: env=$(env)"

logger -t "linuxcaib-lightdm-login($USER)"  "uid=$(id -u) Feim login des de lightdm"
echo "inici caib-lightdm-login.sh"

if [ "$USER" = "" ];then
        exit 0; #Si no hi ha usuari és un canvi dins del greeter que no cal fer res. 
fi


CREDENTIALSUSERNAME=""
USERNAMELOGIN=""
TIMEOUT=""
SEC=5
TMPMEM=$(/bin/df -t tmpfs |grep shm| awk 'BEGIN  { FS=" "} {print $6}')
NOMFITXCREDS="$TMPMEM/""$USER/""$USER""_caib_credentials"
logger -t "linuxcaib-lightdm-login($USER)"  "NOMFITXCREDS: $NOMFITXCREDS"

#if [ ! -r /etc/shadow ];then
#        #ERROR: shadow no és accessible! no te permissos!
#        logger -t "linuxcaib-lightdm-login($USER)" -s "ERROR: no he pogut consultat el fitxer /etc/shadow!"
#        zenity --timeout 10 --width=400 --error --title="Accés a la xarxa corporativa (lightdm)" --text="ERROR: no he pogut consultat el fitxer /etc/shadow!" 
#        exit 1;
#fi


#[ "$DEBUG" -gt "0" ] && logger -t "linuxcaib-lightdm-login"  "pass usuari: $(cat /etc/shadow|grep $USER | cut -d: -f2 2>&1) "
#if [ $(cat /etc/shadow|grep $USER | cut -d: -f2) != "*" ];then
#    #Si l'usuari te contrasenya al sistema és que és un usuari LOCAL, no de SEYCON.
#    logger -t "linuxcaib-lightdm-login($USER)" "Usuari LOCAL"
#    exit 0;
#fi

if [ ! -r $HOME/.caib/MZN_SESSION ];then
        logger -t "linuxcaib-lightdm-login($USER)"  "ERROR: No hi ha fitxer de sessió de mazinger!"
fi

logger -t "linuxcaib-lightdm-login($USER)"  "estat shell $(set -o) "

MZN_SESSION=$(/bin/cat $HOME/.caib/MZN_SESSION 2> /dev/null)
logger -t "linuxcaib-lightdm-login($USER)"  "home: $HOME, MZN_SESSION=$MZN_SESSION "
if [ "$MZN_SESSION"  = "" ];then
    #Si l'usuari no té sessió de Mazinger es que és un usuari LOCAL, no de SEYCON.
    logger -t "linuxcaib-lightdm-login($USER)" "lightdm: Usuari LOCAL"
    zenity --timeout 5 --width=400 --warning --title="Accés a la xarxa corporativa (lightdm)" --text="Sou un usuari LOCAL, no tendreu accés a la Xarxa corporativa"
    exit 0;
fi

if [ ! -f $NOMFITXCREDS  ];then
        logger -t "linuxcaib-lightdm-login($USER)" "No hi ha fitxer de credencials a la particio en memoria"
        #Si el fitxer de credencials NO esta a la particio en memoria significa que PAM-script no l'ha creat i que no és un usuari de seycon
        exit 0;
else
        logger -t "linuxcaib-lightdm-login($USER)" "Existeix el fitxer de credencials a la particio en memoria. PAM-SCRIPT ha anat bé i és un usuari de SEYCON."
fi

#Actualitzar password ShiroKabuto
if [ -f /etc/caib/linuxcaib/disableShiro ];then
        logger -t "linuxcaib-lightdm-login($USER)" "Deshabilitada la sincronització de contrasenya de ShiroKabuto"   
else
        dash /opt/caib/linuxcaib/caib-conf-shirokabuto.sh -c;
        if [ "$?" != "0" ];then
                logger -t "linuxcaib-lightdm-login($USER)" "Error actualitzant la contrasenya de ShiroKabuto"
                /usr/bin/zenity --timeout 10  --error --title="ERROR" --text="ERROR: Actualitzant contrasenya ShiroKabuto\n\nAquest dialeg se tancara en 10 segons"
                logger -t "linuxcaib-lightdm-login($USER)" "Error2 actualitzant la contrasenya de ShiroKabuto"
        fi
fi

if [ "$DEBUG" -gt "0" ];then
	SLEEP=0.5
	LONGSLEEP=2
else
	SLEEP=0
	LONGSLEEP=0.5
fi

(
logger -t "linuxcaib-lightdm-login($USER)" "Detectant entorn"
echo "10" ; echo "# Detectant entorn" ;sleep $SLEEP
#Si l'entorn no és correcte, tornarà 1 i sortirà de l'script.
dash /opt/caib/linuxcaib/caib-conf-entorn-lightdm.sh; 
if [ "$?" != "0" ];then
        logger -t "linuxcaib-lightdm-login($USER)" "Detectant entorn ha tornat error!"
        forceLogout=true
	exit 1;
fi


echo "20" ; echo "# Montant unitats de xarxa" ;sleep $SLEEP;
logger -t "linuxcaib-lightdm-login($USER)"  "Iniciant caib-conf-drives"
bash /opt/caib/linuxcaib/caib-conf-drives.sh -c;

echo "50" ; echo "# Configurant servidor proxy" ;sleep $SLEEP
logger -t "linuxcaib-lightdm-login($USER)"  "Iniciant proxy-server"
dash /opt/caib/linuxcaib/caib-conf-proxy-server.sh -c;

if [ ! -f /etc/caib/linuxcaib/disableconfprinters ];then
        logger -t "linuxcaib-lightdm-login($USER)" "Iniciant impressores"
        echo "65" ; echo "# Donant d'alta impressores" ; sleep $SLEEP
        nohup dash /opt/caib/linuxcaib/caib-conf-printers.sh -c &
else
        echo "65" ; echo "# Alta d'impressores deshabilitada" ; sleep $SLEEP
fi

if [ ! -f /etc/caib/dissoflinux/disabledissofd ];then 
        echo "70" ; echo "#Iniciant dissof daemon";sleep $SLEEP;
        start-stop-daemon  --start --oknodo --pidfile /var/run/dissofd.pid --startas /usr/bin/caib-dissofd 
else
        echo "70" ; echo "#Dissof daemon deshabilitat (/etc/caib/dissoflinux/disabledissofd)";sleep $SLEEP;
fi

echo "100";
) | /usr/bin/zenity  --progress --title="Accés a la xarxa corporativa(lightdm)" --text="Iniciant sessió...." --percentage=0 --no-cancel --auto-close 

if [ "$forceLogout" = true ];then
        /usr/bin/zenity  --error --title="Accés a la xarxa corporativa" --text="S'ha produit un error que impedeix iniciar sessió.\n\n Telefonau al vostre CAU."
        exit 1;
fi  

#Així si l'usuari cancela (ESC), no deixa entrar en sessió
resultCode=$?
if [ "$resultCode" != "0" ];then
        logger -t "linuxcaib-lightdm-login($USER)"  "ERROR: execució de scripts de login amb permissos de root acabats amb codi: $resultCode"
         /usr/bin/zenity --timeout 10  --error --title="ERROR" --text="ERROR: Si cancel·lau no podreu fer login\n\nAquest dialeg se tancara en 10 segons"
        exit $resultCode
fi

#Si hi ha P de linux montada, l'empram, en cas contrari, empram la P de windows
if [ -d /media/P_pcapplinux/caib/ ];then
	PSHARE=pcapplinux
else
	if [ -d /media/P_pcapp/caib/dissoflinux ];then
		PSHARE=pcapp
	fi
fi

#Executam el dissof (esteim amb permissos de root!)
#NOTA: AQUI CAL TENIR JA MONTADA LA UNITAT P !!!!!!
if [ -d /media/P_"$PSHARE"/caib/dissoflinux ];then
        if [ ! -f /etc/caib/dissoflinux/disabledissofadmin ] && [ ! -f ~/.caib/dissoflinux/disabledissofadmin ];then 
                (
                 logger -t "linuxcaib-lightdm-login($USER)"  "INFO: iniciant dissof com administrador"
                 #El HOME ha de ser /tmp !!!! ja que sinó se creen fitxers de configuració ".conf i .gconf" amb propietari "root" dins el HOME de l'usuari.
                 lofFileDissofd=$(date +%Y%m%d_%H%M%S)
                 HOME=/tmp PATH=$PATH:/usr/local/sbin:/usr/sbin:/sbin xterm -T "instal·lant components com administrador" -e "/usr/bin/caib-dissof | tee /tmp/caib-dissof-admin-$lofFileDissofd.log ; sleep 5s"
                 resultDissofd=$?
                 logger -t "linuxcaib-lightdm-login($USER)"  "INFO: resultat execució dissof com administrador: $?, desat log a /tmp/caib-dissof-admin-$lofFileDissofd.log"
                 if [ "$resultDissofd" != "0" ];then
                        logger -t "linuxcaib-lightdm-login($USER)"  "ERROR: inici de dissof com administrador erroni. Veure log a /tmp/caib-dissof-admin-$lofFileDissofd.log"
                        /usr/bin/zenity --timeout 10  --error --title="Instal·lant components de sistema" --text="ERROR iniciant dissof com administrador\n\nVeure log a /tmp/caib-dissof-admin-$lofFileDissofd.log\n\nAquest dialeg se tancara en 10 segons"

                 fi
                ) | /usr/bin/zenity  --progress --title="Instal·lant components de sistema" --text="Instal·lant components de sistema" --pulsate --no-cancel --auto-close 
        else
                logger -t "linuxcaib-lightdm-login($USER)" "INFO: dissof de sistema deshabilitat (/etc/caib/dissoflinux/disabledissofadmin)"
        fi
else
        logger -t "linuxcaib-lightdm-login($USER)" "ERROR: la unitat de xarxa ofimàtica (lofiapp) NO està montada, no es pot executar el DISSOF!"
        /usr/bin/zenity --timeout 10  --error --title="Instal·lant components de sistema" --text="ERROR: la unitat de xarxa ofimàtica (lofiapp) NO està montada.\nNo es poden instal·lar actualitzacions del sistema (dissof)\n\nAquest dialeg se tancara en 10 segons"
fi

#Definim variables d'entorn TMP i TEMP.
mkdir -p /tmp/$USER
chown $USER:$USER /tmp/$USER
usrTmpDir=/tmp/$USER
export TMP=$usrTmpDir
export TEMP=$usrTmpDir

logger -t "linuxcaib-lightdm-login($USER)" -s  "Fi"
#Sempre hauria de tornar 0!!!!
exit 0;
