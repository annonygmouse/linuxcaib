#! /bin/sh

#Prerequisits: caib-conf-proxy-server.sh i caib-conf-proxy-user.sh

#Primer executam caib-conf-proxy-server.sh com a sudo
sudo caib-conf-proxy-server.sh -c -l $USER
caib-conf-proxy-user.sh -c

exit 0;
