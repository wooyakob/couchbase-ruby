require "dotenv/load"
require "couchbase"

options = Couchbase::Options::Cluster.new
options.authenticate(ENV.fetch("USERNAME"), ENV.fetch("PASS"))
options.apply_profile("wan_development")

cluster = Couchbase::Cluster.connect(ENV.fetch("CONN_STR"), options)

bucket = cluster.bucket(ENV.fetch("BUCKET"))
scope = bucket.scope(ENV.fetch("SCOPE"))
collection = scope.collection(ENV.fetch("COLLECTION"))

doc_id = "blog::jakes-blog-post"

begin
    result = collection.get(doc_id)
    puts "Found #{doc_id}:"
    puts result.content
rescue Couchbase::Error::DocumentNotFound
    puts "Sorry, no document with id #{doc_id}."
ensure
    cluster.disconnect
end
