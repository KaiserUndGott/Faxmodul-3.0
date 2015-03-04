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
# Dieses Script uebergibt ein TIFF Dokument sowie sieben Parameter an einen
# Windows Faxserver. FritzFax oder Windows Fax koennen angesteuert werden.
#
# Speedpoint (FW) /HBU (TL), Stand: März 2015
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
WWORK="$WINLW\\$FAXDAT\\$WORK"						###### Parameter 4 fuer Windows
WFAIL="$WINLW\\$FAXDAT\\$FAIL"






function_datname ()
{
  FXTEMP=$(mktemp /tmp/faxfelder.XXXXXXXXXX)
  #
  # Dateinamen in Bestandteile zerlegen (gem. DV-OO-Schema max. 6 Anteile):
  for I in {1..6}; do
	echo $FAXFILE | awk -F "_" '{print $'$I'}' >>$FXTEMP
  done
  #
  # Auswertung der Felder:
  # Parameter 1 fuer Windows (=Faxnr.) siehe weiter unten
  DATNAM="Unbekannt"							###### Parameter 2 fuer Windows
  PATNUM=`sed -n '2 p' $FXTEMP`						###### Parameter 3 fuer Windows
  TYP=`sed -n '1 p' $FXTEMP`
  #
  if [ "$TYP" = "patientbrief" ]; then
	DATNAM="Arztbrief"
	# Empfaenger ermitteln und ersten Buchstaben gross schreiben:
	EMPF=$(sed -n '3 p' $FXTEMP | sed -r 's/(\<[a-zA-Z])/\U\1/g') 	###### Parameter 6, nur fuer Windows
	ARZT=`sed -n '6 p' $FXTEMP`
	[  "$ARZT" = "" ] || ARZT=$(sed -n '4 p' $FXTEMP)		###### Parameter 7, nur fuer Windows
  fi
  #
  #::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
  echo "	+ Faxnummer:  $FAXNR"               | tee -a $LOG
  echo "	+ Dateiname:  $DATNAM"              | tee -a $LOG
  echo "	+ Pat.nummer: $PATNUM"              | tee -a $LOG
  echo "	+ Win Pfad:   $WWORK\\$FAXFILE.tif" | tee -a $LOG
  echo "	+ Dummy:      $DUMMY"               | tee -a $LOG
  echo "	+ Empfaenger: $EMPF"                | tee -a $LOG
  echo "	+ Arzt:       $ARZT"                | tee -a $LOG
  #::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
  #
  rm -f $FXTEMP
}





function_rexsend ()
{
  # Faxjob an den Windows Faxserver uebergeben:
  echo "DAVCMD start /min $SENDCMD /filename:$WWORK\\$FAXFILE.tif /faxnumber:$FAXNR /server:$WINPC" | netcat $FAXSRV $WINPORT
  #
  # Neue Parameter Reihenfolge:
  # echo "DAVCMD start /min $SENDCMD $FAXNR $DATNAM $PATNUM$ WWORK\\$FAXFILE.tif $DUMMY $EMPF " | netcat $FAXSRV $WINPORT
}





function_rexcheck ()
{
  # Rueckgabewert des Rexservers auswerten:
  echo "       Fehlerwert des REX-Servers: $ERROR"
  #
  case $ERROR in
	0)	echo "   --> Faxjob wurde korrekt an $SENDCMD auf $WINPC uebergeben." | tee -a $LOG
		REXFAIL=0
		;;
	1)	echo "   ### $SENDCMD auf $WINPC meldete Fehler 1. Rufen Sie die Polizei!" | tee -a $LOG
		;;
	2)	echo "   ### $SENDCMD auf $WINPC meldete Fehler 2. Legen Sie sich auf den Boden!" | tee -a $LOG
		;;
	3)	echo "   ### $SENDCMD auf $WINPC meldete Fehler 3. Beten Sie drei Rosenkränze!" | tee -a $LOG
		;;
	*)	echo "   ### $SENDCMD auf $WINPC meldete irgend einen Scheiss Fehler, weissjetztauchnich." | tee -a $LOG
		;;
  esac
  #
  rm -f $TEMP  
}





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





# Ist der Rexserver am WinPC erreichbar?
nc -w1 $WINPC $WINPORT
REXOK=$(echo $?)
#
if [ "${REXOK}" = "0" ]; then
	echo "       Verbindungstest zum Rexserver auf $WINPC erfolgreich." | tee -a $LOG
else
	echo "   ### ABBRUCH: Fehlerhafte Antwort des Rexservers an $WINPC erhalten (Code $REXOK)." | tee -a $LOG
	exit 1
fi





# Und los...






# $PATH ggf. anpassen, damit die Errorcode Auswertung des Rexserver Befehls klappt:
if [ `echo $PATH | awk -F ':' '{print $1}'` = "/home/david/bin" ]; then
	echo "       Umgebungsvariablen sind okay."
else
	PATH="/home/david/bin:$PATH"
	export PATH
	echo "       /home/david/bin wurde zu \$PATH hinzugefuegt."
fi





# Zu jedem PDF eine passende FNR Datei suchen:
for ITEM in `find $FAXOUT -maxdepth 1 -iname '*.pdf'`
do
        FAXFILE=$(basename $ITEM .pdf)
        FNRFILE="$FAXOUT/$FAXFILE.fnr"
	echo "       In Bearbeitung: '$ITEM'." | tee -a $LOG
	#
	if [ -f $FNRFILE ]; then
		# Ein gleichnamiges Dateipaar pdf & fnr wurde gefunden:
		function_datname
		mv -f $ITEM $FNRFILE $LWORK/
		#
		# Umwandlung nach TIFF:
		gs -q -sDEVICE=tiffg4 -r600 -dBATCH -sPAPERSIZE=a4 -dPDFFitPage -dNOPAUSE \
                      -sOutputFile=$LWORK/$FAXFILE.tif $LWORK/$FAXFILE.pdf >/dev/null 2>&1
		#
		# Fehler beim Konvertieren?
		CHECK=`echo $?`
		if [ -f "$LWORK/$FAXFILE.tif" -a "${CHECK}" = "0" ]; then
			echo "       TIFF Konvertierung erfolgreich."
			rm -f $LWORK/$FAXFILE.pdf
		else
			echo "   ### Fehler bei TIFF Konvertierung, Job wird verworfen." | tee -a $LOG
			mv -f $LWORK/$FAXFILE.pdf $LFAIL
			mv -f $LWORK/$FNRFILE $LFAIL/$FNRFILE.txt
			continue			
		fi
		#
		# FNR Datei korrekt?
		if [ -f "$LWORK/$FAXFILE.fnr" ]; then
			FAXNR=`cat $LWORK/$FAXFILE.fnr`				######## Parameter 1 fuer Windows
			echo "       Faxjob '$FAXFILE.tif' fuer Rufnummer '$FAXNR' wurde erstellt." | tee -a $LOG
		else
			echo "   ### Keine Faxummer fuer $LWORK/$FAXFILE.tif gefunden, Job wird verworfen." | tee -a $LOG
			mv -f $LWORK/$FAXFILE.tif $LFAIL
			continue		
		fi
		#
		TEMP=$(mktemp /tmp/rexwert.XXXXXXXXXX) 
		function_rexsend | tee >$TEMP
		ERROR=$(cat $TEMP)
		sleep 2
		#
		REXFAIL=1
		function_rexcheck
		#
		if [ ${REXFAIL} = "0" ]; then
			rm -f $LWORK/*
		else
			mv -f $LWORK/$FAXFILE.* $LFAIL
			echo "   ### Faxjob wurde nach $LFAIL verschoben."
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
[ `find $LFAIL -type f  | wc -l` -gt "0" ] && echo "   !!! Bitte '$LFAIL' pruefen !!!" | tee -a $LOG



function_ende
#########################################################################################################################
# FBW: kopiert zu Testzwecken immer wieder Jobs in die Queue:
cp -rvpf /home/david/Desktop/faxablage/* /home/david/trpword/faxablage/
#########################################################################################################################
echo ""
exit 0


