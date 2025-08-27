#!/usr/bin/env python3
"""
YouTube Transcript Downloader

This script downloads the transcript of a YouTube video and saves it to a text file.
Usage: python get_transcript.py <video_id_or_url> [output_filename]
"""

import sys
import os
import re
from youtube_transcript_api import (
    YouTubeTranscriptApi,
    NoTranscriptFound,
    TranscriptsDisabled,
    VideoUnavailable,
)
from youtube_transcript_api.formatters import TextFormatter
from youtube_transcript_api.proxies import WebshareProxyConfig

from dotenv import load_dotenv

load_dotenv()


def extract_video_id(url_or_id):
    """Extract video ID from YouTube URL or return the ID if already provided."""
    # If it's already just a video ID (11 characters of [A-Za-z0-9_-]), return it
    if re.fullmatch(r"[A-Za-z0-9_-]{11}", url_or_id):
        return url_or_id
    
    # Extract video ID from various YouTube URL formats
    patterns = [
        r'(?:youtube\.com/watch\?v=|youtu\.be/|youtube\.com/embed/)([a-zA-Z0-9_-]{11})',
        r'youtube\.com/watch\?.*v=([a-zA-Z0-9_-]{11})'
    ]
    
    for pattern in patterns:
        match = re.search(pattern, url_or_id)
        if match:
            return match.group(1)
    
    raise ValueError(f"Could not extract video ID from: {url_or_id}")


def get_transcript(video_id, preferred_languages=None):
    """Get the transcript for a YouTube video using sensible language fallbacks."""
    if preferred_languages is None:
        preferred_languages = ["en", "en-US", "en-GB", "en-AU", "en-CA"]

    try:
        # Initialize API client (v1.2.x requires instantiation)
        api = YouTubeTranscriptApi(
            proxy_config=WebshareProxyConfig(
                proxy_username=os.getenv("WEBSHARE_PROXY_USERNAME"),
                proxy_password=os.getenv("WEBSHARE_PROXY_PASSWORD"),
                filter_ip_locations=["us"],
            )
        )
        # Try the advanced API first to pick the best transcript
        transcripts = api.list(video_id)
        try:
            # Prefer manually created subtitles if available
            transcript = transcripts.find_manually_created_transcript(preferred_languages)
        except NoTranscriptFound:
            # Fall back to any transcript in preferred languages (may be auto-generated)
            transcript = transcripts.find_transcript(preferred_languages)

        transcript_list = transcript.fetch()

    except TranscriptsDisabled as e:
        raise Exception("Transcripts are disabled for this video.") from e
    except VideoUnavailable as e:
        raise Exception("The requested video is unavailable.") from e
    except NoTranscriptFound:
        # As a last attempt, let the simple API try with language hints
        try:
            fetched = api.fetch(video_id, languages=preferred_languages)
            transcript_list = fetched
        except NoTranscriptFound as e:
            raise Exception(
                f"No transcript found for languages {preferred_languages}."
            ) from e
    except Exception as e:
        raise Exception(f"Error getting transcript: {str(e)}") from e

    # Format the transcript as plain text
    formatter = TextFormatter()
    text_formatted = formatter.format_transcript(transcript_list)

    return text_formatted, transcript_list


def save_transcript(transcript_text, filename):
    """Save the transcript to a file."""
    try:
        with open(filename, 'w', encoding='utf-8') as f:
            f.write(transcript_text)
        print(f"Transcript saved to: {filename}")
    except Exception as e:
        raise Exception(f"Error saving transcript: {str(e)}")


def main():
    if len(sys.argv) < 2:
        print("Usage: python get_transcript.py <video_id_or_url> [output_filename]")
        print("Example: python get_transcript.py dQw4w9WgXcQ")
        print("Example: python get_transcript.py https://www.youtube.com/watch?v=dQw4w9WgXcQ transcript.txt")
        sys.exit(1)
    
    video_input = sys.argv[1]
    
    # Extract video ID
    try:
        video_id = extract_video_id(video_input)
        print(f"Video ID: {video_id}")
    except ValueError as e:
        print(f"Error: {e}")
        sys.exit(1)
    
    # Set output filename
    if len(sys.argv) >= 3:
        output_filename = sys.argv[2]
    else:
        output_filename = f"{video_id}_transcript.txt"
    
    # Get transcript
    try:
        print("Fetching transcript...")
        transcript_text, transcript_data = get_transcript(video_id)
        
        # Print some info about the transcript
        print(f"Transcript contains {len(transcript_data)} segments")
        
        # Save to file
        save_transcript(transcript_text, output_filename)
        
        # Print first few lines as preview
        lines = transcript_text.split('\n')[:5]
        print("\nPreview:")
        for line in lines:
            if line.strip():
                print(f"  {line}")
        
        if len(transcript_text.split('\n')) > 5:
            print("  ...")
            
    except Exception as e:
        print(f"Error: {e}")
        sys.exit(1)


if __name__ == "__main__":
    main()
