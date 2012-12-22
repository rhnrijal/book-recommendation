class AwardsController < ApplicationController
  # GET /awards
  def index
    @awards = Award.all
  end

  # GET /awards/1
  def show
    @award = Award.find(params[:id])
  end
end
