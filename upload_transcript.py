#!/usr/bin/env python3
"""
Script to fetch transcripts locally and upload them to the remote server.
Usage: python upload_transcript.py VIDEO_ID [API_KEY] [SERVER_URL]
"""

import sys
import os
import requests
import subprocess
import tempfile
from pathlib import Path
from dotenv import load_dotenv

load_dotenv()

def get_transcript_locally(video_id):
    """Fetch transcript using the existing get_transcript.py script."""
    script_path = Path("get_transcript.py")
    if not script_path.exists():
        raise FileNotFoundError("get_transcript.py not found in current directory")
    
    venv_python = Path("venv/bin/python")
    if not venv_python.exists():
        raise FileNotFoundError("Virtual environment not found at venv/bin/python")
    
    with tempfile.NamedTemporaryFile(mode='w+', suffix='.txt', delete=False) as tmp_file:
        tmp_path = tmp_file.name
    
    try:
        cmd = [str(venv_python), str(script_path), video_id, tmp_path]
        result = subprocess.run(cmd, capture_output=True, text=True, check=True)
        
        with open(tmp_path, 'r', encoding='utf-8') as f:
            transcript = f.read()
        
        return transcript
    
    except subprocess.CalledProcessError as e:
        error_output = e.stderr.strip() if e.stderr else ""
        stdout_output = e.stdout.strip() if e.stdout else ""
        
        # Combine outputs to analyze the error
        full_output = f"{stdout_output}\n{error_output}".strip()
        
        # Determine the specific type of error
        if "Transcripts are disabled for this video" in full_output:
            print(f"  ⚠️  Transcripts are disabled for video {video_id}")
            return "Transcripts are disabled for this video."
        elif "YouTube is blocking requests" in full_output or "IP has been blocked" in full_output:
            print(f"  🚫 YouTube is blocking requests (IP rate limited)")
            print(f"  💡 This might be temporary - try again later or use a different IP")
            raise Exception("IP_BLOCKED")
        elif "No transcript found" in full_output:
            print(f"  📭 No transcript available for video {video_id}")
            raise Exception("NO_TRANSCRIPT_FOUND")
        elif "Video unavailable" in full_output or "unavailable" in full_output:
            print(f"  🚫 Video {video_id} is unavailable")
            raise Exception("VIDEO_UNAVAILABLE")
        else:
            # Generic error handling
            print(f"Error fetching transcript: ")
            print(f"  ❌ Error: Command returned non-zero exit status {e.returncode}.")
            if stdout_output:
                print(f"  📄 Output: {stdout_output}")
            if error_output:
                print(f"  🚨 Error details: {error_output}")
            raise Exception(f"Command '{' '.join(e.cmd)}' returned non-zero exit status {e.returncode}.")
    finally:
        # Clean up temp file
        if os.path.exists(tmp_path):
            os.unlink(tmp_path)


def upload_transcript(video_id, transcript, api_key, server_url):
    """Upload transcript to the remote server."""
    url = f"{server_url}/api/transcripts"
    
    headers = {
        'X-API-Key': api_key,
        'Content-Type': 'application/json'
    }
    
    data = {
        'video_id': video_id,
        'transcript': transcript
    }
    
    try:
        response = requests.post(url, json=data, headers=headers, timeout=30)
        response.raise_for_status()
        
        result = response.json()
        print(f"✅ Successfully uploaded transcript for video {video_id}")
        print(f"   Meeting ID: {result.get('meeting_id')}")
        print(f"   Message: {result.get('message')}")
        
    except requests.exceptions.RequestException as e:
        print(f"❌ Error uploading transcript: {e}")
        if hasattr(e, 'response') and e.response is not None:
            try:
                error_data = e.response.json()
                print(f"   Server error: {error_data.get('error', 'Unknown error')}")
            except:
                print(f"   HTTP {e.response.status_code}: {e.response.text}")
        raise


def main():
    if len(sys.argv) < 2:
        print("Usage: python upload_transcript.py VIDEO_ID [API_KEY] [SERVER_URL]")
        print("Example: python upload_transcript.py abc123xyz your_api_key https://summarizer.tpaulshippy.com")
        sys.exit(1)
    
    video_id = sys.argv[1]
    api_key = sys.argv[2] if len(sys.argv) > 2 else os.getenv('TRANSCRIPT_API_KEY')
    server_url = sys.argv[3] if len(sys.argv) > 3 else 'https://summarizer.tpaulshippy.com'
    
    if not api_key:
        print("❌ API key required. Provide it as argument or set TRANSCRIPT_API_KEY environment variable.")
        sys.exit(1)
    
    print(f"🔄 Fetching transcript for video ID: {video_id}")
    
    try:
        # Fetch transcript locally
        transcript = get_transcript_locally(video_id)
        
        if not transcript.strip():
            print("❌ Retrieved transcript is empty")
            sys.exit(1)
        
        print(f"✅ Retrieved transcript ({len(transcript)} characters)")
        
        # Upload to server
        print(f"🔄 Uploading to {server_url}")
        upload_transcript(video_id, transcript, api_key, server_url)
        
    except Exception as e:
        print(f"❌ Error: {e}")
        sys.exit(1)


if __name__ == "__main__":
    main()
