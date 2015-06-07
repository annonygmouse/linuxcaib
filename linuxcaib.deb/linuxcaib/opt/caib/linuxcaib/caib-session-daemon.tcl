#!/usr/bin/tclsh 
#Script TCL que obri connexió al port proporcionat i escolta els missatges que li arriben
#Emprat per respondre a les peticions "WHO" del seycon per mantenir la sessió oberta.

#Mostrar alertes en rebre la comanda "ALERT"
#TODO: També hauria de tancar la sessió en notificar-li... 

#Codi tret de: http://wiki.tcl.tk/15315

#COMPROVAR: afegir codi usuari dins nom log

#puts "env_USER:  $::env(USER)"
set logchan [open /tmp/caib-session-daemon-$::env(USER).log a]


if { $argc != 3 } {
        puts "caib-session-daemon.tcl necessita tres parametres, el port on escoltar, el session id del mazinger i el seycon_session_id."
} else {
        puts $logchan "Port emprat: [lindex $argv 0] session_id: [lindex $argv 1] seyconsessionid: [lindex $argv 2] "
        puts $logchan "Log emprat: /tmp/caib-session-daemon.log"
        set ssoport [lindex $argv 0]
        set mazingerid [lindex $argv 1]
        set seyconsessionid [lindex $argv 2] 
}

close stdin
close stdout
close stderr

#puts " $ssoport la cadena: $mazingerid"

set systemTime [clock seconds]

#puts "The time is: [clock format $systemTime -format %H:%M:%S]"
#puts "The date is: [clock format $systemTime -format %D]"
#puts [clock format $systemTime -format {Today is: %A, the %d of %B, %Y}]
#puts "\n the default format for the time is: [clock format $systemTime]\n"

proc accept {chan addr port} {           ;# Make a proc to accept connections
     global mazingerid
     global ssoport
     global logchan
     global seyconsessionid
     set systemTime [clock seconds]
     set entrada [gets $chan]
     puts $logchan "[clock format $systemTime] $addr:$port says $entrada\n" ;# Receive a string
#Mirar que hem rebut del servidor si és el correcte, tornar el mazingerid
     flush $logchan
     set accio [string range $entrada 0 [expr {[string first " " $entrada] - 1 }]]
     set contingutAccio [string range $entrada [expr {[string first " " $entrada] + 1}] end]
     if { $entrada == "WHO" } {
            puts $logchan "Enviam la cadena: $mazingerid\n"
            puts $chan "$mazingerid\n"                   ;# Send a string
     } else {
             puts $logchan  "Accio: -$accio-"
             switch -nocase $accio {
                    "ALERT"  {  
                                #Missatge de intent de login a una altra maquina: En la máquina epreinf41(10.215.2.17): se han identificado con su código de usuario. No se le permitirá el acceso hasta que cierre la sesión actual
                                puts $logchan "Es una alerta! MOSTRAR! $contingutAccio"
                                set err_alert [ catch { exec zenity --timeout 20 --warning --text "$contingutAccio\n\nAquest missatge se tancara en 20 segons"} resultat_alert]
                             }
                    "KEY"  {  
                                puts $logchan "TODO: Es una peticio de actualització de secrets! ($contingutAccio)"
                           }
                    "APP"  {  
                                puts $logchan "TODO: Es una peticio de permissos a aplicació! ($contingutAccio)"
                           }
                    "LOGOUT"  {  
                                puts $logchan "Rebuda petició de logout!"
                                 if { $contingutAccio == $seyconsessionid } {
                                        puts $logchan "Rebuda petició de logout!"
     					flush $logchan
                                        set err_alert [ catch { exec zenity --timeout 20 --warning --text "ALERTA: Rebuda petició de logout.\n\nES TANCARÀ LA SESSIÓ EN 20 SEGONS, desau els documents que estigueu emprant" &} resultat_alert]
                                        puts $logchan "TODO: HEM DE FER LOGOUT per ara només tancam aquest procés, hauriem de fer sessionlogout"
     					flush $logchan
					close $chan
					close $logchan
					exit 
                                 } else {
                                        puts $logchan "Hem rebut petició de logout però l'identificador de sessió de seycon enviat ($contingutAccio) NO es igual al que tenim actualment ($seyconsessionid)" 
                                 }
#Si el $contingutAccio = /var/run/shm/u83511/u83511_seycon_session_key hem de fer logout!
                           }

                    "" {
                                #Acció sense paràmetre el valor està dins $contingutAccio
                                 switch -nocase $contingutAccio {
                                            "VNC"  {  puts $logchan "Es una peticio de acces via VNC (vino)!"
                                                      set err_alert [ catch { exec caib-vnc &} resultat_vnc]
                                                   }
                                            "VNC2"  {  puts $logchan "Es una peticio de acces via VNC2 (x11vnc)!"
                                                      set err_alert [ catch { exec caib-vnc2 &} resultat_vnc]
                                                   }
					                        close $logchan
					    default {
                                                puts $logchan "ContingutAccio ($contingutAccio) desconeguda"
                                                    }
                                }
                        }
                    default {
                                puts $logchan "Accio ($accio) desconeguda amb contingut ($contingutAccio)"
                            }
             }
     }
     close $chan                          ;# Close the socket (automatically flushes)
     flush $logchan
 }                                        ;#
socket -server accept $ssoport              ;# Create a server socket
vwait forever
