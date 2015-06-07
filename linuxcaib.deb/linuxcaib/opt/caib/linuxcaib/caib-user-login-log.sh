#!/bin/sh

# Script que logueja dins /var/log/caib/$usr.log els login de l'usuari
mkdir -p /var/log/caib/

LOGFILE=/var/log/caib/$PAM_USER.log
stamp=`/bin/date +'%Y%m%d%H%M%S %a'`


[ "$PAM_TYPE" = "open_session" ] || exit 0
{
echo $stamp $PAM_SERVICE $PAM_TYPE                                \
        user=$PAM_USER ruser=$PAM_RUSER rhost=$PAM_RHOST                \
        tty=$PAM_TTY                                                        \
        args=["$@"]                                                        \
          Server: $(uname -a)                                \
        >> $LOGFILE
chmod 666 $LOGFILE > /dev/null 2>&1

} 
