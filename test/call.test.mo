import AsyncTester "../src";
import Base "base";

do {
  let mock = AsyncTester.CallTester<(), ()>(null);

  var x = ?();

  func g() : async () {
    mock.call_result(await* mock.call((), func () = x));
  };

  do {
    x := ?();
    let fut = Base.f(g);
    await* mock.wait(0);
    mock.release(0);
    assert (await fut) == true;
  };

  do {
    x := null;
    let fut = Base.f(g);
    await* mock.wait(1);
    mock.release(1);
    assert (await fut) == false;
  };
};
