import Principal "mo:base/Principal";
import AsyncTester "../src";
import Base "base";

do {
  let get_ = AsyncTester.StageTester<(), (), Nat>(Base.DEBUG, "get", null);

  // We are mocking the target with Testers
  let target = actor Target {
    public shared func get() : async Nat {
      get_.call_result(await* get_.call());
    };
  };

  ignore get_.stage(func() = (), func() = ?5);
  ignore get_.stage(func() = (), func() = ?3);

  // We are instantiating the code to test
  let code = await Base.ActorToTest(Principal.fromActor(target));

  // Now the actual test runs
  let fut0 = code.fetch();
  let fut1 = code.fetch();

  await* get_.wait(0, #called);
  get_.release(0);

  await* get_.wait(1, #called);
  get_.release(1);

  let r0 = await fut0;
  let r1 = await fut1;

  assert r0 == 5 and r1 == 8;
  get_.dispose();
};
