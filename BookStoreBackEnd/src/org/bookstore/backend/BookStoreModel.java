package org.bookstore.backend;

import java.io.FileNotFoundException;
import java.io.FileOutputStream;
import java.io.IOException;
import java.io.InputStream;
import java.io.OutputStream;
import java.io.UnsupportedEncodingException;
import java.net.URLEncoder;

import javax.xml.parsers.DocumentBuilder;
import javax.xml.parsers.DocumentBuilderFactory;
import javax.xml.parsers.ParserConfigurationException;

import org.apache.log4j.Logger;
import org.apache.log4j.PropertyConfigurator;
import org.bookstore.utils.BookStoreConstants;
import org.w3c.dom.Document;
import org.w3c.dom.Element;
import org.w3c.dom.Node;
import org.w3c.dom.NodeList;
import org.xml.sax.SAXException;

import com.hp.hpl.jena.query.Dataset;
import com.hp.hpl.jena.query.Query;
import com.hp.hpl.jena.query.QueryExecution;
import com.hp.hpl.jena.query.QueryExecutionFactory;
import com.hp.hpl.jena.query.QueryFactory;
import com.hp.hpl.jena.query.QuerySolution;
import com.hp.hpl.jena.query.ReadWrite;
import com.hp.hpl.jena.query.ResultSet;
import com.hp.hpl.jena.rdf.model.Model;
import com.hp.hpl.jena.rdf.model.ModelFactory;
import com.hp.hpl.jena.rdf.model.Property;
import com.hp.hpl.jena.rdf.model.RDFNode;
import com.hp.hpl.jena.rdf.model.Resource;
import com.hp.hpl.jena.tdb.TDBFactory;
import com.hp.hpl.jena.util.FileManager;
import com.hp.hpl.jena.vocabulary.RDF;

public class BookStoreModel {
	
	private static Logger logger = Logger.getLogger(BookStoreModel.class);
	
	private Model model = null;
	private Dataset dataset = null;
	
	public BookStoreModel() {
		dataset = TDBFactory.createDataset(BookStoreConstants.DATASET_PATH);
		
		if(!dataset.containsNamedModel(BookStoreConstants.DATASET_NAME)) {
			model = readOntologyModel(BookStoreConstants.ONTOLOGY_PATH);
			dataset.begin(ReadWrite.WRITE);
			try {
				populate();
				persistModel();
				dataset.addNamedModel(BookStoreConstants.DATASET_NAME, model);
				dataset.commit();
			} finally {
				dataset.end();
			}
		}
		else {
			model = dataset.getNamedModel(BookStoreConstants.DATASET_NAME);
		}
	}
	
	private void close() {
		
		if(dataset != null){
			dataset.close();
		}
	}
	
	private Model readOntologyModel(String path) {

		Model model = ModelFactory.createDefaultModel();

		InputStream in = FileManager.get().open(path);
		if (in == null) {
			throw new IllegalArgumentException("File: " + path + " not found");
		}

		// read the RDF/XML file
		model.read(in, "");
		
		try {
			in.close();
		}
		catch (IOException e) {
			// TODO Auto-generated catch block
			e.printStackTrace();
		}

		return model;
	}
	
	private void persistModel() {
		
		OutputStream outOWL = null;
		try {
			outOWL = new FileOutputStream(BookStoreConstants.ONTOLOGY_OUTPUT_PATH);
		}
		catch (FileNotFoundException e) {
			e.printStackTrace();
		}

		model.write(outOWL);
		
	}
	
	private void populate() {
		
		Document doc = readXML(BookStoreConstants.ONTOLOGY_XML);
		
		if(doc != null) {
			
			/* Author */
			Resource author = model.getResource(BookStoreConstants.ONTOLOGY_URI + "Author");
			Property hasName = model.getProperty(BookStoreConstants.ONTOLOGY_URI + "hasName");
			Property hasBio = model.getProperty(BookStoreConstants.ONTOLOGY_URI + "hasBio");
			// Property hasNationality = model.getProperty(BookStoreConstants.ONTOLOGY_URI + "hasNationality");

			/* Book */
			Resource book = model.getResource(BookStoreConstants.ONTOLOGY_URI + "Book");
			Property hasAuthor = model.getProperty(BookStoreConstants.ONTOLOGY_URI + "hasAuthor");
			Property hasTitle = model.getProperty(BookStoreConstants.ONTOLOGY_URI + "hasTitle");
			Property hasGenre = model.getProperty(BookStoreConstants.ONTOLOGY_URI + "hasGenre");

			/* Book Type */
			Resource format = model.getResource(BookStoreConstants.ONTOLOGY_URI + "Format");
			Resource eBook = model.getResource(BookStoreConstants.ONTOLOGY_URI + "eBook");
			Resource hardcover = model.getResource(BookStoreConstants.ONTOLOGY_URI + "Hardcover");
			Resource paperback = model.getResource(BookStoreConstants.ONTOLOGY_URI + "Paperback");
			
			/* Edition */
			Resource edition = model.getResource(BookStoreConstants.ONTOLOGY_URI + "Edition");
			Property hasISBN = model.getProperty(BookStoreConstants.ONTOLOGY_URI + "hasISBN");
			Property hasLanguage = model.getProperty(BookStoreConstants.ONTOLOGY_URI + "hasLanguage");
			Property hasPages = model.getProperty(BookStoreConstants.ONTOLOGY_URI + "hasPages");
			Property hasPublisher = model.getProperty(BookStoreConstants.ONTOLOGY_URI + "hasPublisher");
			Property hasType = model.getProperty(BookStoreConstants.ONTOLOGY_URI + "hasType");
			Property hasYear = model.getProperty(BookStoreConstants.ONTOLOGY_URI + "hasYear");
			
			/* Publisher */
			Resource publisher = model.getResource(BookStoreConstants.ONTOLOGY_URI + "Publisher");

			/* Authors */
			NodeList authorsList = null;
			Node readAuthor = null;
			NodeList authorBooks = null;
			Resource authorInstance = null;
			String authorName = null;
			String authorBio = null;

			/* Books */
			Node readBook = null;
			Node bookEdition = null;
			Resource bookInstance = null;
			String bookTitle = null;
			String bookGenre = null;
			
			/* Edition */
			Node readEdition = null;
			Resource editionInstance = null;
			String ISBN = null;
			String pages = null;
			String year = null;
			String language = null;

			/* Publisher */
			String publisherName = null;
			Resource publisherInstance = null;
			
			
			authorsList = doc.getElementsByTagName("author");
			
			for (int temp = 0; temp < authorsList.getLength(); temp++) {
				readAuthor = authorsList.item(temp);
				if (readAuthor.getNodeType() == Node.ELEMENT_NODE) {
					
					authorName = getValue("name", readAuthor);
					authorBio = getValue("bio", readAuthor);

					authorInstance = getResourceByName("Author", authorName);

					if (authorInstance == null) {
						authorInstance = model.createResource(BookStoreConstants.ONTOLOGY_URI + encodeURL(authorName))
								.addProperty(RDF.type, author)
								.addProperty(hasName, authorName).addProperty(hasBio, authorBio);
					}
					
					authorBooks = getNode("books", readAuthor).getChildNodes();
					
					for (int j = 0; j < authorBooks.getLength(); j++) {
						readBook = authorBooks.item(j);
						if (readBook.getNodeType() == Node.ELEMENT_NODE) {
							bookTitle = getValue("title", readBook);
							bookGenre = getValue("genre", readBook);

							bookEdition = getNode("edition", readBook);

							publisherName = getValue("publisher", bookEdition);

							publisherInstance = getResourceByName("Publisher", publisherName);

							if (publisherInstance == null) {
								publisherInstance = model.createResource(BookStoreConstants.ONTOLOGY_URI + encodeURL(publisherName))
										.addProperty(RDF.type, publisher)
										.addProperty(hasName, publisherName);
							}

							bookInstance = getBookByTitle(model, bookTitle);
							
							if(bookInstance == null){
								bookInstance = model.createResource(BookStoreConstants.ONTOLOGY_URI + encodeURL(bookTitle))
										.addProperty(RDF.type, book)
										.addProperty(hasTitle, bookTitle)
										.addProperty(hasGenre, bookGenre)
										.addProperty(hasAuthor, authorInstance);
							}

							ISBN = getValue("isbn", bookEdition);
							pages = getValue("num_pages", bookEdition);
							year = getValue("year", bookEdition);
							language = getValue("language", bookEdition);
												
							editionInstance = model.createResource(BookStoreConstants.ONTOLOGY_URI + encodeURL(bookTitle + year + ISBN))
									.addProperty(RDF.type, edition)
									.addProperty(hasISBN, ISBN)
									.addProperty(hasPages, pages)
									.addProperty(hasYear, year)
									.addProperty(hasLanguage, language)
									.addProperty(hasTitle, bookTitle);
						}
					}
					
				}
				
			}
			System.out.println(getResourceByName("Author", "George R.R. Martin"));
		}
		else {
			logger.error("Could not populate dataset because the XML Document is null");
		}
	}
	
	public void getAuthors() {
		
		System.out.println(getResourceByName("Author", "George R.R. Martin"));
		
	}
	
	private Node getNode(String sTag, Node node) {
		NodeList nList = ((Element)node).getElementsByTagName(sTag);
		return (nList != null) ? nList.item(0) : null;
	}

	private String getValue(String sTag, Node node) {
		NodeList nlList = ((Element)node).getElementsByTagName(sTag).item(0).getChildNodes();
		Node nValue = (Node) nlList.item(0);
		return (nValue != null) ? nValue.getNodeValue() : "";
	}
	
	private Resource getResourceByName(String subject, String object){

		String queryString = "SELECT ?x WHERE { ?x a <http://www.owl-ontologies.com/book.owl#" + encodeURL(subject) + "> . " + "?x  <"
				+ BookStoreConstants.ONTOLOGY_URI + "hasName> \"" + object + "\"}";

		ResultSet results = executeQuery(model, queryString);

		while (results.hasNext()) {
			QuerySolution row = results.next();
			RDFNode thing = row.get("x");
			return (Resource) thing;
		}
		return null;
	}
	
	private Resource getBookByTitle(Model model, String object){
		
//		String queryString = "SELECT ?x WHERE { ?x a <http://www.owl-ontologies.com/book.owl#" + URLDecoder.decode(subject, "UTF-8") + "> . " + "?x  <"
//				+ ontologyURI + "hasName> \"" + object + "\"}";
		
		return null;
	}

	private ResultSet executeQuery(Model model, String queryString) {
		Query query = QueryFactory.create(queryString);
		QueryExecution qe = QueryExecutionFactory.create(query, model);
		return qe.execSelect();
	}
	
	private Document readXML(String path) {

		try {
			DocumentBuilder docBuilder = DocumentBuilderFactory.newInstance().newDocumentBuilder();
			Document doc = docBuilder.parse(path);
			doc.getDocumentElement().normalize();

			return doc;
		}
		catch (ParserConfigurationException e) {
			logger.error("ParserConfigurationException occured while reading XML file! Reason: " + e.getMessage());
		}
		catch (SAXException e) {
			logger.error("SAXException occured while reading XML file! Reason: " + e.getMessage());
		}
		catch (IOException e) {
			logger.error("IOException occured while reading XML file! Reason: " + e.getMessage());
		}

		return null;
	}
	
	public static String encodeURL(String url) {
		try {
			return URLEncoder.encode(url, "UTF-8");
		}
		catch (UnsupportedEncodingException e) {
			e.printStackTrace();
		}
		return null;
	}
	
	public static void main(String args[]){
		PropertyConfigurator.configure("log4j.properties");
		BookStoreModel bookStore = new BookStoreModel();
		bookStore.getAuthors();
		bookStore.close();
	}

}
