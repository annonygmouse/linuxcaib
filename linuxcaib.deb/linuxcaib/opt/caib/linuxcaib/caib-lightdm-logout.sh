#!/bin/sh

#Aquest script s'executa en fer logout des de lightdm. (session-cleanup-script)
#Aquest script lightdm l'executa com a root posant el codi de l'usuari dins la variable USER 


#BUG??? A Debian no hi ha definida la variable "$USER" en fer shutdown!
# A Ubuntu 14.04 sí que està definida

#Si debug no està definida, la definim
if [ -z $DEBUG ]; then DEBUG=0; fi
if [ "$DEBUG" -ge 3 ]; then
    # trace output
    set -x
fi

USER_GID=$(id $USER -gn)
if [ -f /home/$USER/shutdown-lightdm.txt ];then
        rm /home/$USER/shutdown-lightdm.txt
        touch /home/$USER/shutdown-lightdm.txt
        chown $USER:"$USER_GID" /home/$USER/shutdown-lightdm.txt
fi
stamp=`/bin/date +'%Y%m%d%H%M%S %a'`
echo "$stamp iniciant shutdown lightdm de l'usuari $USER amb id=$(id -u)  DISPLAY=$DISPLAY" >> /home/$USER/shutdown-lightdm.txt
[ "$DEBUG" -gt "1" ] && logger -t "linuxcaib-lightdm-logout($USER)" -s "entorn: env=$(env)"
echo $USER > /var/run/caib-last-logout-user

echo "$stamp env:\n$(env)" >> /home/$USER/shutdown-lightdm.txt
cat /var/run/caib-last-logout-user >> /home/$USER/shutdown-lightdm.txt 


#logger -t "linuxcaib-lightdm-logout($USER)" -s  "Intentant obrir missatge a les X"
#logger -t "linuxcaib-lightdm-logout($USER)" -s  "contingut xauthority de  $USER: $(cat /home/$USER/.Xauthority) "
#logger -t "linuxcaib-lightdm-logout($USER)" -s  "xauth -f /home/$USER/.Xauthority -i list  --> $(xauth -f /home/$USER/.Xauthority -i list 2>&1 | tee) "        


logger -t "linuxcaib-lightdm-logout($USER)"  "uid=$(id -u) Feim logout des de lightdm"

if [ "$USER" = "" ];then
        logger -t "linuxcaib-lightdm-logout($USER)"  "res a fer, és un canvi dins del greeter"        
        exit 0; #Si no hi ha usuari és un canvi dins del greeter que no cal fer res. 
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
        [ "$DEBUG" -gt "0" ] && logger -t "linuxcaib-lightdm-logout($USER)" -s "CAIBCONFUTILS=$CAIBCONFUTILS Carregam utilitats de $BASEDIR/caib-conf-utils.sh"
        . /opt/caib/linuxcaib/caib-conf-utils.sh
fi


if [ -z $LANG ]; then 
        export LANG=C.UTF-8
fi

if [ "$USER" = "" ] || [ "$USER" = "lightdm" ];then
        exit 0; #Si no hi ha usuari és un canvi dins del greeter que no cal fer res. 
fi
ZENITYUNAVAILABLE=false
logger -t "linuxcaib-lightdm-logout($USER)" "Usuari $USER amb entorn: $(env) i variables $(set | awk -F '=' '! /^[0-9A-Z_a-z]+=/ {exit} {print $1}') "
MZN_SESSION=$(cat $HOME/.caib/MZN_SESSION)
if [ "$MZN_SESSION"  = "" ];then
        #Si no hi ha sessió de SEYCON/Mazinger significa que esteim desconnectats de la xarxa i no hem de fer res!
        logger -t "linuxcaib-lightdm-logout($USER)" "Usuari $USER no estava loguejat al SEYCON, no feim logout de sessió"
        # No mostram missatge ja que sinó en equivocar-se l'usuari mostraria també aquest missatge.
        # No hi ha manera de discriminar si el logout ve de una sessió correcta d'usuari local o d'una contrasenya incorrecta al
        # login del lightdm
        #zenity --notification --timeout=2 --title="Accés a la xarxa intranet (lightdm)"  --text="Sortint de sessió d'usuari local $USER (lightdm)"
        echo "$stamp caib-lightdm-logout($USER) usuari sense sessió de seycon!" >> /home/$USER/shutdown-lightdm.txt
else
        logger -t "caib-lightdm-logout($USER)" "uid=$(id -u) Logout de lightdm de usuari $USER amb sessió de seycon"
        TIMEOUT=5
        if [ "$(zenity --width=0 --height=0 --timeout=1 --info --text "comprovant zenity..." 2>&1 | grep -v warning)" != "" ];then
                logger -t "linuxcaib-lightdm-logout($USER)" "zenity no està disponible!"
                ZENITYUNAVAILABLE=true
        fi
        (
        SEC=$TIMEOUT;
        echo "#Tancant la sessió CAIB...";
        echo "10"
        if [ ! -f /etc/caib/linuxcaib/disableperfilmobil ] && [ ! -f ~/.caib/linuxcaib/disableperfilmobil ];then 
                logger -t "caib-lightdm-logout($USER)" "iniciant sincronització perfil mobil"
                sh /opt/caib/linuxcaib/caib-perfil-mobil.sh -c -o
        else
                logger -t "caib-lightdm-logout($USER)" "ALERTA: perfil mobil deshabilitat!"
        fi
        echo "20"
        barra=10
        for unitat in $(/bin/df -P  | grep $USER | grep -v $PSERVER_LINUX | grep -v $PSERVER | awk 'BEGIN  { FS=" "} {print $6}');do
                echo "# Desmontant unitat ($unitat)"
                result=$(umount $unitat)
                sync
                #Comprovam que el umount ha anat bé i podem esborrar el directori
                if [ "$(/bin/df -P  | grep $unitat )" != "" ];then
                        logger -t "caib-lightdm-logout($USER)" "ERROR: desmontant unitat ($unitat)!"
                        echo "# ERROR: desmontant unitat ($unitat)";sleep 5;
                else
                        logger -t "caib-lightdm-logout($USER)" "Desmontada unitat ($unitat) correctament podriem eliminar directori, per ara no ho feim!"
                fi
                barra=$((barra=barra+1)) 
                sleep 0.5
        done;
        echo "$stamp caib-lightdm-logout($USER) Unitats de xarxa de l'usuari desmontades" >> /home/$USER/shutdown-lightdm.txt
        logger -t "linuxcaib-lightdm-logout($USER)" "Unitats de xarxa de l'usuari desmontades"

        echo "30"
        echo "Dins del zenity " >> /home/$USER/shutdown-lightdm.txt
        echo "# Fi"
        ) | ( [ "$ZENITYUNAVAILABLE" = false ] && /usr/bin/zenity --no-cancel --progress --title="Accés a la xarxa corporativa(lightdm)" --auto-close --text "Tancant la sessió CAIB." )
        echo "Resultat del zenity $?" >> /home/$USER/shutdown-lightdm.txt
        #Tancament comu de sessió (coses que se poden fer sense ser root!)
        #Fa fora de la barra de progrés anterior perque te la seva propia barra de progres, ja que potser se cridi des de PAM.       
        . /opt/caib/linuxcaib/caib-aux-logout.sh
        echo "Fi execucio caib-aux-logout $?" >> /home/$USER/shutdown-lightdm.txt
        echo 
fi
export USER_LIGHTDM_LOGOUT_EXECUTAT="S"
echo "$stamp fi shutdown lightdm" >> /home/$USER/shutdown-lightdm.txt

