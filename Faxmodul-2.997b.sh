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
# Speedpoint (FW), Stand: Februar 2015
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
FAXOUT="/home/david/trpword/fax"
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
WINPC="DV-DC-FXSRV"
#
###############################################################################
#
# Port des Rexservers am Windows PC (Firewall beachten!):
#
WINPORT="6666"
#
###############################################################################
#
# Pfad & Name des Scripts zum Faxversand auf dem Windows PC:
#
SENDCMD="C:\david\sendfax.vbs"
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
		###
		### +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
		###
		### Empfänger festlegen
		###
		#################################################################################
		### Hinweis: Vorraussetzung hierfür ist die Dateinamenskonvention der 
		###          OpenOffice Schnittstelle.
		###          Dies muss ggf. auch für den Cups-Drucker beachtet werden
		#################################################################################
		FAXFILENF=`ls $FAXFILE.fnr | awk -F "_" '{print NF}'`
		if [ "$FAXFILENF" == "6" ]; then
			FAXEMPF=`ls $FAXFILE.fnr | awk -F "_" '{print $3"-"$4}'`
		else
			FAXEMPF=`ls $FAXFILE.fnr | awk -F "_" '{print $3}'`
		fi
		###
		### Prüfen ob Empfänger "Leer" ist und auf "Unbekannt" setzen
		###
		if [ "$FAXEMPF" == "" ]; then
			FAXEMPF="Unbekannt"
		fi
		echo "   --> Der Empfaenger ist: $FAXEMPF" | tee -a $LOG
		###
		### Betreff festlegen
		###
		FAXBETR=`ls $FAXFILE.fnr | awk -F "_" '{print $1"-"$2}'`
		echo "   --> Der Betreff ist: $FAXBETR" | tee -a $LOG
		###
		### Es wird geprüft ob ein Dokument aus dem Pat-Ordner versendet werden soll
		###
		pdftotext $ITEM
		TXTFILE=$FAXFILE.txt
		SENDDOC=`cat $TXTFILE | grep '@@Send-DOC@@'`
		if [ "$SENDDOC" == "@@Send-DOC@@" ]; then
			DOCPATH=`cat $TXTFILE | grep '@@DOC-Path@@' | awk -F "@@" '{print $3}'`
			DOCNAME=`cat $TXTFILE | grep '@@DOC-Name@@' | awk -F "@@" '{print $3}'`
			#############################################################################
			### ToDo Prüfen ob datei vorhanden ist, sonst Abbruch
			#############################################################################
			###
			### Datei aus Pat-Ordner wird kopiert und umbenannt
			###
			cp -n $DOCPATH/"$DOCNAME" $FAXOUT/working
			DOCNAME=`echo $DOCNAME | awk -F "/" '{print $NF}'`  ### entfernt ggf vorangestellte Verzeichnisse
			mv $FAXOUT/working/"$DOCNAME" $FAXOUT/working/$FAXFILE.pdf  
			rm -f $ITEM	$TXTFILE	### Übergabedatei wir aus $FAXOUT gelöscht
			mv $FNRFILE $FAXOUT/working
		else
		###
		### -----------------------------------------------------------------------------
		###
			mv $ITEM $FNRFILE $FAXOUT/working
			rm -f $TXTFILE
		fi
		### Umwandlung nach TIFF:
		###gs -q -sDEVICE=tiffgray -r240 -dBATCH -sPAPERSIZE=a4 -dPDFFitPage -dNOPAUSE 
		gs -q -sDEVICE=tiffg4 -r600 -dBATCH -sPAPERSIZE=a4 -dPDFFitPage -dNOPAUSE \
		-sOutputFile=working/$FAXFILE.tif working/$FAXFILE.pdf
		#################################################################################
		### Hinweis: Bei dem convert Befehl wird die erzeugte Datei zu groß
		###          Mit dieser Größe kann Windows Fax dann nicht mehr umgehen
		###          und macht daraus ein schwarzes Blatt (ca. halbe A4 Seite)
		###
		###          convert working/$FAXFILE.pdf working/$FAXFILE.tif
		#################################################################################
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
			WINPATH=`echo $FAXOUT | awk -F "/" '{print $NF}'`     
			#############################################################################
			### ToDo "WINPATH" ggf an anderer stelle + Variable für LW-Buchstaben
			#############################################################################
			echo "DAVCMD start /min $SENDCMD W:\\$WINPATH\working\\$FAXFILE.tif $FAXNR $FAXBETR $FAXEMPF" | netcat $FAXSRV $WINPORT >/dev/null 
			echo "Bitte warten..."
			sleep 5
			rm -f working/$FAXFILE.tif working/$FNRFILE working/$FAXFILE.pdf
			#############################################################################
			### ToDo Übermittlung durch eine Batch auf Windows-Seite ersetzen,
			###      da der Rexserver wartet bis die Batch beendet ist und somit der 
			###      sleep Befehl ausgelassen werden kann...
			#############################################################################
			echo "       Aktuellen Job an Faxserver uebergeben." | tee -a $LOG
		else
			# Job zurueck in die Warteschlange stellen:
			mv -f working/$FNRFILE $FAXOUT
			mv -f working/$FAXFILE.pdf $FAXOUT
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


