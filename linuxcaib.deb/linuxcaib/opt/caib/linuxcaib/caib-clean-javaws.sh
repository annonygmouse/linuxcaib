#!/bin/sh

################################################################################
# Elimina los acesos directos JavaWebStart

find  .java/ -iname "*.ind" -print0 | xargs -0 rm  2> /dev/null

#Pendent validar funcionament a linux
