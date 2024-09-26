import Debug "mo:base/Debug";

do {
  class ExampleTester<T>(default : T) {
    var lock_ = false;

    var x : T = default;

    public func lock() = if (lock_) Debug.trap("") else lock_ := true;

    public func release() = if (not lock_) Debug.trap("") else lock_ := false;

    public func await_unlock() : async* () = async* while (lock_) await async ();

    public func get() : T = if (lock_) Debug.trap("") else x;

    public func set(value : T) = x := value;
  };

  type TargetAPI = {
    amount : shared () -> async Nat;
  };

  class CodeToTest(targetAPI : TargetAPI) {
    public var balance : Int = 0;

    public func fetch() : async* Int {
      await async ();
      let delta = await targetAPI.amount();
      balance += delta;
      balance;
    };
  };

  let target = object {
    public let amount_ = ExampleTester<Nat>(0);

    public shared func amount() : async Nat {
      await* amount_.await_unlock();
      amount_.get();
    };
  };

  let code = CodeToTest(target);
  
  target.amount_.set(5);
  target.amount_.lock();
  
  let fut0 = async await* code.fetch();
  await async ();
  target.amount_.release();
  let r0 = await fut0;

  assert r0 == 5;
};
