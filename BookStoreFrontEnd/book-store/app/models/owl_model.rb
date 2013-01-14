class OwlModel
  include ActiveModel::Validations
  include ActiveModel::Conversion
  extend ActiveModel::Naming

  @@book = 'http://www.owl-ontologies.com/book.owl#'
  @@limit = 7
  @@white = Text::WhiteSimilarity.new

  def initialize(attributes = {})
    attributes.each do |name, value|
      send("#{name}=", value)
    end
  end

  def persisted?
    false
  end
end
