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
import java.util.regex.Matcher;
import java.util.regex.Pattern;

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
import com.hp.hpl.jena.query.ParameterizedSparqlString;
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
	Property hasImage = null;
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
	Resource awardWin = null;
	Property hasAward = null;
	Property hasDescription = null;
	Property hasWin = null;
	
	int authorId = 1;
	int bookId = 1;
	int editionId = 1;
	int publisherId = 1;
	int awardId = 1;
	int awardWinnerId = 1;
	
	public BookStoreModel() {
		dataset = TDBFactory.createDataset(BookStoreConstants.DATASET_PATH);
		if(!dataset.containsNamedModel(BookStoreConstants.DATASET_NAME)) {
			model = readOntologyModel(BookStoreConstants.ONTOLOGY_PATH);
			initModel();
			dataset.begin(ReadWrite.WRITE);
			try {
				populateBooks(BookStoreConstants.ONTOLOGY_XML);
				populateAwards(BookStoreConstants.AWARDS_XML);
				populateAuthorAwardWinners(BookStoreConstants.NOBEL_AWARD_WINNERS_XML);
				populateBookAwardWinners(BookStoreConstants.PULITZER_AWARD_WINNERS_XML);
				populateBookAwardWinners(BookStoreConstants.HUGO_AWARD_WINNERS_XML);
				persistModel();
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
		hasImage = model.getProperty(BookStoreConstants.ONTOLOGY_URI + "hasImage");
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
		awardWin = model.getResource(BookStoreConstants.ONTOLOGY_URI + "AwardWin");
		hasDescription = model.getProperty(BookStoreConstants.ONTOLOGY_URI + "hasDescription");
		hasWin = model.getProperty(BookStoreConstants.ONTOLOGY_URI + "hasWin");
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
	
	private void populateBooks(String xmlPath) {
		
		Document doc = readXML(xmlPath);
		
		if(doc != null) {

			/* Authors */
			NodeList authorsList = null;
			Node readAuthor = null;
			NodeList authorBooks = null;
			Resource authorInstance = null;
			String authorName = null;
			String authorBio = null;
			String authorImage = null;

			/* Books */
			Node readBook = null;
			Node bookEdition = null;
			Resource bookInstance = null;
			String bookTitle = null;
			String bookGenre = null;
			
			/* Edition */
			NodeList bookEditions = null;
			Node readEdition = null;
			Resource editionInstance = null;
			String ISBN = null;
			String pages = null;
			String year = null;
			String language = null;
			String editionFormat = null;
			String image_url = null;
			
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
					authorImage = getValue("image_url", readAuthor);
					
					authorInstance = getResourceByName("Author", authorName);

					if (authorInstance == null) {
						authorInstance = model.createResource(BookStoreConstants.ONTOLOGY_URI + "author" + authorId++)
								.addProperty(RDF.type, author)
								.addProperty(hasName, authorName)
								.addProperty(hasBio, authorBio)
								.addProperty(hasImage, authorImage);
					}
					
					authorBooks = getNode("books", readAuthor).getChildNodes();
					
					for (int j = 0; j < authorBooks.getLength(); j++) {
						readBook = authorBooks.item(j);
						if (readBook.getNodeType() == Node.ELEMENT_NODE) {
							bookTitle = getValue("title", readBook);
							bookGenre = getValue("genre", readBook);

							bookEditions = getNode("editions", readBook).getChildNodes();
							
							for(int k = 0; k < bookEditions.getLength(); k++) {
								bookEdition = bookEditions.item(k);
								if(bookEdition.getNodeType() == Node.ELEMENT_NODE) {
		
									publisherName = getValue("publisher", bookEdition);
		
									publisherInstance = getResourceByName("Publisher", publisherName);
		
									if (publisherInstance == null) {
										publisherInstance = model.createResource(BookStoreConstants.ONTOLOGY_URI + "publisher" + publisherId++)
												.addProperty(RDF.type, publisher)
												.addProperty(hasName, publisherName);
									}
									
									image_url = getValue("image_url", bookEdition);
									ISBN = getValue("isbn", bookEdition);
									pages = getValue("num_pages", bookEdition);
									year = getValue("year", bookEdition);
									language = getValue("language", bookEdition);
									editionFormat = getValue("format", bookEdition);
									
									bookInstance = getBookByTitle(bookTitle);
									
									if(bookInstance == null){
										bookInstance = model.createResource(BookStoreConstants.ONTOLOGY_URI + "book" + bookId++)
												.addProperty(RDF.type, book)
												.addProperty(hasTitle, bookTitle)
												.addProperty(hasGenre, bookGenre)
												.addProperty(hasImage, image_url)
												.addProperty(hasAuthor, authorInstance);

										authorInstance.addProperty(hasBook, bookInstance);
									}
									
									formatInstance = getFormatByLabel(editionFormat);
									
									if(formatInstance == null) {
//										editionInstance = model.createResource(BookStoreConstants.ONTOLOGY_URI + encodeURL(bookTitle + "_edition_" + new BigInteger(130, random).toString(32)))
//												.addProperty(RDF.type, edition)
//												.addProperty(hasISBN, ISBN)
//												.addProperty(hasPages, pages)
//												.addProperty(hasYear, year)
//												.addProperty(hasLanguage, language)
//												.addProperty(hasTitle, bookTitle)
//												.addProperty(hasFormat, eBook)
//												.addProperty(hasPublisher, publisherInstance);
//										
//										bookInstance.addProperty(hasEdition, editionInstance);
										formatInstance = paperback;
									}
														
									editionInstance = model.createResource(BookStoreConstants.ONTOLOGY_URI + "edition" + editionId++)
											.addProperty(RDF.type, edition)
											.addProperty(hasImage, image_url)
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
				
			}
		}
		else {
			logger.error("Could not populate dataset with authors, books, editions and publishers because the XML Document is null");
		}
	}
	
	private void populateAwards(String xmlPath) {
		Document doc = readXML(xmlPath);
				
		if(doc != null) {
			
			NodeList awardList = null;
			Node readAward = null;
			String awardName = null;
			String awardDescription = null;
			String awardImage = null;
			Resource awardInstance = null;
			
			awardList = doc.getElementsByTagName("award");
			for(int i = 0; i < awardList.getLength(); i++) {
				readAward = awardList.item(i);
				if (readAward.getNodeType() == Node.ELEMENT_NODE) {
					awardName = getValue("name", readAward);
					awardDescription = getValue("description", readAward);
					awardImage = getValue("image", readAward);
					
					awardInstance = getResourceByName("Award", awardName);
					
					if(awardInstance == null) {
						awardInstance = model.createResource(BookStoreConstants.ONTOLOGY_URI + "award" + awardId++)
								.addProperty(RDF.type, award)
								.addProperty(hasName, awardName)
								.addProperty(hasDescription, awardDescription)
								.addProperty(hasImage, awardImage);
					}
					else {
						System.out.println("Award with name " + awardName + " does not exist.");
					}
				}
			}
		}
	}
	
	private void populateAuthorAwardWinners(String xmlPath) {
		
		Document doc = readXML(xmlPath);		
		
		if(doc != null) {
			
			NodeList authorsList = null;
			Node readAuthor = null;
			Resource authorInstance = null;
			String authorName = null;
			String awardYear = null;
			Resource awardInstance = null;
			Resource awardWinnerInstance = null;
			
			String awardName = null;
			
			authorsList = doc.getElementsByTagName("author");
			
			for (int temp = 0; temp < authorsList.getLength(); temp++) {
				readAuthor = authorsList.item(temp);
				if (readAuthor.getNodeType() == Node.ELEMENT_NODE) {
					
					authorName = getValue("name", readAuthor);
					awardYear = getValue("year", readAuthor);
					awardName = getValue("award", readAuthor);
					
					authorInstance = getResourceByName("Author", authorName);
					
					if(authorInstance != null) {
						
						awardInstance = getAwardByName(awardName);
						
						if(awardInstance != null) {
						
							awardWinnerInstance = model.createResource(BookStoreConstants.ONTOLOGY_URI + "award_winner" + awardWinnerId++)
									.addProperty(RDF.type, awardWin)
									.addProperty(hasAward, awardInstance)
									.addProperty(hasYear, awardYear)
									.addProperty(hasGenre, "");
							
							authorInstance.addProperty(hasWin, awardWinnerInstance);
						}
						else {
							System.out.println("Award with name " + awardName + " does not exist.");
						}
					}
					else {
						//System.out.println("Author with name " + authorName + " does not exist.");
					}
				}
			}
		}
		else {
			logger.error("Could not populate dataset with awards because the XML Document is null");
		}
	}
	
	private void populateBookAwardWinners(String xmlPath) {
		
		Document doc = readXML(xmlPath);		
		
		NodeList bookList = null;
		Node readBook = null;
		Resource bookInstance = null;
		String authorName = null;
		String bookTitle = null;
		String awardYear = null;
		String awardGenre = null;
		Resource awardInstance = null;
		Resource awardWinnerInstance = null;
		
		NodeList editionList = null;
		Node readEdition = null;
		String ISBN = null;
		String pages = null;
		String year = null;
		String language = null;
		String editionFormat = null;
		String image_url = null;
		String publisherName = null;
		
		Resource authorInstance = null;
		Resource formatInstance = null;
		Resource editionInstance = null;
		Resource publisherInstance = null;
		
		Node editions = null;
		
		String awardName = null;
		
		if(doc != null) {
			bookList = doc.getElementsByTagName("book");
			
			for (int temp = 0; temp < bookList.getLength(); temp++) {
				readBook = bookList.item(temp);
				if (readBook.getNodeType() == Node.ELEMENT_NODE) {
					
					bookTitle = getValue("title", readBook);
					awardName = getValue("award", readBook);
					authorName = getValue("author", readBook);
					awardYear = getValue("year", readBook);
					awardGenre = getValue("genre", readBook);
					
					bookInstance = getBookByTitle(bookTitle);
					authorInstance = getResourceByName("Author", authorName);
					
					if(bookInstance == null && authorInstance != null) {	
						
						editions = getNode("editions", readBook);
						
						if (editions != null){
						
							editionList = editions.getChildNodes();
							
							for(int i = 0; i < editionList.getLength(); i++ ) {
								readEdition = editionList.item(i);
								if(readEdition.getNodeType() == Node.ELEMENT_NODE) {
									
									image_url = getValue("image_url", readEdition);
									ISBN = getValue("isbn", readEdition);
									pages = getValue("num_pages", readEdition);
									year = getValue("year", readEdition);
									language = getValue("language", readEdition);
									editionFormat = getValue("format", readEdition);
									publisherName = getValue("publisher", readEdition);
									
									if(bookInstance == null) {
										bookInstance = model.createResource(BookStoreConstants.ONTOLOGY_URI + "book" + bookId++)
												.addProperty(RDF.type, book)
												.addProperty(hasTitle, bookTitle)
												.addProperty(hasGenre, awardGenre)
												.addProperty(hasImage, image_url)
												.addProperty(hasAuthor, authorInstance);
	
										authorInstance.addProperty(hasBook, bookInstance);
									}
									
									publisherInstance = getResourceByName("Publisher", publisherName);
		
									if (publisherInstance == null) {
										publisherInstance = model.createResource(BookStoreConstants.ONTOLOGY_URI + "publisher" + publisherId++)
												.addProperty(RDF.type, publisher)
												.addProperty(hasName, publisherName);
									}
									
									formatInstance = getFormatByLabel(editionFormat);
									
									if(formatInstance == null) {
										formatInstance = paperback;
									}
														
									editionInstance = model.createResource(BookStoreConstants.ONTOLOGY_URI + "edition" + editionId++)
											.addProperty(RDF.type, edition)
											.addProperty(hasImage, image_url)
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
					awardInstance = getAwardByName(awardName);
					if(awardInstance != null && bookInstance != null) {
						
						awardWinnerInstance = model.createResource(BookStoreConstants.ONTOLOGY_URI + "award_winner" + awardWinnerId++)
								.addProperty(RDF.type, awardWin)
								.addProperty(hasAward, awardInstance)
								.addProperty(hasYear, awardYear)
								.addProperty(hasGenre, awardGenre);
						
						bookInstance.addProperty(hasWin, awardWinnerInstance);							
					}
				}
			}
		}
		else {
			logger.error("Could not populate dataset with awards because the XML Document is null");
		}
	}
	
	private void getAuthors() {
		
		System.out.println(getResourceByName("Author", "George R.R. Martin"));
		System.out.println(getResourceByName("Author", "José Saramago"));
		System.out.println(getResourceByName("Author", "Malcolm Gladwell"));
		//getResources();
		
	}
	
	private Node getNode(String sTag, Node node) {
		NodeList nList = ((Element)node).getElementsByTagName(sTag);
		return (nList != null) ? nList.item(0) : null;
	}

	private String getValue(String sTag, Node node) {
		NodeList nlList = null;
		if(((Element)node).getElementsByTagName(sTag).item(0) == null) {
			return "";
		}
		nlList = ((Element)node).getElementsByTagName(sTag).item(0).getChildNodes();
		Node nValue = (Node) nlList.item(0);
		return (nValue != null) ? nValue.getNodeValue() : "";
	}
	
	private void getResources() {
		String queryString = "SELECT ?x WHERE {?x ?p ?o}";
		
		ResultSet results = executeQuery(model, queryString);
		
		while (results.hasNext()) {
		QuerySolution row = results.next();
		RDFNode thing = row.get("x");
			System.out.println((Resource) thing);
		}
	}
	
	private Resource getResourceByName(String subject, String name){

		String queryString =	BookStoreConstants.ONTOLOGY_PREFIX_BOOK + 
								"\nSELECT ?x WHERE { ?x a book:" + encodeURL(subject) + " . ?x book:hasName ?name }";
		
		ParameterizedSparqlString paramQueryString = new ParameterizedSparqlString(queryString);
		paramQueryString.setLiteral("name", name);
		
		ResultSet results = executeQuery(model, paramQueryString.toString());

		while (results.hasNext()) {
			QuerySolution row = results.next();
			RDFNode thing = row.get("x");
			return (Resource) thing;
		}
		return null;
	}
	
	private Resource getBookByTitle(String title){
		String queryString = 	BookStoreConstants.ONTOLOGY_PREFIX_BOOK +
								"\nSELECT ?x WHERE {?x a book:Book . ?x book:hasTitle ?title}";
		
		ParameterizedSparqlString paramQueryString = new ParameterizedSparqlString(queryString);
		paramQueryString.setLiteral("title", title);
		
		ResultSet results = executeQuery(model, paramQueryString.toString());

		while (results.hasNext()) {
			QuerySolution row = results.next();
			RDFNode thing = row.get("x");
			return (Resource) thing;
		}
		return null;
	}
	
	private Resource getAwardByName(String name) {
		String queryString = 	BookStoreConstants.ONTOLOGY_PREFIX_BOOK +
								"\nSELECT ?x WHERE { ?x a book:Award . ?x book:hasName ?name}";
		
		ParameterizedSparqlString paramQueryString = new ParameterizedSparqlString(queryString);
		paramQueryString.setLiteral("name", name);
		ResultSet results = executeQuery(model, paramQueryString.toString());

		while (results.hasNext()) {
			QuerySolution row = results.next();
			RDFNode thing = row.get("x");
			return (Resource) thing;
		}
		return null;
		
	}
	
	private Resource getFormatByLabel(String label) {
		
		String queryString = 	BookStoreConstants.ONTOLOGY_PREFIX_BOOK + "\n" +
								BookStoreConstants.ONTOLOGY_PREFIX_RDFS +
								"SELECT ?format	WHERE { ?format rdfs:subClassOf book:Format . ?format rdfs:label ?label\n" +
								"FILTER regex(?label, ?inserted_label, 'i' )}";
		
		ParameterizedSparqlString paramQueryString = new ParameterizedSparqlString(queryString);
		paramQueryString.setLiteral("inserted_label", label);
		ResultSet results = executeQuery(model, paramQueryString.toString());

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
		bookStore.getAuthors();
		bookStore.close();
	}

}
