import AsyncMethodTester "../src";
import Debug "mo:base/Debug";
import Generics "mo:generics";

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

let mock = AsyncMethodTester.SimpleStageAsyncMethodTester<()>(null);

func g() : async () {
  let output = Generics.Buf<()>();
  await* mock.call(output);
  output.get();
};

do {
  let response = mock.stage(?());
  let fut = f(g);
  await async ();
  Debug.print("waiting");
  mock.release(response);
  await fut;
};

do {
  let response = mock.stage(null);
  let fut = f(g);
  await async ();
  Debug.print("waiting");
  mock.release(response);
  await fut;
};
