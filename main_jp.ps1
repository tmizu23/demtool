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

Show-Info "2017/12/27更新: 日本測地系2011(JGD2011)に対応しています。JGD2000とJGD2011を混在させないでください。"

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
$prjArg = "epsg:$prj"

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
