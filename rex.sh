### Script zum Testen der REX-Server Antwort
############################################
#
CLIENT_IP=192.168.179.20
CLIENT_PORT=6666
#
#
### und Los...
############################################
temp="/home/david/tmp"
echo 'DAVCMD C:\david\test.cmd' >$temp
netcat $CLIENT_IP $CLIENT_PORT <$temp
echo $1
#
#
### Die Batch-Datei "C:\david\test.cmd"
### enthält lediglich eine Zeile:
############################################
#
# exit 3
#
############################################
### Wobei die Zahl den Rückgabewert
### beschreibt und in der Linux-Konsole
### durch "echo $1" ausgegeben wird
############################################