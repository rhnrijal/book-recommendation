class AuthorsController < ApplicationController
  # GET /authors
  def index
    @authors = Author.all
  end

  # GET /authors/1
  def show
    @author = Author.find(params[:id])
    @books = @author.books
    @related_authors = Author.find_related_authors(@author)
  end
end
