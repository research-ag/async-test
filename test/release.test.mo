import AsyncMethodTester "../src";
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

let mock = AsyncMethodTester.ReleaseAsyncMethodTester<()>(null);

func g() : async () {
  await mock.call();
};

do {
  let fut = f(g);
  await async ();
  Debug.print("waiting");
  mock.release(0, ?());
  await fut;
};

do {
  let fut = f(g);
  await async ();
  Debug.print("waiting");
  mock.release(1, null);
  await fut;
};
