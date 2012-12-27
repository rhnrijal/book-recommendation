class Author < OwlModel
  delegate :url_helpers, to: 'Rails.application.routes'
  attr_accessor :id, :name, :image, :bio, :books, :awards

  def to_param
    "#{id} #{name}".parameterize
  end

  def url
    url_helpers.author_path(self)
  end

  def self.all
    hash = Ontology.query(" PREFIX book: <http://www.owl-ontologies.com/book.owl#>
                            SELECT ?author ?name ?image
                            WHERE { ?author a book:Author ;
                                            book:hasName ?name ;
                                            book:hasImage ?image
                                  }
                            ORDER BY ASC(?name)
                            LIMIT 150
                          ")
    hash['results']['bindings'].collect do |resource|
      Author.new( id: resource['author']['value'].gsub!(@@book, ''),
                  name: resource['name']['value'],
                  image: resource['image']['value']
              )
    end
  end

  def self.find(id)
    uri = id.gsub(/-.*/, '')
    hash = Ontology.query(" PREFIX book: <http://www.owl-ontologies.com/book.owl#>
                            SELECT ?name ?image ?bio
                            WHERE { book:#{uri} a book:Author ;
                                                book:hasName ?name ;
                                                book:hasImage ?image ;
                                                book:hasBio ?bio
                                  }
                          ")
    resource = hash['results']['bindings'][0]
    Author.new( id: uri,
                name: resource['name']['value'],
                image: resource['image']['value'],
                bio: resource['bio']['value'],
                books: Book.find_author_books(uri),
                awards: Award.find_author_awards(uri)
              )
  end
end
