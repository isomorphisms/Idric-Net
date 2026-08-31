# ML-family networking research

This note records the networking design research that informs `Idric-Net`. It is a design ledger, not a claim that any one predecessor should be copied wholesale.

The recurring question is: **which network facts belong in types and module boundaries, and which belong only in a backend?**

## Standard ML Basis: the strongest socket type-state precedent

Sources:

- Standard ML Basis Library, `Socket`: https://smlfamily.github.io/Basis/socket.html
- Standard ML Basis Library, `INetSock`: https://smlfamily.github.io/Basis/inet-sock.html
- Standard ML Basis Library, `NetHostDB`: https://smlfamily.github.io/Basis/net-host-db.html
- SML/NJ INet library: https://www.smlnj.org/doc/smlnj-lib/INet/inet-lib.html

The Standard ML Basis socket interface carries semantic distinctions in the socket type instead of leaving all legality to runtime calls.

Its core shape is effectively:

```text
socket address family socket_kind

address family:
  internet
  unix-domain
  ...

socket kind:
  datagram
  stream mode

stream mode:
  passive
  active
```

The important consequence is that operations state which socket states they accept:

- `listen` accepts a passive stream socket;
- `accept` accepts a passive stream socket and returns an active stream socket plus the peer address;
- stream send/receive operations accept active streams;
- datagram send/receive operations accept datagram sockets and preserve the address family;
- Internet socket construction is separated into `INetSock`, which specializes the generic socket interface to the Internet address family.

This is directly relevant to Idriç. `listen`, `accept`, `connect`, stream I/O, and datagram I/O should not all accept one undifferentiated `Socket` value if the type checker can rule out invalid combinations.

The SML interface is not perfect. Close-state is not tracked in the type, and several failures still appear as runtime `SysErr`. But it demonstrates that ordinary systems networking can gain useful static state without becoming an elaborate theorem-proving exercise.

### Name resolution is separate

`NetHostDB` represents Internet addresses separately from host database entries and name lookup. That separation is worth keeping:

```text
HostName --resolve--> one or more IPAddress
IPAddress + DestinationPort --> InternetEndpoint
```

A host name is not an IP address, and resolution is an effectful operation rather than a string conversion.

### SML/NJ and MLton portability

The SML/NJ INet library provides higher-level socket utilities and is packaged for both SML/NJ and MLton. The useful precedent is not a particular helper routine; it is that the portable Basis socket vocabulary can support implementation-specific convenience layers without moving the semantic core into those layers.

## OCaml `Unix`: useful FFI baseline, weaker semantic typing

Source:

- OCaml `Unix` module: https://ocaml.org/manual/5.2/api/Unix.html

OCaml's traditional Unix interface exposes algebraic choices for socket domain and socket kind:

```text
socket_domain = PF_UNIX | PF_INET | PF_INET6
socket_type   = SOCK_STREAM | SOCK_DGRAM | SOCK_RAW | SOCK_SEQPACKET
sockaddr      = ADDR_UNIX ... | ADDR_INET ...
```

This is already clearer than passing raw C integer constants, but the resulting file descriptor does not retain the domain, stream/datagram kind, or listening/connected state in its type. It is therefore a good model for the **native ABI vocabulary**, not the target Idriç surface API.

`Unix.open_connection` also shows why resource ownership must be explicit: it returns input/output channels that share one underlying socket descriptor. Idric-Net should make shared ownership or a single connection owner visible rather than relying on garbage collection conventions.

## Lwt and Async: concurrency is orthogonal to network meaning

Sources:

- Lwt TCP client example: https://ocaml.org/cookbook/tcp-client/lwt
- Lwt Unix socket API: https://ocaml.org/p/lwt/latest/doc/lwt.unix/Lwt_unix/index.html
- Jane Street Async: https://github.com/janestreet/async

Lwt and Async address waiting, nonblocking I/O, event loops, timeouts, readers, and writers. They largely sit around lower-level networking APIs rather than redefining what an IP address, TCP stream, HTTP method, or status code means.

The lesson for Idric-Net is architectural: **do not bake one scheduling model into protocol semantics**. A future synchronous, evented, coroutine, Android, or direct-stack backend should be able to implement the same semantic interfaces.

Cancellation, timeout, and readiness are real network-operation outcomes, but they are not reasons to make `IPAddress`, `DestinationPort`, `HTTPStatusCode`, or `HttpMethod` backend-specific.

## Eio: capability and lifetime typing

Sources:

- Eio networking: https://ocaml.org/p/eio/latest/doc/eio/Eio/Net/index.html
- Eio socket options: https://ocaml.org/p/eio/latest/doc/eio/Eio/Net/Sockopt/index.html

Eio adds two useful ideas beyond the older Unix interface:

1. Network operations require an explicit network resource/capability rather than implicitly reaching into global process state.
2. Socket lifetime is associated with a `Switch`, so ownership and cleanup are structural rather than informal.

Eio also gives socket options typed value domains: Boolean options carry Boolean values, buffer-size options carry integer values, and the option set is extensible for backend-specific additions.

Useful Idric-Net consequences:

- make the authority to perform network I/O explicit at the effect/backend boundary;
- make connection lifetime and close ownership explicit;
- type socket-option values instead of representing every option as `(integer, integer)`;
- keep portable options in the reusable interface and backend-specific options in backend extensions.

## MirageOS: protocol signatures independent of implementation

Sources:

- Mirage TCP/IP stack: https://github.com/mirage/mirage-tcpip
- Mirage TCP/IP architecture note: https://mirage.io/blog/intro-tcpip
- Mirage typed-signature architecture: https://github.com/mirage/mirage/blob/main/lib/mirage.mli

MirageOS is the strongest architecture precedent for Idric-Net's intended backend split.

The Mirage TCP/IP stack defines interfaces corresponding to IP, ICMP, UDP, and TCP and provides multiple implementations. In particular, the same protocol-facing interfaces can be backed either by operating-system sockets or by a direct OCaml TCP/IP stack over a network interface.

That is almost exactly the separation Idric-Net needs:

```text
application / HTTP / DNS / TLS
          |
          v
reusable typed network interfaces
          |
      +---+----------------+
      |                    |
      v                    v
OS socket backend      direct stack backend
```

The interface should say what a TCP connection, datagram endpoint, resolver, or verified TLS connection means. It should not say whether the implementation currently reaches Linux/Android sockets through C, an Idriç native backend, or a future direct packet stack.

Mirage also demonstrates that protocol layers can be separately replaceable: an application that only needs UDP should not have to pretend it needs TCP, and a stack assembled from lower layers need not expose one monolithic "network object".

## Conduit: separate endpoint resolution from connection establishment

Sources:

- Conduit documentation: https://ocaml.org/p/conduit/latest/doc/index.html
- Conduit package description: https://ocaml.org/p/conduit/latest/doc/README.html

Conduit separates:

- abstract endpoints;
- URI/name resolution;
- concrete connection establishment;
- TLS implementation choice;
- Lwt, Async, Unix, and Mirage backends.

This is useful for Idric-Net because `https://example.com/` is not itself a connected socket. There is a sequence of semantic transformations:

```text
URL
  -> origin / authority
  -> host + service or explicit port
  -> resolved candidate IP endpoints
  -> transport connection
  -> optional TLS verification for the intended host
  -> HTTP exchange
```

Each step can fail for a different reason and should not be collapsed into one integer error code.

## Cohttp: protocol core separated from I/O backend

Sources:

- Cohttp repository and architecture: https://github.com/mirage/ocaml-cohttp
- Cohttp generic client interface: https://ocaml.org/p/cohttp/latest/doc/cohttp/Cohttp/Generic/Client/module-type-S/index.html

Cohttp keeps core HTTP definitions and parsing separate from Lwt, Async, Mirage, curl, and Eio implementations. Its generic client interface abstracts the I/O effect and body representation while keeping HTTP request/response concepts common.

This reinforces two Idric-Net rules:

1. HTTP grammar and semantics belong above the transport backend.
2. A backend interface should be small enough that multiple execution models can implement it without duplicating the HTTP model.

Idric-Net should go further where Idriç can express more. Registered methods, status-code classes, constrained port/status ranges, redirect rules, and request/body length relationships should be semantic values rather than falling back to strings and machine integers merely because the wire encoding uses text and numbers.

## ICU: current dogfood client, not the generic owner

Current ICU deliberately represents only:

```text
URL scheme: http | https
request:    GET | POST
```

Its Idriç code owns the current URL subset and HTTP rendering; a native C/OpenSSL provider owns sockets, TLS, response framing, redirects, and response streaming.

That is a useful acceptance client, but generic facts should migrate toward Idric-Net:

- URL/URI component types;
- ports and service names;
- HTTP methods and method properties;
- HTTP status codes and classes;
- header names/values where useful;
- request/response framing facts;
- endpoint resolution;
- transport outcomes;
- socket state;
- TLS peer-name verification state.

ICU should retain only application policy and its intentionally small command surface.

## What Idric-Net should adopt

### 1. SML-style socket state

Target shape, names still provisional:

```text
Socket address_family kind state

kind  = stream | datagram
state = fresh | bound | listening | connected | half_closed | closed
```

Not every Cartesian-product combination needs to exist. Operations should produce only legal successor states.

For example:

```text
listen  : Socket af stream bound     -> Socket af stream listening
accept  : Socket af stream listening -> (Socket af stream connected, Endpoint af)
connect : Socket af stream fresh     -> Endpoint af -> result (Socket af stream connected)
```

A first implementation can use fewer states if compiler support is not ready, but the interface should not intentionally erase distinctions that SML proved practical decades ago.

### 2. Distinct address and endpoint meanings

Do not use `String` for all of these:

```text
HostName
IPv4Address
IPv6Address
IPAddress
DestinationPort
ServiceName
InternetEndpoint
UnixEndpoint
```

Parsing text produces these values; the text itself is not the semantic representation.

### 3. Resolution as an interface

Name resolution should be replaceable:

```text
resolve : Resolver -> HostName -> Service -> result candidate_endpoints
```

The OS resolver, Android resolver, test fixture, cached resolver, or direct DNS implementation can satisfy the same contract.

### 4. Backend-neutral transport interfaces

Keep TCP/UDP semantics independent of whether the provider is:

- the current C/native socket bridge;
- a future direct Idriç/Odriç system-call backend;
- a test backend;
- a direct packet stack.

### 5. Explicit capability and lifetime ownership

Borrow Eio's good idea without copying its runtime model: network I/O should require an explicit provider/capability, and a connection should have one clear lifetime owner.

### 6. Protocol semantics above the wire encoding

`404` is not "just an integer" any more than TCP protocol number `6` is merely an arbitrary byte. The library should retain both:

```text
semantic meaning <-> exact registered wire encoding
```

That does not require a theorem. It requires a library declaration backed by the relevant standard or registry.

## What Idric-Net should not copy

- Do not expose one untyped file descriptor as the main socket abstraction just because POSIX does.
- Do not make concurrency library choice part of `HTTPStatusCode`, `IPAddress`, `TCPConnection`, or other protocol meanings.
- Do not make HTTP depend on a specific TLS library.
- Do not make URI parsing perform network resolution.
- Do not turn every registered numeric protocol field into an unconstrained `Int` after parsing.
- Do not hide backend differences by silently falling back to another implementation.
- Do not claim a direct Idriç stack exists until executable acceptance shows it does.

## Concrete layering target

```text
Network.Types
  constrained scalar domains and finite protocol choices

Network.Address
  host names, IPv4, IPv6, address families

Network.Endpoint
  ports, service names, Internet endpoints

Network.Resolve
  host/service resolution interface and outcomes

Network.Socket
  stream/datagram and lifecycle state

Network.IP
  IP protocol-number semantics and packet-facing types

Network.ICMP
Network.UDP
Network.TCP
  protocol-specific semantics and transport interfaces

Network.TLS
  peer identity, verified/unverified connection state, TLS outcomes

Network.URL
  URI/URL structure used by network protocols

Network.HTTP
  methods, status codes, fields, requests, responses, redirects

backend provider
  OS sockets / Android / native ABI / test / future direct stack
```

This is a research target, not a claim that all modules already exist. The current executable slice remains intentionally smaller.