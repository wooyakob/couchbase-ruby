Testing Couchbase Ruby SDK with Capella Free Cluster Couchbase 8.0.2. Index, Data, Query, Search services enabled. Deployed on GCP US Central (Iowa), Single AZ.

- Ruby 4.0.6
- Couchbase Ruby SDK 3.8

# Compare and Swap
CAS. Compare and Swap. Each time the item is modified, its CAS changes.
The CAS value is returned in document metadata, when a document is accessed.
Without explicitly setting the CAS, a new document has a CAS value of 0.

Lost update. Two clients want to add a tag to the same document.

Client A: get → {"tags": ["ruby"]}
Client B: get → {"tags": ["ruby"]}
Client A: replace → {"tags": ["ruby", "sdk"]}
Client B: replace → {"tags": ["ruby", "cas"]}

B's write lands last and wins. A's SDK tag is gone, nobody gets an errors even though A's write succeeded but was overwritten.
With CAS, B's replace carries the CAS from its get. 
But A's write changed the document's CAS, so B's is stale and the server rejects it with CasMismatch. See cas.rb for an example.

Optimistic locking because every client proceeds as if it will be the only writer, conflict is detected at write time rather than prevented at read time.
Trade off is that the rejection must be handled when there is a mismatch. 