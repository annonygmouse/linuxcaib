#!/bin/sh

#Prerequisits: caib-conf-proxy-server.sh i caib-conf-proxy-user.sh
#       L'usuari que l'executa ha de tenir permissos d'administrador
#       L'usuari ha de tenir fitxer de credencials creat al seu home.

#Primer executam caib-conf-proxy-server.sh com a sudo
sudo caib-conf-proxy-server.sh -c -l $USER
caib-conf-proxy-user.sh -c

exit 0;
