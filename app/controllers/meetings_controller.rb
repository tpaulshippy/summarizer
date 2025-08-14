class MeetingsController < ApplicationController
  include Pagy::Backend

  def index
    @sort = params[:sort]
    @direction = params[:direction] == "asc" ? "asc" : "desc"

    meetings_query = Meeting.includes(:municipality)

    if @sort.present?
      case @sort
      when "date"
        meetings_query = meetings_query.order(held_on: @direction)
      when "meeting_type"
        meetings_query = meetings_query.order(meeting_type: @direction)
      when "municipality"
        meetings_query = meetings_query.joins(:municipality).order("municipalities.name #{@direction}")
      else
        meetings_query = meetings_query.order(held_on: :desc)
      end
    else
      meetings_query = meetings_query.order(held_on: :desc)
    end

    @pagy, @meetings = pagy(meetings_query, items: 20)
  end

  def show
    @meeting = Meeting.find(params[:id])
  end
end
