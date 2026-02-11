import asyncio
import json
import websockets
import base64

async def debug_cam3():
    uri = "ws://localhost:8001/ws/stream/3"
    try:
        async with websockets.connect(uri) as websocket:
            print("Connected to Camera 3 WS")
            
            # Start streaming
            await websocket.send(json.dumps({"action": "start"}))
            
            count = 0
            while count < 30:
                message = await websocket.recv()
                data = json.loads(message)
                
                msg_type = data.get("type")
                if msg_type == "metadata":
                    print(f"Metadata: {data}")
                elif msg_type == "frame":
                    # Corrected variable names and logic based on the instruction's intent
                    roi_metrics = data.get("roi_metrics", {})
                    detection_data = data.get("detection")
                    total_roi_count = sum(m.get("count", 0) for m in roi_metrics.values())
                    print(f"Frame {data.get('current_ms')}ms. Detection: {data.get('detection') is not None}. ROIs={len(roi_metrics)} Metrics={roi_metrics}")
                    
                    if data.get("events"):
                        for evt in data["events"]:
                             print(f"EVENT DETECTED: {evt.get('event_type')} at {evt.get('created_at')}")
                    if total_roi_count > 0:
                        print(f"!!! PERSON IN ROI DETECTED: Total={total_roi_count}")
                elif msg_type == "event":
                    print(f"EVENT RECEIVED: {data.get('message')}")
                
                count += 1
                
    except Exception as e:
        print(f"Error: {e}")

if __name__ == "__main__":
    asyncio.run(debug_cam3())
