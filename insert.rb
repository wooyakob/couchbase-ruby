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
    collection.insert(doc_id, {"title" => "Jake's Blog Post"})
    puts "Document #{doc_id} inserted."
rescue Couchbase::Error::DocumentExists
    puts "Sorry, the document #{doc_id} already exists!"
ensure
    cluster.disconnect
end
