# Compiler-visible network constraints

`Idric-Net` is a primary dogfood target for first-class constrained values in Idriç and Odriç.

The current executable library uses checked wrappers because the language does not yet have the intended refinement syntax. Those wrappers are transitional. The target is that the compiler itself understands the admissible value domain and carries it through type checking, ANF, IR, optimization, and backend lowering.

## Scalar domains

The intended source model is approximately:

```idris
DestinationPort : ℕ where
  1 ≤ number
  number ≤ 65535

HTTPStatusCode : ℕ where
  100 ≤ number
  number ≤ 599
```

Literal construction is compile-time checked. A literal `443` can inhabit `DestinationPort`; `0` and `70000` cannot. Runtime text or bytes must be parsed and checked once before a constrained value is produced.

The constraint is semantic information, not runtime baggage. Any certificate needed only for type checking should be erasable.

## Semantic constants and wire encodings

A registered protocol meaning is not merely a numeric range member. The library declares semantic constants such as:

```idris
not_found : HTTPStatusCode
not_found = 404
```

The compiler should therefore know both that `not_found` inhabits the HTTP status domain and that its exact wire number is 404. The fact that 404 is encoded in decimal on the wire is an HTTP-library fact, not compiler built-in knowledge.

Unregistered HTTP status codes remain representable when they are inside 100..599. Their response class is derived from their first digit; for example any 4xx value is a `client_error` even when no registered semantic name exists.

## Finite choices

`transport_result` has exactly eight alternatives. No integer range should be invented as its source meaning.

The compiler knows from the choice itself:

```text
cardinality = 8
semantic tag domain = 0..7
minimum semantic width = 3 bits
```

A backend may transiently hold that value in a full machine register, but it must not forget the finite domain. Spills and aggregate storage may use byte storage until sub-byte packing exists; range analysis and branch lowering retain the eight-state fact.

The unrelated process exit codes `0, 2, 3, ..., 8` are an explicit ABI encoding introduced only at the process boundary.

## Relations between values

Some network invariants are relations, not independent ranges. These are where dependent results matter most.

Examples:

```text
body has byte length length
Content-Length = length

array has length
index < length

TLS connection is verified for host
request destination host = verified host
```

The compiler should be able to derive or carry these relations so downstream code does not re-check facts already established upstream.

## Arithmetic propagation

Constrained arithmetic should preserve the strongest mechanically derivable bounds.

For example, if:

```text
left  : 0..7
right : 0..7
```

then ordinary widening addition has result range `0..14`. If the programmer requires a smaller result domain, the operation must say what happens: checked failure, modular arithmetic, saturation, or another explicit rule.

The compiler should not silently use machine overflow to choose semantics.

## Scope of the first implementation

The first Idriç/Odriç constraint language should prioritize decidable, systems-useful forms:

- lower and upper integer bounds;
- finite choices and cardinality;
- equality to constants;
- equality/inequality between named values;
- length relationships;
- index less than length;
- simple arithmetic range propagation.

This is enough to express the network contracts above without requiring a general-purpose automated theorem prover.

## Acceptance obligation

A language implementation is not complete merely because constrained syntax parses. Acceptance must show:

1. invalid literals are rejected during compilation;
2. runtime parsing produces a constrained value only after the declared check;
3. derived operations preserve or widen ranges correctly;
4. erased constraint evidence does not inflate runtime representation without need;
5. ANF/IR retain finite cardinality or range information;
6. ARM/Thumb and follower backends do not replace a finite domain with an unconstrained machine word;
7. `not_found` retains exact value 404 and class `client_error` through lowering;
8. ICU consumes the same definitions rather than duplicating protocol semantics.
