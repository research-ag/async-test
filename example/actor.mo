import Principal "mo:base/Principal";

actor class A() {
  var x = 0;
  var delta = 1;
  public func init(p : Principal) : async () {
    let a : actor { foo : () -> async Nat } = actor(Principal.toText(p));
    delta := await a.foo(); 
  };
  public func inc() : async Nat { 
//    try { x } finally { x += 1}
//    x |> ( do {x += 1; _})
    let res = x;
    x += delta;
    res
  };
  public func get() : async Nat { x };
};



