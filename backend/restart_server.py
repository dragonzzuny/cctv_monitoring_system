import subprocess
import os
import time
import signal

def kill_port(port):
    try:
        output = subprocess.check_output(f"netstat -ano | findstr :{port}", shell=True).decode()
        for line in output.splitlines():
            if "LISTENING" in line:
                pid = line.strip().split()[-1]
                print(f"Killing process {pid} on port {port}")
                subprocess.run(f"taskkill /F /PID {pid}", shell=True)
                time.sleep(1)
    except:
        pass

def start_server():
    backend_dir = r"c:\Users\YJP\Desktop\cctv_yolo\backend"
    conda_path = r"C:\Users\YJP\anaconda3\Scripts\conda.exe"
    
    kill_port(8001)
    
    python_path = r"C:\Users\YJP\anaconda3\envs\cctv_yolo\python.exe"
    
    kill_port(8001)
    
    print("Starting server...")
    log_file = open("server.log", "w")
    
    # Use direct python path and set PYTHONPATH
    env = os.environ.copy()
    env["PYTHONPATH"] = backend_dir
    env["PYTHONUNBUFFERED"] = "1"
    
    cmd = f'"{python_path}" -m app.main'
    
    process = subprocess.Popen(
        cmd,
        cwd=backend_dir,
        shell=True,
        stdout=log_file,
        stderr=subprocess.STDOUT,
        env=env,
        creationflags=subprocess.CREATE_NEW_PROCESS_GROUP
    )
    
    print(f"Server started with PID {process.pid}. Logs in server.log")
    return process

if __name__ == "__main__":
    start_server()
