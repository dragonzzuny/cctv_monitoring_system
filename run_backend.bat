@echo off
cd /d "%~dp0backend"

echo ============================================
echo   CCTV YOLO Backend Server
echo ============================================
echo.

REM Use Anaconda cctv_yolo environment
set CONDA_EXE=%USERPROFILE%\anaconda3\Scripts\conda.exe
set ENV_NAME=cctv_yolo

echo Checking conda environment...
"%CONDA_EXE%" run -n %ENV_NAME% python --version >nul 2>&1
if errorlevel 1 (
    echo [ERROR] cctv_yolo environment not found!
    echo Creating environment...
    "%CONDA_EXE%" create -n %ENV_NAME% python=3.10 -y
    echo Installing dependencies...
    "%CONDA_EXE%" run -n %ENV_NAME% pip install -r requirements.txt
)

echo.
echo Checking for existing processes on port 8001...
for /f "tokens=5" %%a in ('netstat -ano ^| findstr :8001 ^| findstr LISTENING') do (
    echo Terminating existing process PID: %%a
    taskkill /F /PID %%a >nul 2>&1
)
timeout /t 2 /nobreak >nul

echo.
set PYTHONUNBUFFERED=1
echo Starting backend server on http://localhost:8001
echo Press Ctrl+C to stop the server
echo.

REM Activate environment and run python directly
call "%USERPROFILE%\anaconda3\Scripts\activate.bat" %ENV_NAME%
python -m uvicorn app.main:app --host 0.0.0.0 --port 8001
pause
