# Protocol sources and registries

This file records the standards and registries behind the semantic values represented by `Idric-Net`.

It complements `ML-NETWORKING.md`:

- `ML-NETWORKING.md` asks how networking interfaces should be typed and layered;
- this file asks what the protocol values actually mean and where their wire encodings come from.

The distinction matters. An RFC can define the semantics of a field while an IANA registry assigns particular values inside that field. Neither fact should be built into the compiler merely because Idriç can represent it precisely.

## Source classes

Use three source classes rather than treating every URL as interchangeable:

1. **Protocol standards** define grammar, state transitions, field meanings, and required behavior.
2. **IANA registries** define assigned names and numeric/textual wire values that can change by addition over time.
3. **Implementation references** show useful interface or backend architecture but are not protocol authority.

The first two belong here. ML-family implementation references belong in `ML-NETWORKING.md`.

## URI / URL structure

Primary source:

- RFC 3986, *Uniform Resource Identifier (URI): Generic Syntax*: https://www.rfc-editor.org/rfc/rfc3986.html

RFC 3986 defines the generic URI decomposition into scheme, authority, path, query, and fragment. `Network.URL` should retain those meanings rather than representing a parsed URL as an undifferentiated string.

HTTP-specific use of URI components is further constrained by the current HTTP specifications. URI parsing itself should not perform DNS resolution or open a connection.

## HTTP semantics

Primary standards and registries:

- RFC 9110, *HTTP Semantics*: https://www.rfc-editor.org/rfc/rfc9110.html
- IANA HTTP Method Registry: https://www.iana.org/assignments/http-methods/http-methods.xhtml
- IANA HTTP Status Code Registry: https://www.iana.org/assignments/http-status-codes/http-status-codes.xhtml

### Status-code domain

RFC 9110 defines HTTP status codes as three decimal digits from 100 through 599 inclusive. The first digit determines the response class:

```text
1xx informational
2xx successful
3xx redirection
4xx client error
5xx server error
```

A recipient can therefore classify an unrecognized status code by its class even when no registered phrase is known. Values outside 100..599 are not valid HTTP status codes.

This is the reason `HTTPStatusCode` is a constrained numeric domain while `status_class` is derivable from every value in that domain.

### Registered status meanings

A registered status is both a member of the numeric domain and a named protocol meaning. For example:

```text
not_found : HTTPStatusCode
wire(not_found) = 404
```

RFC 9110 defines 404 `Not Found` to mean that the origin server did not find a current representation for the target resource or is unwilling to disclose that one exists. It does **not** by itself say whether that condition is temporary or permanent; 410 `Gone` is preferred when permanence is known.

That relationship is a library/standard fact, not an arithmetic theorem and not compiler built-in knowledge.

### HTTP methods

Method names and their standardized safe/idempotent properties come from HTTP semantics plus the IANA HTTP Method Registry. Do not represent every request method as an unconstrained string merely because the method is text on the wire.

The registry is extensible, so Idric-Net should distinguish:

- registered methods with known semantic properties;
- syntactically valid extension methods whose properties are not known to the library.

An application such as ICU may deliberately expose a smaller finite subset such as only `GET` and `POST` without redefining the generic HTTP method universe.

## Service names and transport ports

Primary sources:

- IANA Service Name and Transport Protocol Port Number Registry: https://www.iana.org/assignments/service-names-port-numbers/service-names-port-numbers.xhtml
- RFC 6335, *Internet Assigned Numbers Authority (IANA) Procedures for the Management of the Service Name and Transport Protocol Port Number Registry*: https://www.rfc-editor.org/rfc/rfc6335.html

The IANA registry currently divides the 16-bit port-number space into:

```text
System Ports       0..1023
User Ports         1024..49151
Dynamic/Private    49152..65535
```

Important distinction: the existing `DestinationPort` constructor accepts 1..65535 as an **Idric-Net destination policy**. That must not be documented as though the protocol field itself were only 1..65535. Port zero exists in the 16-bit field and the IANA registry; its special/reserved uses are different from an ordinary destination a client should connect to.

A future lower-level packet representation may therefore need a full `PortNumber` domain of 0..65535 plus a stricter `DestinationPort` used by connection APIs.

Service name resolution is also not just integer parsing. A service name is resolved in the context of a transport protocol and may map to assigned port numbers.

## IP protocol numbers

Primary registry:

- IANA Protocol Numbers: https://www.iana.org/assignments/protocol-numbers/protocol-numbers.xhtml

The IPv4 `Protocol` field and IPv6 `Next Header` use an assigned numeric namespace. Core values relevant to the first Idric-Net packet dispatch work include:

```text
1  -> ICMP
6  -> TCP
17 -> UDP
```

These should be represented as semantic alternatives paired with exact wire encodings, not as compiler knowledge and not as magic integers scattered through parsers.

A packet decoder can therefore have the conceptual shape:

```text
protocol_number bytes
  -> icmp packet
   | tcp segment
   | udp datagram
   | registered/unknown protocol payload
```

The registry contains many more values; Idric-Net does not need a giant closed choice merely to begin decoding ICMP/TCP/UDP. The representation should preserve unknown or not-yet-implemented assigned values without confusing them with malformed field encodings.

## TCP

Primary source:

- RFC 9293 / STD 7, *Transmission Control Protocol (TCP)*: https://www.rfc-editor.org/rfc/rfc9293.html

RFC 9293 is the current base TCP specification and replaces RFC 793 as the normative base specification.

TCP is connection-oriented, bidirectional, and uses port numbers to identify application services and multiplex flows between hosts. The specification also defines the TCP state machine and segment fields.

This gives Idric-Net two related but distinct type-state layers:

1. the **OS/socket API lifecycle** (`fresh`, `bound`, `listening`, `connected`, etc.);
2. the **wire TCP state machine** used by a direct TCP implementation.

Do not collapse those into one type merely because both contain words such as `listen` or `connected`. An OS socket backend can expose a connected stream without Idric-Net itself owning the TCP control block.

## UDP

Primary source:

- RFC 768 / STD 6, *User Datagram Protocol*: https://www.rfc-editor.org/rfc/rfc768.html

RFC 768 defines UDP's datagram service, source/destination port fields, datagram length, and checksum. It does not provide TCP-style ordered reliable delivery.

UDP reinforces the distinction between stream and datagram sockets seen in the Standard ML Basis interface. A datagram endpoint should retain source/destination endpoint information per datagram rather than pretending it is a byte stream.

The RFC has later updates; when direct packet-level UDP support is implemented, conformance work must inspect the RFC Editor's current update chain rather than treating the 1980 document as the whole modern implementation obligation.

## TLS

Primary sources:

- RFC 8446, *The Transport Layer Security (TLS) Protocol Version 1.3*: https://www.rfc-editor.org/rfc/rfc8446.html
- RFC 9525, *Service Identity in TLS*: https://www.rfc-editor.org/rfc/rfc9525.html

RFC 9525 obsoletes RFC 6125 for service identity. It distinguishes the service identity the client intends to reach from the identity presented by the server and specifies the matching/verification rules.

That supports a useful Idric-Net relation:

```text
reference host = host whose identity was successfully verified
```

A raw TLS session and a TLS connection verified for a particular service identity are therefore not semantically interchangeable. The type/API should make verification state visible where practical.

The current ICU provider uses OpenSSL. OpenSSL is an implementation provider, not the authority for what successful service-identity verification means.

## DNS and host resolution

Starting references for the future resolver layer:

- RFC 1034, *Domain Names — Concepts and Facilities*: https://www.rfc-editor.org/rfc/rfc1034.html
- RFC 1035, *Domain Names — Implementation and Specification*: https://www.rfc-editor.org/rfc/rfc1035.html
- RFC 8499, *DNS Terminology*: https://www.rfc-editor.org/rfc/rfc8499.html

Idric-Net does not yet claim a direct DNS implementation. The immediate architectural requirement is narrower: keep `HostName`, `IPAddress`, and effectful name resolution distinct so an OS resolver, test resolver, cache, or future direct DNS backend can satisfy the same interface.

## Provenance rule for new semantic constants

When adding a named network value, record enough provenance to answer both questions:

```text
What does this value mean?
What exact bits/bytes/text represent it on the wire?
```

Examples:

```text
HTTP not_found
  meaning: RFC 9110 §15.5.5
  wire:    decimal status code 404
  registry: IANA HTTP Status Code Registry

IP protocol TCP
  meaning: TCP / RFC 9293
  wire:    protocol number 6
  registry: IANA Protocol Numbers
```

Where a registry can grow, code should distinguish an unknown-to-this-library assignment from an invalid field representation. Updating registry knowledge should not require changing the Idriç compiler.
