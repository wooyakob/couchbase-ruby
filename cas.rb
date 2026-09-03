require "dotenv/load"
require "couchbase"

options = Couchbase::Options::Cluster.new
options.authenticate(ENV.fetch("USERNAME"), ENV.fetch("PASS"))
options.apply_profile("wan_development")

cluster = Couchbase::Cluster.connect(ENV.fetch("CONN_STR"), options)

bucket = cluster.bucket(ENV.fetch("BUCKET"))
scope = bucket.scope(ENV.fetch("SCOPE"))
collection = scope.collection(ENV.fetch("COLLECTION"))

doc_id = "blog::cas-demo"

# Two clients each want to add a tag. They both read before either one writes,
# which is the interleaving that loses an update.
def reset(collection, doc_id)
    collection.upsert(doc_id, {"title" => "Jake's Blog Post", "tags" => ["ruby"]})
    puts "\nReset #{doc_id} to #{collection.get(doc_id).content["tags"]}."
end

# The pattern you actually ship: re-read, re-apply, retry on CasMismatch.
# Bounded, because a document under constant contention should fail loudly
# rather than spin forever.
def add_tag_with_retry(collection, doc_id, tag, attempts: 3)
    attempts.times do |i|
        current = collection.get(doc_id)
        content = current.content
        content["tags"] += [tag]

        begin
            collection.replace(doc_id, content,
                               Couchbase::Options::Replace(cas: current.cas))
            puts "  added #{tag.inspect} on attempt #{i + 1}, tags are now #{content["tags"]}."
            return
        rescue Couchbase::Error::CasMismatch
            puts "  attempt #{i + 1} to add #{tag.inspect} hit a CasMismatch, re-reading."
        end
    end

    raise "gave up adding #{tag.inspect} after #{attempts} attempts"
end

begin
    # Without CAS: the lost update.
    reset(collection, doc_id)

    client_a = collection.get(doc_id)
    client_b = collection.get(doc_id)
    puts "A read CAS #{client_a.cas}, B read CAS #{client_b.cas}. Same generation."

    a_content = client_a.content
    a_content["tags"] += ["sdk"]
    collection.replace(doc_id, a_content)
    puts "A replaced with #{a_content["tags"]}, no CAS passed."

    # B is working from the copy it read before A wrote. With no CAS the server
    # has nothing to compare, so this succeeds and A's tag is gone.
    b_content = client_b.content
    b_content["tags"] += ["cas"]
    collection.replace(doc_id, b_content)
    puts "B replaced with #{b_content["tags"]}, no CAS passed."

    puts "Result: #{collection.get(doc_id).content["tags"]} - A's write is gone, and nobody was told."

    # With CAS: the conflict surfaces, and the retry saves both writes.
    reset(collection, doc_id)

    client_a = collection.get(doc_id)
    client_b = collection.get(doc_id)
    puts "A read CAS #{client_a.cas}, B read CAS #{client_b.cas}. Same generation again."

    a_content = client_a.content
    a_content["tags"] += ["sdk"]
    a_result = collection.replace(doc_id, a_content,
                                  Couchbase::Options::Replace(cas: client_a.cas))
    puts "A replaced with #{a_content["tags"]} using CAS #{client_a.cas}, CAS is now #{a_result.cas}."

    # B's held CAS is now a generation behind, so the server rejects it instead
    # of clobbering A. B re-reads, re-applies its change, and writes again.
    b_content = client_b.content
    b_content["tags"] += ["cas"]
    begin
        collection.replace(doc_id, b_content,
                           Couchbase::Options::Replace(cas: client_b.cas))
        puts "Unexpected: B's stale CAS #{client_b.cas} was accepted."
    rescue Couchbase::Error::CasMismatch
        puts "B's CAS #{client_b.cas} is stale, the document is at #{a_result.cas}. B retries:"
        add_tag_with_retry(collection, doc_id, "cas")
    end

    puts "Result: #{collection.get(doc_id).content["tags"]} - both writes survived."
rescue Couchbase::Error::CouchbaseError => e
    puts "Couchbase error: #{e.class}: #{e.message}"
ensure
    cluster.disconnect
end
