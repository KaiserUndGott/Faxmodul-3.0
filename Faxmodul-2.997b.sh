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
# Ordner und Pfade:
#
WORD="/home/david/trpword"		# DV Standerd, moeglichst belassen!
WINLW="W:"				# DV Standard, moeglichst belassen!
#
#
# Arbeitsordner des Faxmoduls in $WORD, bitte mit OO-Config ablgleichen:
# Diese Ordner werden ggf. neu angelegt.
#
FAXDAT="faxablage"			# entsteht in $WORD
WORK="working"				# entsteht unterhalb $FAXDAT
FAIL="failed"				# entsteht unterhalb $FAXDAT
#
###############################################################################
#
# Trace fuer dieses Script:
#
LOGDATEI="00_Logdatei_Faxmodul.log"	# entsteht in $WORD
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
SENDCMD="C:\\david\\sendfax.wsf"
#
###############################################################################
###############################################################################
#
# Ende der Anpassungen
#
###############################################################################
###############################################################################







# Ab hier Finger weg!





# Weitere Definitionen zur spaeteren Verwendung:
# Linux Pfade:
FAXOUT="$WORD/$FAXDAT"
LWORK="$FAXOUT/$WORK"
LFAIL="$FAXOUT/$FAIL"
LOG="$FAXOUT/$LOGDATEI"
# Windows Pfade:
WFAXOUT="$WINLW\\$FAXDAT"
WWORK="$WINLW\\$FAXDAT\\$WORK"
WFAIL="$WINLW\\$FAXDAT\\$FAIL"






function_ende ()
{
  JETZT=`date` && echo "Ende: $JETZT" | tee -a $LOG
  echo "-----------------------------------------------------------------------------" >>$LOG
  #
  # Sofern $LOG >10MB, die aeltesten 25.000 Zeilen abschneiden:
  test $(stat -c %s $LOG) -gt 10485760 && sed -i 1,$25000d $LOG
  #
  unix2dos $LOG >/dev/null 2>&1
  [ -f "$LWORK/faxok" ] && rm -f $LWORK/faxok
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
if [ ! -e $FAXOUT ]; then
	mkdir -m 775 -p $FAXOUT
	INFO="Dieser wurde automatisch angelegt."
fi
echo "       Das Faxmodul verwendet '$FAXOUT' als Arbeitsordner. $INFO"
#
if [ ! -e $LWORK ]; then
	mkdir -m 775 -p $LWORK
	INFO="Dieser wurde automatisch angelegt."
fi
echo "       Verlaufsordner ist '$LWORK'. $INFO"
#
if [ ! -e $LFAIL ]; then
	mkdir -m 775 -p $LFAIL
	INFO="Dieser wurde automatisch angelegt."
fi
echo "       Verlorene Faxjobs liegen in '$LFAIL'. $INFO"





# Und los...
#
# Zu jedem PDF eine passende FNR Datei suchen:
for ITEM in `find $FAXOUT -maxdepth 1 -iname '*.pdf'`
do
        FAXFILE=$(basename $ITEM .pdf)
        FNRFILE="$FAXOUT/$FAXFILE.fnr"
	echo "       In Bearbeitung: '$ITEM'." | tee -a $LOG
	#
	if [ -f $FNRFILE ]; then
		# Ein gleichnamiges Dateipaar pdf & fnr wurde gefunden:
                #################################################################
                # Hier spaeter eine Function zur Analyse der Dateinameneinsetzen!
		mv -f $ITEM $FNRFILE $LWORK/
                #################################################################
		#
		### Umwandlung nach TIFF:
		gs -q -sDEVICE=tiffg4 -r600 -dBATCH -sPAPERSIZE=a4 -dPDFFitPage -dNOPAUSE \
                      -sOutputFile=$LWORK/$FAXFILE.tif $LWORK/$FAXFILE.pdf >/dev/null 2>&1
		#
		# Fehler beim Konvertieren?
		CHECK=`echo $?`
		if [ -f "$LWORK/$FAXFILE.tif" -a "${CHECK}" = "0" ]; then
			echo "       TIFF Konvertierung erfolgreich."
		else
			echo "   ### Fehler bei TIFF Konvertierung, Job wird verworfen." | tee -a $LOG
			mv -f $LWORK/$FAXFILE.pdf $LFAIL
			mv -f $LWORK/$FNRFILE $LFAIL/$FNRFILE.txt
			continue			
		fi
		#
		# FNR Datei korrekt?
		if [ -f "$LWORK/$FAXFILE.fnr" ]; then
			FAXNR=`cat $LWORK/$FAXFILE.fnr`
			echo "       Faxjob '$FAXFILE.tif' fuer Rufnummer '$FAXNR' wurde erstellt." | tee -a $LOG
		else
			echo "   ### Keine Faxummer fuer $LWORK/$FAXFILE.tif gefunden, Job wird verworfen." | tee -a $LOG
			mv -f $LWORK/$FAXFILE.tif $LFAIL
			continue		
		fi
		#
		# Ist der Rexserver am WinPC erreichbar?
		REXOK=`netcat -v -w 1 $WINPC $WINPORT >/dev/null 2>&1; echo $?`
		#
		if [ "$REXOK" = "0" ]; then
			# Job an das Windows Faxsystem uebergeben:
			[ -f "$LWORK/faxok" ] && rm -f $LWORK/faxok
			#
			echo "DAVCMD start /min $SENDCMD /filename:$WWORK\\$FAXFILE.tif /faxnumber:$FAXNR /server:$WINPC && set/p=<nul>$WWORK\\faxok" | netcat $FAXSRV $WINPORT >/dev/null
			# Erfolgsauswertung der Rexserver Uebergabe:
			sleep 2
			if [ -f "$LWORK/faxok" ]; then
				echo "   --> Faxjob wurde auf $WINPC an $SENDCMD uebergeben." | tee -a $LOG
				##############################################################
				# ACHTUNG: 
				# Korrekte Uebergabe an den Rexserver bedeutet NICHT, dass
				# die Bearbeitung dort geklappt hat!!
				# 
				# ToDo: Queue unter Linux erst leeren, wenn Bearbeitung auf
				# dem Faxserver OK war (->Function)
				rm -f $LWORK/*
				##############################################################
			else
				mv -f $LWORK/$FAXFILE.pdf $LFAIL >>$LOG 2>&1
				mv -f $LWORK/$FAXFILE.fnr $LFAIL >>$LOG 2>&1
				echo "   ### $SENDCMD hat einen Fehler ausgegeben, der Job wurde nach $LFAIL verschoben!" | tee -a $LOG
			fi
		else
			# Job zurueck in die Warteschlange stellen:
			mv -f $LWORK/$FAXFILE.fnr $FAXOUT
			mv -f $LWORK/$FAXFILE.pdf $FAXOUT
			rm -f $LWORK/$FAXFILE.tif
			echo "   ### Fehlerhafte Antwort des Rexservers an $WINPC erhalten, Versuch wird spaeter wiederholt." | tee -a $LOG
		fi
	else
		# keine FNR-Datei zum PDF gefunden (und nu?):
		echo "   ### Keine Faxnummer fuer '$ITEM' gefunden." | tee -a $LOG
		mv -f $ITEM $LFAIL >>$LOG 2>&1
		echo "       Das Dokument wurde in den Ordner $LFAIL verschoben." | tee -a $LOG
	fi
#
done


echo "       Keine weiteren Jobs in $FAXOUT gefunden." | tee -a $LOG
[ `find $LFAIL -type f  | wc -l` -gt "0" ] && echo "     ! Bitte '$LFAIL' pruefen !" | tee -a $LOG

function_ende
exit 0


