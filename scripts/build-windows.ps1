# Build only on Windows; does not install tools, change firewall rules or run the app.
$ErrorActionPreference = 'Stop'
if ($env:OS -ne 'Windows_NT') {
    throw 'Esta compilacion necesita Windows 10 u 11.'
}
$hostArchitecture = if ($env:PROCESSOR_ARCHITEW6432) { $env:PROCESSOR_ARCHITEW6432 } else { $env:PROCESSOR_ARCHITECTURE }
if ($hostArchitecture -ne 'AMD64') {
    throw 'Este paquete requiere un entorno Windows x64 (Intel/AMD). ARM64 no esta incluido en esta entrega.'
}
$projectRoot = Split-Path -Parent $PSScriptRoot
$desktopPath = Join-Path $projectRoot 'desktop'
$flutterCommand = Get-Command flutter -ErrorAction SilentlyContinue
if (-not $flutterCommand) {
    throw 'Falta Flutter en PATH. Instala Flutter y Visual Studio con Desarrollo para el escritorio con C++ antes de compilar.'
}
Push-Location $desktopPath
try {
    & $flutterCommand.Source pub get
    if ($LASTEXITCODE -ne 0) { throw 'No se pudieron preparar las dependencias.' }
    & $flutterCommand.Source build windows --release
    if ($LASTEXITCODE -ne 0) { throw 'La compilacion fallo. Revisa el error de Flutter o Visual Studio mostrado arriba.' }
} finally { Pop-Location }

$release = Join-Path $desktopPath 'build\windows\x64\runner\Release'
foreach ($required in @('NexoDrop.exe', 'flutter_windows.dll', 'data\app.so', 'data\icudtl.dat', 'data\flutter_assets')) {
    if (-not (Test-Path (Join-Path $release $required))) {
        throw "Compilacion incompleta: falta $required. No se genero un paquete."
    }
}
$versionLine = Select-String -Path (Join-Path $desktopPath 'pubspec.yaml') -Pattern '^version:\s*(\S+)'
$version = $versionLine.Matches[0].Groups[1].Value -replace '\+', '-'
$output = Join-Path $projectRoot 'dist'
New-Item -ItemType Directory -Force -Path $output | Out-Null
$staging = Join-Path $output ('.windows-package-' + [guid]::NewGuid().ToString('N'))
$package = Join-Path $staging 'NexoDrop'
New-Item -ItemType Directory -Path $package | Out-Null
try {
    Copy-Item -Path (Join-Path $release '*') -Destination $package -Recurse
    Copy-Item -Path (Join-Path $projectRoot 'LICENSE'), (Join-Path $projectRoot 'NOTICE') -Destination $package
    Copy-Item -Path (Join-Path $projectRoot 'docs\windows-uso.txt') -Destination (Join-Path $package 'LEEME.txt')
    $zip = Join-Path $output "NexoDrop-$version-Windows-x64.zip"
    Compress-Archive -Path $package -DestinationPath $zip -Force
    $checksum = (Get-FileHash -Algorithm SHA256 -Path $zip).Hash.ToLowerInvariant()
    "$checksum  $(Split-Path -Leaf $zip)" | Set-Content -Encoding ASCII -Path "$zip.sha256"
    Write-Host "Listo: $zip"
    Write-Host 'Extrae el ZIP completo y abre NexoDrop.exe. Conserva las DLL y la carpeta data junto al ejecutable.'
} finally {
    # Only the uniquely named staging directory created above is removed.
    Remove-Item -LiteralPath $staging -Recurse -Force
}
