class AwardsController < ApplicationController
  # GET /awards
  def index
    @awards = Award.all
  end

  # GET /awards/1
  def show
    @award = Award.find(params[:id])
    @related_awards = Award.find_related_awards(@award)
  end
end
