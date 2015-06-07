#!/bin/sh

#Script que fa el mapeig de les carpetes DESKTOP, MY DOCUMENTS, etc. cap a la unitat H (si està montada)
#Nota: l'ha d'executar l'usuari (NO ROOT)

if [ $USER = "root"  ]; then
        logger -t "linuxcaib-xdg-userdirs($USER)" -s "ERROR: no se pot executar com a root!"
        exit 1;
fi

#Si debug no està definida, la definim
if [ -z $DEBUG ]; then DEBUG=0; fi


if [ $(df | grep "$HOME" | grep "unitat_H" >/dev/null && echo "SI") = "SI" ];then
        logger -t "linuxcaib-xdg-userdirs($USER)" -s "Habilitam la configuració XDG cap a $HOME/unitat_H/"
        xdg-user-dirs-update --set DESKTOP $HOME/unitat_H/escrit/
        #XDG no defineix ni "NetHood" ni "Favorites" -> Si es volen emprar s'han de gestionar a banda de XDG
        #Feim que la carpeta de descarregues sigui local per no carregar la unitat H
        xdg-user-dirs-update --set DOWNLOAD $HOME/downloads_firefox/
        xdg-user-dirs-update --set DOCUMENTS $HOME/unitat_H/document/
        #No se defineix una carpeta imatges dins H:, empram el home local
        xdg-user-dirs-update --set PICTURES $HOME
        xdg-user-dirs-update --set MUSIC $HOME/unitat_H/document/Mi\ música
        xdg-user-dirs-update --set VIDEOS $HOME/unitat_H/document/Mis\ vídeos
        [ "$DEBUG" -gt "0" ] && logger -t "linuxcaib-xdg-userdirs($USER)" -f $HOME/.config/user-dirs.dirs
else
        logger -t "linuxcaib-xdg-userdirs($USER)" -s "No configuram XDG ja que la unitat H NO està montada"
        #Posam els directoris per defecte
        xdg-user-dirs-update
fi

exit 0;

