import AsyncTester "../src";
import Base "base";
import Text "mo:base/Text";
import Array "mo:base/Array";
import Char "mo:base/Char";

do {
  let mock = AsyncTester.CallTester<(), ()>(Base.DEBUG, "mock method", null);

  var x = ?();

  func g() : async () {
    mock.call_result(await* mock.call((), func() = x));
  };

  do {
    x := ?();
    let fut = Base.f(g);
    await* mock.wait(0, #called);
    mock.release(0);
    assert (await fut) == true;
  };

  do {
    x := null;
    let fut = Base.f(g);
    await* mock.wait(1, #called);
    mock.release(1);
    assert (await fut) == false;
  };
};

do {
  var CHUNK_LENGTH = 3;
  var received = "";

  func receive(t : Text) : ?() {
    if (t == "") return null;
    received #= t;
    ?();
  };

  class Sender(receive : Text -> async ()) {
    let to_send = Array.init<Char>(100, '0');
    var start = 0;
    var end = 0;

    public func push(text : Text) {
      for (c in text.chars()) {
        to_send[end] := c;
        end += 1;
      };
    };

    public func send() : async () {
      var send = "";
      var i = 0;
      while (start < end and i < CHUNK_LENGTH) {
        send #= Char.toText(to_send[start]);
        i += 1;
        start += 1;
      };
      await receive(send);
    };
  };

  let mock = AsyncTester.CallTester<Text, ()>(Base.DEBUG, "receive", null);

  let sender = Sender(
    func(t : Text) : async () = async mock.call_result(await* mock.call(t, receive)),
  );

  sender.push("abc");
  let fut = sender.send();
  await* mock.wait(0, #called);
  mock.release(0);
};
