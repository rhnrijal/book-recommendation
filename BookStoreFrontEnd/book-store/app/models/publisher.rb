class Publisher < OwlModel
  delegate :url_helpers, to: 'Rails.application.routes'
  attr_accessor :id, :name, :image, :editions

  def to_param
    "#{id} #{name}".parameterize
  end

  def url
    url_helpers.publisher_path(self)
  end

  def self.all
    hash = Ontology.query(" PREFIX book: <http://www.owl-ontologies.com/book.owl#>
                            SELECT ?publisher ?name
                            WHERE { ?publisher a book:Publisher ;
                                            book:hasName ?name
                                  }
                            ORDER BY ASC(?name)
                          ")
    hash['results']['bindings'].collect do |resource|
      Publisher.new(id: resource['publisher']['value'].gsub!(@@book, ''),
                    name: resource['name']['value']
                  )
    end
  end

  def self.find(id)
    uri = id.gsub(/-.*/, '')
    hash = Ontology.query(" PREFIX book: <http://www.owl-ontologies.com/book.owl#>
                            SELECT ?name
                            WHERE { book:#{uri} a book:Publisher ;
                                                book:hasName ?name
                                  }
                          ")
    resource = hash['results']['bindings'][0]
    Publisher.new(id: uri,
                  name: resource['name']['value'],
                  editions: Edition.find_publisher_editions(uri)
                )
  end

  def self.find_related_publishers(publisher)
    uri = publisher.id

    genre_format_hash = Ontology.query("PREFIX book: <http://www.owl-ontologies.com/book.owl#>
                                        SELECT DISTINCT ?genre (count(?genre) as ?count_g) ?format (count(?format) as ?count_f)
                                        WHERE { book:#{uri} a book:Publisher ;
                                                              book:hasPublished ?edition .
                                                              ?book a book:Book ;
                                                              book:hasEdition ?edition ;
                                                              book:hasGenre ?genre .
                                                ?edition book:hasFormat ?format .
                                        } 
                                        GROUP BY ?genre ?format 
                                        ORDER BY DESC(?count_g) DESC(?count_f)
                                ")

    similar_publishers = []

    genres = genre_format_hash['results']['bindings'].collect do |resource|
      break if similar_publishers.size == @@limit

      genre = resource['genre']['value']
      format = resource['format']['value']

      hash = Ontology.query("PREFIX book: <http://www.owl-ontologies.com/book.owl#>
                                        SELECT DISTINCT ?publisher ?name (count(?genre) as ?count_g)
                                        WHERE {
                                          ?book a book:Book ;
                                            book:hasEdition ?edition ;
                                            book:hasGenre ?genre .
                                          FILTER regex(?genre, \"#{genre}\", 'i')
                                          ?edition book:hasFormat <#{format}> .
                                          ?publisher a book:Publisher ;
                                              book:hasPublished ?edition ;
                                              book:hasName ?name 
                                        } 
                                        GROUP BY ?publisher ?name
                                        ORDER BY DESC(?count_g)
                                        LIMIT #{@@limit - similar_publishers.size}
                                        ")

                                        puts hash                                  

      hash['results']['bindings'].each do |resource|
        break if similar_publishers.size == @@limit
        similar_publishers << Publisher.new(id: resource['publisher']['value'].gsub!(@@book, ''),
                                            name: resource['name']['value']
                                            )
      end
    end

    similar_publishers
  end

end
