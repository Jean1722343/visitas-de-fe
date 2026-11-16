# Publica una versión nueva: todos los teléfonos la descargan e instalan solos.
#
# Uso (desde la carpeta del proyecto, en PowerShell):
#   .\publicar.ps1 1.0.1 "Qué cambió en esta versión"
#
# 1. Sube la versión en pubspec.yaml (y el número de compilación).
# 2. Compila un APK firmado por tipo de procesador (llave en android/key.properties).
# 3. Guarda los cambios en git y los sube a GitHub.
# 4. Crea el release v<versión> con el APK. Al abrir la app, cada teléfono
#    lo detecta, lo descarga y abre el instalador.

param(
    [Parameter(Mandatory = $true)][string]$Version,
    [string]$Notas = "Mejoras y correcciones."
)
$ErrorActionPreference = "Stop"
$flutter = "C:\Users\jpgcp\flutter\bin\flutter.bat"

if ($Version -notmatch '^\d+\.\d+\.\d+$') { throw "La versión debe ser como 1.0.1" }
if (-not (Test-Path "android\key.properties")) { throw "Falta android\key.properties (la llave de firma)." }

# 1. Versión
$pubspec = Get-Content pubspec.yaml -Raw
$m = [regex]::Match($pubspec, '(?m)^version:\s*([\d\.]+)\+(\d+)')
$compilacion = [int]$m.Groups[2].Value + 1
$pubspec = $pubspec -replace '(?m)^version:.*$', "version: $Version+$compilacion"
[IO.File]::WriteAllText("$PWD\pubspec.yaml", $pubspec)
Write-Host "Versión $Version (compilación $compilacion)"

# 2. Compilar
& $flutter test
if ($LASTEXITCODE -ne 0) { throw "Las pruebas fallaron; no se publica." }
# Un APK por tipo de procesador: cada teléfono baja solo el suyo (~3 veces
# más ligero). No se publica el universal: su número de versión interno es
# menor que el de los separados y Android no lo instalaría encima.
& $flutter build apk --release --split-per-abi
if ($LASTEXITCODE -ne 0) { throw "No compiló." }
$apks = @()
foreach ($abi in @("arm64-v8a", "armeabi-v7a", "x86_64")) {
    $destino = "build/visitas-de-fe-$abi.apk"
    Copy-Item "build/app/outputs/flutter-apk/app-$abi-release.apk" $destino -Force
    $apks += $destino
}

# 3. Git
git add -A
git commit -m "Versión $Version" -m $Notas
git push -u origin HEAD

# 4. Release
gh release create "v$Version" @apks --title "Versión $Version" --notes $Notas
Write-Host "Listo: v$Version publicada. Los teléfonos se actualizarán al abrir la app."
