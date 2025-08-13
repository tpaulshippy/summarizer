class MeetingsController < ApplicationController
  include Pagy::Backend

  def index
    @pagy, @meetings = pagy(Meeting.includes(:municipality).order(held_on: :desc), items: 20)
    @sort = params[:sort]
    @direction = params[:direction] == 'asc' ? 'asc' : 'desc'

    if @sort.present?
      case @sort
      when 'date'
        @meetings = @meetings.reorder(held_on: @direction)
      when 'meeting_type'
        @meetings = @meetings.reorder(meeting_type: @direction)
      when 'municipality'
        @meetings = @meetings.joins(:municipality).reorder('municipalities.name ' + @direction)
      end
    end
  end

  def show
    @meeting = Meeting.find(params[:id])
  end
end
