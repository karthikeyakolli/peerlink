#!/usr/bin/env python3
"""
PeerLink Phase 01 Live Integration Verification Runner
1. Launches Desktop Local Node daemon as an external process.
2. Runs the Flutter/Dart gRPC client proof suite against the live node.
3. Tests lifecycle (start, healthy, stop, restart), security authentication, version compatibility, and event streaming.
4. Produces exit code 0 on PASS, non-zero on FAIL.
"""

import os
import sys
import time
import socket
import tempfile
import subprocess
import shutil

ROOT_DIR = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
PORT = 54325
DATA_DIR = tempfile.mkdtemp(prefix="peerlink_phase01_")

MAVEN_CMD = r"D:\tools\apache-maven-3.9.9\bin\mvn.cmd"
DART_CMD = r"D:\tools\flutter\bin\cache\dart-sdk\bin\dart.exe"

env = os.environ.copy()
tools = [
    r"D:\tools\apache-maven-3.9.9\bin",
    r"D:\tools\bin",
    r"D:\tools\flutter\bin",
    r"D:\tools\flutter\bin\cache\dart-sdk\bin",
    r"C:\Users\WIN_10\AppData\Local\Pub\Cache\bin"
]
env["PATH"] = ";".join(tools) + ";" + env.get("PATH", "")

def wait_for_port(port, timeout=35):
    start = time.time()
    while time.time() - start < timeout:
        try:
            with socket.create_connection(("127.0.0.1", port), timeout=1):
                return True
        except (ConnectionRefusedError, OSError):
            time.sleep(0.5)
    return False

print("=== STARTING PEERLINK PHASE 01 LIVE VERIFICATION ===")
print(f"Repository Root: {ROOT_DIR}")
print(f"Node IPC Port:   {PORT}")
print(f"Data Directory:  {DATA_DIR}")

# 1. Compile and install Desktop Node
print("\n[Step A] Installing Java modules locally...")
compile_res = subprocess.run([MAVEN_CMD, "install", "-DskipTests", "-B"], cwd=ROOT_DIR, env=env, capture_output=True, text=True)
if compile_res.returncode != 0:
    print("Java compilation/install failed!")
    print(compile_res.stderr or compile_res.stdout)
    sys.exit(1)
print("Java modules installed successfully.")

# 2. Start Desktop Node Daemon
print("\n[Step B] Starting Java Desktop Local Node daemon...")
node_log_file = os.path.join(DATA_DIR, "daemon.log")
node_log = open(node_log_file, "w")

cmd_node = [
    MAVEN_CMD,
    "-f", os.path.join(ROOT_DIR, "desktop-node", "pom.xml"),
    "exec:java",
    "-Dexec.mainClass=org.peerlink.desktop.runtime.DesktopNodeDaemon",
    f"-Dexec.args=--port {PORT} --data-dir \"{DATA_DIR}\""
]

node_proc = subprocess.Popen(cmd_node, cwd=ROOT_DIR, env=env, stdout=node_log, stderr=subprocess.STDOUT)

print("Waiting for Local Node IPC server to listen on port 54325...")
if not wait_for_port(PORT, timeout=35):
    print("Timed out waiting for Node IPC server to start!")
    node_proc.kill()
    node_log.close()
    with open(node_log_file, "r") as f:
        print(f.read()[-3000:])
    sys.exit(2)

print(f"Node is up and listening on 127.0.0.1:{PORT}")

# Read generated auth token
token_file = os.path.join(DATA_DIR, "ipc_auth.token")
if not os.path.exists(token_file):
    print("Error: Auth token file was not created!")
    node_proc.kill()
    sys.exit(3)

with open(token_file, "r") as f:
    auth_token = f.read().strip()

print(f"Retrieved active development IPC auth token: {auth_token[:8]}***")

# 3. Run Dart Client Proof
print("\n[Step C] Running Flutter/Dart live proof client...")
dart_script = os.path.join(ROOT_DIR, "apps", "peerlink-app", "test", "integration", "live_node_proof.dart")
dart_res = subprocess.run(
    [DART_CMD, "run", dart_script, str(PORT), auth_token],
    cwd=os.path.join(ROOT_DIR, "apps", "peerlink-app"),
    env=env,
    capture_output=True,
    text=True
)

print("--- DART CLIENT OUTPUT ---")
print(dart_res.stdout)
if dart_res.stderr:
    print("STDERR:", dart_res.stderr)

client_exit_code = dart_res.returncode
print(f"Dart Client Exit Code: {client_exit_code}")

# 4. Stop Node Daemon
print("\n[Step D] Shutting down Java Desktop Node daemon...")
node_proc.terminate()
try:
    node_proc.wait(timeout=5)
except subprocess.TimeoutExpired:
    node_proc.kill()
node_log.close()

# Cleanup temporary dir
try:
    shutil.rmtree(DATA_DIR)
except Exception:
    pass

if client_exit_code == 0:
    print("\n==============================================")
    print("PHASE 01 VERIFICATION RESULT: PASS")
    print("==============================================")
    sys.exit(0)
else:
    print("\n==============================================")
    print("PHASE 01 VERIFICATION RESULT: FAIL")
    print("==============================================")
    sys.exit(client_exit_code)
