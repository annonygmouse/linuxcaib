#DETECTAR SI S'HA FET LOGIN AMB CERTIFICAT DIGITAL I OBTENIR CREDENCIALS SI CAL
#invesstigar que fa el https://$SEYCON_SERVER:$SEYCON_PORT/certificateLogin (o similar)
        #Si hem entrat amb certificat digital hem de mirar com ho podem fer...
        # entenc que seycon ens donarà la informació de l'usuari i permetra autenticar-mos SENSE haver d'autenticar-mos contra ActiveDirectory
        # també seycon ens haurà de donar usuari/password.... mirar com els obté el mazinger.
        #ALERTA!: si hem entrat amb certificat l'usuari no ha ficat el codi d'usuari! L'hem d'obtenir via LDAP mitjaçant el modul PKCS11... l'hauria d'haver passat dins PAM_USER...        
        #xifrar_fitxers_credencials

#        if [ -f /home/$PAM_USER/.credentials.enc ];then
#                logger -t "linuxcaib-pam-auth($PAM_SERVICE-$PAM_USER)" "Desencriptant credentials"
#                #openssl aes-256-cbc -d -a -in .credentials.enc
#        fi


#Manera senzilla de xifrar el credentials amb la contrasenya de l'usuari
#        CREDFILE="
#username=$PAM_USER
#password=$PAM_AUTHTOK
#"
#echo $CREDFILE | openssl aes-256-cbc -a -salt -pass pass:$PAM_AUTHTOK  -out .credentials.enc
#Per desxifrar emprar:  openssl aes-256-cbc -d -a -in .credentials.enc     
        #if [ login_amb_certificat ];then
        #       if [ desxifratge_credentials.enc ];then

        #       else
                        #while ! CREDS_SEYCON_VALIDES;do 
                        #hem de demanar a l'usuari quin és el nou password
                        #introduir_nou_password
        #                        if [  credencials_valids_seycon ];then
        #                              CREDS_SEYCON_VALIDES=0  
        #                        if
                         #done

        #       fi
        #fi

        #Cream fitxer per l'identificador de sessió (Mazinger sessió)
           #     NOMFITX="MZN_SESSION"
            #    touch $TMPMEM/$PAM_USER/$NOMFITX
             #   chown $PAM_USER:$PAM_USER $TMPMEM/$PAM_USER/$NOMFITX
              #  chmod 600 $TMPMEM/$PAM_USER/$NOMFITX



