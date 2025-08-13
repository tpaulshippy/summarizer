
Take a look at Sources.md and build a system that will do the following:
1. Scrape these playlists every day and look for a new video.
2. Get the transcript any new video using get_transcript.py (or a similar ruby script).
3. Save the transcript to a database with a date and meeting type and municipality name.
4. Use the RubyLLM gem with the Claude Haiku 3.5 model to summarize the meeting.
5. Build a beautiful interface that shows a page for each meeting summary with links back to the full videos. 
6. Make the main list paged, sortable by date, meeting type and municipality.

Build this using Ruby on Rails 8 with Hotwire Turbo and Tailwind 4 and Pagy.