@echo off
setlocal

set REPO=F:\development\flutter\colegiosoftware

echo ===============================
echo ACTUALIZANDO main DESDE GitHub
echo ===============================

cd /d "%REPO%"

echo.
echo Cambiando a main...
git checkout main
if errorlevel 1 goto err

echo.
echo Bajando cambios...
git pull origin main
if errorlevel 1 goto err

echo.
echo ===============================
echo ACTUALIZACION COMPLETA
echo ===============================
pause
exit /b 0

:err
echo.
echo Error ejecutando comandos git!
pause
exit /b 1
