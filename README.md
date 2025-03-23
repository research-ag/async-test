[![mops](https://oknww-riaaa-aaaam-qaf6a-cai.raw.ic0.app/badge/mops/async-test)](https://mops.one/async-test)
[![documentation](https://oknww-riaaa-aaaam-qaf6a-cai.raw.ic0.app/badge/documentation/async-test)](https://mops.one/async-test/docs)

# Asyncronous methods tester for Motoko

## Overview

Often code under test (CUT) depends on external asyncronous methods. We provide functionality to mock those methods i.e. manage their responses and response times.

### Links

The package is published on [MOPS](https://mops.one/async-test) and [GitHub](https://github.com/research-ag/async-test).

The API documentation can be found [here](https://mops.one/async-test/docs).

For updates, help, questions, feedback and other requests related to this package join us on:

* [OpenChat group](https://oc.app/2zyqk-iqaaa-aaaar-anmra-cai)
* [Twitter](https://twitter.com/mr_research_ag)
* [Dfinity forum](https://forum.dfinity.org/)

### Motivation

Consider such a code to test:

This is the API of a target canister which is being called by the canister that we are testing.

```motoko
type TargetAPI = {
  amount : shared () -> async Nat;
};
```

This is the original code to test that make asynchronous calls.
It is a class that is wrapped in a shim layer of an actor.
For convenience we test the class, not the actor.

With this technique the class functions are usually async*.

We assume that the dependency on the call target is injected via a constructor argument.
This should be standard practice because it is the most flexible for testing.
This technique is used instead of, for example, passing in the actor type or
passing in the principal of the target actor.

We can mock the target (see further below) but we cannot modify the code in this class.
This code is usually given to us and imported.

```motoko
class CodeToTest(targetAPI : TargetAPI) {
  public var balance : Int = 0;

  public func fetch() : async* Int {
    await async ();
    let delta = await targetAPI.amount();
    balance += delta;
    balance;
  };
};
```

Let's solve the following problem by a simple tester:
```motoko
class ExampleTester<T>(default : T) {
  var lock_ = false;

  var x : T = default;

  public func lock() = if (lock_) Debug.trap("") else lock_ := true;

  public func release() = if (not lock_) Debug.trap("") else lock_ := false;

  public func await_unlock() : async* () = async* while (lock_) await async ();

  public func get() : T = if (lock_) Debug.trap("") else x;

  public func set(value : T) = x := value;
};
```

Testing code:
```motoko
let target = object {
  public let amount_ = ExampleTester<Nat>(0);

  public shared func amount() : async Nat {
    await* amount_.await_unlock();
    amount_.get();
  };
};

let code = CodeToTest(target);

target.amount_.set(5);
target.amount_.lock();

let fut0 = async await* code.fetch();
await async ();
target.amount_.release();
let r0 = await fut0;

assert r0 == 5;
```
The classes provided in this library are spin-offs of the ExampleTester.

### Interface

## Usage

### Install with mops

You need `mops` installed. In your project directory run:
```
mops add async-test
```

In the Motoko source file import the package as:
```
import AsyncTester "mo:async-test";
```

### Example

See tests for example usages.

### Build & test

We need up-to-date versions of `node`, `moc` and `mops` installed.

Then run:
```
git clone git@github.com:research-ag/async-test.git
mops install
mops test
```

## Design

## Implementation notes

## Copyright

MR Research AG, 2024-2025
## Authors

Main author: Timo Hanke (timohanke), Andrii Stepanov (AStepanov25)

Contributors: Timo Hanke (timohanke), Andrii Stepanov (AStepanov25)

## License 

Apache-2.0
