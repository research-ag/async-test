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
  public type State = {
    #staged;
    #running;
    #ready;
  };

  type Methods<T, S, R> = (pre : T -> S, after : S -> ?R);

  class Response<T, S, R>(method : ?Methods<T, S, R>, limit : Nat) {
    var lock = true;

    public var state : State = #staged;

    var methods : ?Methods<T, S, R> = method;

    public var result : ?R = null;

    var midstate : ?S = null;

    public func release() {
      if (not lock) {
        Debug.trap("Response must be locked before release");
      };
      lock := false;
      let ?(_, after) = methods else return;
      let ?s = midstate else Debug.trap("middle result expected");
      result := after(s);
    };

    public func run(arg : T) : async () {
      midstate := Option.map<Methods<T, S, R>, S>(methods, func((pre, _)) = pre(arg));
      state := #running;

      var inc = limit;
      while (lock and inc > 0) {
        await async ();
        inc -= 1;
      };
      if (inc == 0) {
        Debug.trap("Iteration limit reached");
      };

      if (Option.isNull(result)) throw Error.reject("");

      state := #ready;
    };
  };

  class BaseAsyncMethodTester<T, S, R>(iterations_limit : ?Nat) {
    var queue : Buffer.Buffer<Response<T, S, R>> = Buffer.Buffer(1);
    public var front = 0;
    let limit = Option.get(iterations_limit, 100);

    public func call_result(i : Nat) : R {
      let ?r = get(i).result else Debug.trap("No call result");
      r;
    };

    public func add(method : ?Methods<T, S, R>) : Nat {
      let response = Response<T, S, R>(method, limit);
      queue.add(response);
      queue.size() - 1;
    };

    public func pop() : ?Response<T, S, R> {
      if (front == queue.size()) {
        return null;
      };
      let r = queue.get(front);
      front += 1;
      ?r;
    };

    public func get(i : Nat) : Response<T, S, R> = queue.get(i);
  };

  public class StageAsyncMethodTester<T, S, R>(iterations_limit : ?Nat) {
    let base : BaseAsyncMethodTester<T, S, R> = BaseAsyncMethodTester<T, S, R>(iterations_limit);

    public func stage(arg : Methods<T, S, R>) : Nat {
      base.add(?arg);
    };

    public func call(arg : T) : async* Nat {
      let i = base.front;
      let ?r = base.pop() else Debug.trap("Pop out of empty queue");
      await r.run(arg);
      i;
    };

    public func call_result(i : Nat) : R = base.call_result(i);

    public func release(i : Nat) = base.get(i).release();

    public func state(i : Nat) : State = base.get(i).state;
  };

  public class SimpleStageAsyncMethodTester<R>(iterations_limit : ?Nat) {
    let base : StageAsyncMethodTester<(), (), R> = StageAsyncMethodTester<(), (), R>(iterations_limit);

    public func stage(arg : ?R) : Nat = base.stage(func() = (), func() = arg);

    public func call() : async* Nat = async* await* base.call();

    public func call_result(i : Nat) : R = base.call_result(i);

    public func release(i : Nat) = base.release(i);

    public func state(i : Nat) : State = base.state(i);
  };

  public class CallAsyncMethodTester<S, R>(iterations_limit : ?Nat) {
    let base : BaseAsyncMethodTester<S, S, R> = BaseAsyncMethodTester<S, S, R>(iterations_limit);

    public func call(arg : S, method : (S -> ?R)) : async* Nat {
      let i = base.add(?(func(x : S) = x, method));
      await base.get(i).run(arg);
      i;
    };

    public func call_result(i : Nat) : R = base.call_result(i);

    public func release(i : Nat) = base.get(i).release();

    public func state(i : Nat) : State = base.get(i).state;
  };

  public class ReleaseAsyncMethodTester<R>(iterations_limit : ?Nat) {
    let base : CallAsyncMethodTester<(), R> = CallAsyncMethodTester<(), R>(iterations_limit);

    var result : ?R = null;
  
    public func call() : async* Nat {
      await* base.call((), func() = result);
    };

    public func call_result(i : Nat) : R = base.call_result(i);

    public func release(i : Nat, result_ : ?R) {
      result := result_; 
      base.release(i);
    };

    public func state(i : Nat) : State = base.state(i);
  };

  public class AsyncVariableTester<T>(default : T, iterations_limit : ?Nat) {
    let limit = Option.get(iterations_limit, 100);
    var key_ = "";
    var lock_ = true;

    var value_ : T = default;

    public func lock(key : Text) {
      if (lock_) {
        Debug.trap(key_ # " Variable must be unlocked before lock");
      };
      key_ := key;
      lock_ := false;
    };

    public func release() {
      if (not lock_) {
        Debug.trap("Variable must be locked before release");
      };
      lock_ := false;
      key_ := "";
    };

    public func await_unlock() : async () {
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
    }
  };
};
