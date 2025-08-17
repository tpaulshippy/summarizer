# Transcript Upload Functionality

This document explains how to upload transcripts from your local machine to the cloud server when YouTube blocks direct transcript fetching.

## Setup

1. **Set up your API key**: You'll need to configure an API key for authentication.

   In production, set the environment variable:
   ```bash
   export TRANSCRIPT_API_KEY="your_secure_api_key_here"
   ```

   Or add it to your Rails credentials:
   ```bash
   rails credentials:edit
   ```
   ```yaml
   api:
     transcript_upload_key: your_secure_api_key_here
   ```

2. **Make sure your local environment works**: Ensure you can fetch transcripts locally using the existing `get_transcript.py` script.

## Usage

### Upload a Single Transcript

```bash
# Using environment variable for API key
export TRANSCRIPT_API_KEY="your_api_key"
python upload_transcript.py VIDEO_ID

# Or provide API key as argument
python upload_transcript.py VIDEO_ID your_api_key

# Custom server URL (defaults to https://summarizer.tpaulshippy.com)
python upload_transcript.py VIDEO_ID your_api_key https://your-server.com
```

### Example

```bash
python upload_transcript.py abc123xyz my_secret_key
```

This will:
1. Fetch the transcript for video ID `abc123xyz` using your local Python environment
2. Upload it to the server via the API
3. The server will find the matching meeting and save the transcript

### Batch Upload Multiple Transcripts

For uploading many transcripts at once:

1. Create a text file with video IDs (one per line):
   ```bash
   echo -e "abc123xyz\ndef456uvw\nghi789rst" > video_ids.txt
   ```

2. Run the batch upload script:
   ```bash
   python batch_upload_transcripts.py video_ids.txt your_api_key
   ```

The batch script will:
- Process each video ID in sequence
- Show progress for each upload
- Provide a summary of successful vs failed uploads
- Continue processing even if some uploads fail

## API Endpoint

The server exposes a REST API endpoint:

**POST** `/api/transcripts`

**Headers:**
- `X-API-Key: your_api_key`
- `Content-Type: application/json`

**Request Body:**
```json
{
  "video_id": "abc123xyz",
  "transcript": "The full transcript text..."
}
```

**Response (Success):**
```json
{
  "message": "Transcript uploaded successfully",
  "meeting_id": 123,
  "video_id": "abc123xyz"
}
```

**Response (Error):**
```json
{
  "error": "Meeting not found for video ID: abc123xyz"
}
```

## How It Works

1. **Cloud Environment Detection**: The `TranscriptFetcher` automatically detects when running in a cloud environment and skips transcript fetching to avoid YouTube blocks.

2. **Local Fetching**: You run the `upload_transcript.py` script locally where YouTube access works.

3. **Secure Upload**: The script uploads transcripts via an authenticated API endpoint.

4. **Meeting Matching**: The server finds the meeting with the matching `video_id` and saves the transcript.

## Security

- API key authentication prevents unauthorized uploads
- The endpoint only accepts transcripts for existing meetings
- All requests are logged for monitoring

## Troubleshooting

- **"Meeting not found"**: Make sure the meeting with that video_id exists in the database
- **"Invalid API key"**: Check your API key configuration
- **Local fetch fails**: Ensure your virtual environment and `get_transcript.py` work locally
- **Upload fails**: Check network connectivity and server availability
