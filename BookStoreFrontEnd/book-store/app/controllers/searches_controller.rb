class SearchesController < ApplicationController
  def new
    @more_results = (params[:opt] ? true : false)

    search = Search.new(params[:q], @more_results)

    # raise "OWL" + "\n" +
    #       "CLASSES" + CLASSES.to_yaml +
    #       "FORMATS" + FORMATS.to_yaml +
    #       "OBJECT_PROPERTIES" + OBJECT_PROPERTIES.to_yaml +
    #       "DATATYPE_PROPERTIES" + DATATYPE_PROPERTIES.to_yaml

    # raise "Query: " + search.query + "\n" +
    #       "Stems: " + search.stems.to_yaml +
    #       "Words: " + search.words.to_yaml +
    #       "Years: " + search.years.to_yaml +
    #       "Classes: " + search.classes.to_yaml +
    #       "Formats: " + search.formats.to_yaml +
    #       "Object Properties: " + search.object_properties.to_yaml +
    #       "Datatype Properties: " + search.datatype_properties.to_yaml +
    #       "Languages: " + search.languages.to_yaml

    search.with_words

    if search.words.length == search.years.length
      search.everything_with_years
    end

    if search.object_properties.empty?
      search.with_classes
    else
      search.with_object_properties
    end

    if search.words.length != search.years.length
      search.with_years
    end
    search.with_formats

    search.with_languages

    @results = search.get_results
    @words = search.words
  end
end
