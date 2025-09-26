# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is a Japanese elevation DEM data conversion tool (基盤地図情報 標高DEMデータ変換ツール) that converts JPGIS (GML format) elevation data from Japan's Geospatial Information Authority into GeoTIFF format. The project migrated from VBScript to PowerShell in version 1.8.0.

## Commands

### Running the Tool
- **Japanese version**: `.\変換結合.cmd` or double-click the file
- **English version**: `.\convert_and_merge.cmd` or double-click the file
- Both launch PowerShell scripts (`main_jp.ps1` or `main_en.ps1`) with GUI dialogs

### Development/Compilation (for developers)
- Compile C++ code: Use Visual Studio Community 2017 x64 Native Tools Command Prompt
- Build dependencies: GDAL 3.0.4 and PROJ 6.3.2 libraries are required
- Main executable: `dem.exe` (compiled from `dem.cpp`)

## Architecture

### Core Components
1. **Launcher Scripts** (`*.cmd`): Windows batch files that launch PowerShell scripts
2. **Main Processing Scripts** (`main_jp.ps1`, `main_en.ps1`): PowerShell GUI applications
3. **DEM Converter** (`dem.exe`): C++ executable that converts XML/GML to TIFF
4. **GDAL Tools**: Bundled executables for geospatial processing
   - `gdalbuildvrt.exe`: Creates virtual raster datasets
   - `gdalwarp.exe`: Reprojects and warps raster data
   - `gdaldem.exe`: Generates hillshade relief maps

### Processing Workflow
1. User selects projection type (lat/long, UTM, or Japanese plane rectangular coordinates)
2. User selects folder containing `*FG-GML*.xml` files
3. `dem.exe` converts each XML file to individual TIFF files
4. `gdalbuildvrt` creates a virtual raster from all TIFFs
5. `gdalwarp` reprojects and merges into final `merge.tif`
6. Optional: `gdaldem` generates hillshade relief as `merge_shade.tif`

### Data Structure
- **`data/`**: GDAL data files and configuration templates
- **`proj/`**: PROJ coordinate system database and transformation grids
- **Input**: JPGIS (GML) XML files (`*FG-GML*.xml`)
- **Output**: `merge.tif` (merged elevation) and optional `merge_shade.tif` (hillshade)

### Coordinate System Support
- **Datum**: JGD2000 and JGD2011 (Japanese geodetic systems)
- **Projections**:
  - Geographic (lat/long): EPSG:4612/6668
  - UTM zones 51-56: EPSG:3097-3102 (JGD2000) or +3591 offset (JGD2011)
  - Japanese plane rectangular coordinates 1-19: EPSG:2443-2461 (JGD2000) or +4226 offset (JGD2011)

### ASCII Path Fallback
Both PowerShell scripts include fallback mechanisms that copy data to `%TEMP%` when the script path contains non-ASCII characters, ensuring GDAL tools work correctly with international file paths.

### Error Handling
- GUI-based error reporting through Windows Forms MessageBox
- Validation of required executables and input files
- Datum consistency checking across multiple input files
- Exit code handling from GDAL processes

## Important Notes
- Do not mix JGD2000 and JGD2011 data in the same processing run
- The tool expects `*FG-GML*.xml` files as input (specific naming pattern)
- Ocean elevation can be set to 0 or -9999 (nodata value)
- All GDAL environment variables are configured automatically by the scripts