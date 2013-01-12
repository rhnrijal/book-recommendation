class EditionsController < ApplicationController
  # GET /editions
  def index
    @editions = Edition.all
  end

  # GET /editions/1
  def show
    @edition = Edition.find(params[:id])
    @related_editions = Edition.find_related_editions(@edition)
  end
end
