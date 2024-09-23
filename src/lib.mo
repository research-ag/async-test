/// Async method tester
///
/// Copyright: 2023-2024 MR Research AG
/// Main author: Timo Hanke (timohanke), Andrii Stepanov (AStepanov25)
/// Contributors: Timo Hanke (timohanke), Andrii Stepanov (AStepanov25)

import Debug "mo:base/Debug";
import Error "mo:base/Error";
import Option "mo:base/Option";
import Buffer "mo:base/Buffer";
import Nat "mo:base/Nat";

module {
  public type State = {
    #staged;
    #running;
    #ready;
  };

  public type PreFunc<T, S> = T -> S;

  public type PostFunc<S, R> = S -> ?R;

  func debugMessage(name : ?Text, index : Nat) : Text {
    let ?n = name else return "";
    "Method name: " # n # ". Index: " # Nat.toText(index) # ".";
  };

  class Response<T, S, R>(lock_ : Bool, pre_ : PreFunc<T, S>, post_ : PostFunc<S, R>, debug_ : Bool, name : ?Text, index : Nat, limit : Nat) {
    let debug_message : Text = debugMessage(name, index);

    var lock = lock_;

    public var state : State = #staged;

    let pre : PreFunc<T, S> = pre_;

    public var post : PostFunc<S, R> = post_;

    public var result : ?R = null;

    public func release() {
      if (not lock) {
        Debug.trap("Response must be locked before release. " # debug_message);
      };
      if (debug_) Debug.print("Releasing response. " # debug_message);
      lock := false;
    };

    public func run(arg : T) : async* () {
      if (debug_) Debug.print("Response is #running. " # debug_message);
      state := #running;
      let midstate = pre(arg);

      if (lock) {
        var inc = limit;
        while (lock and inc > 0) {
          await async ();
          inc -= 1;
        };
        if (inc == 0) {
          Debug.trap("Iteration limit reached in run. " # debug_message);
        };
      };

      state := #ready;
      result := post(midstate);
      if (debug_) Debug.print("Response is #ready. " # debug_message);

      if (Option.isNull(result)) throw Error.reject("Response rejected. " # debug_message);
    };
  };

  class BaseTester<T, S, R>(name : ?Text, iterations_limit : ?Nat, debug_ : Bool) {
    var queue : Buffer.Buffer<Response<T, S, R>> = Buffer.Buffer(1);
    public var front = 0;
    let limit = Option.get(iterations_limit, 100);

    public func call_result(index : Nat) : R {
      let ?r = get(index).result else Debug.trap("No call result");
      r;
    };

    public func add(lock : Bool, pre : PreFunc<T, S>, post : PostFunc<S, R>) {
      let response = Response<T, S, R>(lock, pre, post, debug_, name, queue.size(), limit);
      queue.add(response);
    };

    public func size() : Nat = queue.size();

    public func pop() : ?Response<T, S, R> {
      if (front == queue.size()) {
        return null;
      };
      let r = queue.get(front);
      front += 1;
      ?r;
    };

    public func get(index : Nat) : Response<T, S, R> = queue.get(index);

    public func state(index : Nat) : State = queue.get(index).state;

    public func release(index : Nat) = queue.get(index).release();

    public func wait(index : Nat, state : { #running; #ready }) : async* () {
      func stateNumber(a : State) : Nat = switch (a) {
        case (#staged) 0;
        case (#running) 1;
        case (#ready) 2;
      };
      var inc = limit;
      while (inc > 0 and (queue.size() <= index or stateNumber(queue.get(index).state) < stateNumber(state))) {
        await async ();
        inc -= 1;
      };
      if (inc == 0) {
        Debug.trap("Iteration limit reached in wait. " # debugMessage(name, index));
      };
      await async ();
    };
  };

  public class StageTester<T, S, R>(name : ?Text, iterations_limit : ?Nat, debug_ : Bool) {
    let base : BaseTester<T, S, R> = BaseTester<T, S, R>(name, iterations_limit, debug_);

    func stage_(lock : Bool, pre : PreFunc<T, S>, post : PostFunc<S, R>) : Nat {
      if (debug_) Debug.print("Staging response. " # debugMessage(name, base.size()));
      base.add(lock, pre, post);
      base.size() - 1;
    };

    public func stage(pre : PreFunc<T, S>, post : PostFunc<S, R>) : Nat = stage_(true, pre, post);

    public func stage_unlocked(pre : PreFunc<T, S>, post : PostFunc<S, R>) : Nat = stage_(false, pre, post);

    public func call(arg : T) : async* Nat {
      let index = base.front;
      let ?r = base.pop() else Debug.trap("Pop out of empty queue");
      await* r.run(arg);
      index;
    };

    public func call_result(index : Nat) : R = base.call_result(index);

    public func release(index : Nat) = base.release(index);

    public func state(index : Nat) : State = base.state(index);

    public func wait(index : Nat, state : { #running; #ready }) : async* () = async* await* base.wait(index, state);
  };

  public class SimpleStageTester<R>(name : ?Text, iterations_limit : ?Nat, debug_ : Bool) {
    let base : StageTester<(), (), R> = StageTester<(), (), R>(name, iterations_limit, debug_);

    public func stage(arg : ?R) : Nat = base.stage(func() = (), func() = arg);

    public func stage_unlocked(arg : ?R) : Nat = base.stage_unlocked(func() = (), func() = arg);

    public func call() : async* Nat = async* await* base.call();

    public func call_result(index : Nat) : R = base.call_result(index);

    public func release(index : Nat) = base.release(index);

    public func state(index : Nat) : State = base.state(index);

    public func wait(index : Nat, state : { #running; #ready }) : async* () = async* await* base.wait(index, state);
  };

  public class CallTester<S, R>(name : ?Text, iterations_limit : ?Nat, debug_ : Bool) {
    let base : BaseTester<S, S, R> = BaseTester<S, S, R>(name, iterations_limit, debug_);

    public func call(arg : S, method : (S -> ?R)) : async* Nat {
      let index = base.size();
      base.add(true, func(x : S) = x, method);
      await* base.get(index).run(arg);
      index;
    };

    public func call_result(index : Nat) : R = base.call_result(index);

    public func release(index : Nat) = base.release(index);

    public func state(index : Nat) : State = base.state(index);

    public func wait(index : Nat, state : { #running; #ready }) : async* () = async* await* base.wait(index, state);
  };

  public class ReleaseTester<R>(name : ?Text, iterations_limit : ?Nat, debug_ : Bool) {
    let base : BaseTester<(), (), R> = BaseTester<(), (), R>(name, iterations_limit, debug_);

    public func call() : async* Nat {
      let index = base.size();
      base.add(true, func() = (), func() = null);
      await* base.get(index).run();
      index;
    };

    public func call_result(index : Nat) : R = base.call_result(index);

    public func release(index : Nat, result : ?R) {
      let r = base.get(index);
      r.post := func() = result;
      r.release();
    };

    public func state(index : Nat) : State = base.state(index);

    public func wait(index : Nat, state : { #running; #ready }) : async* () = async* await* base.wait(index, state);
  };
};
