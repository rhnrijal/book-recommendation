class Award < OwlModel
  delegate :url_helpers, to: 'Rails.application.routes'
  attr_accessor :id, :name, :year, :image, :genre, :book, :author

  def to_param
    "#{id} #{name}".parameterize
  end

  def url
    url_helpers.award_path(self)
  end

  def self.all
    # genre image
    hash = Ontology.query(" PREFIX book: <http://www.owl-ontologies.com/book.owl#>
                            SELECT ?award ?name ?year
                            WHERE { ?award a book:Award ;
                                            book:hasName ?name ;
                                            book:hasYear ?year ;
                                  }
                            ORDER BY ASC(?name) DESC(?year)
                          ")
    hash['results']['bindings'].collect do |resource|
      Award.new(id: resource['award']['value'].gsub!(@@book, ''),
                name: resource['name']['value'],
                year: resource['year']['value']
              )
    end
  end

  def self.find(id)
    uri = id.gsub(/-.*/, '')
    hash = Ontology.query(" PREFIX book: <http://www.owl-ontologies.com/book.owl#>
                            SELECT ?name ?year ?winner ?author_name ?book_title
                            WHERE { book:#{uri} a book:Award ;
                                                book:hasName ?name ;
                                                book:hasYear ?year .
                                    ?winner book:hasAward book:#{uri} ;
                                    OPTIONAL { ?winner book:hasName ?author_name } .
                                    OPTIONAL { ?winner book:hasTitle ?book_title }
                                  }
                          ")
    resource = hash['results']['bindings'][0]
    award = Award.new(id: uri,
                      name: resource['name']['value'],
                      year: resource['year']['value']
                    )
    if resource['book_title']['value']
      award.book = Book.new(id: resource['winner']['value'].gsub!(@@book, ''),
                            title: resource['book_title']['value']
                          )
    else
      award.author = Author.new(id: resource['winner']['value'].gsub!(@@book, ''),
                                name: resource['author_name']['value']
                              )
    end
    award
  end

  def self.find_author_awards(author_id)
    author_uri = author_id.gsub(/-.*/, '')
    hash = Ontology.query(" PREFIX book: <http://www.owl-ontologies.com/book.owl#>
                            SELECT ?award ?name ?year ?book ?title
                            WHERE {
                              { ?award a book:Award ;
                                        book:hasName ?name ;
                                        book:hasYear ?year .
                                book:#{author_uri} book:hasAward ?award .
                              } UNION {
                                ?award a book:Award ;
                                        book:hasName ?name ;
                                        book:hasYear ?year .
                                book:#{author_uri} book:hasBook ?book .
                                ?book book:hasAward ?award ;
                                      book:hasTitle ?title
                              }
                            }
                            ORDER BY DESC(?year)
                          ")
    hash['results']['bindings'].collect do |resource|
      award = Award.new(id: resource['award']['value'].gsub!(@@book, ''),
                        name: resource['name']['value'],
                        year: resource['year']['value']
                      )
      if resource['book']
        award.book = Book.new(id: resource['book']['value'].gsub!(@@book, ''),
                              title: resource['title']['value']
                              )
      end
      award
    end
  end

  def self.find_book_awards(book_id)
    book_uri = book_id.gsub(/-.*/, '')
    hash = Ontology.query(" PREFIX book: <http://www.owl-ontologies.com/book.owl#>
                            SELECT ?award ?name ?year
                            WHERE { ?award a book:Award ;
                                            book:hasName ?name ;
                                            book:hasYear ?year .
                                    book:#{book_uri} book:hasAward ?award
                                  }
                            ORDER BY DESC(?year)
                          ")
    hash['results']['bindings'].collect do |resource|
      Award.new(id: resource['award']['value'].gsub!(@@book, ''),
                name: resource['name']['value'],
                year: resource['year']['value']
              )
    end
  end
end
