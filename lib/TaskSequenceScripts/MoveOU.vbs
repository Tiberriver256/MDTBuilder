' //***************************************************************************
' //***************************************************************************
' // ***** Script Header *****
' //
' // Solution:  ConfigMgr
' // File:      MoveComputerToCorrectOU.vbs
' // Author:	Jakob Gottlieb Svendsen, Coretech A/S. http://blog.coretech.dk
' // Purpose:   Move computer to the correct OU that remains in variable MachineObjectOU
' //		Run inside TS after install
' //
' // Usage:     MoveComputerToCorrectOU.vbs
' //
' //
' // CORETECH A/S History:
' // 0.0.1	JGS 17/12/2009  Created initial version.
' // 0.0.2	MIP 17/03/2009 	Added feature to add argument to script
' // 0.0.3  JGS 02/12/2010  Changed to ADSystemInfo for the DN retrieval, instead of a homemade function.
' //						Thanks to Nico_ at Technet Forums
' //
' // Customer History:
' //
' // ***** End Header *****
' //***************************************************************************
'//----------------------------------------------------------------------------
'//  Main routines
'//----------------------------------------------------------------------------

On Error Resume Next

'Get MachineObjectOU Value
Set wshNetwork = CreateObject("WScript.Network")
Set oFso = CreateObject("Scripting.FileSystemObject")
Set objSysInfo = CreateObject( "ADSystemInfo" )
Set ArgObj = WScript.Arguments

'Use first argument as target OU
strMachineObjectOU = ArgObj(0)
strComputerDN = objSysInfo.ComputerName

nComma = InStr(strComputerDN,",")
strCurrentOU = Mid(strComputerDN,nComma+1)
strComputerName = Left(strComputerDN,nComma - 1)

'If current ou is different than target OU. Move object
If UCase(strCurrentOU) <> UCase(strMachineObjectOU) Then
	Set objNewOU = GetObject("LDAP://" & strMachineObjectOU)
	Set objMoveComputer = objNewOU.MoveHere("LDAP://" & strComputerDN, strComputerName)
End If 

'//----------------------------------------------------------------------------
'//  End Script
'//----------------------------------------------------------------------------