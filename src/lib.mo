/// Async method tester
///
/// Copyright: 2023-2024 MR Research AG
/// Main author: Timo Hanke (timohanke), Andrii Stepanov (AStepanov25)
/// Contributors: Timo Hanke (timohanke), Andrii Stepanov (AStepanov25)

import Debug "mo:base/Debug";
import Error "mo:base/Error";
import Option "mo:base/Option";
import Buffer "mo:base/Buffer";

module {
  /// State of a response/call.
  public type State = {
    /// Staged means the call hasn't arrived yet.
    #staged;
    /// Running means the call has arrived and is waiting to be released.
    #running;
    /// Ready means the call has arrived and been released.
    #ready;
  };

  /// The first function is being run before release, the second after release.
  /// Null in return of the second function means throw an error.
  type Methods<T, S, R> = (pre : T -> S, after : S -> ?R);

  /// Class responsible for a single call.
  class Response<T, S, R>(lock_ : Bool, method : Methods<T, S, R>, limit : Nat) {
    var lock = lock_;

    public var state : State = #staged;

    var methods : Methods<T, S, R> = method;

    public var result : ?R = null;

    var midstate : ?S = null;

    /// Release a call. The call should have arrived at this point.
    public func release() {
      if (not lock) {
        Debug.trap("Response must be locked before release");
      };
      lock := false;
    };

    /// Run a call waiting inside for the release.
    public func run(arg : T) : async* () {
      let (pre, after) = methods;

      state := #running;
      midstate := ?pre(arg);

      if (lock) {
        var inc = limit;
        while (lock and inc > 0) {
          await async ();
          inc -= 1;
        };
        if (inc == 0) {
          Debug.trap("Iteration limit reached in run");
        };
      };

      state := #ready;
      result := Option.chain<S, R>(midstate, after); // Note that midstate == null cannot happen

      if (Option.isNull(result)) throw Error.reject("");
    };
  };

  /// Base class for all testers.
  class BaseTester<T, S, R>(iterations_limit : ?Nat) {
    var queue : Buffer.Buffer<Response<T, S, R>> = Buffer.Buffer(1);
    public var front = 0;
    let limit = Option.get(iterations_limit, 100);

    /// Response of the i-th call.
    public func call_result(i : Nat) : R {
      let ?r = get(i).result else Debug.trap("No call result");
      r;
    };

    /// Push back a call
    public func add(lock : Bool, method : Methods<T, S, R>) : Nat {
      let response = Response<T, S, R>(lock, method, limit);
      queue.add(response);
      queue.size() - 1;
    };

    /// Pop front a call
    public func pop() : ?Response<T, S, R> {
      if (front == queue.size()) {
        return null;
      };
      let r = queue.get(front);
      front += 1;
      ?r;
    };

    /// Get the i-th call.
    public func get(i : Nat) : Response<T, S, R> = queue.get(i);

    /// Wait for the arrival of the i-th call.
    public func wait(i : Nat) : async* () {
      var inc = limit;
      while (inc > 0 and (queue.size() <= i or queue.get(i).state == #staged)) {
        await async ();
        inc -= 1;
      };
      if (inc == 0) {
        Debug.trap("Iteration limit reached in wait");
      };
    };
  };

  /// Stage version of tester. You first stage the result, then call a method.
  public class StageTester<T, S, R>(iterations_limit : ?Nat) {
    let base : BaseTester<T, S, R> = BaseTester<T, S, R>(iterations_limit);

    /// Stage methods
    public func stage(arg : Methods<T, S, R>) : Nat = base.add(true, arg);

    /// Stage already released call
    public func stage_unlocked(arg : Methods<T, S, R>) : Nat = base.add(false, arg);

    public func call(arg : T) : async* Nat {
      let i = base.front;
      let ?r = base.pop() else Debug.trap("Pop out of empty queue");
      await* r.run(arg);
      i;
    };

    public func call_result(i : Nat) : R = base.call_result(i);

    public func release(i : Nat) = base.get(i).release();

    public func state(i : Nat) : State = base.get(i).state;

    public func wait(i : Nat) : async* () = async* await* base.wait(i);
  };

  public class SimpleStageTester<R>(iterations_limit : ?Nat) {
    let base : StageTester<(), (), R> = StageTester<(), (), R>(iterations_limit);

    public func stage(arg : ?R) : Nat = base.stage(func() = (), func() = arg);

    public func stage_unlocked(arg : ?R) : Nat = base.stage_unlocked(func() = (), func() = arg);

    public func call() : async* Nat = async* await* base.call();

    public func call_result(i : Nat) : R = base.call_result(i);

    public func release(i : Nat) = base.release(i);

    public func state(i : Nat) : State = base.state(i);

    public func wait(i : Nat) : async* () = async* await* base.wait(i);
  };

  public class CallTester<S, R>(iterations_limit : ?Nat) {
    let base : BaseTester<S, S, R> = BaseTester<S, S, R>(iterations_limit);

    func call_(lock : Bool, arg : S, method : (S -> ?R)) : async* Nat {
      let i = base.add(lock, (func(x : S) = x, method));
      await* base.get(i).run(arg);
      i;
    };

    public func call(arg : S, method : (S -> ?R)) : async* Nat = async* await* call_(true, arg, method);

    public func call_unlocked(arg : S, method : (S -> ?R)) : async* Nat = async* await* call_(false, arg, method);

    public func call_result(i : Nat) : R = base.call_result(i);

    public func release(i : Nat) = base.get(i).release();

    public func state(i : Nat) : State = base.get(i).state;

    public func wait(i : Nat) : async* () = async* await* base.wait(i);
  };

  public class ReleaseTester<R>(iterations_limit : ?Nat) {
    let base : CallTester<(), R> = CallTester<(), R>(iterations_limit);

    var results = Buffer.Buffer<?R>(0);

    public func call() : async* Nat {
      let i = results.size();
      results.add(null);
      await* base.call((), func() = results.get(i));
    };

    public func call_unlocked() : async* Nat {
      let i = results.size();
      results.add(null);
      await* base.call_unlocked((), func() = results.get(i));
    };

    public func call_result(i : Nat) : R = base.call_result(i);

    public func release(i : Nat, result_ : ?R) {
      results.put(i, result_);
      base.release(i);
    };

    public func state(i : Nat) : State = base.state(i);

    public func wait(i : Nat) : async* () = async* await* base.wait(i);
  };

  public class VariableTester<T>(default : T, iterations_limit : ?Nat) {
    let limit = Option.get(iterations_limit, 100);
    var key_ = "";
    var lock_ = false;

    var value_ : T = default;

    public func lock(key : Text) {
      if (lock_) {
        Debug.trap(key_ # " Variable must be unlocked before lock");
      };
      key_ := key;
      lock_ := true;
    };

    public func release() {
      if (not lock_) {
        Debug.trap("Variable must be locked before release");
      };
      lock_ := false;
      key_ := "";
    };

    public func await_unlock() : async* () {
      var inc = limit;
      while (lock_ and inc > 0) {
        await async ();
        inc -= 1;
      };
      if (inc == 0) {
        Debug.trap(key_ # " Iteration limit reached");
      };
    };

    public func get() : T {
      if (lock_) {
        Debug.trap("Variable must be unlocked before get");
      };
      value_;
    };

    public func set(value : T) {
      value_ := value;
    };

    public func reset() {
      set(default);
    };
  };
};
