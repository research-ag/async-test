import AsyncMethodTester "../src";
import Debug "mo:base/Debug";

// This is the API of a target canister which is being called
// by the canister that we are testing.
type TargetAPI = {
  get : shared () -> async Nat;
};

// This is the original code to test that make asynchronous calls.
// It is a class that is wrapped in a shim layer of an actor.
// For convenience we test the class, not the actor.
//
// With this technique the class functions are usually async*.
//
// We assume that the dependency on the call target is injected via a constructor argument.
// This should be standard practice because it is the most flexible for testing.
// This technique is used instead of, for example, passing in the actor type or
// passing in the principal of the target actor.
//
// We can mock the target (see further below) but we cannot modify the code in this class.
// This code is usually given to us and imported.
class CodeToTest(targetAPI : TargetAPI) {
  public var balance : Int = 0;
  public func fetch() : async* Int {
    let delta = await targetAPI.get();
    balance += delta;
    balance;
  };
};

// Demo: ReleaseAsyncMethodTester
do {
  // We are mocking the target with AsyncMethodTesters
  let target = object {
    public let get_ = AsyncMethodTester.ReleaseAsyncMethodTester<Nat>(null);
    public shared func get() : async Nat {
      get_.call_result(await* get_.call());
    };
  };

  // We are instantiating the code to test
  let code = CodeToTest(target);

  // Now the actual test runs
  let fut0 = async await* code.fetch();
  let fut1 = async await* code.fetch();
  await async {};

  target.get_.release(0, ?5);
  target.get_.release(1, ?3);

  let r0 = await fut0;
  let r1 = await fut1;

  Debug.print(debug_show (r0, r1));
  assert r0 == 5 and r1 == 8;
};

// Demo: CallAsyncMethodTester
do {
  // We are mocking the target with AsyncMethodTesters
  let target = object {
    public let get_ = AsyncMethodTester.CallAsyncMethodTester<(), Nat>(null);
    public var x : Nat = 0;
    public shared func get() : async Nat {
      get_.call_result(await* get_.call((), func() = ?x));
    };
  };

  // We are instantiating the code to test
  let code = CodeToTest(target);

  // Now the actual test runs
  let fut0 = async await* code.fetch();
  let fut1 = async await* code.fetch();
  await async {};

  target.x := 5;
  target.get_.release(0);
  target.x := 3;
  target.get_.release(1);

  let r0 = await fut0;
  let r1 = await fut1;

  Debug.print(debug_show (r0, r1));
  assert r0 == 5 and r1 == 8;
};
