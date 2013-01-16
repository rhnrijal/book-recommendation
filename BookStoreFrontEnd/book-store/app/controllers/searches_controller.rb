class SearchesController < ApplicationController
  def new
    @more_results = (params[:opt] ? true : false)

    @words, years, classes, formats, object_properties, datatype_properties = Search.tokenizer(params[:q])

    tokens = "Words:" + @words.to_yaml +
             "Years:" + years.to_yaml +
             "Classes:" + classes.to_yaml +
             "Formats:" + formats.to_yaml +
             "Object Properties:" + object_properties.to_yaml +
             "Datatype Properties:" + datatype_properties.to_yaml

    # raise tokens

    @ranking, @results = Search.search(@words, years, classes, formats, object_properties, datatype_properties, @more_results)

    # tokens, years, strings = Search.tokenizer(query)

    # if tokens.empty? && years.empty?
    #   @resources = Search.simple(query)
    #   render :simple
    # elsif tokens.empty? && !years.empty?
    #   @resources = Search.with_years(years, strings)
    #   render :with_years
    # elsif tokens.size == 1 && years.empty?
    #   @authors, @awards, @books, @editions, @publishers = Search.with_one_token(tokens[0], strings)
    #   render :with_one_token
    # else
    #   render text: [tokens, years, strings], layout: true and return
    # end

    # render text: results.inspect, layout: true and return

    # book = ['book', 'books', 'livro', 'livros']
    # author = ['author', 'authors', 'writer', 'writers', 'autor', 'autores', 'escritor', 'escritores']

    # book_request = words.any? { |word| book.include?(word) }
    # author_request = words.any? { |word| author.include?(word) }

    # if book_request
    #   name = words.reject { |word| book.include?(word) }.join(' ')
    #   @books = Book.find_by_name(name)
    #   render 'books/index'
    # elsif author_request
    #   name = words.reject { |word| author.include?(word) }.join(' ')
    #   @authors = Author.find_by_name(name)
    #   render 'authors/index'
    # else
    #   render text: 'I have no idea what you want', layout: true
    # end
  end
end
