require "dotenv/load"
require "couchbase"

options = Couchbase::Options::Cluster.new
options.authenticate(ENV.fetch("USERNAME"), ENV.fetch("PASS"))
options.apply_profile("wan_development")

cluster = Couchbase::Cluster.connect(ENV.fetch("CONN_STR"), options)
ping = cluster.ping(Couchbase::Options::Ping.new(service_types: %i[kv query search]))
ping.services.each { |svc, eps| puts "#{svc}: #{eps.first.state}" }
cluster.disconnect
