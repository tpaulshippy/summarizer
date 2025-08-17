#!/usr/bin/env python3
"""
Batch script to upload multiple transcripts.
Usage: python batch_upload_transcripts.py video_ids.txt [API_KEY] [SERVER_URL]

The video_ids.txt file should contain one video ID per line.
"""

import sys
import os
from pathlib import Path
from upload_transcript import get_transcript_locally, upload_transcript


def main():
    if len(sys.argv) < 2:
        print("Usage: python batch_upload_transcripts.py video_ids.txt [API_KEY] [SERVER_URL]")
        print("The video_ids.txt file should contain one video ID per line.")
        sys.exit(1)
    
    video_ids_file = sys.argv[1]
    api_key = sys.argv[2] if len(sys.argv) > 2 else os.getenv('TRANSCRIPT_API_KEY')
    server_url = sys.argv[3] if len(sys.argv) > 3 else 'https://summarizer.tpaulshippy.com'
    
    if not api_key:
        print("❌ API key required. Provide it as argument or set TRANSCRIPT_API_KEY environment variable.")
        sys.exit(1)
    
    if not Path(video_ids_file).exists():
        print(f"❌ File not found: {video_ids_file}")
        sys.exit(1)
    
    # Read video IDs from file
    with open(video_ids_file, 'r') as f:
        video_ids = [line.strip() for line in f if line.strip()]
    
    if not video_ids:
        print("❌ No video IDs found in file")
        sys.exit(1)
    
    print(f"📋 Found {len(video_ids)} video IDs to process")
    print(f"🎯 Target server: {server_url}")
    
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
            successful += 1
            
        except Exception as e:
            error_msg = str(e)
            if error_msg == "TRANSCRIPTS_DISABLED":
                transcripts_disabled += 1
            elif error_msg == "IP_BLOCKED":
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


if __name__ == "__main__":
    main()
