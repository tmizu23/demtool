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
Dim prjtype	'投影法のタイプ idokeido(緯度経度)、UTM、heimen(平面直角座標)
Dim prj		'投影法の定義パラメーター
Dim zone
Dim sh_flag	'陰影起伏画像作成 0:作成しない 1:作成する
Dim sh_scale    '陰影起伏の水平垂直比率 111120:緯度経度 1：UTM、平面直角座標系
''''''''''''''

MsgBox("2017/12/27更新："& vbCr & "日本測地系2011(JGD2011)に対応しました。JGD2000とJGD2011のデータを混在させると変換できないので注意してください。")


inpstr = InputBox("投影法を選択してください。" & vbCrLf & "緯度経度：0 UTM：1 平面直角座標：2",,"0")
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
 MsgBox("投影法を正しく入力してください。終了します。")
 WScript.Quit() 
End If

If prjtype = "UTM" Then
 zone = InputBox("UTMのゾーンを選択してください。" & vbCrLf & "51～56")
End If
If prjtype = "heimen" Then
 zone = InputBox("平面直角座標の系番号を選択してください。" & vbCrLf & "1～19")
End If

sh_flag = 0

yesno = MsgBox("陰影起伏図を作成しますか？", vbYesNo + vbQuestion)
If yesno = vbYes Then
 sh_flag = 1
Else
 sh_flag = 0
End If


		
'''''''''''''''''''''''''''''''''''''''''''''''''''''''''


Set objShell = WScript.CreateObject("Shell.Application")
Set fso = WScript.CreateObject("Scripting.FileSystemObject")
Set objWshShell = WScript.CreateObject("WScript.Shell")

'環境変数設定
Set tempEnv = objWshShell.Environment("Process")
tempEnv.Item("GDAL_DATA") = "data"
tempEnv.Item("GDAL_FILENAME_IS_UTF8") = "NO"


Set objFolder = objShell.BrowseForFolder(0, "JPGIS(GML形式)の入っているフォルダを選択してください", 0)

If fso.FileExists(objFolder.Items.Item.Path & "\merge.tif") Then
    MsgBox("merge.tifファイルが存在します。先に消去してください。")
    WScript.Quit()
End If



If Not objFolder Is Nothing Then
 yesno = MsgBox("海域の標高を選択してください。はい → 0 いいえ → -9999", vbYesNo + vbQuestion)
 If yesno = vbYes Then nodata = 0 Else nodata = 1 

 Set folder = fso.GetFolder(objFolder.Items.Item.Path)


 'GeoTIFに変換
 MsgBox("変換作業を開始します。メッセージが出るまでお待ちください。")
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
          MsgBox(file.Name&"の測地系が異なっているので確認してください。終了します。")
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

'''''''平面直角座標
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
 MsgBox("投影法のゾーンもしくは系番号を正しく入力してください。終了します。")
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



'結合 緯度経度
strCmdLine = "gdalbuildvrt.exe -overwrite "  & """" & objFolder.Items.Item.Path & "\mergeLL.vrt" & """" & " " & """" & objFolder.Items.Item.Path & "\*.tif" & """" 
flag = objWshShell.Run(strCmdLine,,True)

'変換 prj
If nodata = 0 Then
   strCmdLine = "gdalwarp.exe -r bilinear -srcnodata None -t_srs " & prj & " """ & objFolder.Items.Item.Path & "\mergeLL.vrt" & """" & " " & """" & objFolder.Items.Item.Path & "\merge.tif" & """" 
Else
   strCmdLine = "gdalwarp.exe -r bilinear -srcnodata -9999 -dstnodata -9999 -t_srs " & prj & " """ & objFolder.Items.Item.Path & "\mergeLL.vrt" & """" & " " & """" & objFolder.Items.Item.Path & "\merge.tif" & """" 
End If
flag = objWshShell.Run(strCmdLine,,True)

'陰影
 If sh_flag = 1 Then 
  strCmdLine = "gdaldem.exe hillshade -s " & sh_scale & " " & """" & objFolder.Items.Item.Path & "\merge.tif" & """" & " "  & """" & objFolder.Items.Item.Path & "\merge_shade.tif" & """"
  flag = objWshShell.Run(strCmdLine,,True)
 End If
 MsgBox("変換終了しました。")
 If flag <> 0 Then WScript.Quit() 
End If
