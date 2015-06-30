#!/bin/sh

#Script per generar tots els fitxers de manuals dels scripts de linuxcaib

versio=$(grep ersion ../linuxcaib.deb/linuxcaib/DEBIAN/control | awk '{ print $2 }')

scriptsPerGenerar="../linuxcaib.deb/linuxcaib/opt/caib/linuxcaib/caib-conf-drives.sh \
                ../linuxcaib.deb/linuxcaib/opt/caib/linuxcaib/caib-conf-proxy-server.sh \
                ../linuxcaib.deb/linuxcaib/opt/caib/linuxcaib/caib-conf-proxy-user.sh \
                ../linuxcaib.deb/linuxcaib/opt/caib/linuxcaib/caib-conf-printers.sh \
                ../linuxcaib.deb/linuxcaib/opt/caib/linuxcaib/caib-conf-mazinger.sh \
                ../linuxcaib.deb/linuxcaib/opt/caib/linuxcaib/caib-conf-seyconsession.sh \
                ../linuxcaib.deb/linuxcaib/opt/caib/linuxcaib/caib-conf-shirokabuto.sh \
                ../linuxcaib.deb/linuxcaib/opt/caib/linuxcaib/caib-perfil-mobil.sh \
                ../linuxcaib.deb/linuxcaib/opt/caib/linuxcaib/caib-conf-roles.sh \
                ../linuxcaib.deb/linuxcaib/opt/caib/linuxcaib/caib-conf-grups.sh \
                ../linuxcaib.deb/linuxcaib/usr/bin/caib-afageix-certificat \
                ../linuxcaib.deb/linuxcaib/usr/bin/caib-canvi-jvm-global \
                ../linuxcaib.deb/linuxcaib/usr/bin/caib-secure-delete \
                ../linuxcaib.deb/linuxcaib/usr/bin/caib-canvi-obrir-app-fitxer \
                ../linuxcaib.deb/linuxcaib/usr/bin/caib-install-api-firma \
                ../linuxcaib.deb/linuxcaib/usr/bin/caib-esborrar-temporals-java \
                ../linuxcaib.deb/linuxcaib/usr/bin/caib-error-firefox \
                ../linuxcaib.deb/linuxcaib/usr/bin/caib-load-monitor \
                "       

for fitx in $scriptsPerGenerar;do
        #echo $fitx $(basename $fitx)
        help2man -S linuxcaib -N -L ca_ES.utf8 --version-string=$versio -i seccio_autor_bugs \
                -h -h  $fitx | gzip > ../linuxcaib.deb/linuxcaib/usr/share/man/ca/man1/$(basename $fitx).1.gz
        echo "Fitxer man generat a ../linuxcaib.deb/linuxcaib/usr/share/man/ca/man1/$(basename $fitx.1.gz)"
done

