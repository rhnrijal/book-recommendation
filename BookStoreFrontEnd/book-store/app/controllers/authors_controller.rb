class AuthorsController < ApplicationController
  # GET /authors
  def index
    @authors = Author.all
  end

  # GET /authors/1
  def show
    @author = Author.find(params[:id])
  end
end
