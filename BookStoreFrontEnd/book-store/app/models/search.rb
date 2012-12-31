class Search
  require 'author'
  require 'book'
  require 'edition'
  require 'publisher'
  require 'award'

  @@book = 'http://www.owl-ontologies.com/book.owl#'

  @@noise_words = [ 'a', 'an', 'and', 'are', 'as', 'at', 'be', 'by', 'from', 'how', 'i', 'in', 'is', 'it', 'of',
                    'on', 'or', 'that', 'the', 'this', 'to', 'was', 'we']

  @@points_at_start = 1
  @@points_for_property = 3
  @@points_for_belonging_to_class = 3
  @@points_for_relation = 1
  @@points_for_year = 3
  @@points_for_solo_year = 1
  @@points_for_format = 2

  def self.tokenizer(query)
    years = []
    classes = []
    formats = []
    properties = []

    downcased_query = query.downcase

    FORMATS.each do |format, uri|
      if downcased_query.slice!(format)
        formats << uri
      end
    end

    PROPERTIES.each do |format, uri|
      if downcased_query.slice!(format)
        properties << uri
      end
    end

    words = downcased_query.split(/\W+/).reject { |w| w.length < 3 || @@noise_words.include?(w) }

    words.each do |word|
      klass = CLASSES[word]
      if klass
        classes << klass
      end
      number = word.to_i
      if number > 1900 && number <= Date.today.year
        years << number
      end
    end

    return words, years, classes, formats, properties
  end

  def self.search(words, years, classes, formats, properties, more_results)
    score = {}

    if properties.empty?
      puts 'Searching without properties'

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

          points = @@points_at_start

          if classes.include?(klass)
            points += @@points_for_belonging_to_class
          end

          if score[uri]
            score[uri][:points] += points
            puts "#{uri} => #{score[uri]}"
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
                score[key][:points] += @@points_for_relation
                related_to_previous = true
              end
            end

            if klass != (@@book + 'Edition')
              if (related_to_previous || index == 0 || more_results)
                temp_score[uri] = {klass: klass, points: points}
                puts "#{uri} => #{temp_score[uri]}"
              else
                puts "#{uri} => Dead End - No Relation"
              end
            end
          end
        end

        score.merge!(temp_score)
      end

    else
      puts 'Searching with properties!'

      properties.each do |property|
        words.each_with_index do |word, index|
          puts "#{index}: searching for #{word}"

          hash = Ontology.query(" PREFIX book: <http://www.owl-ontologies.com/book.owl#>
                                  SELECT ?class ?instance
                                  WHERE { ?related_instance a ?related_class .
                                          ?related_instance <#{property}> ?instance .
                                          ?instance a ?class .
                                          OPTIONAL { ?related_instance book:hasName ?name } .
                                          OPTIONAL { ?related_instance book:hasTitle ?name } .
                                          FILTER regex(?name, '#{word}', 'i' )
                                  }
                                ")
          hash['results']['bindings'].each do |resource|
            klass = resource['class']['value']
            uri = resource['instance']['value']

            points = @@points_for_property

            if score[uri]
              score[uri][:points] += points
              puts "#{uri} => #{score[uri]}"
            else
              score[uri] = {klass: klass, points: points}
              puts "#{uri} => #{score[uri]}"
            end
          end
        end
      end
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
          score[key][:points] += @@points_for_year
        end
      end
    end

    if words.length == years.length   # if there are only years
      years.each do |year|
        years_hash = Ontology.query(" PREFIX book: <http://www.owl-ontologies.com/book.owl#>
                                      SELECT ?class ?instance
                                      WHERE {
                                        ?instance a ?class ;
                                                  book:hasYear ?year
                                        FILTER regex(?year, '#{year}', 'i' )
                                      }
                                    ")
        years_hash['results']['bindings'].each do |resource|
          klass = resource['class']['value']
          uri = resource['instance']['value']
          if score[uri]
            score[uri][:points] += @@points_for_solo_year
            puts "#{uri} => #{score[uri]}"
          else
            score[uri] = {klass: klass, points: @@points_at_start}
            puts "#{uri} => #{score[uri]}"
          end
        end
      end
    end

    if !more_results
      min_points = words.length - classes.length
      if !years.empty?
        min_points = min_points - years.length + @@points_for_year
      end
      score.delete_if { |key, value| value[:points] < min_points }
    end

    if !formats.empty?
      books_to_delete = []
      temp_score = {}

      formats.each_with_index do |format, index|
        puts "#{index}: searching for #{format}"
        score.each do |key, value|
          next if value[:klass] != 'http://www.owl-ontologies.com/book.owl#Book'

          formats_hash = Ontology.query(" PREFIX book: <http://www.owl-ontologies.com/book.owl#>
                                          SELECT ?class ?instance
                                          WHERE { ?instance a ?class ;
                                                            book:hasFormat <#{format}> .
                                                  <#{key}> book:hasEdition ?instance
                                                }
                                        ")
          formats_hash['results']['bindings'].each do |resource|
            klass = resource['class']['value']
            uri = resource['instance']['value']
            if temp_score[uri]
              temp_score[uri][:points] += @@points_for_format
              puts "#{uri} => #{temp_score[uri]}"
            else
              temp_score[uri] = {klass: klass, points: value[:points] + @@points_for_format}
              books_to_delete << key
              puts "#{uri} => #{temp_score[uri]}"
            end
          end
        end
      end

      score.delete_if {|key, value| value[:klass] == 'http://www.owl-ontologies.com/book.owl#Book' }
      score.merge!(temp_score)
    end

    models = []
    ranking = []

    resources = score.sort_by { |key, value| -value[:points] }

    resources.each do |resource|
      model = MODELS[resource[1][:klass]]
      models << model.find(resource[0].gsub(@@book, ''))
      ranking << resource[1][:points]
    end

    return ranking, models
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
