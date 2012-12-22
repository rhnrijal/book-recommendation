class Search
  @@book = 'http://www.owl-ontologies.com/book.owl#'

  def self.tokenizer(query)
    words = query.split(/\W+/)

    tokens = []
    years = []
    strings = []

    parsing_a_string = false
    words.each do |word|
      token = LABELS[word]
      if token
        tokens << token
        parsing_a_string = false
      else
        number = word.to_i
        if number > 1900 && number <= Date.today.year
          years << number
          parsing_a_string = false
        else
          if parsing_a_string
            strings[strings.length-1] += ' ' + word
          else
            strings << word
            parsing_a_string = true
          end
        end
      end
    end

    return tokens, years, strings
  end

  def self.simple(query)
    hash = Ontology.query(" PREFIX book: <http://www.owl-ontologies.com/book.owl#>
                            PREFIX rdfs: <http://www.w3.org/2000/01/rdf-schema#>
                            SELECT ?class ?instance ?name ?image
                            WHERE {
                              {
                                ?instance a ?class ;
                                OPTIONAL { ?instance book:hasName ?name } .
                                OPTIONAL { ?instance book:hasTitle ?name } .
                                OPTIONAL { ?instance book:hasImage ?image } .
                                FILTER regex(?name, '#{query}', 'i' ) .
                              } UNION {
                                ?instance a ?class ;
                                OPTIONAL { ?instance book:hasName ?name } .
                                OPTIONAL { ?instance book:hasTitle ?name } .
                                OPTIONAL { ?instance book:hasImage ?image } .
                                ?instance book:hasGenre ?genre .
                                FILTER regex(?genre, '#{query}', 'i' )
                              }
                            }
                          ")
    hash['results']['bindings'].collect do |resource|
      klass = KLASSES[resource['class']['value']]
      klass.new(id: resource['instance']['value'].gsub!(@@book, ''),
                name: resource['name']['value'],
                image: resource['image'] ? resource['image']['value'] : nil
              )
    end
  end

  def self.with_years(years, strings)
    resources = []

    # Search for each string in a given year
    strings.each do |string|
      years.each do |year|
        hash = Ontology.query(" PREFIX book: <http://www.owl-ontologies.com/book.owl#>
                                PREFIX rdfs: <http://www.w3.org/2000/01/rdf-schema#>
                                SELECT ?edition ?title ?image ?year
                                WHERE { ?edition a book:Edition ;
                                                 book:hasTitle ?title ;
                                                 book:hasImage ?image ;
                                                 book:hasYear ?year .
                                        FILTER regex(?year, '#{year}', 'i' ) .
                                        FILTER regex(?title, '#{string}', 'i' )
                                }
                              ")
        hash['results']['bindings'].each do |resource|
          resources << Edition.new( id: resource['edition']['value'].gsub!(@@book, ''),
                                    title: resource['title']['value'],
                                    image: resource['image']['value'],
                                    year: resource['year']['value']
                                )
        end
      end
    end

    # Search for books with awards in the given year
    # UNION
    # Years can also be names of books. Example: 1984
    years.each do |year|
      hash = Ontology.query(" PREFIX book: <http://www.owl-ontologies.com/book.owl#>
                              PREFIX rdfs: <http://www.w3.org/2000/01/rdf-schema#>
                              SELECT ?book ?title ?image ?award_win ?award_year ?award_name
                              WHERE {
                                {
                                  ?book a book:Book ;
                                        book:hasTitle ?title ;
                                        book:hasImage ?image ;
                                        book:hasWin ?award_win .
                                  ?award_win book:hasYear ?award_year .
                                  ?award_win book:hasAward ?award .
                                  ?award book:hasName ?award_name .
                                  FILTER regex(?award_year, '#{year}', 'i' ) .
                                } UNION {
                                  ?book a book:Book ;
                                        book:hasTitle ?title ;
                                        book:hasImage ?image .
                                  FILTER regex(?title, '#{year}', 'i' ) .
                                }
                              }
                            ")
      hash['results']['bindings'].each do |resource|
        book = Book.new(id: resource['book']['value'].gsub!(@@book, ''),
                        title: resource['title']['value'],
                        image: resource['image']['value']
                        )
        if resource['award_win']
          book.award_win = AwardWin.new(year: resource['award_year']['value'],
                                        name: resource['award_name']['value']
                                      )
        end
        resources << book
      end
    end

    # If no string is given, search for editions in a given year
    if resources.size < 10
      years.each do |year|
        hash = Ontology.query(" PREFIX book: <http://www.owl-ontologies.com/book.owl#>
                                PREFIX rdfs: <http://www.w3.org/2000/01/rdf-schema#>
                                SELECT ?edition ?title ?image ?year
                                WHERE { ?edition a book:Edition ;
                                                 book:hasTitle ?title ;
                                                 book:hasImage ?image ;
                                                 book:hasYear ?year .
                                        FILTER regex(?year, '#{year}', 'i' )
                                }
                              ")
        hash['results']['bindings'].each do |resource|
          resources << Edition.new( id: resource['edition']['value'].gsub!(@@book, ''),
                                    title: resource['title']['value'],
                                    image: resource['image']['value'],
                                    year: resource['year']['value']
                                  )
        end
      end
    end

    resources
  end

def self.with_one_token(token, strings)

    authors = []
    awards = []
    books = []
    editions = []
    publishers = []

    hash = {}

    strings.each do |string|

      hash = Ontology.query(" PREFIX book: <http://www.owl-ontologies.com/book.owl#>
                              PREFIX rdfs: <http://www.w3.org/2000/01/rdf-schema#>
                              SELECT DISTINCT ?instance ?name ?image ?class
                              WHERE {
                                {
                                    ?instance a <#{token}> ;
                                              a ?class ;
                                    OPTIONAL { ?instance book:hasTitle ?name } .
                                    OPTIONAL { ?instance book:hasName ?name } .
                                    OPTIONAL { ?instance book:hasImage ?image  } .
                                    FILTER regex(?name, '#{string}', 'i' )
                                } UNION {
                                  ?instance a <#{token}> ;
                                            a ?class ;
                                  OPTIONAL { ?instance book:hasTitle ?name } .
                                  OPTIONAL { ?instance book:hasName ?name } .
                                  OPTIONAL { ?instance book:hasImage ?image  } .
                                  
                                  ?related_instance ?has ?instance .
                                  ?related_instance a ?related_instance_class
                                    OPTIONAL { ?related_instance book:hasTitle ?related_name } .
                                    OPTIONAL { ?related_instance book:hasName ?related_name } .
                                    FILTER regex(?related_name, '#{string}', 'i' )
                                }
                              }
                            ")
    
        hash['results']['bindings'].each do |resource|

          if resource['class']['value'] == 'http://www.owl-ontologies.com/book.owl#Author'

            authors << Author.new(id: resource['instance']['value'].gsub!(@@book, ''),
                            name: resource['name']['value'],
                            image: resource['image']['value'])

          elsif resource['class']['value'] == 'http://www.owl-ontologies.com/book.owl#Award'

            awards <<  Award.new(id: resource['instance']['value'].gsub!(@@book, ''),
                            name: resource['name']['value'],
                            image: resource['image']['value'])

          elsif resource['class']['value'] == 'http://www.owl-ontologies.com/book.owl#Book'
            
            books << Book.new(id: resource['instance']['value'].gsub!(@@book, ''),
                            title: resource['name']['value'],
                            image: resource['image']['value']
                            )

          elsif resource['class']['value'] == 'http://www.owl-ontologies.com/book.owl#Edition'
            editions <<  Edition.new(id: resource['instance']['value'].gsub!(@@book, ''),
                                    title: resource['name']['value'],
                                    image: resource['image']['value']
                                  )

          elsif resource['class']['value'] == 'http://www.owl-ontologies.com/book.owl#Publisher'

            publishers << Publisher.new(id: resource['instance']['value'].gsub!(@@book, ''),
                                    name: resource['name']['value'])

          end
        end
      end
      return authors, awards, books, editions, publishers
  end
end
