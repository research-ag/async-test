import AsyncTester "../src";
import Debug "mo:base/Debug";

func f(g : () -> async ()) : async () {
  Debug.print("before g");
  try {
    await g();
  } catch (_) {
    Debug.print("error in g");
    return;
  };
  Debug.print("after g");
};

do {
  let mock = AsyncTester.SimpleStageTester<()>(null);

  func g() : async () {
    mock.call_result(await* mock.call());
  };

  do {
    let response = mock.stage(?());
    let fut = f(g);
    await* mock.wait(0);
    Debug.print("waiting");
    mock.release(response);
    await fut;
  };

  do {
    let response = mock.stage(null);
    let fut = f(g);
    await* mock.wait(0);
    Debug.print("waiting");
    mock.release(response);
    await fut;
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
    Debug.print("waiting");
    mock.release(0, ?());
    await fut;
  };

  do {
    let fut = f(g);
    await* mock.wait(1);
    Debug.print("waiting");
    mock.release(1, null);
    await fut;
  };
};
