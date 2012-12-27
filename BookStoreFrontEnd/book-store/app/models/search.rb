class Search
  require 'author'
  require 'book'
  require 'publisher'
  require 'award'

  @@book = 'http://www.owl-ontologies.com/book.owl#'

  @@noise_words = [ 'a', 'about', 'an', 'and', 'are', 'as', 'at', 'be', 'by', 'from', 'how', 'i', 'in', 'is', 'it', 'of',
                    'on', 'or', 'that', 'the', 'this', 'to', 'was', 'we', 'what', 'when', 'where', 'which', 'with']

  def self.tokenizer(query)
    strings = query.downcase.split(/\W+/).reject { |w| @@noise_words.include?(w) }

    words = []
    years = []
    tokens = []

    strings.each do |string|
      token = LABELS[string]
      if token
        tokens << token
      end
      number = string.to_i
      if number > 1900 && number <= Date.today.year
        years << number
      else
        words << string
      end
    end

    return words, years, tokens
  end

  def self.search(words, years, tokens, more_results)
    score = {}

    words.each_with_index do |word, index|
      puts "#{index}: searching for #{word}"
      temp_score = {}

      hash = Ontology.query(" PREFIX book: <http://www.owl-ontologies.com/book.owl#>
                              SELECT ?class ?instance
                              WHERE { ?instance a ?class ;
                                      OPTIONAL { ?instance book:hasName ?name } .
                                      OPTIONAL { ?instance book:hasTitle ?name } .
                                      FILTER regex(?name, '#{word}', 'i' )
                              }
                            ")
      hash['results']['bindings'].each do |resource|
        klass = resource['class']['value']
        uri = resource['instance']['value']

        points = 1

        if tokens.include?(klass)
          points += 5
        end

        if score[uri]
          score[uri][:points] += points
          puts "#{uri} => #{temp_score[uri]}"
        else

          related_to_previous = false
          score.each do |key, value|
            next if value[:klass] == klass

            relations_hash = Ontology.query(" SELECT ?is_related_to
                                              WHERE {
                                                { <#{key}> ?is_related_to <#{uri}> }
                                              UNION
                                                { <#{uri}> ?is_related_to <#{key}> }
                                              }
                                            ")
            n_relations = relations_hash['results']['bindings'].size
            if n_relations > 0
              points += n_relations
              score[key][:points] += n_relations
              related_to_previous = true
            end
          end

          if klass != (@@book + 'Edition')
            temp_score[uri] = {klass: klass, points: points}
            if (related_to_previous || index == 0)
              puts "#{uri} => #{temp_score[uri]}"
            else
              puts "#{uri} => Dead End - No Relation"
            end
          end
        end
      end

      score.merge!(temp_score)

      if more_results
        min_points = index - 1
      else
        min_points = index + 1
      end
      score.reject! { |key, value| value[:points] < min_points }
    end

    score.each do |key, value|
      years.each do |year|
        years_hash = Ontology.query(" PREFIX book: <http://www.owl-ontologies.com/book.owl#>
                                      SELECT ?year
                                      WHERE {
                                        <#{key}> book:hasYear ?year
                                        FILTER regex(?year, '#{year}', 'i' )
                                      }
                                    ")
        if years_hash['results']['bindings'].size > 0
          score[key][:points] += 3
        end
      end
    end

    if !more_results
      min_points = words.length + years.length
      score.reject! { |key, value| value[:points] < min_points }
    end

    models = []
    ranking = []

    resources = score.sort_by {|key, value| -value[:points]}

    resources.each do |resource|
      klass = KLASSES[resource[1][:klass]]
      models << klass.find(resource[0].gsub(@@book, ''))
      ranking << resource[1][:points]
    end

    return ranking, models
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
