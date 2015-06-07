#!/bin/sh
#set -x
#Script que executa tots els scripts per emular les polítiques de l'AD.
#ALERTA: si run-parts no funciona des de share ntfs, el que podem fer és descarregar
# els scripts en local i executar)

#S'ha d'executar amb permissos de root (id=0) i la variable $USER ha de contenir el codi
#d'usuari al que se li han d'aplicar les polítiques. Ja que hi ha coses que cal ser 
#root per poder deshabilitar-les.


if [ -z $LANG ]; then 
        export LANG=C.UTF-8
fi
#Importam les funcions auxiliars
#Ruta base scripts
BASEDIRPAM=$(dirname $0)
      
if [ "$(readlink $0)" = "" ];then
        #no es un enllaç, agafam ruta normal
        echo "fitxer normal"
        RUTA_FITXER=$(dirname $0)
        BASEDIR=$RUTA_FITXER
else
        echo "enllaç"
        RUTA_FITXER=$(readlink $0)
        BASEDIR=$( dirname $RUTA_FITXER)
fi

#Si debug no està definida, la definim
if [ -z $DEBUG ]; then DEBUG=0; fi
if [ "$DEBUG" -ge 3 ]; then
    # trace output
    set -x
fi

[ "$DEBUG" -gt "0" ] && logger -t "linuxcaib-ad-policies($USER)" -s "Inici"  
echo "BASEDIRPAM=$BASEDIRPAM  BASEDIR: $BASEDIR , RUTA_FITXER=$RUTA_FITXER"
if [ "$CAIB_CONF_SETTINGS" != "SI" ]; then
        [ "$DEBUG" -gt "0" ] && logger -t "linuxcaib-ad-policies($USER)" -s "Carregam utils de $BASEDIR/caib-conf-utils.sh"
        . $BASEDIR/caib-conf-utils.sh
fi

#Detectam la carpeta P
#Si hi ha P de linux montada, l'empram, en cas contrari, empram la P de windows
if [ -d /media/P_pcapplinux/caib/ ];then
	PSHARE=pcapplinux
else
	if [ -d /media/P_pcapp/caib/dissoflinux ];then
		PSHARE=pcapp
	fi
fi


if [ -d /media/P_$PSHARE/caib/ad-policies ];then
	policiesDir=/media/P_$PSHARE/caib/ad-policies
else
	policiesDir=/opt/caib/linuxcaib/ad-policies
fi

run-parts --test $policiesDir > /tmp/runparts-test-ad-policy.log
if [ "$(run-parts --test $policiesDir)" != "" ];then
        #TODO verificar: crec que si la carpeta de scripts de polítiques està montada sobre CIFS s'ha d'emprar run-parts --list ja que no son "executables"
        [ "$DEBUG" -gt "0" ] && logger -t "linuxcaib-ad-policies($USER)" -s "Inici run-parts $policiesDir"
        run-parts $policiesDir > /tmp/runparts-ad-policy.log
        [ "$DEBUG" -gt "0" ] && logger -t "linuxcaib-ad-policies($USER)" -s "Fi run-parts"
else
        #Els fitxers no son executables! No podem emprar run-parts!
        [ "$DEBUG" -gt "0" ] && logger -t "linuxcaib-ad-policies($USER)" -s "ERROR: els scripts no son executables, no podem emprar run-parts"
fi

