module {
  public let DEBUG = false;

  public func f(g : () -> async ()) : async Bool {
    try {
      await g();
    } catch (_) {
      return false;
    };
    return true;
  };

  // This is the API of a target canister which is being called
  // by the canister that we are testing.
  public type TargetAPI = {
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
  public class CodeToTest(targetAPI : TargetAPI) {
    public var balance : Int = 0;

    public func fetch() : async* Int {
      await async {};
      let delta = await targetAPI.get();
      balance += delta;
      balance;
    };
  };
};
