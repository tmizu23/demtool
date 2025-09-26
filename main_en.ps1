<#!
Elevation DEM convert + merge (English)
Ported from convert_and_merge.vbs
#>
[CmdletBinding()]
param()

if([System.Threading.Thread]::CurrentThread.ApartmentState -ne 'STA'){
    Start-Process powershell.exe -ArgumentList @('-NoProfile','-ExecutionPolicy','Bypass','-STA','-File',"$PSCommandPath") -WorkingDirectory (Split-Path -Parent $PSCommandPath)
    return
}
try { [Console]::OutputEncoding = [System.Text.Encoding]::UTF8 } catch {}
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName Microsoft.VisualBasic
# Always-on-top invisible owner form to prevent dialogs appearing behind other windows
$script:TopOwner = New-Object System.Windows.Forms.Form
$TopOwner.ShowInTaskbar = $false
$TopOwner.FormBorderStyle = 'FixedToolWindow'
$TopOwner.Opacity = 0
$TopOwner.TopMost = $true
$TopOwner.StartPosition = 'Manual'
$TopOwner.Size = [Drawing.Size]::new(1,1)
$TopOwner.Location = [Drawing.Point]::new(-2000,-2000)
$TopOwner.Show() | Out-Null
function Info($m){[Windows.Forms.MessageBox]::Show($TopOwner,$m,'Info',[Windows.Forms.MessageBoxButtons]::OK,[Windows.Forms.MessageBoxIcon]::Information)|Out-Null}
function ErrMsg($m){[Windows.Forms.MessageBox]::Show($TopOwner,$m,'Error',[Windows.Forms.MessageBoxButtons]::OK,[Windows.Forms.MessageBoxIcon]::Error)|Out-Null}
function AskYN($m){ $TopOwner.Activate()|Out-Null; ([Windows.Forms.MessageBox]::Show($TopOwner,$m,'Confirm',[Windows.Forms.MessageBoxButtons]::YesNo,[Windows.Forms.MessageBoxIcon]::Question) -eq [Windows.Forms.DialogResult]::Yes) }
function AskIn($m,$d=''){ $TopOwner.Activate()|Out-Null; [Microsoft.VisualBasic.Interaction]::InputBox($m,'Input',$d) }

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location $scriptDir

function Use-AsciiFallback([string]$root){ if($root -notmatch '[^\x00-\x7f]'){return $null}; $tmp=Join-Path $env:TEMP 'demtool_ascii_en'; if(Test-Path $tmp){Remove-Item $tmp -Recurse -Force -ErrorAction SilentlyContinue}; New-Item -ItemType Directory -Path $tmp|Out-Null; foreach($d in 'proj','data'){ if(Test-Path (Join-Path $root $d)){ Copy-Item (Join-Path $root $d) (Join-Path $tmp $d) -Recurse -Force } }; @{Root=$tmp;Proj=(Join-Path $tmp 'proj');Data=(Join-Path $tmp 'data')} }
$ascii=Use-AsciiFallback $scriptDir
if($ascii){ $env:GDAL_DATA=$ascii.Data; $env:PROJ_LIB=$ascii.Proj } else { $env:GDAL_DATA=Join-Path $scriptDir 'data'; $env:PROJ_LIB=Join-Path $scriptDir 'proj' }
$env:GDAL_FILENAME_IS_UTF8='YES'

Info '2025/09/26 update: JGD2000(EPSG codes), JGD2011(EPSG codes), JGD2024(WKT definitions). Do NOT mix data from different geodetic systems.'
$inProj = AskIn "Select projection:`r`nLat/Long:0  UTM:1  Plane Rectangular:2" '0'
switch($inProj){
  '0' {$prjType='idokeido';$shadeScale=111120}
  '1' {$prjType='UTM';$shadeScale=1}
  '2' {$prjType='heimen';$shadeScale=1}
  default { ErrMsg 'Invalid projection.'; return }
}
$zone=''
if($prjType -eq 'UTM'){ $zone = AskIn 'Enter UTM zone (51-56)' }
elseif($prjType -eq 'heimen'){ $zone = AskIn 'Enter plane coordinate system number (1-19)' }
$shadeFlag = if(AskYN 'Generate shaded relief?'){1}else{0}
$dlg = New-Object Windows.Forms.FolderBrowserDialog
$dlg.Description='Select folder containing JPGIS (GML) files'
if($dlg.ShowDialog() -ne [Windows.Forms.DialogResult]::OK){ return }
$targetDir = $dlg.SelectedPath
$mergeTif = Join-Path $targetDir 'merge.tif'
if(Test-Path $mergeTif){ ErrMsg 'merge.tif already exists. Delete it first.'; return }
$nodataFlag = if(AskYN 'Assign ocean elevation 0? (No = -9999)'){0}else{1}
Info 'Processing... Please wait.'
$demExe = Join-Path $scriptDir 'dem.exe'
if(-not (Test-Path $demExe)){ ErrMsg 'dem.exe not found.'; return }
$xmlFiles = Get-ChildItem -Path $targetDir -Filter '*FG-GML*.xml' -File -ErrorAction SilentlyContinue
if(-not $xmlFiles){ ErrMsg 'No *FG-GML*.xml files found.'; return }
$jgd=$null
foreach($f in $xmlFiles){ $arg='"{0}" {1}' -f $f.FullName,$nodataFlag; $p=Start-Process -FilePath $demExe -ArgumentList $arg -NoNewWindow -Wait -PassThru; $code=$p.ExitCode; if(-not $jgd){$jgd=$code} elseif($code -ne $jgd){ ErrMsg "$($f.Name) has a different datum."; return } }
$prj=$null
if($prjType -eq 'idokeido'){ $prj=4612 } elseif($prjType -eq 'UTM'){ $utm=@{'51'=3097;'52'=3098;'53'=3099;'54'=3100;'55'=3101;'56'=3102}; if($utm.ContainsKey($zone)){ $prj=$utm[$zone] } } elseif($prjType -eq 'heimen'){ $hm=@{'1'=2443;'2'=2444;'3'=2445;'4'=2446;'5'=2447;'6'=2448;'7'=2449;'8'=2450;'9'=2451;'10'=2452;'11'=2453;'12'=2454;'13'=2455;'14'=2456;'15'=2457;'16'=2458;'17'=2459;'18'=2460;'19'=2461}; if($hm.ContainsKey($zone)){ $prj=$hm[$zone] } }
if(-not $prj){ ErrMsg 'Invalid zone / system number.'; return }
if($jgd -eq 2011){ switch($prjType){ 'idokeido'{$prj=6668}; 'UTM'{$prj+=3591}; 'heimen'{$prj+=4226} } }
elseif($jgd -eq 2024){
	# JGD2024 support (using WKT definitions)
	switch($prjType){
		'idokeido' { $prj = 'JGD2024_GEOG' }
		'UTM' { $prj = "JGD2024_UTM_$zone" }
		'heimen' { $prj = "JGD2024_PLANE_$zone" }
	}
}
# Set JGD2024 coordinate system WKT definitions
if($prj -eq 'JGD2024_GEOG'){
	# JGD2024 geographic coordinate system
	$prjArg = 'GEOGCS["JGD2024",DATUM["Japanese_Geodetic_Datum_2024",SPHEROID["GRS_1980",6378137.0,298.257222101],AUTHORITY["EPSG","7019"]],PRIMEM["Greenwich",0.0,AUTHORITY["EPSG","8901"]],UNIT["Degree",0.0174532925199433,AUTHORITY["EPSG","9122"]]]'
}elseif($prj -match '^JGD2024_UTM_(\d+)$'){
	# JGD2024 UTM coordinate system
	$utmZone = [int]$Matches[1]
	if($utmZone -ge 51 -and $utmZone -le 56){
		$centralMeridian = ($utmZone * 6) - 183
		$prjArg = "PROJCS[`"JGD_2024_UTM_Zone_${utmZone}N`",GEOGCS[`"GCS_JGD_2024`",DATUM[`"D_JGD_2024`",SPHEROID[`"GRS_1980`",6378137.0,298.257222101]],PRIMEM[`"Greenwich`",0.0],UNIT[`"Degree`",0.0174532925199433]],PROJECTION[`"Transverse_Mercator`"],PARAMETER[`"False_Easting`",500000.0],PARAMETER[`"False_Northing`",0.0],PARAMETER[`"Central_Meridian`",$centralMeridian.0],PARAMETER[`"Scale_Factor`",0.9996],PARAMETER[`"Latitude_Of_Origin`",0.0],UNIT[`"Meter`",1.0]]"
	}else{
		ErrMsg "Invalid UTM zone: $utmZone (only 51-56 supported)"; return
	}
}elseif($prj -match '^JGD2024_PLANE_(\d+)$'){
	# JGD2024 plane rectangular coordinate system
	$planeZone = [int]$Matches[1]

	# Central meridian and origin latitude for each zone
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
		ErrMsg "Invalid plane rectangular coordinate zone: $planeZone"; return
	}
}else{
	$prjArg = "epsg:$prj"
}
$gdalbuildvrt = Join-Path $scriptDir 'gdalbuildvrt.exe'
$gdalwarp = Join-Path $scriptDir 'gdalwarp.exe'
$gdaldem = Join-Path $scriptDir 'gdaldem.exe'
foreach($exe in @($gdalbuildvrt,$gdalwarp,$gdaldem)){ if(-not (Test-Path $exe)){ ErrMsg "Missing executable: $exe"; return } }
$mergeLL = Join-Path $targetDir 'mergeLL.vrt'
$tifGlob = Join-Path $targetDir '*.tif'
$cmd1 = '"{0}" -overwrite "{1}" "{2}"' -f $gdalbuildvrt,$mergeLL,$tifGlob
$p = Start-Process -FilePath powershell -ArgumentList "-NoLogo -NoProfile -Command $cmd1" -Wait -PassThru -WindowStyle Hidden; if($p.ExitCode -ne 0){ ErrMsg 'gdalbuildvrt failed.'; return }
if($nodataFlag -eq 0){ $warpArgs = ' -r bilinear -srcnodata None -t_srs {0} "{1}" "{2}"' -f $prjArg,$mergeLL,$mergeTif } else { $warpArgs = ' -r bilinear -srcnodata -9999 -dstnodata -9999 -t_srs {0} "{1}" "{2}"' -f $prjArg,$mergeLL,$mergeTif }
$cmd2 = '"{0}"{1}' -f $gdalwarp,$warpArgs
$p = Start-Process -FilePath powershell -ArgumentList "-NoLogo -NoProfile -Command $cmd2" -Wait -PassThru -WindowStyle Hidden; if($p.ExitCode -ne 0){ ErrMsg 'gdalwarp failed.'; return }
if($shadeFlag -eq 1){ $shadeTif = Join-Path $targetDir 'merge_shade.tif'; $cmd3 = '"{0}" hillshade -s {1} "{2}" "{3}"' -f $gdaldem,$shadeScale,$mergeTif,$shadeTif; $p = Start-Process -FilePath powershell -ArgumentList "-NoLogo -NoProfile -Command $cmd3" -Wait -PassThru -WindowStyle Hidden; if($p.ExitCode -ne 0){ ErrMsg 'gdaldem hillshade failed.'; return } }
Info 'Finished.'
try { if($TopOwner -and -not $TopOwner.IsDisposed){ $TopOwner.Close() } } catch {}
