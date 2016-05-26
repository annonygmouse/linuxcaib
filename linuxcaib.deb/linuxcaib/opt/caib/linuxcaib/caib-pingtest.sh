#!/bin/sh

#set -x
(
i=0
while [ $i -lt 20 ]; do
        sleep 1
        is_up=$(ping -q -w 1 -c 1 `ip r | grep default | cut -d ' ' -f 3` > /dev/null && echo 1 || echo 0)
#test is_up=0
        i=$(($i+1))
        if [ $is_up -eq 1 ]; then
                i=20
        fi
        echo "$(($i*5))"
done
)|
zenity --progress \
  --title="Esperant xarxa" \
  --text="Esperant la configuració de xarxa." \
  --percentage=0 \
   --auto-close


is_up=$(ping -q -w 1 -c 1 `ip r | grep default | cut -d ' ' -f 3` > /dev/null && echo 1 || echo 0)
if [ $is_up -eq 0 ];then
        zenity --modal --timeout=10 --error --title="Error de xarxa" --text="ERROR: no hi ha configurada/connectada la xarxa.\nNo podreu iniciar sessió a la Xarxa corporativa.\nTan sols podreu iniciar sessió amb un usuari local!"
else 
        #Ara que hi ha xarxa, forçam la sincronització de temps amb el servidor de temps de la CAIB
        ntpdate -sb timesrv.caib.es
fi


