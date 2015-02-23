#!/bin/bash




###############################################################################
#
# Speedpoint Faxmodul Version 3.0 Vorversion
#
# Diess Modul nimmt Faxjobs aus der DATA VITAL OO-Schnittstelle
# entgegen und uebergibt sie an einen Windows PC mit Windows Faxdrucker.
#
# Bitte zur regelmaessigen Ausführung in die crontab eintragen!
#
# Script erfordert sendfax.wsf aufseiten des Windows PCs, siehe ganz unten.
#
# Speedpoint (FW) /HBU (TL), Stand: Februar 2015
#
###############################################################################




###############################################################################
###############################################################################
#
# Varaiblen, bitte anpassen:
#
###############################################################################
###############################################################################
#
# DV Faxablage, bitte im DV OpenOffice Setup entsprechend anpassen:
#
FAXOUT="/home/david/trpword/faxablage"
#
###############################################################################
#
# Trace fuer dieses Script:
#
LOG="$FAXOUT/00_Speedpoint_Faxmodul.log"
#
###############################################################################
#
# Windows Hostname (mit passender IP in die /etc/hosts eintragen!!)
#
WINPC="Win7PC"
#
###############################################################################
#
# Port des Rexservers am Windows PC (Firewall beachten!):
#
WINPORT="6667"
#
###############################################################################
#
# Pfad & Name des Scripts zum Faxversand auf dem Windows PC:
#
SENDCMD="C:\david\sendfax.wsf"
#
###############################################################################
###############################################################################
#
# Ende der Anpassungen
#
###############################################################################
###############################################################################







# Ab hier Finger weg!








function_ende ()
{
  JETZT=`date` && echo "Ende: $JETZT" | tee -a $LOG
  echo "-----------------------------------------------------------------------------" >>$LOG
  #
  # Sofern $LOG >10MB, die aeltesten 25.000 Zeilen abschneiden:
  test $(stat -c %s $LOG) -gt 10485760 && sed -i 1,$25000d $LOG
  #
  unix2dos $LOG >/dev/null 2>&1
  echo ""
}




# Trace anlegen und aktuellen Zeitpunkt eintragen:
echo ""
JETZT=`date` && echo "Speedpoint Faxmodul gestartet: $JETZT" | tee -a $LOG





# Kann der Windows Faxserver aufgeloest und erreicht werden?
FAXSRV=$(cat /etc/hosts | grep $WINPC | awk '{print $1}')

if [ "$FAXSRV" = "" ]; then
	echo "   ### ABBRUCH, '$WINPC' nicht in /etc/hosts gefunden!" | tee -a $LOG
	function_ende
	exit 1
else
	ping -c 2 $FAXSRV >>/dev/null
	PTEST=$(echo $?)
	#
	if [ ! "$PTEST" = "0" ]; then
		echo "   ### ABBRUCH: '$WINPC' nicht unter '$FAXSRV' erreichbar!" | tee -a $LOG
		function_ende
		exit 1
	fi
fi




# Existieren die Faxausgangsordner?
INFO=""
if [ ! -e $FAXOUT/working ]; then
	mkdir -m 775 -p $FAXOUT/working
	INFO="Dieser wurde automatisch angelegt."
fi
echo "Aktueller Arbeitsordner ist $FAXOUT/working. $INFO" | tee -a $LOG
#
if [ ! -e $FAXOUT/failed ]; then
	mkdir -m 775 -p $FAXOUT/failed
	INFO="Dieser wurde automatisch angelegt."
fi
echo "Aktueller Ordner fuer verlorene Faxjobs ist $FAXOUT/failed. $INFO" | tee -a $LOG




# Und los...
cd $FAXOUT
#
# Zu jedem PDF eine passende FNR Datei suchen:
for ITEM in `find -maxdepth 1 -iname '*.pdf'`
do
        FAXFILE=$(basename $ITEM .pdf)
        FNRFILE=$FAXFILE.fnr
	#
	if [ -f $FNRFILE ]; then
		# Ein gleichnamiges Dateipaar pdf & fnr gefunden:
		cp -n $ITEM $FNRFILE $FAXOUT/working ####################### cp noch ersetzen durch mv
		# Umwandlung nach TIFF:
		#gs -q -sDEVICE=tiffgray -r240 -dBATCH -sPAPERSIZE=a4 -dPDFFitPage -dNOPAUSE \
		gs -q -sDEVICE=tiffg4 -r600 -dBATCH -sPAPERSIZE=a4 -dPDFFitPage -dNOPAUSE \
                      -sOutputFile=working/$FAXFILE.tif working/$FAXFILE.pdf
		#
		FAXNR=`cat working/$FAXFILE.fnr`
		echo "   --> Faxjob '$FAXFILE.tif' fuer Rufnummer '$FAXNR' wurde erstellt." | tee -a $LOG		
#-----------------------------------------
		# Ist der Rexserver am WinPC erreichbar?
		REXOK=`netcat -v -w 1 $WINPC $WINPORT >/dev/null 2>&1; echo $?`
		#
		if [ "$REXOK" = "0" ]; then
			# Job an das Windows Faxsystem uebergeben:
			#echo "       Rexserver an $WINPC ist bereit." | tee -a $LOG
			echo "DAVCMD start /min $SENDCMD /filename:W:\faxablage\working\\$FAXFILE.tif /faxnumber:$FAXNR /server:$WINPC" | netcat $FAXSRV $WINPORT >/dev/null 
			sleep 3
			rm -f working/$FAXFILE.tif working/$FNRFILE
			echo "       Aktuellen Job an Faxserver uebergeben." | tee -a $LOG
			rm -f working/$FAXFILE.pdf
		else
			# Job zurueck in die Warteschlange stellen:
			mv -f working/$FNRFILE $FAXOUT
			rm -f working/$FAXFILE.tif
			echo "   ### Fehlerhafte Antwort des Rexservers an $WINPC erhalten, Versuch wird spaeter wiederholt." | tee -a $LOG
		fi
#-----------------------------------------
	else
		# keine FNR-Datei zum PDF gefunden (und nu?):
		echo "   ### Keine Faxnummer fuer '$FAXFILE' gefunden." | tee -a $LOG
		# cp -f $ITEM $FAXOUT/failed >>$LOG 2>&1 ####################### cp noch ersetzen durch mv
		echo "       Das Dokument wurde in den Ordner $FAXOUT/failed verschoben." | tee -a $LOG
	fi
done




function_ende
exit 0





###############################################################################
###############################################################################
#
# 'sendfax.wsf' Script des Win PCs: 
#
###############################################################################
###############################################################################

###   <job>
###   <runtime>
###   <description>Sends fax</description>
###   <named name="filename"
###   helpstring="Path and filename of printable file"
###   type="string" required="true" />
###   <named name="faxnumber"
###   helpstring="Fax number to dial"
###   type="string" required="true" />
###   <named name="server"
###   helpstring="Name of computer running Fax Service"
###   type="string" required="false" />
###   </runtime>
###   <script language="VBScript">
###   Set oDoc = CreateObject("FaXCOMEX.FaxDocument")
###   oDoc.Body = WScript.Arguments.Named("filename")
###   oDoc.Recipients.Add WScript.Arguments.Named("faxnumber")
###   oDoc.Submit WScript.Arguments.Named("server")
###   </script>
###   </job>

