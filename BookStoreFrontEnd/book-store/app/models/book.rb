class Book < OwlModel
  delegate :url_helpers, to: 'Rails.application.routes'
  attr_accessor :id, :title, :image, :genre, :author, :editions, :award_wins, :award_win, :year

  def to_param
    "#{id} #{title}".parameterize
  end

  def url
    url_helpers.book_path(self)
  end

  def name
    title
  end

  def name=(value)
    @title = value
  end

  def self.all
    hash = Ontology.query(" PREFIX book: <http://www.owl-ontologies.com/book.owl#>
                            SELECT ?book ?title ?image
                            WHERE { ?book a book:Book ;
                                          book:hasTitle ?title ;
                                          book:hasImage ?image
                                  }
                            ORDER BY ASC(?title)
                            LIMIT 20
                          ")
    hash['results']['bindings'].collect do |resource|
      Book.new( id: resource['book']['value'].gsub!(@@book, ''),
                name: resource['title']['value'],
                image: resource['image']['value']
              )
    end
  end

  def self.find(id)
    uri = id.gsub(/-.*/, '')
    hash = Ontology.query(" PREFIX book: <http://www.owl-ontologies.com/book.owl#>
                            SELECT ?title ?image ?genre ?author ?author_name ?author_image
                            WHERE { book:#{uri} a book:Book ;
                                                book:hasTitle ?title ;
                                                book:hasImage ?image ;
                                                book:hasGenre ?genre .
                                    ?author book:hasBook book:#{uri} ;
                                            book:hasName ?author_name ;
                                            book:hasImage ?author_image
                                  }
                          ")
    resource = hash['results']['bindings'][0]
    Book.new( id: uri,
              title: resource['title']['value'],
              image: resource['image']['value'],
              genre: resource['genre']['value'],
              author: Author.new( id: resource['author']['value'].gsub!(@@book, ''),
                                  name: resource['author_name']['value'],
                                  image: resource['author_image']['value']
                                ),
              editions: Edition.find_book_editions(uri),
              award_wins: AwardWin.find_book_award_wins(uri)
            )
  end

  def self.find_author_books(author_id)
    author_uri = author_id.gsub(/-.*/, '')
    hash = Ontology.query(" PREFIX book: <http://www.owl-ontologies.com/book.owl#>
                            SELECT ?book ?title ?image ?year
                            WHERE { ?book a book:Book ;
                                          book:hasTitle ?title ;
                                          book:hasImage ?image ;
                                          book:hasEdition ?edition .
                                    ?edition book:hasYear ?year .
                                    book:#{author_uri} book:hasBook ?book
                                  }
                            ORDER BY ASC(?year)
                          ")
    resources = hash['results']['bindings'].collect do |resource|
      Book.new( id: resource['book']['value'].gsub!(@@book, ''),
                title: resource['title']['value'],
                image: resource['image']['value'],
                year: resource['year']['value']
              )
    end
    resources.uniq! {|r| r.id}
    resources.sort! { |a,b| b.year <=> a.year }
  end
end
