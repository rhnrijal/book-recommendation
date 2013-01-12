class BooksController < ApplicationController
  # GET /books
  def index
    @books = Book.all
  end

  # GET /books/1
  def show
    @book = Book.find(params[:id])
    @related_books = Book.find_related_books(@book)
  end
end
