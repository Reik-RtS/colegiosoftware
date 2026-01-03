@echo off
setlocal

set REPO=F:\development\flutter\colegiosoftware
set BRANCH=codex/implementar-backend-y-frontend-de-login

echo ===============================
echo 🔀 MERGE de "%BRANCH%" -> main
echo ===============================

cd /d "%REPO%"

echo.
echo 🔎 Verificando que no tengas cambios sin commit...
git status --porcelain
for /f %%A in ('git status --porcelain') do (
  echo ❌ Tienes cambios sin commit. Guarda/commitea antes de mergear.
  echo    (o descarta cambios con git restore .)
  pause
  exit /b 1
)

echo.
echo ⬇️ Actualizando referencias remotas...
git fetch origin
if errorlevel 1 goto err

echo.
echo ✅ Cambiando a main...
git checkout main
if errorlevel 1 goto err

echo.
echo ⬇️ Pull de main...
git pull origin main
if errorlevel 1 goto err

echo.
echo ✅ Cambiando a la rama del PR: %BRANCH% ...
git checkout "%BRANCH%"
if errorlevel 1 goto err

echo.
echo ⬇️ Actualizando rama PR...
git pull origin "%BRANCH%"
if errorlevel 1 goto err

echo.
echo ✅ Volviendo a main...
git checkout main
if errorlevel 1 goto err

echo.
echo 🔀 Mergeando "%BRANCH%" a main...
git merge --no-ff "%BRANCH%"
if errorlevel 1 (
  echo.
  echo ❌ Hubo conflicto en el merge.
  echo 👉 Resuélvelo, luego:
  echo    git add .
  echo    git commit
  echo    git push origin main
  pause
  exit /b 1
)

echo.
echo ⬆️ Subiendo main a GitHub...
git push origin main
if errorlevel 1 goto err

echo.
echo ===============================
echo ✅ MERGE COMPLETADO Y SUBIDO
echo ===============================
pause
exit /b 0

:err
echo.
echo ❌ Error ejecutando comandos git.
pause
exit /b 1
