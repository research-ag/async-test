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

    public var methods : ?Methods<T, S, R> = method;

    public var result : ?R = null;

    public func release() {
      if (not lock) {
        Debug.trap("Response must be locked before release");
      };
      lock := false;
    };

    public func run(arg : T) : async () {
      let middle_result = Option.map<Methods<T, S, R>, S>(methods, func((pre, _)) = pre(arg));

      state := #running;

      var inc = limit;
      while (lock and inc > 0) {
        await async ();
        inc -= 1;
      };
      if (inc == 0) {
        Debug.trap("Iteration limit reached");
      };

      switch (methods, middle_result) {
        case (?(_, after), ?s) {
          let ?r = after(s) else throw Error.reject("");
          result := ?r;
        };
        case (_, _) {};
      };

      state := #ready;
    };
  };

  class BaseAsyncMethodTester<T, S, R>(iterations_limit : ?Nat) {
    var queue : Buffer.Buffer<Response<T, S, R>> = Buffer.Buffer(1);
    var front = 0;
    let limit = Option.get(iterations_limit, 100);

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
    var last_call_result : ?R = null;

    public func stage(arg : Methods<T, S, R>) : Nat {
      base.add(?arg);
    };

    public func call(arg : T) : async () {
      let ?r = base.pop() else Debug.trap("Pop out of empty queue");
      await r.run(arg);
      last_call_result := r.result;
    };

    public func call_result() : R {
      let ?r = last_call_result else Debug.trap("No call result");
      last_call_result := null;
      r;
    };

    public func release(i : Nat) = base.get(i).release();

    public func state(i : Nat) : State = base.get(i).state;
  };

  public class SimpleStageAsyncMethodTester<R>(iterations_limit : ?Nat) {
    let base : StageAsyncMethodTester<(), (), R> = StageAsyncMethodTester<(), (), R>(iterations_limit);

    public func stage(arg : ?R) : Nat = base.stage(func() = (), func() = arg);

    public func call() : async () = async await base.call();

    public func call_result() : R = base.call_result();

    public func release(i : Nat) = base.release(i);

    public func state(i : Nat) : State = base.state(i);
  };

  public class CallAsyncMethodTester<S, R>(iterations_limit : ?Nat) {
    let base : BaseAsyncMethodTester<S, S, R> = BaseAsyncMethodTester<S, S, R>(iterations_limit);
    var last_call_result : ?R = null;

    public func call(arg : S, method : (S -> ?R)) : async () {
      let r = base.get(base.add(?(func(x : S) = x, method)));
      await r.run(arg);
      last_call_result := r.result;
    };

    public func call_result() : R {
      let ?r = last_call_result else Debug.trap("No call result");
      last_call_result := null;
      r;
    };

    public func release(i : Nat) = base.get(i).release();

    public func state(i : Nat) : State = base.get(i).state;
  };

  public class ReleaseAsyncMethodTester<R>(iterations_limit : ?Nat) {
    let base : BaseAsyncMethodTester<(), (), R> = BaseAsyncMethodTester<(), (), R>(iterations_limit);
    var last_call_result : ?R = null;

    public func call() : async () {
      let r = base.get(base.add(?(func() = (), func () = null)));
      await r.run(());
      last_call_result := r.result;
    };

    public func call_result() : R {
      let ?r = last_call_result else Debug.trap("No call result");
      last_call_result := null;
      r;
    };

    public func release(i : Nat, result : ?R) {
      let response = base.get(i);

      assert Option.isNull(response.result);
      response.methods := ?(func() = (), func () = result);

      response.release();
    };

    public func state(i : Nat) : State = base.get(i).state;
  };
};
