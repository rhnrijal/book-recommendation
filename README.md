# BookStore

Web Semantic Project to create Book recommendations

## Usage

Get the back-end running with the following script:

```
fuseki-server.bat --update --loc=.\BookStoreBackEnd\bin\dataset\ /BookStore
```

Start the front-end by first entering the `BookStoreFrontEnd` folder.

Then make sure you have installed all the gems with the command:

```
bundle install --without production
```

Finally, start a web server on port 3000 with the command:

```
rails server
```
