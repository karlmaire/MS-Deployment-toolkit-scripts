Const ForReading = 1
Const ForWriting = 2

Const FILE_SHARE          = 0 
Const MAXIMUM_CONNECTIONS = 4294967295 

On Error Resume Next
Set oShell = CreateObject("WScript.Shell")
SysDrive=oShell.ExpandEnvironmentStrings("%SystemDrive%")
Set WSHShell = CreateObject("WScript.Shell")
Set objFSO = CreateObject("Scripting.FileSystemObject")
Set objFileIn = objFSO.OpenTextFile(SysDrive & "\backedup_shares\shares.txt", ForReading)
Set colDrives = objFSO.Drives
Dim DrivesSNarray

DrivesSNarray = FileToArray(SysDrive & "\backedup_shares\drives_sn.list", False)

Do Until objFileIn.AtEndOfStream
	ProcessShare()
Loop

objFileIn.Close

Sub ProcessShare()

share_name = ""
share_path = ""
share_desc = ""

Do Until objFileIn.AtEndOfStream Or ((Len(share_name) > 0) And (Len(share_path) > 0) And (Len(share_desc) > 0))
	tmpline = objFileIn.ReadLine
	If (Len(tmpline) > 0) Then
		If (InStr(tmpline, "Share:") = 1) Then share_name = Right(tmpline, Len(tmpline) - Len("Share:"))
		If (InStr(tmpline, "Path:") = 1) Then share_path = Right(tmpline, Len(tmpline) - Len("Path:"))
		If (InStr(tmpline, "Desc:") = 1) Then share_desc = Right(tmpline, Len(tmpline) - Len("Desc:"))
	End If
Loop ' Считали все три параметра для создания общей папки - создаем

'Проверяем, не изменилась ли буква системного диска и если изменилась - подставляем новую
If (UCase(left(share_path, 2)) = WScript.Arguments(0)) And (WScript.Arguments(0) <> SysDrive) Then
	share_path = SysDrive & Right(share_path, Len(share_path) - Len("C:"))
End If

' Проверяем, не изменилась ли буква диска после развёртывания

drivesn = ""
OldDrvLetter = Left(share_path, 2)

For Each rrtmpline in DrivesSNarray
	If (InStr(rrtmpline, OldDrvLetter) = 1) Then
		drivesn = Right(rrtmpline, Len(rrtmpline) - Len(OldDrvLetter & " "))
	End If
Next

If (Len(drivesn) > 0) Then
	For Each objDrive in colDrives
		If objDrive.DriveType = 2 Then
			If (CStr(objDrive.SerialNumber) = drivesn) And (objFSO.FolderExists(objDrive.DriveLetter & Right(share_path, Len(share_path) - 1))) Then
				share_path = objDrive.DriveLetter & Right(share_path, Len(share_path) - 1)
			End If
		End If
	Next
End If

If ((Len(share_name) > 0) And (Len(share_path) > 0) And (Len(share_desc) > 0)) Then

	strComputer = "."
	Set objWMIService = GetObject("winmgmts:" & "{impersonationLevel=impersonate}!\\" & strComputer & "\root\cimv2")
	Set objNewShare = objWMIService.Get("Win32_Share")
	WScript.Echo ""
	WScript.Echo share_name & " (" & share_path & "):"
	errReturn = objNewShare.Create (share_path, share_name, FILE_SHARE, MAXIMUM_CONNECTIONS, share_desc)

	If errReturn = 0 Then
		' Создали общую папку, чистим дефолтные доступы
		WSHShell.Run SysDrive & "\backedup_shares\setacl.exe -ot shr -on """ & share_name & """ -actn trustee -trst ""n1:""ВСЕ"";ta:remtrst""", 1, True
		WSHShell.Run SysDrive & "\backedup_shares\setacl.exe -ot shr -on """ & share_name & """ -actn trustee -trst ""n1:""EVERYONE"";ta:remtrst""", 1, True

		Do
			trustee = ""
			perm = ""
			Do Until objFileIn.AtEndOfStream Or ((Len(trustee) > 0) And (Len(perm) > 0)) Or (Len(tmpline) < 2)
				tmpline = objFileIn.ReadLine
				If (Len(tmpline) > 0) Then
					If (InStr(tmpline, "Trustee:") = 1) Then trustee = Right(tmpline, Len(tmpline) - Len("Trustee:"))
					If (InStr(tmpline, "Right:") = 1) Then perm = Right(tmpline, Len(tmpline) - Len("Right:"))
				End If
			Loop ' Считали группу доступа и уровень доступа - применяем

			If ((Len(trustee) > 0) And (Len(perm) > 0)) Then
				If (InStr(UCase(trustee), "BUILTIN\") = 1) Then trustee = Right(trustee, Len(trustee) - Len("BUILTIN\"))
				If (perm = "FullControl") Then perm = "full"
				If (perm = "ReadAndExecute") Then perm = "read"
				If (perm = "Modify") Then perm = "change"
				WScript.Echo trustee & " - " & perm 
				WSHShell.Run SysDrive & "\backedup_shares\setacl.exe -ot shr -on """ & share_name & """ -actn ace -ace ""n:" & trustee & ";p:" & perm & ";m:set""", 1, True
			End If
		Loop Until (Len(tmpline) < 2) Or objFileIn.AtEndOfStream
	Else
		Select Case errReturn
			Case 2
				errText = "Access Denied"
			Case 8
				errText = "Unknown Problem"
			Case 9
				errText = "Invalid Name"
			Case 10
				errText = "Invalid Level"
			Case 21
				errText = "Invalid Parm"
			Case 22
				errText = "Share Already Exists"
			Case 23
				errText = "Redirected Path"
			Case 24
				errText = "Missing Folder"
			Case 25
				errText = "Missing Server"
			Case Else
				errText = "Operation could not be completed"
		End Select
		WScript.Echo "Error while creating shared folder " & share_name & "! Error code:" & errReturn & " - " & errText
	End If

End If

End Sub

Function FileToArray(ByVal strFile, ByVal blnUNICODE)
  Const FOR_READING = 1
  Dim objFSO, objTS, strContents
  FileToArray = Split("")
  Set objFSO = CreateObject("Scripting.FileSystemObject")
  If objFSO.FileExists(strFile) Then
    On Error Resume Next
    Set objTS = objFSO.OpenTextFile(strFile, FOR_READING, False, blnUNICODE)
    If Err = 0 Then
      strContents = objTS.ReadAll
      objTS.Close
      FileToArray = Split(strContents, vbNewLine)
    End If
  End If
End Function

'Производим замену в списке ACL, если сменилась буква системного диска
Set objFileACL = objFSO.OpenTextFile(SysDrive & "\backedup_shares\acllist.lca", ForReading)
strText = objFileACL.ReadAll
objFileACL.Close
strNewText = Replace(strText, WScript.Arguments(0), SysDrive)
Set objFileACL = objFSO.OpenTextFile(SysDrive & "\backedup_shares\acllist.lca", ForWriting)
objFileACL.Write strNewText
objFileACL.Close
