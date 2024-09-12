import AsyncTester "../src";
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
    await async {};
    let delta = await targetAPI.get();
    balance += delta;
    balance;
  };
};

// Demo: ReleaseTester
do {
  // We are mocking the target with AsyncTesters
  let target = object {
    public let get_ = AsyncTester.ReleaseTester<Nat>(null);
    public shared func get() : async Nat {
      get_.call_result(await* get_.call());
    };
  };

  // We are instantiating the code to test
  let code = CodeToTest(target);

  // Now the actual test runs
  let fut0 = async await* code.fetch();
  let fut1 = async await* code.fetch();
  
  await* target.get_.wait(0);
  target.get_.release(0, ?5);
 
  await* target.get_.wait(1);
  target.get_.release(1, ?3);

  let r0 = await fut0;
  let r1 = await fut1;

  assert r0 == 5 and r1 == 8;
};

// Demo: StageTester
do {
  // We are mocking the target with Testers
  let target = object {
    public let get_ = AsyncTester.StageTester<(), (), Nat>(null);
    public shared func get() : async Nat {
      get_.call_result(await* get_.call());
    };
  };

  ignore target.get_.stage(func() = (), func () = ?5);
  ignore target.get_.stage(func() = (), func () = ?3);

  // We are instantiating the code to test
  let code = CodeToTest(target);

  // Now the actual test runs
  let fut0 = async await* code.fetch();
  let fut1 = async await* code.fetch();
  
  await* target.get_.wait(0);
  target.get_.release(0);

  await* target.get_.wait(1);
  target.get_.release(1);

  let r0 = await fut0;
  let r1 = await fut1;

  assert r0 == 5 and r1 == 8;
};
