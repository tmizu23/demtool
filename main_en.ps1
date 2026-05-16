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

Info 'Supports JGD2000, JGD2011, and JGD2024. JGD2024 horizontal coordinates are processed with the same EPSG codes as JGD2011 (per EPSG Dataset v12.055). Do NOT mix data from different geodetic systems.'
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
$jgdFirstFile=$null
foreach($f in $xmlFiles){
	$arg='"{0}" {1}' -f $f.FullName,$nodataFlag
	$p=Start-Process -FilePath $demExe -ArgumentList $arg -NoNewWindow -Wait -PassThru
	$code=$p.ExitCode
	if(-not $jgd){ $jgd=$code; $jgdFirstFile=$f.Name }
	elseif($code -ne $jgd){
		$msg = "Files with different geodetic datums are mixed in the target folder.`r`n`r`n"
		$msg += "  $jgdFirstFile : JGD$jgd`r`n"
		$msg += "  $($f.Name) : JGD$code`r`n`r`n"
		if(($jgd -eq 2011 -and $code -eq 2024) -or ($jgd -eq 2024 -and $code -eq 2011)){
			$msg += "JGD2011 and JGD2024 share the same map positions (lat/lon, plane rectangular,`r`n"
			$msg += "UTM), but their height references differ by a few cm to tens of cm depending`r`n"
			$msg += "on location. Mixing them would cause elevation jumps at the boundaries`r`n"
			$msg += "between datasets.`r`n`r`n"
		} else {
			$msg += "Different geodetic datums have different horizontal coordinates, so mixing`r`n"
			$msg += "them would produce coordinate inconsistencies.`r`n`r`n"
		}
		$msg += "To preserve data integrity, processing is aborted.`r`n"
		$msg += "Please collect only files with the same datum in the target folder and try again."
		ErrMsg $msg
		return
	}
}
$prj=$null
if($prjType -eq 'idokeido'){ $prj=4612 } elseif($prjType -eq 'UTM'){ $utm=@{'51'=3097;'52'=3098;'53'=3099;'54'=3100;'55'=3101;'56'=3102}; if($utm.ContainsKey($zone)){ $prj=$utm[$zone] } } elseif($prjType -eq 'heimen'){ $hm=@{'1'=2443;'2'=2444;'3'=2445;'4'=2446;'5'=2447;'6'=2448;'7'=2449;'8'=2450;'9'=2451;'10'=2452;'11'=2453;'12'=2454;'13'=2455;'14'=2456;'15'=2457;'16'=2458;'17'=2459;'18'=2460;'19'=2461}; if($hm.ContainsKey($zone)){ $prj=$hm[$zone] } }
if(-not $prj){ ErrMsg 'Invalid zone / system number.'; return }
if($jgd -eq 2011 -or $jgd -eq 2024){ switch($prjType){ 'idokeido'{$prj=6668}; 'UTM'{$prj+=3591}; 'heimen'{$prj+=4226} } }
$prjArg = "epsg:$prj"
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
