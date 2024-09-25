import AsyncTester "../src";
import Base "base";

do {
  let mock = AsyncTester.ReleaseTester<()>(?"mock method", null, Base.DEBUG);

  func g() : async () {
    mock.call_result(await* mock.call());
  };

  do {
    let fut = Base.f(g);
    await* mock.wait(0, #running);
    mock.release(0, ?());
    assert (await fut) == true;
  };

  do {
    let fut = Base.f(g);
    await* mock.wait(1, #running);
    mock.release(1, null);
    assert (await fut) == false;
  };
};

// Demo: ReleaseTester
do {
  // We are mocking the target with AsyncTesters
  let target = object {
    public let get_ = AsyncTester.ReleaseTester<Nat>(?"get", null, Base.DEBUG);
    
    public shared func get() : async Nat {
      get_.call_result(await* get_.call());
    };
  };

  // We are instantiating the code to test
  let code = Base.CodeToTest(target);

  // Now the actual test runs
  let fut0 = async await* code.fetch();
  let fut1 = async await* code.fetch();
  
  await* target.get_.wait(0, #running);
  target.get_.release(0, ?5);
 
  await* target.get_.wait(1, #running);
  target.get_.release(1, ?3);

  let r0 = await fut0;
  let r1 = await fut1;

  assert r0 == 5 and r1 == 8;
};