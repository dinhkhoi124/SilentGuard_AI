from fastapi import APIRouter, WebSocket, WebSocketDisconnect
from typing import Dict, List

router = APIRouter(prefix="/api/streams", tags=["Streams"])

class ConnectionManager:
    def __init__(self):
        # Maps camera_id to a list of connected frontend WebSockets
        self.active_connections: Dict[str, List[WebSocket]] = {}
        # Keeps track of the Edge device WebSocket for a camera
        self.edge_connections: Dict[str, WebSocket] = {}

    async def connect_client(self, websocket: WebSocket, camera_id: str):
        await websocket.accept()
        if camera_id not in self.active_connections:
            self.active_connections[camera_id] = []
        self.active_connections[camera_id].append(websocket)
        print(f"[WebSocket] Client subscribed to camera {camera_id}. Total clients: {len(self.active_connections[camera_id])}")

    def disconnect_client(self, websocket: WebSocket, camera_id: str):
        if camera_id in self.active_connections and websocket in self.active_connections[camera_id]:
            self.active_connections[camera_id].remove(websocket)
            print(f"[WebSocket] Client unsubscribed from camera {camera_id}.")

    async def connect_edge(self, websocket: WebSocket, camera_id: str):
        await websocket.accept()
        # If there's an existing edge connection for this camera, close it (only 1 publisher allowed)
        if camera_id in self.edge_connections:
            try:
                await self.edge_connections[camera_id].close(code=1008, reason="New publisher connected")
            except Exception:
                pass
        self.edge_connections[camera_id] = websocket
        print(f"[WebSocket] Edge publisher connected for camera {camera_id}.")

    def disconnect_edge(self, camera_id: str):
        if camera_id in self.edge_connections:
            del self.edge_connections[camera_id]
            print(f"[WebSocket] Edge publisher disconnected for camera {camera_id}.")

    async def broadcast_frame(self, camera_id: str, frame_bytes: bytes):
        if camera_id in self.active_connections:
            # Create a copy of the list to iterate over, as disconnects might modify the original list
            for connection in list(self.active_connections[camera_id]):
                try:
                    await connection.send_bytes(frame_bytes)
                except Exception as e:
                    print(f"[WebSocket] Failed to send frame to client on camera {camera_id}: {e}")
                    self.disconnect_client(connection, camera_id)

manager = ConnectionManager()


@router.websocket("/{camera_id}/publish")
async def publish_stream(websocket: WebSocket, camera_id: str):
    """
    WebSocket endpoint for Edge Device to push MJPEG frames.
    For security, the Edge script should provide the device_api_key, 
    but for MVP we simply rely on the unguessable URL/Headers.
    """
    await manager.connect_edge(websocket, camera_id)
    try:
        while True:
            # Expecting binary frame data (JPEG bytes)
            frame_bytes = await websocket.receive_bytes()
            # Relay frame to all subscribed clients
            await manager.broadcast_frame(camera_id, frame_bytes)
    except WebSocketDisconnect:
        manager.disconnect_edge(camera_id)
    except Exception as e:
        print(f"Error in publish_stream for camera {camera_id}: {e}")
        manager.disconnect_edge(camera_id)


@router.websocket("/{camera_id}/subscribe")
async def subscribe_stream(websocket: WebSocket, camera_id: str):
    """
    WebSocket endpoint for Web/App Frontend to receive MJPEG frames.
    """
    await manager.connect_client(websocket, camera_id)
    try:
        while True:
            # Keep connection alive, wait for client disconnect or ping
            _ = await websocket.receive_text()
    except WebSocketDisconnect:
        manager.disconnect_client(websocket, camera_id)
    except Exception as e:
        print(f"Error in subscribe_stream for camera {camera_id}: {e}")
        manager.disconnect_client(websocket, camera_id)
