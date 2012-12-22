include Ontology

LABELS = {}

hash = Ontology.query(" PREFIX book: <http://www.owl-ontologies.com/book.owl#>
                        PREFIX rdfs: <http://www.w3.org/2000/01/rdf-schema#>
                        SELECT ?class ?label
                        WHERE { ?class a rdfs:Class .
                                ?class rdfs:label ?label }
                          ")
hash['results']['bindings'].each do |resource|
  key = resource['label']['value'].downcase
  value = resource['class']['value']
  LABELS[key] = value
end

KLASSES = {
  "http://www.owl-ontologies.com/book.owl#Author" => Author,
  "http://www.owl-ontologies.com/book.owl#Book" => Book,
  "http://www.owl-ontologies.com/book.owl#Edition" => Edition,
  "http://www.owl-ontologies.com/book.owl#Award" => Award,
  "http://www.owl-ontologies.com/book.owl#Publisher" => Publisher
}