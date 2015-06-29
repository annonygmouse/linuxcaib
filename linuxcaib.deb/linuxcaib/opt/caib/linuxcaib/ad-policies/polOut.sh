#!/bin/sh

#Script que deshabilitat totes les polítiques 

#Requisits, només un administrador pot deshabilitar les polítiques de sistema (caib)

dconf reset /etc/dconf/db/caib

# Obtenim llista de "esquema clau" que modifiquen els scripts de ad-policy
# i els resetejam als seus valors per defecte
grep --exclude=polOut.sh "gsettings set"  /opt/caib/linuxcaib/ad-policies/*| grep -v "#"|cut -d: -f2-|sed 's/gsettings set//g'| sed -e 's/^[ \t]*//'|cut -d" " -f1,2|sort|uniq| (while read -r line; do
    if [ "$line" != "" ];then
	#echo "gsettings reset $line"
	comanda=$(echo "gsettings reset $line")
	echo "executant: $comanda"
	eval ${comanda}
    else
	echo "linia buida ($line)" 
    fi
done)

