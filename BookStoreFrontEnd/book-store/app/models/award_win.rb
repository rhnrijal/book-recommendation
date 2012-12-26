class AwardWin < OwlModel
  delegate :url_helpers, to: 'Rails.application.routes'
  attr_accessor :id, :genre, :year, :book, :author, :award, :name

  def to_param
    id
  end

  def url
    url_helpers.award_path(self)
  end

  def self.find_book_award_wins(book_id)
    book_uri = book_id.gsub(/-.*/, '')
    hash = Ontology.query(" PREFIX book: <http://www.owl-ontologies.com/book.owl#>
                            SELECT ?award_win ?year ?genre ?award ?name ?image
                            WHERE { ?award_win a book:AwardWin ;
                                               book:hasYear ?year ;
                                               book:hasGenre ?genre ;
                                               book:hasAward ?award .
                                    ?award book:hasName ?name ;
                                           book:hasImage ?image .
                                    book:#{book_uri} book:hasWin ?award_win
                                  }
                            ORDER BY DESC(?year)
                          ")
    hash['results']['bindings'].collect do |resource|
      AwardWin.new( id: resource['award_win']['value'].gsub!(@@book, ''),
                    year: resource['year']['value'],
                    genre: resource['genre']['value'],
                    award: Award.new( id: resource['award']['value'].gsub!(@@book, ''),
                                      name: resource['name']['value'],
                                      image: resource['image']['value']
                                    )
                  )
    end
  end

  def self.find_author_award_wins(author_id)
    author_uri = author_id.gsub(/-.*/, '')
    hash = Ontology.query(" PREFIX book: <http://www.owl-ontologies.com/book.owl#>
                            SELECT ?award_win ?year ?genre ?award ?name ?book ?image ?title
                            WHERE {
                              { ?award_win a book:AwardWin ;
                                           book:hasYear ?year ;
                                           book:hasGenre ?genre ;
                                           book:hasAward ?award .
                                ?award book:hasName ?name ;
                                       book:hasImage ?image .
                                book:#{author_uri} book:hasWin ?award_win .
                              } UNION {
                                ?award_win a book:AwardWin ;
                                           book:hasYear ?year ;
                                           book:hasGenre ?genre ;
                                           book:hasAward ?award .
                                ?award book:hasName ?name ;
                                       book:hasImage ?image .
                                book:#{author_uri} book:hasBook ?book .
                                ?book book:hasWin ?award_win ;
                                      book:hasTitle ?title
                              }
                            }
                            ORDER BY DESC(?year)
                          ")
    hash['results']['bindings'].collect do |resource|
      award_win = AwardWin.new( id: resource['award_win']['value'].gsub!(@@book, ''),
                                year: resource['year']['value'],
                                genre: resource['genre']['value'],
                                award: Award.new( id: resource['award']['value'].gsub!(@@book, ''),
                                                  name: resource['name']['value'],
                                                  image: resource['image']['value']
                                                )
                              )
      if resource['book']
        award_win.book = Book.new(id: resource['book']['value'].gsub!(@@book, ''),
                                  title: resource['title']['value']
                                  )
      end
      award_win
    end
  end

  def self.find_award_award_wins(award_id)
    award_uri = award_id.gsub(/-.*/, '')
    hash = Ontology.query(" PREFIX book: <http://www.owl-ontologies.com/book.owl#>
                            SELECT ?award_win ?year ?genre ?book ?book_title
                            WHERE { ?award_win a book:AwardWin ;
                                              book:hasYear ?year ;
                                              book:hasGenre ?genre ;
                                              book:hasAward book:#{award_uri} .
                                    ?book book:hasWin ?award_win ;
                                          book:hasTitle ?book_title .
                                  }
                            ORDER BY DESC(?year)
                          ")
    results = hash['results']['bindings'].collect do |resource|
      AwardWin.new( id: resource['award_win']['value'].gsub!(@@book, ''),
                    year: resource['year']['value'],
                    genre: resource['genre']['value'],
                    book: Book.new( id: resource['book']['value'].gsub!(@@book, ''),
                                    title: resource['book_title']['value']
                                  )
              )
    end

    if results.empty?
      hash = Ontology.query(" PREFIX book: <http://www.owl-ontologies.com/book.owl#>
                              SELECT ?award_win ?year ?genre ?author ?name
                              WHERE { ?award_win a book:AwardWin ;
                                                book:hasYear ?year ;
                                                book:hasGenre ?genre ;
                                                book:hasAward book:#{award_uri} .
                                      ?author book:hasWin ?award_win ;
                                            book:hasName ?name .
                                    }
                              ORDER BY DESC(?year)
                            ")
      results = hash['results']['bindings'].collect do |resource|
        AwardWin.new( id: resource['award_win']['value'].gsub!(@@book, ''),
                      year: resource['year']['value'],
                      genre: resource['genre']['value'],
                      author: Author.new( id: resource['author']['value'].gsub!(@@book, ''),
                                          name: resource['name']['value']
                                    )
                )
      end
    end

    results
  end
end
