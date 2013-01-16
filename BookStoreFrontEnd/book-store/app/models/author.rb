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

  def self.find_related_authors(author)
    uri = author.id

    genres_hash = Ontology.query(" PREFIX book: <http://www.owl-ontologies.com/book.owl#>
                                   SELECT DISTINCT ?genre (count(?genre) as ?count)
                                    WHERE {
                                      book:#{uri} a book:Author ;
                                          book:hasBook ?book .
                                      ?book book:hasGenre ?genre .
                                    } GROUP BY ?genre
                                    ORDER BY DESC(?count)")

    similar_authors = []


    if genres_hash['results']['bindings'][0]['count']['value'].to_i > 0

      genres = genres_hash['results']['bindings'].collect do |resource|
        resource['genre']['value']
      end
      
      genres.each do |genre|
        hash = Ontology.query(" PREFIX book: <http://www.owl-ontologies.com/book.owl#>
                                SELECT DISTINCT ?author ?name ?image (count(?book) as ?count)
                                WHERE {
                                  ?author a book:Author ;
                                      book:hasName ?name ;
                                      book:hasImage ?image ;
                                      book:hasBook ?book .
                                  MINUS { ?author book:hasName ?author_name .
                                          FILTER regex(?author_name, \"#{author.name}\" ,'i')
                                  }
                                  ?book book:hasGenre ?genre .
                                  FILTER regex(?genre, \"#{genre}\", 'i')
                                } GROUP BY ?author ?name ?image
                                ORDER BY DESC(?count)
                                LIMIT #{@@limit - similar_authors.size}")

        if hash['results']['bindings'][0]['count']['value'].to_i > 0

          hash['results']['bindings'].each do |resource|
            break if similar_authors.size == @@limit
            similar_authors << Author.new( id: resource['author']['value'].gsub!(@@book, ''),
                        name: resource['name']['value'],
                        image: resource['image']['value']
                    )
          end
        end
      end
    end

    similar_authors
  end
end
