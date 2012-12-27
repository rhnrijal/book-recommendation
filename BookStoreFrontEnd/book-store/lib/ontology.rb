#!/usr/bin/env ruby
# -*- coding: utf-8 -*-

# Licensed to the Apache Software Foundation (ASF) under one
# or more contributor license agreements.  See the NOTICE file
# distributed with this work for additional information
# regarding copyright ownership.  The ASF licenses this file
# to you under the Apache License, Version 2.0 (the
# "License"); you may not use this file except in compliance
# with the License.  You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

# SPARQL HTTP Update, client.

require 'optparse'
require 'net/http'
require 'uri'
require 'cgi'
require 'pp'
require 'ostruct'

# ToDo
#  Allow a choice of media type for GET
#   --accept "content-type" (and abbreviations)
#   --header "Add:this"
#   --user, --password
#  Basic authentication: request.basic_auth("username", "password")
#  Follow redirects => 301:  puts response["location"] # All headers are lowercase?

SOH_NAME="SOH"
SOH_VERSION="0.0.0"

$proxy = ENV['http_proxy'] ? URI.parse(ENV['http_proxy']) : OpenStruct.new

#$service = 'http://alacarte.dei.uc.pt/BookStore/query'
$service = 'http://127.0.0.1:3030/BookStore/query'
$type = 'json'
$verbose = false

# What about direct naming?

# Names
$mtTurtle           = 'text/turtle;charset=utf-8'
$mtRDF              = 'application/rdf+xml'
$mtText             = 'text/plain'
$mtNQuads           = 'text/n-quads'
$mtTriG             = 'application/trig'
$mtSparqlResultsX   = 'application/sparql-results+xml'
$mtSparqlResultsJ   = 'application/sparql-results+json'
$mtAppJSON          = 'application/json'
$mtAppXML           = 'application/xml'
$mtSparqlResultsTSV = 'application/sparql-results+tsv'
$mtSparqlResultsCSV = 'application/sparql-results+csv'
$mtSparqlUpdate     = 'application/sparql-update'
$mtWWWForm          = 'application/x-www-form-urlencoded'
$mtSparqlQuery      = "application/sparql-query" ;

# Global media type table.
$fileMediaTypes = {}
$fileMediaTypes['ttl']   = $mtTurtle
$fileMediaTypes['n3']    = 'text/n3; charset=utf-8'
$fileMediaTypes['nt']    = $mtText
$fileMediaTypes['rdf']   = $mtRDF
$fileMediaTypes['owl']   = $mtRDF
$fileMediaTypes['nq']    = $mtNQuads
$fileMediaTypes['trig']  = $mtTriG

# Global charset : no entry means "don't set"
$charsetUTF8      = 'utf-8'
$charset = {}
$charset[$mtTurtle]   = 'utf-8'
$charset[$mtText]     = 'ascii'
$charset[$mtTriG]     = 'utf-8'
$charset[$mtNQuads]   = 'ascii'

# Headers

$hContentType         = 'Content-Type'
# $hContentEncoding     = 'Content-Encoding'
$hContentLength       = 'Content-Length'
# $hContentLocation     = 'Content-Location'
# $hContentRange        = 'Content-Range'

$hAccept              = 'Accept'
$hAcceptCharset       = 'Accept-Charset'
$hAcceptEncoding      = 'Accept-Encoding'
$hAcceptRanges        = 'Accept-Ranges' 

$headers = { "User-Agent" => "#{SOH_NAME}/Fuseki #{SOH_VERSION}"}
$print_http = false

# Default for GET
# At least allow anythign (and hope!)
$accept_rdf="#{$mtRDF};q=0.9 , #{$mtTurtle}"
# For SPARQL query
$accept_results="#{$mtSparqlResultsJ} , #{$mtSparqlResultsX};q=0.9 , #{$accept_rdf}"

# Accept any in case of trouble.
$accept_rdf="#{$accept_rdf} , */*;q=0.1"
$accept_results="#{$accept_results} , */*;q=0.1" 

# The media type usually forces the charset.
$accept_charset=nil

## Who we are.
## Two styles:
##    s-query .....
##    soh query .....

## -------- 


module Ontology
  def self.query(sparql)
    service = $service
    usePOST = false

    args = {}
    args['output'] = $type

    SPARQL_query_GET(service, sparql, args)
  end
end


def GET(dataset, graph)
  print "GET #{dataset} #{graph}\n" if $verbose
  requestURI = target(dataset, graph)
  headers = {}
  headers.merge!($headers)
  headers[$hAccept] = $accept_rdf
  headers[$hAcceptCharset] = $accept_charset unless $accept_charset.nil?
  get_worker(requestURI, headers)
end

def get_worker(requestURI, headers)
  uri = URI.parse(requestURI)
  request = Net::HTTP::Get.new(uri.request_uri)
  request.initialize_http_header(headers)
  print_http_request(uri, request)
  response_print_body(uri, request)
end

def HEAD(dataset, graph)
  print "HEAD #{dataset} #{graph}\n" if $verbose
  requestURI = target(dataset, graph)
  headers = {}
  headers.merge!($headers)
  headers[$hAccept] = $accept_rdf
  headers[$hAcceptCharset] = $accept_charset unless $accept_charset.nil?
  uri = URI.parse(requestURI)
  request = Net::HTTP::Head.new(uri.request_uri)
  request.initialize_http_header(headers)
  print_http_request(uri, request)
  response_no_body(uri, request)
end

def PUT(dataset, graph, file)
  print "PUT #{dataset} #{graph} #{file}\n" if $verbose
  send_body(dataset, graph, file, Net::HTTP::Put)
end

def POST(dataset, graph, file)
  print "POST #{dataset} #{graph} #{file}\n" if $verbose
  send_body(dataset, graph, file, Net::HTTP::Post)
end

def DELETE(dataset, graph)
  print "DELETE #{dataset} #{graph}\n" if $verbose
  requestURI = target(dataset, graph)
  uri = URI.parse(requestURI)
  request = Net::HTTP::Delete.new(uri.request_uri)
  headers = {}
  headers.merge!($headers)
  request.initialize_http_header(headers)
  print_http_request(uri, request)
  response_no_body(uri, request)
end

def uri_escape(string)
  CGI.escape(string)
end

def target(dataset, graph)
  return dataset+"?default" if graph == "default"
  return dataset+"?graph="+uri_escape(graph)
end

def send_body(dataset, graph, file, method)
  mt = content_type(file)
  headers = {}
  headers.merge!($headers)
  headers[$hContentType] = mt
  headers[$hContentLength] = File.size(file).to_s
  ## p headers

  requestURI = target(dataset, graph)
  uri = URI.parse(requestURI)
  
  request = method.new(uri.request_uri)
  request.initialize_http_header(headers)
  print_http_request(uri, request)
  request.body_stream = File.open(file)
  response_no_body(uri, request)
end

def response_no_body(uri, request)
  http = Net::HTTP::Proxy($proxy.host,$proxy.port).new(uri.host, uri.port)
  http.read_timeout = nil
  # check we can connect.
  begin http.start
  rescue StandardError => e
    # puts e.message  
    #puts e.backtrace.inspect  
    warn_exit "Failed to connect: #{uri.host}:#{uri.port}: #{e.message}", 3
  end
  response = http.request(request)
  print_http_response(response)
  case response
  when Net::HTTPSuccess, Net::HTTPRedirection
    # OK
  when Net::HTTPNotFound
    warn_exit "404 Not found: #{uri}", 9
    #print response.body
  else
    warn_exit "#{response.code} #{response.message} #{uri}", 9
    # Unreachable
      response.error!
  end
  # NO BODY IN RESPONSE
end

def response_print_body(uri, request)
  http = Net::HTTP::Proxy($proxy.host,$proxy.port).new(uri.host, uri.port)
  http.read_timeout = nil
  # check we can connect.
  begin http.start
  rescue StandardError => e
    #puts e.backtrace.inspect  
    #print e.class
    warn_exit "Failed to connect: #{uri.host}:#{uri.port}: #{e.message}", 3
  end

  # Add a blank line if headers were output.
  print "\n" if $http_print ;

  begin
    response = http.request(request)
    # response = http.request(request) { |res|
    #   print_http_response(res)
    #   #puts res.code
    #   res.read_body do |segment|
    #     print segment
    #   end
    # }
    case response
    when Net::HTTPSuccess, Net::HTTPRedirection
      return JSON.parse(response.read_body)
      # OK
    when Net::HTTPNotFound
      warn_exit "404 Not found: #{uri}", 9
      #print response.body
    else
      warn_exit "#{response.code}: #{uri}", 9
      # Unreachable
      response.error!
    end
  rescue EOFError => e
    warn_exit "IO Error: "+e.message, 3
  end
end

def print_http_request(uri, request)
  return unless $print_http
  #print "Request\n"
  print request.method," ",uri, "\n"
  print_headers("  ",request)
end

def print_http_response(response)
  return unless $print_http
  #print "Response\n"
  print response.code, " ", response.message, "\n"
  print_headers("  ",response)
end

def print_headers(marker, headers)
  headers.each do |k,v| 
    k = k.split('-').map{|w| w.capitalize}.join('-')+':'
    printf "%s%-20s %s\n",marker,k,v
  end
end

def content_type(file)
  file =~ /\.([^.]*)$/
  ext = $1
  mt = $fileMediaTypes[ext]
  cs = $charset[mt]
  mt = mt+';charset='+cs if ! cs.nil?
  return mt
end

def charset(content_type)
  return $charset[content_type]
end

def warn_exit(msg, rc)
    warn msg
    exit rc ;
end

def parseURI(uri_string)
  begin
    return URI.parse(uri_string).to_s
  rescue URI::InvalidURIError => err
    warn_exit "Bad URI: <#{uri_string}>", 2
  end
end

## ---- Command

def cmd_soh(command=nil)
  ## Command line
  options = {}
  optparse = OptionParser.new do |opts|
    # Set a banner, displayed at the top
    # of the help screen.
    case $cmd
    when "s-http", "sparql-http", "soh"
      banner="$cmd [get|post|put|delete] datasetURI graph [file]"
    when "s-get", "s-head", "s-delete"
      banner="$cmd  datasetURI graph"
    end

    opts.banner = $banner
    # Define the options, and what they do
    
    options[:verbose] = false
    opts.on( '-v', '--verbose', 'Verbose' ) do
      options[:verbose] = true
    end
    
    options[:version] = false
    opts.on( '--version', 'Print version and exit' ) do
      print "#{SOH_NAME} #{SOH_VERSION}\n"
      exit
    end
    
    # This displays the help screen, all programs are
    # assumed to have this option.
    opts.on( '-h', '--help', 'Display this screen and exit' ) do
      puts opts
      exit
    end
  end

  begin optparse.parse!    
  rescue OptionParser::InvalidArgument => e
    warn e
    exit
  end

  $verbose = options[:verbose]
  $print_http = $verbose

  if command.nil?
    if ARGV.size == 0
      warn "No command given: expected one of get, put, post, delete"
      exit 1
    end
    cmdPrint=ARGV.shift
    command=cmdPrint.upcase
  else
    cmdPrint=command
  end

  case command
  when "HEAD", "GET", "DELETE"
    requiredFile=false
  when "PUT", "POST"
    requiredFile=true
  else
    warn_exit "Unknown command: #{cmdPrint}", 2
  end

  if requiredFile 
  then
    if ARGV.size != 3
      warn_exit "Required: dataset URI, graph URI (or 'default') and file", 1 
    end
  else
    if ARGV.size != 2
      warn_exit "Required: dataset URI and graph URI (or 'default')", 1 
    end
  end

  dataset=parseURI(ARGV.shift)
  # Relative URI?
  graph=parseURI(ARGV.shift)
  file=""
  if requiredFile
  then
    file = ARGV.shift if requiredFile
    if ! File.exist?(file)
      warn_exit "No such file: "+file, 3
    end
    if File.directory?(file)
      warn_exit "File is a directory: "+file, 3
    end
  end

  case command
  when "GET"
    GET(dataset, graph)
  when "HEAD"
    HEAD(dataset, graph)
  when "PUT"
    PUT(dataset, graph, file)
  when "DELETE"
    DELETE(dataset, graph)
  when "POST"
    POST(dataset, graph, file)
  else
    warn_exit "Internal error: Unknown command: #{cmd}", 2
  end
  exit 0
end

## --------
def string_or_file(arg)
  return arg if ! arg.match(/^@/)
  a=(arg[1..-1])
  open(a, 'rb'){|f| f.read}
end

## -------- SPARQL Query

## Choose method
def SPARQL_query(service, query, forcePOST=false, args2={})
  if forcePOST || query.length >= 2*1024 
    SPARQL_query_POST(service, query, args2)
  else
    SPARQL_query_GET(service, query, args2)
  end
end

## By GET

def SPARQL_query_GET(service, query, args2)
  args = { "query" => query }
  args.merge!(args2)
  qs=args.collect { |k,v| "#{k}=#{uri_escape(v)}" }.join('&')
  action="#{service}?#{qs}"
  headers={}
  headers.merge!($headers)
  headers[$hAccept]=$accept_results
  get_worker(action, headers)
end

## By POST

def SPARQL_query_POST(service, query, args2)
  # DRY - body/no body for each of request and response.
  post_params={ "query" => query }
  post_params.merge!(args2)
  uri = URI.parse(service)
  headers={}
  headers.merge!($headers)
  headers[$hAccept]=$accept_results
  execute_post_form_body(uri, headers, post_params)
end

def execute_post_form_body(uri, headers, post_params)
  request = Net::HTTP::Post.new(uri.request_uri)
  qs=post_params.collect { |k,v| "#{k}=#{uri_escape(v)}" }.join('&')
  headers[$hContentType] = $mtWWWForm
  headers[$hContentLength] = qs.length.to_s
  request.initialize_http_header(headers)
  request.body = qs
  print_http_request(uri, request)
  response_print_body(uri, request)
end

## -------- SPARQL Update

# Update sent as a WWW form.
def SPARQL_update_by_form(service, update, args2={})
  args = {}
  args.merge!(args2)
  headers={}
  headers.merge!($headers)
  # args? encode?
  body="update="+uri_escape(update)
  headers[$hContentType] = $mtWWWForm
  headers[$hContentLength] = body.length.to_s
  uri = URI.parse(service)
  execute_post_form(uri, headers, body)
end

# DRY - query form.
def execute_post_form(uri, headers, body)
  request = Net::HTTP::Post.new(uri.request_uri)
  request.initialize_http_header(headers)
  request.body = body
  print_http_request(uri, request)
  response_no_body(uri, request)
end

def SPARQL_update(service, update, args2={})
  args = {}
  args.merge!(args2)
  headers={}
  headers.merge!($headers)
  headers[$hContentType] = $mtSparqlUpdate
  uri = URI.parse(service)
  request = Net::HTTP::Post.new(uri.request_uri)
  request.initialize_http_header(headers)
  request.body = update
  print_http_request(uri, request)
  response_no_body(uri, request)
end

def cmd_sparql_update(by_raw_post=true)
  # Share with cmd_sparql_query
  options={}
  optparse = OptionParser.new do |opts|
    opts.banner = "Usage: #{$cmd} [--file REQUEST] [--service URI] 'request' | @file"
    opts.on('--service=URI', '--server=URI', 'SPARQL endpoint') do |uri|
      options[:service]=uri
    end
    opts.on('--update=FILE', '--file=FILE', 'Take update from a file') do |file|
      options[:file]=file
    end
    options[:verbose] = false
    opts.on( '-v', '--verbose', 'Verbose' ) do
      options[:verbose] = true
    end
    opts.on( '--version', 'Print version and exit' ) do
      print "#{SOH_NAME} #{SOH_VERSION}\n"
      exit
    end 
    opts.on( '-h', '--help', 'Display this screen and exit' ) do
      puts opts
      exit
    end
  end

  begin optparse.parse!    
  rescue OptionParser::InvalidArgument => e
    warn e
    exit
  end

  $verbose = options[:verbose]
  $print_http = $verbose

  service = options[:service]
  warn_exit 'No service specified. Required --service=URI',1   if service.nil?
  
  update=nil
  update_file=options[:file]

  if update_file.nil? && ARGV.size == 0
  then
    warn_exit 'No update specified.',1
    end
  if update_file.nil?
    update = ARGV.shift
    if update.match(/^@/)
      update_file = update[1..-1]
      update = nil
    end
  end
  
  print "SPARQL-Update #{service}\n" if $verbose
  args={}

  # Reads in the file :-(
  if update.nil?
  then
    update = open(update_file, 'rb'){|f| f.read}
  else
    update = string_or_file(update)
  end

  if by_raw_post
    SPARQL_update(service, update, args)
  else
    SPARQL_update_by_form(service, update, args)
  end
end
