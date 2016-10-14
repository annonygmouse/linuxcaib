#!/bin/bash

#TODO: fer que funcioni amb DASH!!!

#http://stackoverflow.com/questions/2832376/how-to-detect-pending-system-shutdown-on-linux
#Igual convé fe-ho amb python http://stackoverflow.com/questions/13527451/how-can-i-catch-a-system-suspend-event-in-python

#Script que escolta si hi ha un shutdown al dbus i neteja (fa logout al seycon).

#ALERTA: aquest script s'ha de iniciar i deixar en background!
#set -x

#comprovar que el daemon del seyconsession estigui en marxa
#if ! ps ux|grep screensaver|grep -q -v grep 
#then
#	logger -t "linuxcaib-monitor-shutdown($USER)" -s "ERROR: gnome-screensaver no iniciat, tancam"
#	exit -1;
#fi

#Si debug no està definida, la definim
if [ -z $DEBUG ]; then DEBUG=1; fi
if [ "$DEBUG" -ge 3 ]; then
    # trace output
    set -x
fi


logger -t "linuxcaib-monitor-shutdown($USER)" -s "Inici tasca escoltar dbus per detectar apagat estació de treball"
#v O: signal time=1455574415.680084 sender=:1.4 -> destination=(null destination) serial=426 path=/org/freedesktop/login1; interface=org.freedesktop.login1.Manager; member=PrepareForShutdown


#23:13:29 I: Started dbus-monitor --system
#23:13:35 O: signal time=1455574415.639243 sender=:1.4 -> destination=(null destination) serial=420 path=/org/freedesktop/login1; interface=org.freedesktop.DBus.Properties; member=PropertiesChanged
#23:13:35 O:    string "org.freedesktop.login1.Manager"
#23:13:35 O:    array [
#23:13:35 O:       dict entry(
#23:13:35 O:          string "DelayInhibited"
#23:13:35 O:          variant             string "shutdown:sleep"
#23:13:35 O:       )
#23:13:35 O:    ]
#23:13:35 O:    array [
#23:13:35 O:    ]
#23:13:35 O: signal time=1455574415.680084 sender=:1.4 -> destination=(null destination) serial=426 path=/org/freedesktop/login1; interface=org.freedesktop.login1.Manager; member=PrepareForShutdown
#23:13:35 O:    boolean true
#23:13:35 O: signal time=1455574415.680137 sender=:1.4 -> destination=(null destination) serial=428 path=/org/freedesktop/login1; interface=org.freedesktop.DBus.Properties; member=PropertiesChanged
#23:13:35 O:    string "org.freedesktop.login1.Manager"
#23:13:35 O:    array [
#23:13:35 O:       dict entry(
#23:13:35 O:          string "DelayInhibited"
#23:13:35 O:          variant             string "shutdown:sleep"
#23:13:35 O:       )
#23:13:35 O:    ]

#echo "fsdjflñsdjk\nflkñakdsjfñl skdf\nsdflkñjsd\nboolean\nfsdfkldsj" > x.txt
#cat x.txt
#if cat x.txt | grep "boolean true" &> /dev/null; then
#	echo "tancant seyconsession"
#fi  

#TODO: inhibit http://unix.stackexchange.com/questions/64151/networkmanager-disabled-network-when-sending-system-to-sleep#102658

dbus-monitor --system  "type='signal',interface='org.freedesktop.login1.Manager'" | \
(
  while true; do
    read X
    stamp=$(/bin/date +'%Y%m%d%H%M%S %a')
    [ "$DEBUG" -gt "0" ] && echo "--- rebut: " >> $HOME/tancant.log
    [ "$DEBUG" -gt "0" ] && echo $X >> $HOME/tancant.log
    [ "$DEBUG" -gt "0" ] && echo "--- ara ho processarem " >> $HOME/tancant.log
#    echo $X >> $HOME/tancant.log
    if echo $X | grep "PrepareForShutdown";then
            read X
            [ "$DEBUG" -gt "0" ] && echo "PrepareForShutdown detected " >> $HOME/tancant.log
            if echo $X | grep "boolean true" &> /dev/null; then
                stamp=$(/bin/date +'%Y%m%d%H%M%S %a')
                [ "$DEBUG" -gt "0" ] && echo "True detected " >> $HOME/tancant.log
	        echo "tancant seyconsession" >> $HOME/tancant-$stamp.log
	        logger -t "linuxcaib-monitor-shutdown($USER)" -s "Màquina tancant, feim logout de seycon"
	        /opt/caib/linuxcaib/caib-aux-logout.sh
            fi
    fi  
   done
)

logger -t "linuxcaib-monitor-shutdown($USER)" -s "Fi tasca escoltar dbus per detectar apagat estació de treball"


