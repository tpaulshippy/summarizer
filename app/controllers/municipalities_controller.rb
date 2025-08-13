class MunicipalitiesController < ApplicationController
  def index
    @municipalities = Municipality.order(:name)
  end

  def show
    @municipality = Municipality.find_by!(slug: params[:id]) rescue Municipality.find(params[:id])
    @meetings = @municipality.meetings.recent
  end
end
