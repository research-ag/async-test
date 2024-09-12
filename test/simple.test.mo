import AsyncTester "../src";

func f(g : () -> async ()) : async Bool {
  try {
    await g();
  } catch (_) {
    return false;
  };
  return true;
};

do {
  let mock = AsyncTester.SimpleStageTester<()>(null);

  func g() : async () {
    mock.call_result(await* mock.call());
  };

  do {
    let id = mock.stage(?());
    let fut = f(g);
    await* mock.wait(id);
    mock.release(id);
    assert (await fut) == true;
  };

  do {
    let id = mock.stage(null);
    let fut = f(g);
    await* mock.wait(id);
    mock.release(id);
    assert (await fut) == false;
  };
};

do {
  let mock = AsyncTester.ReleaseTester<()>(null);

  func g() : async () {
    mock.call_result(await* mock.call());
  };

  do {
    let fut = f(g);
    await* mock.wait(0);
    mock.release(0, ?());
    assert (await fut) == true;
  };

  do {
    let fut = f(g);
    await* mock.wait(1);
    mock.release(1, null);
    assert (await fut) == false;
  };
};
