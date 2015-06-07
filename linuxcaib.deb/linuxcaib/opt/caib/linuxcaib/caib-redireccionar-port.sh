#!/bin/sh

#Copiat de caib-conf-utils.sh


#Funció que redirecciona el port PORT_ALT al PORT_BAIX, essent el port ALT un port
#que l'usuari pot obrir i BAIX el port < 1024 que l'usuari vol obrir
#Requisits: que l'usuari tengui permisos d'administrador via sudo
#           que NOMES tengui una interfície de xarxa amb adreça IP assignada
#param1: port alt 
#param2: port baix
RedireccionarPort () {
        portAlt=$1
        portBaix=$2
        interf1=
IP=$(/sbin/ifconfig | grep "inet addr:" | grep -v 127.0.0.1 | sed -e 's/Bcast//' | cut -d: -f2)
sudo iptables -t nat -A PREROUTING -p tcp --dport $portBaix -j REDIRECT --to-port $portAlt
sudo iptables -t nat -I OUTPUT -p tcp -d $IP --dport $portBaix -j REDIRECT --to-ports $portAlt
echo "ATENCIÓ: Port $portAlt redireccionat al port $portBaix !"
}

#Funció que redirecciona el port de VNC (5900) cap al port 80 per evitar firewalls 
#RedireccionarPortVNC () {
#        RedireccionarPort 5900 80
#}
#RedireccionarPortVNC

