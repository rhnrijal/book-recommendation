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
end
