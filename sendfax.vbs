'for x = 0 to wscript.arguments.count - 1
'	if wscript.arguments(x) = "" then wscript.quit(0)
'next


if wscript.arguments.count <> 4 then
	wscript.echo "Usage: send_fax.vbs tiff_file recipient_fax_number subject recipient_name"
	wscript.quit 1
end if

set oShell = Wscript.CreateObject("WScript.Shell")

fax_file = wscript.arguments(0)
fax_recipient = wscript.arguments(1)
fax_subject =  wscript.arguments(2)
fax_recipient_name =  wscript.arguments(3)
' WICHTIG: Namen des Fax-Servers eingeben
fax_server = "DV-DC-FXSRV"
fax_sender_email = "Absender-Mail" 
fax_sender_name = "Absender-Name" 
fax_sender_fax_number = "0123456789"
' WICHTIG: Mail-Adresse für Sendebestätigung eingeben
fax_receipt_address = "***"


oShell.LogEvent	0, "File: " & fax_file & vbcrlf & "Recipient Fax No.: " & fax_recipient & vbcrlf & "Fax Subject: " & fax_subject & vbcrlf & _
							"Recipient Name: " & fax_recipient_name

Sub CheckError(strDetails) 
   Dim strErr 
   If Err.Number <> 0 then 
     strErr = strDetails & " : Exception " & Err.Description & " err.Number=0x" & Hex(Err.Number) 
	 ' echo ändern in log-Datei...
     WScript.Echo strErr 
     WScript.Quit(Err.Number) 
   End If 
End Sub 

On Error Resume Next 
Set FaxServer = WScript.CreateObject("FAXCOMEX.FaxServer") 
CheckError("WScript.CreateObject(FAXCOMEX.FaxServer)") 
'WScript.Echo "FaxServer created" 
'    Connect to the fax server. Specify computer name if the server is remote. See How to connect to a remote Fax Service for details. 
FaxServer.Connect fax_server
CheckError("FaxServer.Connect") 

Set FaxDoc = WScript.CreateObject("FAXCOMEX.FaxDocument") 
CheckError("WScript.CreateObject(FAXCOMEX.FaxDocument)")
'
'
'Set FaxOpt = FaxServer.ReceiptOptions
'CheckError("FaxServer.ReceiptOptions")

'FaxOpt.Refresh()
'CheckError("FaxOpt.Refresh()") 
'FaxOpt.AllowedReceipts = 1
'CheckError("FaxOpt.AllowedReceipts = 1")
'FaxOpt.SMTPSender = "***"
'FaxOpt.Save()
'CheckError("FaxOpt.Save()")

'    Set file name of any printable document. 
FaxDoc.Body = fax_file
CheckError("FaxDoc.Body") 
FaxDoc.DocumentName = fax_subject 
FaxDoc.Subject = fax_subject

'    Add recipient's fax number. If this string contains a canonical fax number 
'    (starting with plus + followed by a country code, an area code in round brackets 
'    surrounded by spaces and a fax number), the Fax Service will translate 
'    that number into dialable format in accordance with your current location. 
'    Otherwise, make sure the international prefix or long distance prefix is specified when needed, 
'    as the fax number will be passed on to a fax driver (Fax Service Provider) unchanged. 
'    For example, sending a fax from San Francisco to Sydney's fax number 123456, the canonical address 
'    +61 (2) 123456 will be translated into dialable address 011612123456. 
'    If you are using T37FSP in conjunction with Internet Fax Service, specify absolute address 
'    612123456 (without leading plus, to avoid translation into dialable format), 
'    as most Internet Fax Services expect the number in the absolute format. 
'    To take advantage of Windows Fax Service outbound routing available on Windows Server 
'    fax address must be specified in canonical format. 

Set FaxRecipient = FaxDoc.Recipients.Add(fax_recipient)
FaxRecipient.FaxNumber = fax_recipient
FaxRecipient.Name = fax_recipient_name

'    Optionally, set the sender properties. 
'    T37FSP uses only FaxDoc.Sender.Email in Windows Server 2003 for delivery status notifications. 
'    In Windows Server 2008, T37FSP derives email address from FaxDoc.Sender.Name via facsBridge.xml file. 


FaxDoc.Sender.Email = fax_sender_email 
FaxDoc.Sender.Name = fax_sender_name 
FaxDoc.Sender.FaxNumber = fax_sender_fax_number

'    Hier wird bestimmt was nach dem versenden passieren soll
'
FaxDoc.ReceiptAddress = fax_receipt_address
FaxDoc.ReceiptType = 1
FaxDoc.AttachFaxToReceipt = True


'    Optionally, Use FaxDoc.CoverPage and FaxDoc.CoverPageType to specify a cover page 
'    FaxDoc.CoverPage = generic 
'    FaxDoc.CoverPageType = 2 

'    Optionally, you can control banner in outbound faxes 
FaxServer.Folders.OutgoingQueue.Branding = False '    True to set banner on, False to set banner off 
FaxServer.Folders.OutgoingQueue.Save '      Make the change persistent 
'    Optionally, use FaxServer.Folders.OutgoingQueue.Retries and 
'    FaxServer.Folders.OutgoingQueue.RetryDelay to control retries 

'    Submit the document to the connected fax server and get back the job ID. 
JobID = FaxDoc.ConnectedSubmit(FaxServer) 
CheckError("FaxDoc.ConnectedSubmit") 
'WScript.Echo "FaxDoc.ConnectedSubmit success" 