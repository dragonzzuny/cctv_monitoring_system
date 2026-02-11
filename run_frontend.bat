@echo off
cd /d "%~dp0frontend"
echo Getting Flutter packages...
flutter pub get
echo.
echo Starting Flutter app...
flutter run -d windows
pause
