#!/bin/sh

# Configura les aplicacions ofimàtiques
# S'ha d'executar amb permissos d'usuari NO amb permissos de root.

# S'ha d'executar DESPRÉS de montar les unitats de xarxa

BASEDIR=$(dirname $0)
if [ "$CAIBCONFUTILS" != "SI" ]; then
        logger -t "linuxcaib-conf-office($USER)" "Carregam utilitats de $BASEDIR/caib-conf-utils.sh"
        . $BASEDIR/caib-conf-utils.sh
fi

#Si debug no està definida, la definim
if [ -z $DEBUG ]; then DEBUG=0; fi
if [ "$DEBUG" -ge 3 ]; then
    # trace output
    set -x
fi


if [ $USER = "root"  ]; then
        logger -t "linuxcaib-conf-office($USER)" -s "ERROR: no se pot executar com a root!"
        exit 1;
fi


#Configuram ruta plantilles de LibreOffice
configurarPlantillesLibreOffice () {

#Configuració de LibreOffice v4
if [ -d $HOME/.config/libreoffice/4/ ];then
        #.config/libreoffice/4/user
        #Per defecte la ruta és $HOME/.config/libreoffice/4/user/template
        #La configuració està dins: $HOME/.config/libreoffice/4/user/registrymodifications.xcu
#canviar: <item oor:path="/org.openoffice.Office.Paths/Paths/org.openoffice.Office.Paths:NamedPath['Template']"><prop oor:name="WritePath" oor:op="fuse"><value>$(user)/template</value></prop></item>
#i posar:
#<item oor:path="/org.openoffice.Office.Paths/Paths/org.openoffice.Office.Paths:NamedPath['Template']"><prop oor:name="WritePath" oor:op="fuse"><value>$(work)/unitat_H/office/Plantillas</value></prop></item>
        sed 's/\$(user)\/template/\$(work)\/unitat_H\/Libreoffice\/Plantillas/g'  $HOME/.config/libreoffice/4/user/registrymodifications.xcu
        logger -t "linuxcaib-conf-office($USER)" -s "Configurat libreoffice 4!"
else
        logger -t "linuxcaib-conf-office($USER)" -s "ERROR: libreoffice no instal·lat o no emprat!"
fi

}

if [ "$(unitatHMontada)" = "true" ];then
        #Cream la carpeta si no existeix
        mkdir -p $HOME/unitat_H/Libreoffice/Plantillas
        #Configuram l'openoffice per a que empri aquesta carpeta per guardar/agafar les plantilles.
        configurarPlantillesLibreOffice
else
        logger -t "linuxcaib-conf-office($USER)" -s "ERROR: unitat H NO montada"        
fi


