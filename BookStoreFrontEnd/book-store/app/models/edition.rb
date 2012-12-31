class Edition < OwlModel
  delegate :url_helpers, to: 'Rails.application.routes'
  attr_accessor :id, :title, :image, :isbn, :language, :pages, :year, :format, :book, :author, :publisher

  def to_param
    "#{id} #{title}".parameterize
  end

  def url
    url_helpers.edition_path(self)
  end

  def name
    title
  end

  def name=(value)
    @title = value
  end

  def self.find(id)
    uri = id.gsub(/-.*/, '')
    hash = Ontology.query(" PREFIX book: <http://www.owl-ontologies.com/book.owl#>
                            SELECT ?edition ?title ?image ?isbn ?language ?pages ?year ?format ?publisher ?publisher_name ?book ?book_title ?author ?author_name
                            WHERE { book:#{uri} a book:Edition ;
                                                book:hasTitle ?title ;
                                                book:hasImage ?image ;
                                                book:hasISBN ?isbn ;
                                                book:hasLanguage ?language ;
                                                book:hasPages ?pages ;
                                                book:hasYear ?year ;
                                                book:hasFormat ?format .
                                    ?publisher book:hasName ?publisher_name ;
                                               book:hasPublished book:#{uri} .
                                    ?book book:hasEdition book:#{uri} ;
                                          book:hasTitle ?book_title .
                                    ?author book:hasBook ?book ;
                                            book:hasName ?author_name
                                  }
                          ")
    resource = hash['results']['bindings'][0]
    Edition.new(id: id,
                title: resource['title']['value'],
                image: resource['image']['value'],
                isbn: resource['isbn']['value'],
                language: resource['language']['value'],
                pages: resource['pages']['value'],
                year: resource['year']['value'],
                format: resource['format']['value'].gsub!(@@book, ''),
                book: Book.new( id: resource['book']['value'].gsub!(@@book, ''),
                                title: resource['book_title']['value']
                              ),
                author: Author.new( id: resource['author']['value'].gsub!(@@book, ''),
                                    name: resource['author_name']['value']
                                  ),
                publisher: Publisher.new( id: resource['publisher']['value'].gsub!(@@book, ''),
                                          name: resource['publisher_name']['value']
                                        )
                )
  end

  def self.find_book_editions(book_id)
    book_uri = book_id.gsub(/-.*/, '')
    hash = Ontology.query(" PREFIX book: <http://www.owl-ontologies.com/book.owl#>
                            SELECT ?edition ?title ?image ?year
                            WHERE {?edition a book:Edition ;
                                            book:hasTitle ?title ;
                                            book:hasImage ?image ;
                                            book:hasYear ?year .
                                    book:#{book_uri} book:hasEdition ?edition
                                  }
                            ORDER BY ASC(?year)
                          ")
    hash['results']['bindings'].collect do |resource|
      Edition.new(id: resource['edition']['value'].gsub!(@@book, ''),
                  title: resource['title']['value'],
                  image: resource['image']['value']
              )
    end
  end

  def self.find_publisher_editions(publisher_id)
    publisher_uri = publisher_id.gsub(/-.*/, '')
    hash = Ontology.query(" PREFIX book: <http://www.owl-ontologies.com/book.owl#>
                            SELECT ?edition ?title ?image
                            WHERE {?edition a book:Edition ;
                                            book:hasTitle ?title ;
                                            book:hasImage ?image ;
                                            book:hasPublisher book:#{publisher_uri}
                                  }
                          ")
    hash['results']['bindings'].collect do |resource|
      Edition.new(id: resource['edition']['value'].gsub!(@@book, ''),
                  title: resource['title']['value'],
                  image: resource['image']['value']
              )
    end
  end
end
