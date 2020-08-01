Option Explicit

Dim objRE
Dim tempEnv
Dim fso, folder, file, subFolder
Dim objShell 
Dim objFolder 
Dim objPath
Dim FileEx
Dim objWshShell  
Dim strCmdLine
Dim filepath
Dim flag
Dim jgd
Dim nodata
Dim yesno
Dim str
Dim inpstr
''''''''''''''
Dim prjtype	'���e�@�̃^�C�v idokeido(�ܓx�o�x)�AUTM�Aheimen(���ʒ��p���W)
Dim prj		'���e�@�̒�`�p�����[�^�[
Dim zone
Dim sh_flag	'�A�e�N���摜�쐬 0:�쐬���Ȃ� 1:�쐬����
Dim sh_scale    '�A�e�N���̐��������䗦 111120:�ܓx�o�x 1�FUTM�A���ʒ��p���W�n
''''''''''''''

MsgBox("2017/12/27�X�V�F"& vbCr & "���{���n�n2011(JGD2011)�ɑΉ����܂����BJGD2000��JGD2011�̃f�[�^�����݂�����ƕϊ��ł��Ȃ��̂Œ��ӂ��Ă��������B")


inpstr = InputBox("���e�@��I�����Ă��������B" & vbCrLf & "�ܓx�o�x�F0 UTM�F1 ���ʒ��p���W�F2",,"0")
If inpstr = "0" Then
 prjtype = "idokeido"
 sh_scale = 111120
ElseIf inpstr = "1" Then
 prjtype = "UTM"
 sh_scale = 1
ElseIf inpstr = "2" Then
 prjtype = "heimen"
 sh_scale = 1
Else
 MsgBox("���e�@�𐳂������͂��Ă��������B�I�����܂��B")
 WScript.Quit() 
End If

If prjtype = "UTM" Then
 zone = InputBox("UTM�̃]�[����I�����Ă��������B" & vbCrLf & "51�`56")
End If
If prjtype = "heimen" Then
 zone = InputBox("���ʒ��p���W�̌n�ԍ���I�����Ă��������B" & vbCrLf & "1�`19")
End If

sh_flag = 0

yesno = MsgBox("�A�e�N���}���쐬���܂����H", vbYesNo + vbQuestion)
If yesno = vbYes Then
 sh_flag = 1
Else
 sh_flag = 0
End If


		
'''''''''''''''''''''''''''''''''''''''''''''''''''''''''


Set objShell = WScript.CreateObject("Shell.Application")
Set fso = WScript.CreateObject("Scripting.FileSystemObject")
Set objWshShell = WScript.CreateObject("WScript.Shell")

'���ϐ��ݒ�
Set tempEnv = objWshShell.Environment("Process")
tempEnv.Item("GDAL_DATA") = "data"
tempEnv.Item("GDAL_FILENAME_IS_UTF8") = "YES"
tempEnv.Item("PROJ_LIB") = "proj"


Set objFolder = objShell.BrowseForFolder(0, "JPGIS(GML�`��)�̓����Ă���t�H���_��I�����Ă�������", 0)

If fso.FileExists(objFolder.Items.Item.Path & "\merge.tif") Then
    MsgBox("merge.tif�t�@�C�������݂��܂��B��ɏ������Ă��������B")
    WScript.Quit()
End If



If Not objFolder Is Nothing Then
 yesno = MsgBox("�C��̕W����I�����Ă��������B�͂� �� 0 ������ �� -9999", vbYesNo + vbQuestion)
 If yesno = vbYes Then nodata = 0 Else nodata = 1 

 Set folder = fso.GetFolder(objFolder.Items.Item.Path)


 'GeoTIF�ɕϊ�
 MsgBox("�ϊ���Ƃ��J�n���܂��B���b�Z�[�W���o��܂ł��҂����������B")
 Set objRE = CreateObject("VBScript.RegExp")
 objRE.Pattern = "^.*FG-GML.*xml$"
 
 jgd=""
 For Each file In folder.Files
    If objRE.Test(fso.GetFileName(file)) Then
	   strCmdLine = "dem.exe " & """" & objFolder.Items.Item.Path & "\" & file.Name & """" & " " & nodata
	   flag = objWshShell.Run(strCmdLine,7,True)
       If jgd="" Then
          jgd = flag
       End If
       If flag <> jgd Then
          MsgBox(file.Name&"�̑��n�n���قȂ��Ă���̂Ŋm�F���Ă��������B�I�����܂��B")
          WScript.Quit()
       End If
    End If  
 Next
 


prj=""

If prjtype = "idokeido" Then
 prj = 4612
End If
If prjtype = "UTM" And zone = "51" Then
 prj = 3097
End If
If prjtype = "UTM" And zone = "52" Then
 prj = 3098
End If
If prjtype = "UTM" And zone = "53" Then
 prj = 3099
End If
If prjtype = "UTM" And zone = "54" Then
 prj = 3100
End If
If prjtype = "UTM" And zone = "55" Then
 prj = 3101
End If
If prjtype = "UTM" And zone = "56" Then
 prj = 3102
End If

'''''''���ʒ��p���W
If prjtype = "heimen" And zone = "1" Then
prj = 2443
End If
If prjtype = "heimen" And zone = "2" Then
prj = 2444
End If
If prjtype = "heimen" And zone = "3" Then
prj = 2445
End If
If prjtype = "heimen" And zone = "4" Then
prj = 2446
End If
If prjtype = "heimen" And zone = "5" Then
prj = 2447
End If
If prjtype = "heimen" And zone = "6" Then
prj = 2448
End If
If prjtype = "heimen" And zone = "7" Then
prj = 2449
End If
If prjtype = "heimen" And zone = "8" Then
prj = 2450
End If
If prjtype = "heimen" And zone = "9" Then
prj = 2451
End If
If prjtype = "heimen" And zone = "10" Then
prj = 2452
End If
If prjtype = "heimen" And zone = "11" Then
prj = 2453
End If
If prjtype = "heimen" And zone = "12" Then
prj = 2454
End If
If prjtype = "heimen" And zone = "13" Then
prj = 2455
End If
If prjtype = "heimen" And zone = "14" Then
prj = 2456
End If
If prjtype = "heimen" And zone = "15" Then
prj = 2457
End If
If prjtype = "heimen" And zone = "16" Then
prj = 2458
End If
If prjtype = "heimen" And zone = "17" Then
prj = 2459
End If
If prjtype = "heimen" And zone = "18" Then
prj = 2460
End If
If prjtype = "heimen" And zone = "19" Then
prj = 2461
End If

If prj = "" Then
 MsgBox("���e�@�̃]�[���������͌n�ԍ��𐳂������͂��Ă��������B�I�����܂��B")
 WScript.Quit() 
End If

If prjtype="idokeido" And jgd="2011" Then
  prj = 6668
End If
If prjtype="UTM" And jgd="2011" Then
  prj = prj+3591
End If
If prjtype="heimen" And jgd="2011" Then
  prj = prj+4226
End If

prj = """" & "epsg:" & prj & """"



'���� �ܓx�o�x
strCmdLine = "gdalbuildvrt.exe -overwrite "  & """" & objFolder.Items.Item.Path & "\mergeLL.vrt" & """" & " " & """" & objFolder.Items.Item.Path & "\*.tif" & """"
flag = objWshShell.Run(strCmdLine,,True)

'�ϊ� prj
If nodata = 0 Then
   strCmdLine = "gdalwarp.exe -r bilinear -srcnodata None -t_srs " & prj & " """ & objFolder.Items.Item.Path & "\mergeLL.vrt" & """" & " " & """" & objFolder.Items.Item.Path & "\merge.tif" & """"
Else
   strCmdLine = "gdalwarp.exe -r bilinear -srcnodata -9999 -dstnodata -9999 -t_srs " & prj & " """ & objFolder.Items.Item.Path & "\mergeLL.vrt" & """" & " " & """" & objFolder.Items.Item.Path & "\merge.tif" & """"
End If

flag = objWshShell.Run(strCmdLine,,True)

'�A�e
 If sh_flag = 1 Then 
  strCmdLine = "gdaldem.exe hillshade -s " & sh_scale & " " & """" & objFolder.Items.Item.Path & "\merge.tif" & """" & " "  & """" & objFolder.Items.Item.Path & "\merge_shade.tif" & """"
  flag = objWshShell.Run(strCmdLine,,True)
 End If
 MsgBox("�ϊ��I�����܂����B")
 If flag <> 0 Then WScript.Quit() 
End If
