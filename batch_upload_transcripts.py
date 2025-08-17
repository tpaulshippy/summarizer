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
            print(f"   ❌ Error: {e}")
            failed += 1
    
    print(f"\n📊 Summary:")
    print(f"   ✅ Successful: {successful}")
    print(f"   ❌ Failed: {failed}")
    print(f"   📈 Success rate: {successful/(successful+failed)*100:.1f}%")


if __name__ == "__main__":
    main()
