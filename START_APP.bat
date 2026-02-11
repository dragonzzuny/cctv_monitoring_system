@echo off
title CCTV YOLO - One Click Launcher
color 0A

echo.
echo  ========================================================
echo     CCTV Safety Monitoring System - One Click Launcher
echo  ========================================================
echo.

cd /d "%~dp0"

REM Configuration
set CONDA_EXE=%USERPROFILE%\anaconda3\Scripts\conda.exe
set ENV_NAME=cctv_yolo
set BACKEND_PORT=8001

echo [1/4] Checking Anaconda installation...
if not exist "%CONDA_EXE%" (
    echo [ERROR] Anaconda not found at %CONDA_EXE%
    echo Please install Anaconda or update the path in this script.
    pause
    exit /b 1
)
echo       OK - Anaconda found

echo.
echo [2/4] Checking conda environment '%ENV_NAME%'...
"%CONDA_EXE%" run -n %ENV_NAME% python --version >nul 2>&1
if errorlevel 1 (
    echo       Environment not found. Creating...
    "%CONDA_EXE%" create -n %ENV_NAME% python=3.10 -y
    echo       Installing backend dependencies...
    cd backend
    "%CONDA_EXE%" run -n %ENV_NAME% pip install -r requirements.txt
    cd ..
)
echo       OK - Environment ready

echo.
echo [3/4] Starting Backend Server...

REM Kill any existing process on port 8000
echo       Checking for processes on port %BACKEND_PORT%...
for /f "tokens=5" %%a in ('netstat -ano ^| findstr :%BACKEND_PORT% ^| findstr LISTENING') do (
    echo       Terminating existing process PID: %%a
    taskkill /F /PID %%a >nul 2>&1
)
ping 127.0.0.1 -n 2 >nul

start "CCTV Backend" /D "%~dp0backend" cmd /k "%CONDA_EXE%" run -n %ENV_NAME% python -m uvicorn app.main:app --host 0.0.0.0 --port %BACKEND_PORT%

REM Wait for backend to start
echo       Waiting for backend to initialize...
ping 127.0.0.1 -n 6 >nul

echo.
echo [4/4] Starting Flutter Frontend...
start "CCTV Frontend" /D "%~dp0frontend" cmd /k flutter run -d windows

echo.
echo  ========================================================
echo   Application Started Successfully!
echo  ========================================================
echo.
echo   Backend:  http://localhost:%BACKEND_PORT%
echo   API Docs: http://localhost:%BACKEND_PORT%/docs
echo.
echo   Two windows have been opened:
echo   - Backend server (keep this running)
echo   - Flutter frontend application
echo.
echo   To stop: Close both windows
echo  ========================================================
echo.
echo Press any key to close this launcher window...
pause >nul
