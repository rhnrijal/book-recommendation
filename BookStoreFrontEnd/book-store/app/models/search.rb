class Search
  require 'author'
  require 'book'
  require 'edition'
  require 'publisher'
  require 'award'



  @@book = 'http://www.owl-ontologies.com/book.owl#'

  @@en_noise_words = [ 'a', 'an', 'and', 'are', 'as', 'at', 'be', 'by', 'from', 'how', 'i', 'in', 'is', 'it', 'of',
                    'on', 'or', 'that', 'the', 'this', 'to', 'was', 'we']

  @@pt_noise_words = ['de', 'a', 'o', 'que', 'e', 'do', 'da', 'em', 'um', 'para', 'com', 'no', 'uma', 'os', 'no', 'se',
                      'na', 'por', 'mais', 'as', 'dos', 'como', 'mas', 'foi', 'ao', 'ele', 'das', 'tem', 'seu', 'sua', 'ou',
                      'ser', 'quando', 'muito', 'h', 'nos', 'j', 'est', 'eu', 'tambm', 's', 'pelo', 'pela', 'at', 'isso',
                      'ela', 'entre', 'era', 'depois', 'sem', 'mesmo', 'aos', 'ter', 'seus', 'quem', 'nas', 'me', 'esse',
                      'eles', 'est', 'essa', 'num', 'nem', 'suas', 'meu', 's', 'minha', 'tm', 'numa', 'pelos', 'elas', 'havia',
                      'seja', 'qual', 'ser', 'ns', 'lhe', 'deles', 'essas', 'esses', 'pelas', 'este']

  @@points_at_start = 1
  @@points_for_property = 3
  @@points_for_belonging_to_class = 1
  @@points_for_looking_like_class = 1
  @@points_for_relation = 1
  @@points_for_year = 3
  @@points_for_format = 2

  def self.tokenizer(query)
    years = []
    classes = []
    formats = []
    object_properties = []
    datatype_properties = []

    downcased_query = query.downcase
    tokens = downcased_query.split(/\W+/)
    stems = Array(Lingua.stemmer(tokens)).join(' ')

    OBJECT_PROPERTIES.each do |object_property, uri|
      if stems.slice!(object_property)
        object_properties << uri
      end
    end

    DATATYPE_PROPERTIES.each do |datatype_property, uri|
      if stems.slice!(datatype_property)
        datatype_properties << uri
      end
    end

    CLASSES.each do |klass, uri|
      if stems.slice!(klass)
        classes << uri
      end
    end

    tokens.delete_if do |token|
      format_uri = FORMATS[token]
      if format_uri
        formats << format_uri
        true
      end
    end

    words = tokens.reject { |token| @@en_noise_words.include?(token) || @@pt_noise_words.include?(token) || !stems.include?(Lingua.stemmer(token)) }

    words.each do |word|
      number = word.to_i
      if number > 1900 && number <= Date.today.year
        years << number
      end
    end

    return words, years, classes, formats, object_properties, datatype_properties
  end

  def self.search(words, years, classes, formats, object_properties, datatype_properties, more_results)
    score = {}

    if object_properties.empty?
      puts 'Searching without object_properties'

      words.each_with_index do |word, index|
        puts "#{index}: searching for #{word}"
        temp_score = {}

        hash = Ontology.query(" PREFIX book: <http://www.owl-ontologies.com/book.owl#>
                                SELECT ?class ?instance
                                WHERE { ?instance a ?class ;
                                        OPTIONAL { ?instance book:hasName ?name } .
                                        OPTIONAL { ?instance book:hasTitle ?name } .
                                        FILTER regex(?name, '#{word}', 'i' )
                                        FILTER NOT EXISTS { ?instance a book:Edition }
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

            if (related_to_previous || index == 0 || more_results)
              temp_score[uri] = {klass: klass, points: points}
              puts "#{uri} => #{temp_score[uri]}"
            else
              puts "#{uri} => Dead End - No Relation"
            end
          end
        end

        score.merge!(temp_score)
      end

    else
      puts 'Searching with object_properties!'

      object_properties.each do |property|
        words.each_with_index do |word, index|
          puts "#{index}: searching for #{word}"

          hash = Ontology.query(" PREFIX book: <http://www.owl-ontologies.com/book.owl#>
                                  SELECT ?class ?instance
                                  WHERE { ?instance a ?class .
                                          ?related_instance a ?related_class .
                                          ?related_instance <#{property}> ?instance .
                                          ?related_instance book:hasName ?name .
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

    if words.length == (years.length + classes.length)
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
          points = @@points_for_year

          if classes.include?('http://www.owl-ontologies.com/book.owl#Book') && klass == 'http://www.owl-ontologies.com/book.owl#Edition'
            points += @@points_for_looking_like_class
          end

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

    if !formats.empty?
      editions_to_delete = []
      temp_score = {}

      formats.each_with_index do |format, index|
        puts "#{index}: searching for #{format}"
        score.each do |key, value|
          if value[:klass] == 'http://www.owl-ontologies.com/book.owl#Book'

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
                puts "#{uri} => #{temp_score[uri]}"
              end
            end

          elsif value[:klass] == 'http://www.owl-ontologies.com/book.owl#Edition'

            formats_hash = Ontology.query(" PREFIX book: <http://www.owl-ontologies.com/book.owl#>
                                            SELECT ?class ?instance
                                            WHERE { <#{key}> book:hasFormat <#{format}> }
                                          ")
            if formats_hash['results']['bindings'].size == 0
              editions_to_delete << key
            end
          else

            next

          end
        end
      end

      score.delete_if {|key, value| (value[:klass] == 'http://www.owl-ontologies.com/book.owl#Book') || (editions_to_delete.include? key) }
      score.merge!(temp_score)
    end

    if !more_results
      min_points = words.length - classes.length
      if !years.empty?
        min_points = min_points - years.length + @@points_for_year
      end
      if !formats.empty?
        min_points = min_points + @@points_for_format
      end
      puts 'XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX'
      puts "Minimum points needed = #{min_points}"
      score.delete_if { |key, value| value[:points] < min_points }
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
end
