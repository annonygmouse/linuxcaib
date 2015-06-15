#!/bin/bash
set +e

#Script que mostra el certificat digital passat per paràmetre per pantalla (i també amb el keytool l'exporta a un fitxer)
#Nota: també s'empra el keytool perquè en alguns casos l'openssl NO mostra tota la informació d'un certificat


#Si debug no està definida, la definim
if [ -z $DEBUG ]; then DEBUG=0; fi
if [ "$DEBUG" -ge 3 ]; then
    # trace output
    set -x
fi

#cd $HOME/bin/jxplorer
java -cp $HOME/bin/jxplorer/jars/jxplorer.jar com.ca.commons.security.cert.CertViewer $1

