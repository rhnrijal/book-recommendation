class Award < OwlModel
  delegate :url_helpers, to: 'Rails.application.routes'
  attr_accessor :id, :name, :image, :award_wins

  def to_param
    "#{id} #{name}".parameterize
  end

  def url
    url_helpers.award_path(self)
  end

  def self.all
    hash = Ontology.query(" PREFIX book: <http://www.owl-ontologies.com/book.owl#>
                            SELECT ?award ?name ?image
                            WHERE { ?award a book:Award ;
                                            book:hasName ?name ;
                                            book:hasImage ?image
                                  }
                            ORDER BY ASC(?name)
                          ")
    hash['results']['bindings'].collect do |resource|
      Award.new(id: resource['award']['value'].gsub!(@@book, ''),
                name: resource['name']['value'],
                image: resource['image']['value']
              )
    end
  end

  def self.find(id)
    uri = id.gsub(/-.*/, '')
    hash = Ontology.query(" PREFIX book: <http://www.owl-ontologies.com/book.owl#>
                            SELECT ?name ?image
                            WHERE { book:#{uri} a book:Award ;
                                                book:hasName ?name ;
                                                book:hasImage ?image
                                  }
                          ")
    resource = hash['results']['bindings'][0]
    Award.new(id: uri,
              name: resource['name']['value'],
              image: resource['image']['value'],
              award_wins: AwardWin.find_award_award_wins(uri)
              )
  end
end
