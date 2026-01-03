@echo on
setlocal
echo ==== START ====
where flutter
echo VCToolsVersion(before)=%VCToolsVersion%
set VCToolsVersion=
echo VCToolsVersion(after)=%VCToolsVersion%
cd /d F:\development\flutter\colegiosoftware
call F:\Apps\FlutterSDK\flutter\bin\flutter.bat --version
call F:\Apps\FlutterSDK\flutter\bin\flutter.bat clean
rmdir /s /q build\windows 2>nul
call F:\Apps\FlutterSDK\flutter\bin\flutter.bat run -d windows
echo ==== END (exitcode=%errorlevel%) ====
pause
