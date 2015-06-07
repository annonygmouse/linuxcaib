#!/usr/bin/env sh

#Immportam les funcions auxiliars
#Ruta base scripts

CAIBCONFPATH="$(whoami)/bin"

BASEDIR=$(dirname $0)
echo "basedir $BASEDIR"

echo "${0##*/}"
echo "CAIBCONFUTILS=$CAIBCONFUTILS"
echo "carregam utilitats"
. $BASEDIR/caib-conf-utils.sh
echo "CAIBCONFUTILS=$CAIBCONFUTILS"

if  ( isHostNear "192.168.1.1" )
then
        echo "si"
fi

#Comprovar funcionament flash
# http://www.utexas.edu/learn/flash/examples.html

