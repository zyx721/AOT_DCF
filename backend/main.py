from fastapi import FastAPI, WebSocket, WebSocketDisconnect
from pydantic import BaseModel
import google.generativeai as genai
from fastapi.middleware.cors import CORSMiddleware
from typing import Dict, List
import json
import os
import uuid
import asyncio
from fastapi.staticfiles import StaticFiles

app = FastAPI()

# Mount static files directory
app.mount("/audio_files", StaticFiles(directory="audio_files"), name="audio_files")

# Configure CORS
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Configure Gemini API
GOOGLE_API_KEY = "AIzaSyDjsiA8U72-Zqt3xD4cEUHW8V5NooY6Y2A"
genai.configure(api_key=GOOGLE_API_KEY)

# Initialize Gemini model
model = genai.GenerativeModel('models/gemini-2.0-flash')

# Store active connections
active_connections: Dict[str, WebSocket] = {}

class ChatRequest(BaseModel):
    user_id: str
    query: str

# Create audio directory if it doesn't exist
if not os.path.exists("audio_files"):
    os.makedirs("audio_files")

@app.post("/chat")
async def chat_endpoint(request: ChatRequest):
    try:
        print(f"\n[User]: {request.query}")  # Print user message
        response = model.generate_content(request.query)
        print(f"[Gemini]: {response.text}\n")  # Print Gemini response
        return {"response": response.text}
    except Exception as e:
        print(f"[Error]: {str(e)}")  # Print any errors
        return {"error": str(e)}

@app.websocket("/ws")
async def websocket_endpoint(websocket: WebSocket):
    await websocket.accept()
    
    try:
        while True:
            message = await websocket.receive_text()
            data = json.loads(message)
            
            if data["type"] == "text":
                print(f"\n[User]: {data['text']}")
                
                # Generate response using Gemini
                response = model.generate_content(data["text"])
                response_text = response.text
                
                print(f"[Gemini]: {response_text}\n")

                # Send only text response
                await websocket.send_json({
                    "type": "response",
                    "text": response_text
                })

    except WebSocketDisconnect:
        print("[WebSocket]: Client disconnected")
    except Exception as e:
        print(f"[Error]: {str(e)}")
    finally:
        if websocket in active_connections.values():
            del active_connections[next(k for k, v in active_connections.items() if v == websocket)]

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000)
