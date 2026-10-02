Import loans from the nightly export

Adds `npm run import:loans -- <members.json> <loans.json>`. Loans whose member joined at another branch get a placeholder member ("Visiting member N") so nothing is dropped. The sample files in `fixtures/` show the shape.
