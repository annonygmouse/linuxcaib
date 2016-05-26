#!/bin/bash

#TODO: fer que funcioni amb DASH!!!
#TODO: millorar que no sigui poling! 
#http://blog.troyastle.com/2011/06/run-scripts-when-gnome-screensaver.html
#http://unix.stackexchange.com/questions/28181/run-script-on-screen-lock-unlock

#Script que monitoritza el bloqueig de pantalla de gnome-screensaver.
#Quan s'ha desbloquejat, s'inicia la comprovació de caducitat de contrasenya

#ALERTA: aquest script s'ha de iniciar i deixar en background!
#set -x

if ! ps ux|grep screensaver|grep -q -v grep 
then
	logger -t "linuxcaib-screensaver-check-password($USER)" -s "ERROR: gnome-screensaver no iniciat, tancam"
	exit -1;
fi

logger -t "linuxcaib-screensaver-check-password($USER)" -s "Inici tasca escoltar dbus del gnome-screensaver per forçar caducitat contrasenya"
dbus-monitor --session  "type='signal',interface='org.gnome.ScreenSaver'" | \
(
  while true; do
    read X
    if echo $X | grep "boolean true" &> /dev/null; then
      echo "Pantalla bloquejada";
    elif echo $X | grep "boolean false" &> /dev/null; then
        #TODO: moure aquest codi a una funció/script comú, ja que per ara esta duplicat dins caib-conf-xsession-login.sh i caib-screensaver-check-password.sh
        #Canvi forsat de contrasenya! S'ha de fer en la fase de xsession ja que s'ha d'executar des de sessió d'usuari!
        result=$(dash /opt/caib/linuxcaib/ad-policies/prompt-chgpasswd-before-expiration-account)
        logger -t "linuxcaib-screensaver-check-password($USER)" -s "Resultat /opt/caib/linuxcaib/ad-policies/prompt-chgpasswd-before-expiration-account  $result"
        if [ "$result" = "changed" ];then
                logger -t "linuxcaib-screensaver-check-password($USER)" -s "Canviada contrasenya, hem de tancar la sessió per a que l'usuari se torni a autenticar amb les credencials correctes"
                #REVISAR
                zenity --timeout=20 --width=400 --notification --title="Accés a la xarxa corporativa" --text="Contrasenya canviada satisfactòriament, reiniciant la sessió" &
                gnome-session-quit --logout --no-prompt
                #Ha canviat contrasenya, hem de tornar a fer login!
        else 
                if [ "$result" = "" ];then
                        logger -t "linuxcaib-screensaver-check-password($USER)" "No cal canviar la contrasenya o l'usuari no l'ha volgut canviar ara."
                else 
                        logger -t "linuxcaib-screensaver-check-password($USER)" -s "ERROR canviant contrasenya: $result."
                fi
        fi
	sleep 1;
    fi
  done
)

logger -t "linuxcaib-screensaver-check-password($USER)" -s "Fi tasca escoltar dbus del gnome-screensaver per forçar caducitat contrasenya"
