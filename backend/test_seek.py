"""Test seek on two cameras sequentially (simulates camera switch)."""
import asyncio
import websockets
import json
import sys

# Fix Windows encoding
sys.stdout.reconfigure(encoding='utf-8')

async def test_seek_on_camera(camera_id: int):
    uri = f"ws://localhost:8001/ws/stream/{camera_id}"
    print(f"\n{'='*60}")
    print(f"Testing camera {camera_id}: {uri}")
    print(f"{'='*60}")
    
    try:
        async with websockets.connect(uri) as ws:
            # 1. Send START
            await ws.send(json.dumps({"action": "start"}))
            print("[1] Sent START")
            
            # 2. Read metadata
            resp = await asyncio.wait_for(ws.recv(), timeout=30)
            meta = json.loads(resp)
            print(f"[2] Received: type={meta.get('type')}, total_duration_ms={meta.get('total_duration_ms')}")
            
            total_ms = meta.get('total_duration_ms', 0)
            
            # 3. Read 3 frames (allow long timeout for first frame - model loading)
            for i in range(3):
                resp = await asyncio.wait_for(ws.recv(), timeout=30)
                data = json.loads(resp)
                print(f"[3] Frame {i}: current_ms={data.get('current_ms', 0):.0f}, total_ms={data.get('total_ms', 0):.0f}")
            
            last_pre_seek = data.get('current_ms', 0)
            
            # 4. SEEK to midpoint
            seek_target = int(total_ms / 2) if total_ms > 0 else 60000
            await ws.send(json.dumps({"action": "seek", "position_ms": seek_target}))
            print(f"[4] Sent SEEK to {seek_target}ms (pre-seek position was {last_pre_seek:.0f}ms)")
            
            # 5. Read frames after seek
            for i in range(5):
                resp = await asyncio.wait_for(ws.recv(), timeout=30)
                data = json.loads(resp)
                current = data.get('current_ms', 0)
                total = data.get('total_ms', 0)
                
                if abs(current - seek_target) < 15000:
                    status = "OK SEEK WORKED"
                elif current > last_pre_seek + 5000:
                    status = "PARTIAL - position moved forward"
                else:
                    status = "FAIL - position did not change"
                print(f"[5] Post-seek frame {i}: current_ms={current:.0f} total_ms={total:.0f} -> {status}")
            
            # 6. STOP
            await ws.send(json.dumps({"action": "stop"}))
            print(f"[6] Sent STOP, done.")
            
    except asyncio.TimeoutError:
        print(f"TIMEOUT: Backend did not respond in time for camera {camera_id}")
    except Exception as e:
        print(f"Error: {type(e).__name__}: {e}")

async def main():
    # Test camera 3
    await test_seek_on_camera(3)
    await asyncio.sleep(2)
    # Then camera 4 (simulating switch)
    await test_seek_on_camera(4)

if __name__ == "__main__":
    asyncio.run(main())
