# Mirage architecture translation

This directory is a deliberately small translation of a few MirageOS networking ideas into Idriç-shaped interfaces. It is not a port of MirageOS and it does not claim that Idric-Net already has a direct TCP/IP stack.

## The two ideas being preserved

### 1. Protocol interfaces do not belong to one backend

Mirage's TCP/IP libraries define protocol-facing module signatures and provide more than one implementation. In particular, the same broad IP/UDP/TCP interfaces can be supplied by a traditional host-socket stack or by a direct stack that talks to a network device.

`Architecture.idric` translates that into explicit provider values:

```text
application
    |
    v
NetworkStack
  |      |
  v      v
 TCP    UDP

underneath the same application-facing shape:

host sockets                 direct stack
     |                            |
     v                            v
HostSocketProvider           NetworkDevice
                                  |
                                  v
                              IPProvider
                                  |
                                  v
                           TCPProvider / UDPProvider
```

The application receives `NetworkStack`. It does not need to know whether the implementation underneath came from POSIX/Android sockets, a test implementation, or a future direct Idriç stack.

### 2. A network stack is assembled from smaller layers

Mirage does not treat "the network" as one indivisible object. Its configuration layer composes a network interface, Ethernet, ARP/IP, UDP, TCP, resolver, and higher protocols.

The first Idriç sketch keeps only enough structure to preserve that architectural fact:

- `NetworkDevice` is the packet-facing device boundary;
- `IPProvider` sits above a device;
- `TCPProvider` and `UDPProvider` are application-facing transport capabilities;
- `NetworkStack` groups the transports an application actually consumes;
- `HostSocketAssembly` and `DirectAssembly` record which implementation route supplied that common stack.

This is intentionally less machinery than Mirage's module/functor and configuration system. The point is to preserve the separation, not copy OCaml's module language.

## Why this matters for Idric-Net

The immediate Idric-Net implementation may use native host sockets. That should not force `HTTP`, DNS, or application code to become host-socket APIs. If a later backend implements IP/TCP/UDP directly, the higher layers should be reusable rather than rewritten.

The useful invariant is:

```text
protocol meaning is stable
backend assembly is replaceable
```

That is the part of Mirage worth carrying forward first.

## Upstream references

- MirageOS typed configuration interfaces: <https://github.com/mirage/mirage/blob/main/lib/mirage.mli>
- Mirage TCP/IP stack: <https://github.com/mirage/mirage-tcpip>

The upstream `mirage-tcpip` repository explicitly maintains both socket-backed and direct implementations of its IP/ICMP/UDP/TCP interfaces. The direct implementation is built over a network-interface abstraction rather than Unix sockets.
