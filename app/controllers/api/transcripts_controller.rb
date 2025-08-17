class Api::TranscriptsController < ApplicationController
  protect_from_forgery with: :null_session
  before_action :authenticate_api_request
  before_action :find_meeting, only: [:create]

  def index
    meetings_without_transcripts = Meeting.where(transcript: [nil, ""]).limit(100)
    video_ids = meetings_without_transcripts.pluck(:video_id)
    
    render json: {
      video_ids: video_ids,
      count: video_ids.length,
      message: "#{video_ids.length} meetings need transcripts"
    }
  rescue => e
    Rails.logger.error("Error fetching missing transcripts: #{e.message}")
    render json: { error: "Internal server error" }, status: :internal_server_error
  end

  def create
    transcript_text = params[:transcript]
    
    if transcript_text.blank?
      render json: { error: "Transcript text is required" }, status: :bad_request
      return
    end

    if @meeting.update(transcript: transcript_text)
      render json: { 
        message: "Transcript uploaded successfully", 
        meeting_id: @meeting.id,
        video_id: @meeting.video_id
      }, status: :ok
    else
      render json: { 
        error: "Failed to save transcript", 
        errors: @meeting.errors.full_messages 
      }, status: :unprocessable_entity
    end
  rescue => e
    Rails.logger.error("Transcript upload error: #{e.message}")
    render json: { error: "Internal server error" }, status: :internal_server_error
  end

  private

  def authenticate_api_request
    api_key = request.headers['X-API-Key'] || params[:api_key]
    expected_key = Rails.application.credentials.dig(:api, :transcript_upload_key) || ENV['TRANSCRIPT_API_KEY']
    
    if expected_key.blank?
      Rails.logger.error("No API key configured for transcript uploads")
      render json: { error: "API key not configured" }, status: :internal_server_error
      return
    end

    unless api_key == expected_key
      render json: { error: "Invalid API key" }, status: :unauthorized
    end
  end

  def find_meeting
    video_id = params[:video_id]
    
    if video_id.blank?
      render json: { error: "Video ID is required" }, status: :bad_request
      return
    end

    @meeting = Meeting.find_by(video_id: video_id)
    
    unless @meeting
      render json: { error: "Meeting not found for video ID: #{video_id}" }, status: :not_found
    end
  end
end
