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

  func debugMessage(name : ?Text, key : ?Text) : Text {
    let name_part = switch (name) {
      case (?t) "Method name: " # t # ".";
      case null "";
    };
    let key_part = switch (key) {
      case (?t) "Key of response: " # t # ".";
      case null "";
    };
    if (name_part != "" and key_part != "") name_part # " " # key_part else name_part # key_part;
  };

  class Response<T, S, R>(lock_ : Bool, pre_ : PreFunc<T, S>, post_ : PostFunc<S, R>, name : ?Text, key : ?Text, limit : Nat) {
    let debug_message : Text = debugMessage(name, key);

    var lock = lock_;

    public var state : State = #staged;

    let pre : PreFunc<T, S> = pre_;

    public var post : PostFunc<S, R> = post_;

    public var result : ?R = null;

    public func release() {
      if (not lock) {
        Debug.trap("Response must be locked before release. " # debug_message);
      };
      lock := false;
    };

    public func run(arg : T) : async* () {
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

      if (Option.isNull(result)) throw Error.reject("Reponse rejected. " # debug_message);
    };
  };

  class BaseTester<T, S, R>(name : ?Text, iterations_limit : ?Nat) {
    var queue : Buffer.Buffer<Response<T, S, R>> = Buffer.Buffer(1);
    public var front = 0;
    let limit = Option.get(iterations_limit, 100);

    public func call_result(i : Nat) : R {
      let ?r = get(i).result else Debug.trap("No call result");
      r;
    };

    public func add(lock : Bool, pre : PreFunc<T, S>, post : PostFunc<S, R>, key : ?Text) {
      let response = Response<T, S, R>(lock, pre, post, name, key, limit);
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

    public func get(i : Nat) : Response<T, S, R> = queue.get(i);

    public func state(i : Nat) : State = queue.get(i).state;

    public func release(i : Nat) = queue.get(i).release();

    public func wait(i : Nat, state : { #running; #ready }) : async* () {
      func stateNumber(a : State) : Nat = switch (a) {
        case (#staged) 0;
        case (#running) 1;
        case (#ready) 2;
      };
      var inc = limit;
      while (inc > 0 and (queue.size() <= i or stateNumber(queue.get(i).state) < stateNumber(state))) {
        await async ();
        inc -= 1;
      };
      if (inc == 0) {
        Debug.trap("Iteration limit reached in wait. " # debugMessage(name, ?Nat.toText(i)));
      };
      await async ();
    };
  };

  public class StageTester<T, S, R>(name : ?Text, iterations_limit : ?Nat) {
    let base : BaseTester<T, S, R> = BaseTester<T, S, R>(name, iterations_limit);

    public func stage(pre : PreFunc<T, S>, post : PostFunc<S, R>, key : ?Text) : Nat {
      base.add(true, pre, post, key);
      base.size() - 1;
    };

    public func stage_unlocked(pre : PreFunc<T, S>, post : PostFunc<S, R>, key : ?Text) : Nat {
      base.add(false, pre, post, key);
      base.size() - 1;
    };

    public func call(arg : T) : async* Nat {
      let i = base.front;
      let ?r = base.pop() else Debug.trap("Pop out of empty queue");
      await* r.run(arg);
      i;
    };

    public func call_result(i : Nat) : R = base.call_result(i);

    public func release(i : Nat) = base.release(i);

    public func state(i : Nat) : State = base.state(i);

    public func wait(i : Nat, state : { #running; #ready }) : async* () = async* await* base.wait(i, state);
  };

  public class SimpleStageTester<R>(name : ?Text, iterations_limit : ?Nat) {
    let base : StageTester<(), (), R> = StageTester<(), (), R>(name, iterations_limit);

    public func stage(arg : ?R, key : ?Text) : Nat = base.stage(func() = (), func() = arg, key);

    public func stage_unlocked(arg : ?R, key : ?Text) : Nat = base.stage_unlocked(func() = (), func() = arg, key);

    public func call() : async* Nat = async* await* base.call();

    public func call_result(i : Nat) : R = base.call_result(i);

    public func release(i : Nat) = base.release(i);

    public func state(i : Nat) : State = base.state(i);

    public func wait(i : Nat, state : { #running; #ready }) : async* () = async* await* base.wait(i, state);
  };

  public class CallTester<S, R>(name : ?Text, iterations_limit : ?Nat) {
    let base : BaseTester<S, S, R> = BaseTester<S, S, R>(name, iterations_limit);

    public func call(arg : S, method : (S -> ?R)) : async* Nat {
      let i = base.size();
      base.add(true, func(x : S) = x, method, if (not Option.isNull(name)) ?Nat.toText(i) else null);
      await* base.get(i).run(arg);
      i;
    };

    public func call_result(i : Nat) : R = base.call_result(i);

    public func release(i : Nat) = base.release(i);

    public func state(i : Nat) : State = base.state(i);

    public func wait(i : Nat, state : { #running; #ready }) : async* () = async* await* base.wait(i, state);
  };

  public class ReleaseTester<R>(name : ?Text, iterations_limit : ?Nat) {
    let base : BaseTester<(), (), R> = BaseTester<(), (), R>(name, iterations_limit);

    public func call() : async* Nat {
      let i = base.size();
      base.add(true, func() = (), func() = null, if (not Option.isNull(name)) ?Nat.toText(i) else null);
      await* base.get(i).run();
      i;
    };

    public func call_result(i : Nat) : R = base.call_result(i);

    public func release(i : Nat, result : ?R) {
      let r = base.get(i);
      r.post := func() = result;
      r.release();
    };

    public func state(i : Nat) : State = base.state(i);

    public func wait(i : Nat, state : { #running; #ready }) : async* () = async* await* base.wait(i, state);
  };
};
