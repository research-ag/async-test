import AsyncTester "../src";
import Base "base";

do {
  let mock = AsyncTester.SimpleStageTester<()>(Base.DEBUG, ?"mock method", null);

  func g() : async () {
    mock.call_result(await* mock.call());
  };

  do {
    let id = mock.stage(?());
    let fut = Base.f(g);
    await* mock.wait(id, #running);
    mock.release(id);
    assert (await fut) == true;
  };

  do {
    let id = mock.stage(null);
    let fut = Base.f(g);
    await* mock.wait(id, #running);
    mock.release(id);
    assert (await fut) == false;
  };
};
