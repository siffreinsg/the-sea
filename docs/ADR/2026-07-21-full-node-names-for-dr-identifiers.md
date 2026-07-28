# DR identifiers use full node names

**2026-07-21 · Accepted · `f952cee`**

Restic repositories, Backrest plans and Backrest instance names all use the full ship
name — `thriller-bark`, `going-merry`. Not `tb`/`gm`.

These are the identifiers someone reads during a restore, possibly under pressure,
possibly years later, possibly from a bare repo listing with no other context. Ambiguity
there is expensive in a way that ambiguity in a DNS name is not.

**Consequence:** short forms stay allowed exactly where they are throwaway — DNS
(`backrest-tb.siffreinsigy.me`) and Komodo stack names (`backrest-tb`, `alloy-gm`). Both
conventions coexist on purpose; this is not drift.
