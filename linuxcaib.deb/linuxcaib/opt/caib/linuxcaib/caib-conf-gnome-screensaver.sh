#!/bin/sh

#Script que comprova la configuració del salvapantalles (bloqueig d'usuari)
#de gnome.
#Comprova que tengui com a maxim un temps d'espera de 10minuts i que calgui 
#contrasenya per desactivar el salvapantalles.

#Aquest script s'ha d'executar quan ja s'hagi arrancar l'xscreensaver, així
#ens asseguram que existeixi el fitxer de configuració.

#Si debug no està definida, la definim
if [ -z $DEBUG ]; then DEBUG=0; fi
if [ "$DEBUG" -ge 3 ]; then
    # trace output
    set -x
fi

logger -t "linuxcaib-conf-gnome-screensaver($USER)" -s "INFO: Comprovació configuració bloqueig d'estació d'usuari"

#Hem de permetre a l'usuari bloquejar la pantalla
gsettings set org.gnome.desktop.lockdown disable-lock-screen false

#Hem de permetre canviar d'usuari
gsettings set org.gnome.desktop.screensaver user-switch-enabled true

#En cas que suspenguem la màquina (NO HO HAURIEM DE PODER FER), que demani password:
gsettings set org.gnome.desktop.screensaver ubuntu-lock-on-suspend true

#No atenuam la pantalla per estalviar energia (només ho permeten les pantalles de portàtils)
gsettings set org.gnome.settings-daemon.plugins.power idle-dim false


activarBloqueigAutomatic () {
   [ "$DEBUG" -gt "0" ] && logger -t "linuxcaib-conf-gnome-screensaver($USER)" -s "DEBUG: activant bloueig automàtic"
   gsettings set org.gnome.desktop.screensaver lock-enabled true 
}

activarBloqueigDeuMinuts () {
   [ "$DEBUG" -gt "0" ] && logger -t "linuxcaib-conf-gnome-screensaver($USER)" -s "DEBUG: configurant timeout de 10 minuts (timeout original=$timeout)"
   gsettings set org.gnome.desktop.session idle-delay 'uint32 600'
}

#Detectam que gnome-screensaver estigui instal·lat i actiu 
if [ -r /usr/bin/gsettings ];then
        #Detectam timeout i lock
        timeout=$(gsettings get org.gnome.desktop.session idle-delay| awk '{print $2}')
        lock=$(gsettings get org.gnome.desktop.screensaver lock-enabled)
        [ "$DEBUG" -gt "0" ] && logger -t "linuxcaib-conf-gnome-screensaver($USER)" -s "INFO: lock=$lock i timeout=$timeout"
        if [ "$lock" != "true" ];then
                zenity --question --title="bloqueig d'usuari" --text="El seu equip no te activat el bloqueig automàtic.\n\nAquesta característica és necessària per tal de donar compliment a \nl'article 91 del R.D. 1720/2007, de 13 de desembre.\n\n Vol activar ara el bloqueig automàtic de l'equip?"
                case $? in 
                        (0) activarBloqueigAutomatic;
                                ;; 
                        (1) exit 0; #L'usuari no vol canviar-ho... no feim res
                                ;;
                esac
        fi
        #Lock esta activat hem de mirar que hi hagi màxim 10 minuts de timeout (600 segons)
        canviar="n"
        if [ $timeout -gt 600 -o $timeout -eq 0 ];then
                canviar="s"
                [ "$DEBUG" -gt "0" ] && logger -t "linuxcaib-conf-gnome-screensaver($USER)" -s "INFO: temps de bloqueig superior a 15 minuts ($timeout)"
        fi
        if [ "$canviar" = "s" ];then
                zenity --question --title="bloqueig d'usuari" --text="El seu equip té assignat un temps de bloqueig automàtic superior a deu minuts.\n\nPer tal de donar compliment a l'article 91 del R.D. 1720/2007, de data 13 de desembre,\nes recomana que l'equip es bloquegi després de 10 minuts de no activitat.\n\nVol activar ara el bloqueig automàtic de l'equip als 10 minuts?"
                case $? in
                        (0) activarBloqueigDeuMinuts;
                                ;; 
                        (1) exit 0; #L'usuari no vol canviar-ho... no feim res
                                ;;
                esac
        fi    
fi 
logger -t "linuxcaib-conf-gnome-screensaver($USER)" -s "INFO: Configurat bloqueig d'estació d'usuari correctament"

