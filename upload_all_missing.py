#!/usr/bin/env python3
"""
One command to fetch all missing transcripts and upload them in sequence.
Usage: python upload_all_missing.py [API_KEY] [SERVER_URL]
"""

import sys
import os
import requests
import tempfile
from upload_transcript import get_transcript_locally, upload_transcript
from dotenv import load_dotenv

load_dotenv()


def get_missing_video_ids(api_key, server_url):
    """Get list of video IDs that need transcripts."""
    url = f"{server_url}/api/transcripts"
    
    headers = {
        'X-API-Key': api_key,
        'Accept': 'application/json'
    }
    
    try:
        response = requests.get(url, headers=headers, timeout=30)
        response.raise_for_status()
        
        data = response.json()
        return data.get('video_ids', [])
    
    except requests.exceptions.RequestException as e:
        print(f"❌ Error fetching missing transcripts: {e}")
        if hasattr(e, 'response') and e.response is not None:
            try:
                error_data = e.response.json()
                print(f"   Server error: {error_data.get('error', 'Unknown error')}")
            except:
                print(f"   HTTP {e.response.status_code}: {e.response.text}")
        raise


def main():
    api_key = sys.argv[1] if len(sys.argv) > 1 else os.getenv('TRANSCRIPT_API_KEY')
    server_url = sys.argv[2] if len(sys.argv) > 2 else 'https://summarizer.tpaulshippy.com'
    
    if not api_key:
        print("❌ API key required. Provide it as argument or set TRANSCRIPT_API_KEY environment variable.")
        print("Usage: python upload_all_missing.py [API_KEY] [SERVER_URL]")
        sys.exit(1)
    
    print(f"🔄 Fetching list of missing transcripts from {server_url}")
    
    try:
        # Get list of video IDs that need transcripts
        video_ids = get_missing_video_ids(api_key, server_url)
        
        if not video_ids:
            print("✅ No missing transcripts found! All meetings have transcripts.")
            return
        
        print(f"📋 Found {len(video_ids)} videos that need transcripts")
        print(f"🎯 Starting upload process...")
        
        successful = 0
        failed = 0
        transcripts_disabled = 0
        ip_blocked = 0
        no_transcript = 0
        video_unavailable = 0
        
        for i, video_id in enumerate(video_ids, 1):
            print(f"\n[{i}/{len(video_ids)}] Processing video ID: {video_id}")
            
            try:
                # Fetch transcript locally
                print("   🔄 Fetching transcript...")
                transcript = get_transcript_locally(video_id)
                
                if not transcript.strip():
                    print("   ⚠️  Retrieved transcript is empty, skipping")
                    failed += 1
                    continue
                
                print(f"   ✅ Retrieved transcript ({len(transcript)} characters)")
                
                # Upload to server
                print("   🔄 Uploading...")
                upload_transcript(video_id, transcript, api_key, server_url)
                
                if transcript == "Transcripts are disabled for this video.":
                    transcripts_disabled += 1
                else:
                    successful += 1
                
            except Exception as e:
                error_msg = str(e)
                if error_msg == "IP_BLOCKED":
                    ip_blocked += 1
                elif error_msg == "NO_TRANSCRIPT_FOUND":
                    no_transcript += 1
                elif error_msg == "VIDEO_UNAVAILABLE":
                    video_unavailable += 1
                else:
                    print(f"   ❌ Error: {e}")
                    failed += 1
        
        print(f"\n📊 Summary:")
        print(f"   ✅ Successful: {successful}")
        print(f"   ❌ Failed (other): {failed}")
        if transcripts_disabled > 0:
            print(f"   ⚠️  Transcripts disabled: {transcripts_disabled}")
        if ip_blocked > 0:
            print(f"   🚫 IP blocked/rate limited: {ip_blocked}")
        if no_transcript > 0:
            print(f"   📭 No transcript found: {no_transcript}")
        if video_unavailable > 0:
            print(f"   🚫 Video unavailable: {video_unavailable}")
        
        total_processed = successful + failed + transcripts_disabled + ip_blocked + no_transcript + video_unavailable
        if total_processed > 0:
            print(f"   📈 Success rate: {successful/total_processed*100:.1f}%")
            
        # Provide helpful tips if there are IP blocks
        if ip_blocked > 0:
            print(f"\n💡 Tips for IP blocking issues:")
            print(f"   • Wait a few hours/minutes before retrying")
            print(f"   • Try running from a different network/IP")
            print(f"   • Consider using a VPN if the issue persists")
        
    except Exception as e:
        print(f"❌ Error: {e}")
        sys.exit(1)


if __name__ == "__main__":
    main()
