# encoding: UTF-8

class Search
  require 'author'
  require 'book'
  require 'edition'
  require 'publisher'
  require 'award'

  attr_accessor :query, :tokens, :stems, :words, :years, :classes, :formats, :more_results,
                :object_properties, :datatype_properties, :languages, :score

  @@book = 'http://www.owl-ontologies.com/book.owl#'

  @@accepted_languages = {'português' => 'Portuguese', 'portuguese' => 'Portuguese', 'english' => 'English', 'inglês' => 'English'}

  @@en_noise_words = ['a', 'an', 'and', 'are', 'as', 'at', 'be', 'by', 'from', 'how', 'i', 'in',
                      'is', 'it', 'of', 'on', 'or', 'that', 'the', 'this', 'to', 'was', 'we']

  @@pt_noise_words = ['de', 'a', 'o', 'que', 'e', 'do', 'da', 'em', 'um', 'para', 'com', 'no', 'uma',
                      'os', 'no', 'se', 'na', 'por', 'mais', 'as', 'dos', 'como', 'mas', 'foi', 'ao',
                      'ele', 'das', 'tem', 'seu', 'sua', 'ou', 'ser', 'quando', 'muito', 'nos',
                      'está', 'eu', 'pelo', 'pela', 'at', 'isso', 'ela', 'entre', 'era', 'depois',
                      'sem', 'mesmo', 'aos', 'ter', 'seus', 'quem', 'nas', 'me', 'esse', 'eles', 'est',
                      'essa', 'num', 'nem', 'suas', 'meu', 'minha', 'numa', 'pelos', 'elas',
                      'havia', 'seja', 'qual', 'ser', 'ns', 'lhe', 'deles', 'essas', 'esses', 'pelas', 'este']

  @@points_at_start = 1
  @@points_for_property = 2
  @@points_for_class = 1
  @@points_for_relation = 2
  @@points_for_year = 1
  @@points_for_format = 6
  @@points_for_language = 6

  def initialize(query, more_results)
    @query = query
    @more_results = more_results
    @score = {}
    @years = []
    @classes = []
    @formats = []
    @object_properties = []
    @datatype_properties = []
    @languages = []
    @tokens = query.downcase.split(/[\s,']+/)
    @stems = Array(Lingua.stemmer(@tokens))

    _tokens = @tokens
    singulars = @tokens.collect { |token| token.singularize }.join(' ')

    OBJECT_PROPERTIES.each do |object_property, uri|
      if singulars.slice!(object_property)
        @object_properties << uri
      end
    end

    DATATYPE_PROPERTIES.each do |datatype_property, uri|
      if singulars.slice!(datatype_property)
        @datatype_properties << uri
      end
    end

    _tokens.delete_if do |token|
      delete = false

      format_uri = FORMATS[token]
      if format_uri
        @formats << format_uri
        delete = true
      end

      class_uri = CLASSES[Lingua.stemmer(token)] || CLASSES[token.singularize]
      if class_uri
        @classes << class_uri
        delete = true
      end

      language = @@accepted_languages[token]
      if language
        languages << language
        delete = true
      end
      delete
    end

    # if classes.include?('http://www.owl-ontologies.com/book.owl#Book')
    #   classes << 'http://www.owl-ontologies.com/book.owl#Edition'
    # end

    @words = _tokens.reject do |token|
      @@en_noise_words.include?(token) || @@pt_noise_words.include?(token) || !singulars.include?(token.singularize)
    end

    @words.each do |word|
      number = word.to_i
      if number > 1900 && number <= Date.today.year
        @years << number
      end
    end
  end

  def with_words
    @words.each_with_index do |word, index|
      puts "#{index}: searching for #{word}"
      temp_score = {}

      hash = Ontology.query(" PREFIX book: <http://www.owl-ontologies.com/book.owl#>
                              SELECT ?class ?instance
                              WHERE {
                                {
                                  ?instance a ?class .
                                  ?instance book:hasName ?name
                                  FILTER regex(?name, \"#{word}\", 'i' )
                                  FILTER NOT EXISTS { ?instance a book:Edition } .
                                } UNION {
                                  ?instance a ?class .
                                  ?instance book:hasTitle ?name
                                  FILTER regex(?name, \"#{word}\", 'i' )
                                  FILTER NOT EXISTS { ?instance a book:Edition } .
                                } UNION {
                                  ?instance a ?class .
                                  ?instance book:hasGenre ?name
                                  FILTER regex(?name, \"#{word}\", 'i' )
                                  FILTER NOT EXISTS { ?instance a book:Edition } .
                                }
                              }
                            ")
      hash['results']['bindings'].each do |resource|
        klass = resource['class']['value']
        uri = resource['instance']['value']

        points = @@points_at_start

        if classes.include?(klass)
          points += @@points_for_class
        end

        if @score[uri]
          @score[uri][:points] += points
          puts "#{uri} => #{@score[uri]}"
        else
          related_to_previous = false
          @score.each do |key, value|
            next if value[:klass] == klass  # In this Ontology, instances of a class aren't related to instances of the same class

            relations_hash = Ontology.query(" SELECT ?is_related_to
                                              WHERE {
                                                { <#{key}> ?is_related_to <#{uri}> }
                                              UNION
                                                { <#{uri}> ?is_related_to <#{key}> }
                                              }
                                            ")
            n_relations = relations_hash['results']['bindings'].size
            if n_relations > 0
              points += @@points_for_relation
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
      @score.merge!(temp_score)
    end
  end

  def with_object_properties
    temp_score = {}

    @object_properties.each_with_index do |property, property_index|
      puts "#{property_index}: searching for #{property}"
      @score.each do |key, value|
        property_hash = Ontology.query("PREFIX book: <http://www.owl-ontologies.com/book.owl#>
                                        SELECT ?class ?instance
                                        WHERE {
                                          ?instance a ?class .
                                          <#{key}> <#{property}> ?instance
                                        }
                                      ")
        property_hash['results']['bindings'].each do |resource|
          klass = resource['class']['value']
          uri = resource['instance']['value']
          points = value[:points] + @@points_for_property
          if @score[uri]
            @score[uri][:points] += points
          elsif temp_score[uri]
            temp_score[uri][:points] += points
            puts "#{uri} => #{temp_score[uri]}"
          else
            temp_score[uri] = {klass: klass, points: points}
            puts "#{uri} => #{temp_score[uri]}"
          end
        end
      end
    end
    @score.merge!(temp_score)
  end

  def with_classes
    temp_score = {}

    @classes.each_with_index do |klass, index|
      puts "#{index}: searching for #{klass}"
      @score.each do |key, value|
        if value[:klass] == klass
          value[:points] += @@points_for_class
        else
          class_hash = Ontology.query(" PREFIX book: <http://www.owl-ontologies.com/book.owl#>
                                        SELECT ?instance
                                        WHERE {
                                          { 
                                            ?instance a <#{klass}> .
                                            ?instance ?is_related_to <#{key}>
                                          } UNION {
                                            ?instance a <#{klass}> .
                                            <#{key}> ?is_related_to ?instance
                                          }
                                        }
                                      ")
          class_hash['results']['bindings'].each do |resource|
            uri = resource['instance']['value']
            points = value[:points] + @@points_for_class
            if @score[uri]
              @score[uri][:points] += points
              puts "#{uri} => #{@score[uri]}"
            elsif temp_score[uri]
              temp_score[uri][:points] += points
              puts "#{uri} => #{temp_score[uri]}"
            else
              temp_score[uri] = {klass: klass, points: points}
              puts "#{uri} => #{temp_score[uri]}"
            end
          end
        end
      end
    end
    @score.merge!(temp_score)
  end

  def everything_with_years
    temp_score = {}

    @years.each_with_index do |year, index|
      puts "#{index}: searching for #{year}"

      years_hash = Ontology.query(" PREFIX book: <http://www.owl-ontologies.com/book.owl#>
                                    SELECT ?class ?instance
                                    WHERE {
                                      ?instance a ?class ;
                                                book:hasYear '#{year}' .
                                    }
                                  ")
      years_hash['results']['bindings'].each do |resource|
        klass = resource['class']['value']
        uri = resource['instance']['value']
        if @score[uri]
          @score[uri][:points] += @@points_for_year
          puts "#{uri} => #{@score[uri]}"
        elsif temp_score[uri]
          temp_score[uri][:points] += @@points_for_year
          puts "#{uri} => #{temp_score[uri]}"
        else
          temp_score[uri] = {klass: klass, points: @@points_for_year}
          puts "#{uri} => #{temp_score[uri]}"
        end
      end
    end
    @score.merge!(temp_score)
  end

  def with_years
    temp_score = {}

    @years.each_with_index do |year, index|
      puts "#{index}: searching for #{year}"
      @score.each do |key, value|
        if value[:klass] == 'http://www.owl-ontologies.com/book.owl#Award' || value[:klass] == 'http://www.owl-ontologies.com/book.owl#Edition'

          years_hash = Ontology.query(" PREFIX book: <http://www.owl-ontologies.com/book.owl#>
                                        SELECT (count(*) as ?count)
                                        WHERE { <#{key}> book:hasYear '#{year}' }
                                      ")
          if years_hash['results']['bindings'][0]['count']['value'].to_i > 0
            value[:points] += @@points_for_year
          end

        elsif value[:klass] == 'http://www.owl-ontologies.com/book.owl#Book'

          years_hash = Ontology.query(" PREFIX book: <http://www.owl-ontologies.com/book.owl#>
                                        SELECT ?class ?instance
                                        WHERE {
                                          ?instance a ?class ;
                                                    book:hasYear '#{year}' .
                                          <#{key}> book:hasEdition ?instance
                                        }
                                      ")
          years_hash['results']['bindings'].each do |resource|
            klass = resource['class']['value']
            uri = resource['instance']['value']
            if @score[uri]
              @score[uri][:points] += @@points_for_year
              puts "#{uri} => #{@score[uri]}"
            elsif temp_score[uri]
              temp_score[uri][:points] += @@points_for_year
              puts "#{uri} => #{temp_score[uri]}"
            else
              temp_score[uri] = {klass: klass, points: value[:points] + @@points_for_year}
              puts "#{uri} => #{temp_score[uri]}"
            end
          end

        else

          next

        end
      end
    end
    @score.merge!(temp_score)
  end

  def with_formats
    temp_score = {}

    @formats.each_with_index do |format, index|
      puts "#{index}: searching for #{format}"
      @score.each do |key, value|
        if value[:klass] == 'http://www.owl-ontologies.com/book.owl#Edition'

          formats_hash = Ontology.query(" PREFIX book: <http://www.owl-ontologies.com/book.owl#>
                                          SELECT (count(*) as ?count)
                                          WHERE { <#{key}> book:hasFormat <#{format}> }
                                        ")
          if formats_hash['results']['bindings'][0]['count']['value'].to_i > 0
            value[:points] += @@points_for_format
          end

        elsif value[:klass] == 'http://www.owl-ontologies.com/book.owl#Book'

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
            if @score[uri]
              @score[uri][:points] += @@points_for_format
              puts "#{uri} => #{@score[uri]}"
            elsif temp_score[uri]
              temp_score[uri][:points] += @@points_for_format
              puts "#{uri} => #{temp_score[uri]}"
            else
              temp_score[uri] = {klass: klass, points: value[:points] + @@points_for_format}
              puts "#{uri} => #{temp_score[uri]}"
            end
          end

        else

          next

        end
      end
    end
    @score.merge!(temp_score)
  end

  def with_languages
    temp_score = {}

    @languages.each_with_index do |language, index|
      puts "#{index}: searching for #{language}"
      @score.each do |key, value|
        if value[:klass] == 'http://www.owl-ontologies.com/book.owl#Edition'

          languages_hash = Ontology.query(" PREFIX book: <http://www.owl-ontologies.com/book.owl#>
                                            SELECT (count(*) as ?count)
                                            WHERE { <#{key}> book:hasLanguage '#{language}' }
                                          ")
          if languages_hash['results']['bindings'][0]['count']['value'].to_i > 0
            value[:points] += @@points_for_language
          end

        elsif value[:klass] == 'http://www.owl-ontologies.com/book.owl#Book'

          languages_hash = Ontology.query(" PREFIX book: <http://www.owl-ontologies.com/book.owl#>
                                            SELECT ?class ?instance
                                            WHERE { ?instance a ?class ;
                                                              book:hasLanguage '#{language}' .
                                                    <#{key}> book:hasEdition ?instance
                                                  }
                                          ")
          languages_hash['results']['bindings'].each do |resource|
            klass = resource['class']['value']
            uri = resource['instance']['value']
            if @score[uri]
              @score[uri][:points] += @@points_for_language
              puts "#{uri} => #{@score[uri]}"
            elsif temp_score[uri]
              temp_score[uri][:points] += @@points_for_language
              puts "#{uri} => #{temp_score[uri]}"
            else
              temp_score[uri] = {klass: klass, points: value[:points] + @@points_for_language}
              puts "#{uri} => #{temp_score[uri]}"
            end
          end

        else

          next

        end
      end
    end
    @score.merge!(temp_score)
  end

  def get_results
    if !@more_results
      min_points = @words.length + @object_properties.length*@@points_for_property
      if !@classes.empty? && @object_properties.empty?
        min_points = min_points + @@points_for_class
      end
      if !@years.empty?
        min_points = min_points - @years.length + @@points_for_year
      end
      if !@formats.empty?
        min_points = min_points + @@points_for_format
      end
      if !@languages.empty?
        min_points = min_points + @@points_for_language
      end
      puts 'XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX'
      puts "Minimum points needed = #{min_points}"
      score.delete_if { |key, value| value[:points] < min_points }
    end

    ranking = []

    resources = @score.sort_by { |key, value| -value[:points] }

    resources.each do |resource|
      if resource[1][:klass] == 'http://www.owl-ontologies.com/book.owl#Author'
        ranking << [resource[1], Author.find(resource[0].gsub(@@book, ''))]
      elsif resource[1][:klass] == 'http://www.owl-ontologies.com/book.owl#Award'
        ranking <<  [resource[1], Award.find(resource[0].gsub(@@book, ''))]
      elsif resource[1][:klass] == 'http://www.owl-ontologies.com/book.owl#Book'
        ranking << [resource[1], Book.find(resource[0].gsub(@@book, ''))]
      elsif resource[1][:klass] == 'http://www.owl-ontologies.com/book.owl#Edition'
        ranking << [resource[1], Edition.find(resource[0].gsub(@@book, ''))]
      elsif resource[1][:klass] == 'http://www.owl-ontologies.com/book.owl#Publisher'
        ranking << [resource[1], Publisher.find(resource[0].gsub(@@book, ''))]
      end
    end

    return ranking
  end
end
