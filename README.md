# Idric-Net

`Idric-Net` is the reusable networking library for Idriç and Odriç. ICU is its first real dogfood client, not the permanent owner of generic URL, HTTP, TLS, or socket semantics.

## Ownership

The intended stack is:

```text
Idriç / Odriç language
  constrained values, finite choices, dependent relationships
             |
             v
Idric-Net
  URL -> HTTP -> transport/TLS/socket interfaces
             |
             v
small native ABI provider while required
             |
             v
ICU and other applications
```

The compiler owns the *general mechanisms*: constrained scalar domains, finite choices, relations between values, erasure of compile-time facts, and preservation of semantic range/cardinality into IR and backends.

This library owns the *network meanings*: destination ports, URL components, HTTP methods and status semantics, headers, request framing, origins, redirect policy, transport outcomes, and eventually socket/TLS state types.

The compiler should not contain special knowledge that `404` means `not_found`; `Idric-Net` declares that semantic constant and its wire representation. Conversely, `Idric-Net` should not implement a private range-analysis system that the compiler cannot see.

## First executable slice

The first slice deliberately uses only language features available in current Idriç while recording the stronger refinement contract separately in `CONSTRAINTS.md`.

It provides:

- `DestinationPort` with the current checked 1..65535 construction boundary;
- HTTP and HTTPS URL parsing for the subset ICU already exercises;
- `HTTPStatusCode` with the valid 100..599 wire domain and named values such as `not_found = 404`;
- status-class derivation, so any 4xx code is a `client_error` even when unregistered;
- semantic HTTP methods with safe/idempotent properties for the core registered methods used here;
- `HttpHeader`, `HttpBody`, `ByteCount`, request rendering, and UTF-8 byte length;
- the eight-case `transport_result` used by ICU instead of a generic integer.

The nominal/checking wrappers in this initial implementation are a compatibility bridge, not the final Idriç language design. The target is first-class constrained values whose facts survive lowering.

## Native transport boundary

ICU currently owns the live C/OpenSSL socket implementation. That remains an honest temporary provider while the reusable interface is extracted. `Idric-Net` must not claim pure-Idriç TLS or socket ownership until the implementation actually moves.

The migration order is:

1. make pure URL/HTTP/transport semantics authoritative here;
2. make ICU consume this package rather than duplicate those definitions;
3. move the reusable native socket/TLS provider under this repository;
4. replace native pieces with Idriç/Odriç implementations only when executable acceptance proves the new owner.

## Research ledger

Design research and comparison material lives under `research/`:

- [`research/ML-NETWORKING.md`](research/ML-NETWORKING.md) records the Standard ML, OCaml, Lwt/Async, Eio, MirageOS, Conduit, and Cohttp networking precedents and the specific ideas Idric-Net should adopt or reject.
- [`research/PROTOCOL-SOURCES.md`](research/PROTOCOL-SOURCES.md) records the RFC/IANA authority behind URI, HTTP, service ports, IP protocol numbers, TCP, UDP, TLS service identity, and the future resolver boundary.
- [`CONSTRAINTS.md`](CONSTRAINTS.md) records which of those semantic facts should be visible to the Idriç/Odriç type checker and survive lowering.

These are complementary: implementation precedents inform the shape of the interface; standards and registries define protocol meaning and wire encodings; the compiler supplies reusable mechanisms for expressing the resulting constraints.

## Compiler dependency

CI follows the declared Idriç branch `Idriç`, resolves it on every run, and
records the exact SHA that actually ran. A compiler/library incompatibility is
a failing current-head receipt; CI does not retry an older green revision.
`.idric` source is mapped to GitHub Linguist's Idris grammar through
`.gitattributes`.

## ai-ci

The repository carries a deterministic `ai-ci` contract and pins the reviewed `ai-ci` revision in CI. The cross-repository registration also lives in `isomorphisms/ai-ci` so the Idric-Net/Idriç/ICU boundary is treated as a shared acceptance obligation rather than a local README promise.
