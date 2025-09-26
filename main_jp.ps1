# Japanese main script (以前の 変換結合.ps1 をインライン化)
<#
基盤地図情報 標高DEM 変換+結合 PowerShell版
Original: 変換結合.vbs
Integrated date: 2025-08-19 (inlined former 変換結合.ps1)
#>

[CmdletBinding()]
param()

# --- ダブルクリック起動対応 (STA で再起動) ------------------------------
if([System.Threading.Thread]::CurrentThread.ApartmentState -ne 'STA'){
	$argsList = @('-NoProfile','-ExecutionPolicy','Bypass','-STA','-File',"$PSCommandPath")
	Start-Process -FilePath powershell.exe -ArgumentList $argsList -WorkingDirectory (Split-Path -Parent $PSCommandPath)
	return
}
try { [Console]::OutputEncoding = [System.Text.Encoding]::UTF8 } catch {}

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName Microsoft.VisualBasic

# --- 常に前面に出る不可視オーナーフォーム（メッセージボックスが背面に行く問題対策） ---
$script:TopOwner = New-Object System.Windows.Forms.Form
$TopOwner.ShowInTaskbar = $false
$TopOwner.FormBorderStyle = 'FixedToolWindow'
$TopOwner.Opacity = 0
$TopOwner.TopMost = $true
$TopOwner.StartPosition = 'Manual'
$TopOwner.Size = [Drawing.Size]::new(1,1)
$TopOwner.Location = [Drawing.Point]::new(-2000,-2000) # 画面外
$TopOwner.Show() | Out-Null

function Show-Info($msg){ [System.Windows.Forms.MessageBox]::Show($TopOwner,$msg,'情報',[Windows.Forms.MessageBoxButtons]::OK,[Windows.Forms.MessageBoxIcon]::Information) | Out-Null }
function Show-Error($msg){ [System.Windows.Forms.MessageBox]::Show($TopOwner,$msg,'エラー',[Windows.Forms.MessageBoxButtons]::OK,[Windows.Forms.MessageBoxIcon]::Error) | Out-Null }
function Ask-YesNo($msg){
	$TopOwner.Activate() | Out-Null
	$res = [System.Windows.Forms.MessageBox]::Show($TopOwner,$msg,'確認',[System.Windows.Forms.MessageBoxButtons]::YesNo,[System.Windows.Forms.MessageBoxIcon]::Question)
	return ($res -eq [System.Windows.Forms.DialogResult]::Yes)
}
function Ask-Input($msg,$default=''){
	$TopOwner.Activate() | Out-Null
	# VB の InputBox はオーナー指定できないため直前にアクティブ化
	return [Microsoft.VisualBasic.Interaction]::InputBox($msg,'入力',$default)
}

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location $scriptDir

function Use-AsciiPathFallback {
	param([string]$ScriptDir)
	if($ScriptDir -notmatch '[^\x00-\x7f]') { return $null }
	$fallbackRoot = Join-Path $env:TEMP 'demtool_ascii'
	$projSrc = Join-Path $ScriptDir 'proj'
	$dataSrc = Join-Path $ScriptDir 'data'
	$projDst = Join-Path $fallbackRoot 'proj'
	$dataDst = Join-Path $fallbackRoot 'data'
	try {
		if(Test-Path $fallbackRoot){ Remove-Item $fallbackRoot -Recurse -Force -ErrorAction SilentlyContinue }
		New-Item -ItemType Directory -Path $fallbackRoot | Out-Null
		if(Test-Path $projSrc){ Copy-Item $projSrc $projDst -Recurse -Force }
		if(Test-Path $dataSrc){ Copy-Item $dataSrc $dataDst -Recurse -Force }
		return @{ Root=$fallbackRoot; Proj=$projDst; Data=$dataDst }
	} catch { return $null }
}

${_asciiInfo} = Use-AsciiPathFallback -ScriptDir $scriptDir

trap {
	Show-Error ("未処理エラー:`n" + $_.Exception.Message)
	break
}

if(${_asciiInfo}){ $env:GDAL_DATA = ${_asciiInfo}.Data; $env:PROJ_LIB  = ${_asciiInfo}.Proj } else { $env:GDAL_DATA = Join-Path $scriptDir 'data'; $env:PROJ_LIB  = Join-Path $scriptDir 'proj' }
$env:GDAL_FILENAME_IS_UTF8 = 'YES'

Show-Info "2025/09/26更新: JGD2000(EPSGコード)、JGD2011(EPSGコード)、JGD2024(WKT定義)に対応しています。異なる測地系のデータを混在させないでください。"

$prjTypeInput = Ask-Input "投影法を選択してください。`r`n緯度経度:0  UTM:1  平面直角座標:2" '0'
switch($prjTypeInput){
	'0' { $prjType='idokeido'; $shadeScale=111120 }
	'1' { $prjType='UTM';      $shadeScale=1 }
	'2' { $prjType='heimen';   $shadeScale=1 }
	default { Show-Error '投影法を正しく入力してください。終了します。'; return }
}

$zone = ''
if($prjType -eq 'UTM'){ $zone = Ask-Input 'UTMのゾーンを選択してください。 51～56' }
elseif($prjType -eq 'heimen'){ $zone = Ask-Input '平面直角座標の系番号を選択してください。 1～19' }

$shadeFlag = if(Ask-YesNo '陰影起伏図を作成しますか?'){1}else{0}

$dlg = New-Object System.Windows.Forms.FolderBrowserDialog
$dlg.Description = 'JPGIS(GML形式)の入っているフォルダを選択してください'
if($dlg.ShowDialog() -ne [System.Windows.Forms.DialogResult]::OK){ return }
$targetDir = $dlg.SelectedPath

$mergeTif = Join-Path $targetDir 'merge.tif'
if(Test-Path $mergeTif){ Show-Error 'merge.tif が既に存在します。先に削除してください。'; return }

$nodataFlag = if(Ask-YesNo '海域の標高を選択してください。はい→0  いいえ→-9999'){0}else{1}

Show-Info '変換作業を開始します。しばらくお待ちください。'

$demExe = Join-Path $scriptDir 'dem.exe'
if(-not (Test-Path $demExe)){ Show-Error 'dem.exe が見つかりません。'; return }

$xmlFiles = Get-ChildItem -Path $targetDir -Filter '*FG-GML*.xml' -File -ErrorAction SilentlyContinue
if(-not $xmlFiles){ Show-Error '対象となる *FG-GML*.xml ファイルが見つかりません。'; return }

$jgd = $null
foreach($f in $xmlFiles){
	$argLine = '"{0}" {1}' -f $f.FullName, $nodataFlag
	$p = Start-Process -FilePath $demExe -ArgumentList $argLine -NoNewWindow -Wait -PassThru
	$code = $p.ExitCode
	if(-not $jgd){ $jgd = $code }
	elseif($code -ne $jgd){ Show-Error "$($f.Name) の測地系が異なります (期待: $jgd, 実際: $code)。終了します。"; return }
}

$prj = $null
if($prjType -eq 'idokeido'){ $prj = 4612 }
elseif($prjType -eq 'UTM'){
	$utmMap = @{ '51'=3097; '52'=3098; '53'=3099; '54'=3100; '55'=3101; '56'=3102 }
	if($utmMap.ContainsKey($zone)){ $prj = $utmMap[$zone] }
}
elseif($prjType -eq 'heimen'){
	$heimenMap = @{'1'=2443;'2'=2444;'3'=2445;'4'=2446;'5'=2447;'6'=2448;'7'=2449;'8'=2450;'9'=2451;'10'=2452;'11'=2453;'12'=2454;'13'=2455;'14'=2456;'15'=2457;'16'=2458;'17'=2459;'18'=2460;'19'=2461}
	if($heimenMap.ContainsKey($zone)){ $prj = $heimenMap[$zone] }
}
if(-not $prj){ Show-Error '投影法のゾーン/系番号が不正です。終了します。'; return }

if($jgd -eq 2011){ switch($prjType){ 'idokeido' { $prj = 6668 }; 'UTM' { $prj += 3591 }; 'heimen' { $prj += 4226 } } }
elseif($jgd -eq 2024){
	# JGD2024対応（WKT定義使用）
	switch($prjType){
		'idokeido' { $prj = 'JGD2024_GEOG' }
		'UTM' { $prj = "JGD2024_UTM_$zone" }
		'heimen' { $prj = "JGD2024_PLANE_$zone" }
	}
}
# JGD2024座標系のWKT定義を設定
if($prj -eq 'JGD2024_GEOG'){
	# JGD2024地理座標系
	$prjArg = 'GEOGCS["JGD2024",DATUM["Japanese_Geodetic_Datum_2024",SPHEROID["GRS_1980",6378137.0,298.257222101],AUTHORITY["EPSG","7019"]],PRIMEM["Greenwich",0.0,AUTHORITY["EPSG","8901"]],UNIT["Degree",0.0174532925199433,AUTHORITY["EPSG","9122"]]]'
}elseif($prj -match '^JGD2024_UTM_(\d+)$'){
	# JGD2024 UTM座標系
	$utmZone = [int]$Matches[1]
	if($utmZone -ge 51 -and $utmZone -le 56){
		$centralMeridian = ($utmZone * 6) - 183
		$prjArg = "PROJCS[`"JGD_2024_UTM_Zone_${utmZone}N`",GEOGCS[`"GCS_JGD_2024`",DATUM[`"D_JGD_2024`",SPHEROID[`"GRS_1980`",6378137.0,298.257222101]],PRIMEM[`"Greenwich`",0.0],UNIT[`"Degree`",0.0174532925199433]],PROJECTION[`"Transverse_Mercator`"],PARAMETER[`"False_Easting`",500000.0],PARAMETER[`"False_Northing`",0.0],PARAMETER[`"Central_Meridian`",$centralMeridian.0],PARAMETER[`"Scale_Factor`",0.9996],PARAMETER[`"Latitude_Of_Origin`",0.0],UNIT[`"Meter`",1.0]]"
	}else{
		Show-Error "不正なUTMゾーン番号: $utmZone （51-56のみ対応）"; return
	}
}elseif($prj -match '^JGD2024_PLANE_(\d+)$'){
	# JGD2024平面直角座標系
	$planeZone = [int]$Matches[1]

	# 各系の中央経線と原点緯度
	$planeParams = @{
		1=@{lat=33.0; lon=129.5}; 2=@{lat=33.0; lon=131.0}; 3=@{lat=36.0; lon=132.166666666667}
		4=@{lat=33.0; lon=133.5}; 5=@{lat=36.0; lon=134.333333333333}; 6=@{lat=36.0; lon=136.0}
		7=@{lat=36.0; lon=137.166666666667}; 8=@{lat=36.0; lon=138.5}; 9=@{lat=36.0; lon=139.833333333333}
		10=@{lat=40.0; lon=140.833333333333}; 11=@{lat=44.0; lon=140.25}; 12=@{lat=44.0; lon=142.25}
		13=@{lat=44.0; lon=144.25}; 14=@{lat=26.0; lon=142.0}; 15=@{lat=26.0; lon=127.5}
		16=@{lat=26.0; lon=124.0}; 17=@{lat=26.0; lon=131.0}; 18=@{lat=20.0; lon=136.0}; 19=@{lat=26.0; lon=154.0}
	}

	if($planeParams.ContainsKey($planeZone)){
		$p = $planeParams[$planeZone]
		$prjArg = "PROJCS[`"JGD2024_Japan_Zone_$planeZone`",GEOGCS[`"JGD2024`",DATUM[`"Japanese_Geodetic_Datum_2024`",SPHEROID[`"GRS_1980`",6378137.0,298.257222101]],PRIMEM[`"Greenwich`",0.0],UNIT[`"Degree`",0.0174532925199433]],PROJECTION[`"Transverse_Mercator`"],PARAMETER[`"False_Easting`",0.0],PARAMETER[`"False_Northing`",0.0],PARAMETER[`"Central_Meridian`",$($p.lon)],PARAMETER[`"Scale_Factor`",0.9999],PARAMETER[`"Latitude_Of_Origin`",$($p.lat)],UNIT[`"Meter`",1.0]]"
	}else{
		Show-Error "不正な平面直角座標系番号: $planeZone"; return
	}
}else{
	$prjArg = "epsg:$prj"
}

$gdalbuildvrt = Join-Path $scriptDir 'gdalbuildvrt.exe'
$gdalwarp     = Join-Path $scriptDir 'gdalwarp.exe'
$gdaldem      = Join-Path $scriptDir 'gdaldem.exe'
foreach($exe in @($gdalbuildvrt,$gdalwarp,$gdaldem)){ if(-not (Test-Path $exe)){ Show-Error "必要な実行ファイルが見つかりません: $exe"; return } }

$mergeLL = Join-Path $targetDir 'mergeLL.vrt'
$tifGlob = Join-Path $targetDir '*.tif'
$cmd1 = '"{0}" -overwrite "{1}" "{2}"' -f $gdalbuildvrt, $mergeLL, $tifGlob
$p = Start-Process -FilePath powershell -ArgumentList "-NoLogo -NoProfile -Command $cmd1" -Wait -PassThru -WindowStyle Hidden
if($p.ExitCode -ne 0){ Show-Error 'gdalbuildvrt 失敗'; return }

if($nodataFlag -eq 0){ $warpArgs = ' -r bilinear -srcnodata None -t_srs {0} "{1}" "{2}"' -f $prjArg,$mergeLL,$mergeTif } else { $warpArgs = ' -r bilinear -srcnodata -9999 -dstnodata -9999 -t_srs {0} "{1}" "{2}"' -f $prjArg,$mergeLL,$mergeTif }
$cmd2 = '"{0}"{1}' -f $gdalwarp,$warpArgs
$p = Start-Process -FilePath powershell -ArgumentList "-NoLogo -NoProfile -Command $cmd2" -Wait -PassThru -WindowStyle Hidden
if($p.ExitCode -ne 0){ Show-Error 'gdalwarp 失敗'; return }

if($shadeFlag -eq 1){
	$shadeTif = Join-Path $targetDir 'merge_shade.tif'
	$cmd3 = '"{0}" hillshade -s {1} "{2}" "{3}"' -f $gdaldem,$shadeScale,$mergeTif,$shadeTif
	$p = Start-Process -FilePath powershell -ArgumentList "-NoLogo -NoProfile -Command $cmd3" -Wait -PassThru -WindowStyle Hidden
	if($p.ExitCode -ne 0){ Show-Error 'gdaldem hillshade 失敗'; return }
}

Show-Info '変換終了しました。'
try { if($TopOwner -and -not $TopOwner.IsDisposed){ $TopOwner.Close() } } catch {}
