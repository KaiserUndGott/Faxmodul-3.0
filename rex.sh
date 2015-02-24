#!/bin/bash
################################################################
#
CLIENT_IP=192.168.179.20
CLIENT_PORT=6666
#
### Funktion für den REX-Server
################################################################
#
rex_server() 
{
echo "DAVCMD C:\david\test.cmd" | netcat $CLIENT_IP $CLIENT_PORT
}
#
#
### Aufruf des REX-Servers mit Umlenkung der Ausgabe
################################################################
#
rex_server | tee > temp
echo "Der REX-Server hat mit "`cat temp`" geantwortet"
#
### Die Batch-Datei "C:\david\test.cmd"
### enthält lediglich eine Zeile:
################################################################
#
# exit 3
#
################################################################
### Wobei die Zahl den Rückgabewert
### beschreibt und in der Linux-Konsole
### durch "echo $1" ausgegeben wird
################################################################