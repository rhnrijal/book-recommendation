package org.bookstore.backend;

import java.io.FileNotFoundException;
import java.io.FileOutputStream;
import java.io.IOException;
import java.io.InputStream;
import java.io.OutputStream;
import java.io.UnsupportedEncodingException;
import java.math.BigInteger;
import java.net.URLEncoder;
import java.security.SecureRandom;

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
	private SecureRandom random = new SecureRandom();
	
	/* Author */
	Resource author = null;
	Property hasName = null;
	Property hasBio = null;
	// Property hasNationality = model.getProperty(BookStoreConstants.ONTOLOGY_URI + "hasNationality");
	Property hasBook = null;

	/* Book */
	Resource book = null;
	Property hasAuthor = null;
	Property hasTitle = null;
	Property hasGenre = null;

	/* Book Type */
	Resource format = null;
	Resource eBook = null;
	Resource hardcover = null;
	Resource paperback = null;
	Property hasEdition = null;
	
	/* Edition */
	Resource edition = null;
	Property hasISBN = null;
	Property hasLanguage = null;
	Property hasPages = null;
	Property hasPublisher = null;
	Property hasType = null;
	Property hasYear = null;
	Property hasFormat = null;
	
	/* Publisher */
	Resource publisher = null;
	
	/* Award */
	Resource award = null;
	Property hasAward = null;
	
	public BookStoreModel() {
		dataset = TDBFactory.createDataset(BookStoreConstants.DATASET_PATH);
		
		if(!dataset.containsNamedModel(BookStoreConstants.DATASET_NAME)) {
			model = readOntologyModel(BookStoreConstants.ONTOLOGY_PATH);
			initModel();
			dataset.begin(ReadWrite.WRITE);
			try {
				populate(BookStoreConstants.ONTOLOGY_XML);
				dataset.addNamedModel(BookStoreConstants.DATASET_NAME, model);
				dataset.commit();
			} finally {
				dataset.end();
			}
		}
		else {
			model = dataset.getNamedModel(BookStoreConstants.DATASET_NAME);
			initModel();
		}
	}
	
	private void close() {
		if(dataset != null){
			dataset.close();
		}
	}
	
	private void initModel() {
		author = model.getResource(BookStoreConstants.ONTOLOGY_URI + "Author");
		hasName = model.getProperty(BookStoreConstants.ONTOLOGY_URI + "hasName");
		hasBio = model.getProperty(BookStoreConstants.ONTOLOGY_URI + "hasBio");
		
		hasBook = model.getProperty(BookStoreConstants.ONTOLOGY_URI + "hasBook");

		book = model.getResource(BookStoreConstants.ONTOLOGY_URI + "Book");
		hasAuthor = model.getProperty(BookStoreConstants.ONTOLOGY_URI + "hasAuthor");
		hasTitle = model.getProperty(BookStoreConstants.ONTOLOGY_URI + "hasTitle");
		hasGenre = model.getProperty(BookStoreConstants.ONTOLOGY_URI + "hasGenre");

		format = model.getResource(BookStoreConstants.ONTOLOGY_URI + "Format");
		eBook = model.getResource(BookStoreConstants.ONTOLOGY_URI + "eBook");
		hardcover = model.getResource(BookStoreConstants.ONTOLOGY_URI + "Hardcover");
		paperback = model.getResource(BookStoreConstants.ONTOLOGY_URI + "Paperback");
		hasEdition = model.getProperty(BookStoreConstants.ONTOLOGY_URI + "hasEdition");
		
		edition = model.getResource(BookStoreConstants.ONTOLOGY_URI + "Edition");
		hasISBN = model.getProperty(BookStoreConstants.ONTOLOGY_URI + "hasISBN");
		hasLanguage = model.getProperty(BookStoreConstants.ONTOLOGY_URI + "hasLanguage");
		hasPages = model.getProperty(BookStoreConstants.ONTOLOGY_URI + "hasPages");
		hasPublisher = model.getProperty(BookStoreConstants.ONTOLOGY_URI + "hasPublisher");
		hasType = model.getProperty(BookStoreConstants.ONTOLOGY_URI + "hasType");
		hasYear = model.getProperty(BookStoreConstants.ONTOLOGY_URI + "hasYear");
		hasFormat = model.getProperty(BookStoreConstants.ONTOLOGY_URI + "hasFormat");
		
		publisher = model.getResource(BookStoreConstants.ONTOLOGY_URI + "Publisher");
		
		award = model.getResource(BookStoreConstants.ONTOLOGY_URI + "Award");
		hasAward = model.getProperty(BookStoreConstants.ONTOLOGY_URI + "hasAward");
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
		
		model.setNsPrefix("owl", "http://www.w3.org/2002/07/owl#");

		model.write(outOWL);
		
	}
	
	private void populate(String xmlPath) {
		
		Document doc = readXML(xmlPath);
		
		if(doc != null) {

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
			String editionFormat = null;
			
			Resource formatInstance = null;

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

							bookInstance = getBookByTitle(bookTitle);
							
							if(bookInstance == null){
								bookInstance = model.createResource(BookStoreConstants.ONTOLOGY_URI + encodeURL(bookTitle))
										.addProperty(RDF.type, book)
										.addProperty(hasTitle, bookTitle)
										.addProperty(hasGenre, bookGenre)
										.addProperty(hasAuthor, authorInstance);

								authorInstance.addProperty(hasBook, bookInstance);
							}

							ISBN = getValue("isbn", bookEdition);
							pages = getValue("num_pages", bookEdition);
							year = getValue("year", bookEdition);
							language = getValue("language", bookEdition);
							editionFormat = getValue("format", bookEdition);
							
							formatInstance = getFormatByLabel(editionFormat);
							
							if(formatInstance == null) {
								editionInstance = model.createResource(BookStoreConstants.ONTOLOGY_URI + encodeURL(bookTitle + "_edition_" + new BigInteger(130, random).toString(32)))
										.addProperty(RDF.type, edition)
										.addProperty(hasISBN, ISBN)
										.addProperty(hasPages, pages)
										.addProperty(hasYear, year)
										.addProperty(hasLanguage, language)
										.addProperty(hasTitle, bookTitle)
										.addProperty(hasFormat, eBook)
										.addProperty(hasPublisher, publisherInstance);
								
								bookInstance.addProperty(hasEdition, editionInstance);
								formatInstance = paperback;
							}
												
							editionInstance = model.createResource(BookStoreConstants.ONTOLOGY_URI + encodeURL(bookTitle + "_edition_" + new BigInteger(130, random).toString(32)))
									.addProperty(RDF.type, edition)
									.addProperty(hasISBN, ISBN)
									.addProperty(hasPages, pages)
									.addProperty(hasYear, year)
									.addProperty(hasLanguage, language)
									.addProperty(hasTitle, bookTitle)
									.addProperty(hasFormat, formatInstance)
									.addProperty(hasPublisher, publisherInstance);
							
							bookInstance.addProperty(hasEdition, editionInstance);
						}
					}
					
				}
				
			}
		}
		else {
			logger.error("Could not populate dataset with authors, books, editions and publishers because the XML Document is null");
		}
	}
	
	private void addNobelAwards(String xmlPath) {
		
		Document doc = readXML(xmlPath);
		
		NodeList authorsList = null;
		Node readAuthor = null;
		Resource authorInstance = null;
		String authorName = null;
		String nobelYear = null;
		
		Resource awardInstance = null;
		
		if(doc != null) {
			authorsList = doc.getElementsByTagName("author");
			
			for (int temp = 0; temp < authorsList.getLength(); temp++) {
				readAuthor = authorsList.item(temp);
				if (readAuthor.getNodeType() == Node.ELEMENT_NODE) {
					
					authorName = getValue("name", readAuthor);
					nobelYear = getValue("nobel", readAuthor);
					
					authorInstance = getResourceByName("Author", authorName);
					
					if(authorInstance != null) {
						
						awardInstance = model.createResource(BookStoreConstants.ONTOLOGY_URI + "Nobel_" + nobelYear)
								.addProperty(RDF.type, award)
								.addProperty(hasName, "Nobel")
								.addProperty(hasYear, nobelYear);
						
						authorInstance.addProperty(hasAward, awardInstance);
						
					}
					
					
				}
			}
		}
		else {
			logger.error("Could not populate dataset with awwards because the XML Document is null");
		}
		
	}
	
	private void getAuthors() {
		
		System.out.println(getResourceByName("Author", "George R. R. Martin"));
		System.out.println(getResourceByName("Author", "José Saramago"));
		System.out.println(getResourceByName("Author", "Malcolm Gladwell"));
		
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
	
	private Resource getResourceByName(String subject, String name){

		String queryString =	BookStoreConstants.ONTOLOGY_PREFIX_BOOK + 
								"\nSELECT ?x WHERE { ?x a book:" + encodeURL(subject) + " . ?x book:hasName \"" + name + "\"}";
		
		ResultSet results = executeQuery(model, queryString);

		while (results.hasNext()) {
			QuerySolution row = results.next();
			RDFNode thing = row.get("x");
			return (Resource) thing;
		}
		return null;
	}
	
	private Resource getBookByTitle(String title){
		
		String queryString = 	BookStoreConstants.ONTOLOGY_PREFIX_BOOK +
								"\nSELECT ?x WHERE { ?x a book:Book . ?x book:hasTitle> \"" + title + "\"}";
		return null;
//		ResultSet results = executeQuery(model, queryString);
//
//		while (results.hasNext()) {
//			QuerySolution row = results.next();
//			RDFNode thing = row.get("x");
//			return (Resource) thing;
//		}
//		return null;
	}
	
	private Resource getFormatByLabel(String label) {
		
		String queryString = 	BookStoreConstants.ONTOLOGY_PREFIX_BOOK + "\n" +
								BookStoreConstants.ONTOLOGY_PREFIX_RDFS +
								"SELECT ?format	WHERE { ?format rdfs:subClassOf book:Format . ?format rdfs:label ?label\n" +
								"FILTER regex(?label, \"" + label + "\", 'i' )}";
		
		ResultSet results = executeQuery(model, queryString);

		while (results.hasNext()) {
			QuerySolution row = results.next();
			RDFNode thing = row.get("x");
			return (Resource) thing;
		}
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
		bookStore.addNobelAwards("nobelAwards.xml");
		bookStore.getAuthors();
		bookStore.persistModel();
		bookStore.close();
	}

}
