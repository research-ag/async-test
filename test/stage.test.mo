import AsyncTester "../src";
import Base "base";

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
  let code = Base.CodeToTest(target);

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
