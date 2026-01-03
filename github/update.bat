@echo off
echo ===============================
echo 🔄 Actualizando GitHub Repo
echo ===============================

cd /d F:\development\flutter\colegiosoftware

git status
git add .
git commit -m "update %date% %time%"
git push

echo ===============================
echo ✅ Repo actualizado correctamente
echo ===============================
pause
