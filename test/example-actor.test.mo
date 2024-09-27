import Debug "mo:base/Debug";
import Principal "mo:base/Principal";
import Text "mo:base/Text";
import X "../example/actor";

func printName(a : actor {}, name : Text) {
  let p = Principal.fromActor(a);
  let ?t = Text.decodeUtf8(Principal.toBlob(p)) else Debug.trap("");
  Debug.print("Created actor " # name # " with raw principal: " # t);
};

let a = await X.A(); // actor to test
// printName(a, "a");

assert (await a.get()) == 0; 
assert (await a.inc()) == 0;
assert (await a.get()) == 1; 

let b = actor {
  public func foo() : async Nat { 5 }; 
};
// printName(b, "b");

await a.init(Principal.fromActor(b));

