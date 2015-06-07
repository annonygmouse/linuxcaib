#!/bin/sh

#Script que comprova la configuració del salvapantalles (bloqueig d'usuari)
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

logger -t "linuxcaib-conf-xscreensaver($USER)" -s "INFO: Comprovació configuració bloqueig d'estació d'usuari"

activarBloqueigAutomatic () {
   [ "$DEBUG" -gt "0" ] && logger -t "linuxcaib-conf-xscreensaver($USER)" -s "DEBUG: activant bloueig automàtic"
   #Si lock no hi és dins del fitxer 
   if [ "$lock" = "" ];then
        echo "lock;\tTrue" >> .xscreensaver
   elif [ "$lock" = "False" ];then
        #Si lock existeix però és false
        sed -i 's/^lock:.*/lock:\tTrue/g' .xscreensaver
   fi
}

activarBloqueigDeuMinuts () {
   [ "$DEBUG" -gt "0" ] && logger -t "linuxcaib-conf-xscreensaver($USER)" -s "DEBUG: configurant timeout de 15 minuts (timeout original=$timeout)"
   #Si timeout no hi és dins del fitxer 
   if [ "$timeout" = "" ];then
        echo "timeout:\t0:10:00" >> .xscreensaver
   elif [ "$timeout" != "0:10:00" ];then
        echo "sed timeout"
        sed -i 's/^timeout.*/timeout:\t0:10:00/g' .xscreensaver
   fi
}

if [ -f $HOME/.xscreensaver ];then
        #Detectam timeout i lock
        timeout=$(grep timeout .xscreensaver| awk '{print $2}')
        lock=$(grep ^lock: .xscreensaver| awk '{print $2}')
        
        if [ "$lock" != "True" ];then
                zenity --question --title="bloqueig d'usuari" --text="El seu equip no te activat el bloqueig automàtic.\n\nAquesta característica és necessària per tal de donar compliment a \nl'article 91 del R.D. 1720/2007, de 13 de desembre.\n\n Vol activar ara el bloqueig automàtic de l'equip?"
                case $? in 
                        (0) activarBloqueigAutomatic;
                                ;; 
                        (1) exit 0; #L'usuari no vol canviar-ho... no feim res
                                ;;
                esac
        fi
        #Lock esta activat hem de mirar que hi hagi màxim 10 minuts de timeout
        timeout_hora=$(echo $timeout|cut -d":" -f 1)
        timeout_minut=$(echo $timeout|cut -d":" -f 2)
        canviar="n"
        if [ $timeout_hora -gt 0 -o $timeout_minut -gt 10  ];then
                canviar="s"
                [ "$DEBUG" -gt "0" ] && logger -t "linuxcaib-conf-xscreensaver($USER)" -s "INFO: temps de bloqueig superior a 10 minuts ($timeout)"
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
fi #Quan no existeix... agafa la versió que hi ha dins /etc/X11/app-defaults/XScreenSaver que suposarem que està bé (la instalació de linuxcaib.deb canvia aquest fitxer)
        #zenity --timeout 10 --width=200 --warning --title="Accés a la xarxa corporativa" --text="ERROR: no existeix fitxer de configuració de xscreensaver\n\nAquest dialeg se tancara en 10 segons"
        #logger -t "linuxcaib-conf-xscreensaver($USER)" -s "ERROR: no exiteix fitxer de configuració de xscreensaver."

logger -t "linuxcaib-conf-xscreensaver($USER)" -s "INFO: Configurat bloqueig d'estació d'usuari correctament"

