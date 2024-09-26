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
  /// State of a response.
  public type State = {
    /// Response is `#staged` before `call` function call.
    #staged;
    /// Response is `#called` after `call` and before `release` calls.
    #called;
    /// Response is `#responded` after `release` call (and maybe some time).
    #responded;
  };

  /// Preprocess function called before on `call` i.e. `#called` state.
  public type PreFunc<T, S> = T -> S;

  /// Postprocess function called on `release` i.e. `#responded` state. Returned `null` means `Error.reject(m)`.
  public type PostFunc<S, R> = S -> ?R;

  /// Create debug message by `name` and `index`.
  func debugMessage(name : Text, index : Nat) : Text {
    if (name == "") return "";
    "Method name: " # name # ". Index: " # Nat.toText(index) # ".";
  };

  /// Class representing a single method call.
  class Response<T, S, R>(
    lock_ : Bool,
    pre_ : PreFunc<T, S>,
    post_ : PostFunc<S, R>,
    debug_ : Bool,
    debug_message : Text,
    limit : Nat,
  ) {
    /// Boolean flag to indicate if the response is locked.
    var lock = lock_;

    /// Current state of the response.
    public var state : State = #staged;

    /// Pre-processing function.
    let pre : PreFunc<T, S> = pre_;

    /// Post-processing function.
    public var post : PostFunc<S, R> = post_;

    /// Result (if already present).
    public var result : ?R = null;

    /// Release response.
    public func release() {
      if (not lock) {
        Debug.trap("Response must be locked before release. " # debug_message);
      };
      if (debug_) Debug.print("Releasing response. " # debug_message);
      lock := false;
    };

    /// Runs pre-processing function, waits for the release,
    /// runs post-processing function, optionaly throws.
    public func run(arg : T) : async* () {
      if (debug_) Debug.print("Response is #called. " # debug_message);
      state := #called;
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

      state := #responded;
      result := post(midstate);
      if (debug_) Debug.print("Response is #responded. " # debug_message);

      if (Option.isNull(result)) throw Error.reject("Response rejected. " # debug_message);
    };
  };

  /// Manages a queue of `Response` objects and provides methods to add,
  /// retrieve, and manage responses.
  class BaseTester<T, S, R>(
    debug_ : Bool,
    name : Text,
    iterations_limit : ?Nat,
  ) {
    /// A buffer storing `Response` objects.
    var queue : Buffer.Buffer<Response<T, S, R>> = Buffer.Buffer(1);
    /// Index of the next response to be processed.
    public var front = 0;
    let limit = Option.get(iterations_limit, 100);

    /// Retrieves the result of the response at the given index.
    public func call_result(index : Nat) : R {
      let ?r = get(index).result else Debug.trap("No call result");
      r;
    };

    /// Adds a new response to the queue.
    public func add(lock : Bool, pre : PreFunc<T, S>, post : PostFunc<S, R>) {
      let debug_message : Text = debugMessage(name, queue.size());
      let response = Response<T, S, R>(lock, pre, post, debug_, debug_message, limit);
      queue.add(response);
    };

    /// Returns the size of the queue.
    public func size() : Nat = queue.size();

    /// Retrieves and removes the response at the front of the queue.
    public func pop() : ?Response<T, S, R> {
      if (front == queue.size()) {
        return null;
      };
      let r = queue.get(front);
      front += 1;
      ?r;
    };

    /// Retrieves the response at the specified index.
    public func get(index : Nat) : Response<T, S, R> = queue.get(index);

    /// Retrieves the state of the response at the given index.
    public func state(index : Nat) : State = queue.get(index).state;

    /// Releases the lock of the response at the given index.
    public func release(index : Nat) = queue.get(index).release();

    /// Waits for a response at the given index to reach a specified state.
    public func wait(index : Nat, state : { #called; #responded }) : async* () {
      func stateNumber(a : State) : Nat = switch (a) {
        case (#staged) 0;
        case (#called) 1;
        case (#responded) 2;
      };
      var inc = limit;
      while (inc > 0 and (queue.size() <= index or stateNumber(queue.get(index).state) < stateNumber(state))) {
        await async ();
        inc -= 1;
      };
      if (inc == 0) {
        Debug.trap("Iteration limit reached in wait. " # debugMessage(name, index));
      };
      // Thist one needed for the response to be processed by the caller.
      await async ();
    };

    /// Assert that all the responses are used.
    public func dispose() {
      if (front != queue.size()) {
        Debug.trap("Some responses are not used. " # debugMessage(name, front));
      };
    };
  };

  /// `AsyncTester` variation where pre and post processing function first have to be staged
  /// then retrieved at `call`.
  public class StageTester<T, S, R>(
    debug_ : Bool,
    name : Text,
    iterations_limit : ?Nat,
  ) {
    let base : BaseTester<T, S, R> = BaseTester<T, S, R>(debug_, name, iterations_limit);

    func stage_(lock : Bool, pre : PreFunc<T, S>, post : PostFunc<S, R>) : Nat {
      if (debug_) Debug.print("Staging response. " # debugMessage(name, base.size()));
      base.add(lock, pre, post);
      base.size() - 1;
    };

    /// Stages a response with a lock.
    public func stage(pre : PreFunc<T, S>, post : PostFunc<S, R>) : Nat = stage_(true, pre, post);

    /// Stages a response without a lock.
    public func stage_unlocked(pre : PreFunc<T, S>, post : PostFunc<S, R>) : Nat = stage_(false, pre, post);

    /// Executes the staged response.
    public func call(arg : T) : async* Nat {
      let index = base.front;
      let ?r = base.pop() else Debug.trap("Pop out of empty queue");
      await* r.run(arg);
      index;
    };

    /// Retrieves the result of a response by the index.
    public func call_result(index : Nat) : R = base.call_result(index);

    /// Releases the lock of a response.
    public func release(index : Nat) = base.release(index);

    /// Returns the state of a response.
    public func state(index : Nat) : State = base.state(index);

    /// Waits for a response to reach a specified state.
    public func wait(index : Nat, state : { #called; #responded }) : async* () = async* await* base.wait(index, state);

    /// Assert that all the responses are used.
    public func dispose() = base.dispose();
  };

  /// `AsyncTester` variation where the result first have to be staged then retrieved at `call`.
  /// A simplified version of `StageTester`.
  public class SimpleStageTester<R>(
    debug_ : Bool,
    name : Text,
    iterations_limit : ?Nat,
  ) {
    let base : StageTester<(), (), R> = StageTester<(), (), R>(debug_, name, iterations_limit);

    /// Stages a response with a result. The response MUST be released at `release` and retieved at `call`.
    public func stage(arg : ?R) : Nat = base.stage(func() = (), func() = arg);

    /// Stages an unlocked response with a result. The response MUST be retieved at `call`.
    public func stage_unlocked(arg : ?R) : Nat = base.stage_unlocked(func() = (), func() = arg);

    /// Executes the staged response. Returns the index of the response.
    public func call() : async* Nat = async* await* base.call();

    public func call_result(index : Nat) : R = base.call_result(index);

    /// Releases the lock of a response.
    public func release(index : Nat) = base.release(index);

    /// Returns the state of a response.
    public func state(index : Nat) : State = base.state(index);

    /// Waits for a response to reach a specified state.
    public func wait(index : Nat, state : { #called; #responded }) : async* () = async* await* base.wait(index, state);

    /// Assert that all the responses are used.
    public func dispose() = base.dispose();
  };

  /// `AsyncTester` variation for managing and running asynchronous methods
  /// with a given input `T` and result `R`.
  public class CallTester<T, R>(
    debug_ : Bool,
    name : Text,
    iterations_limit : ?Nat,
  ) {
    let base : BaseTester<T, T, R> = BaseTester<T, T, R>(debug_, name, iterations_limit);

    /// Stages post-processing function, i.e. being run on `release` and waits for response.
    /// Returns the index of the response.
    /// The response MUST be released.
    public func call(arg : T, method : (T -> ?R)) : async* Nat {
      let index = base.size();
      base.add(true, func(x : T) = x, method);
      await* base.get(index).run(arg);
      index;
    };

    /// Retrieves the result of a response by the index.
    public func call_result(index : Nat) : R = base.call_result(index);

    /// Releases the lock of a response.
    public func release(index : Nat) = base.release(index);

    /// Returns the state of a response.
    public func state(index : Nat) : State = base.state(index);

    /// Waits for a response to reach a specified state.
    public func wait(index : Nat, state : { #called; #responded }) : async* () = async* await* base.wait(index, state);
  };

  /// `AsyncTester` variation that stages responses without input
  /// and allows setting the result after running on `release`.
  public class ReleaseTester<R>(
    debug_ : Bool,
    name : Text,
    iterations_limit : ?Nat,
  ) {
    let base : BaseTester<(), (), R> = BaseTester<(), (), R>(debug_, name, iterations_limit);

    /// Stages a method without input. The response MUST be released.
    public func call() : async* Nat {
      let index = base.size();
      base.add(true, func() = (), func() = null);
      await* base.get(index).run();
      index;
    };

    /// Retrieves the result of a response by the index.
    public func call_result(index : Nat) : R = base.call_result(index);

    /// Sets the result and releases the lock of a response.
    public func release(index : Nat, result : ?R) {
      let r = base.get(index);
      r.post := func() = result;
      r.release();
    };

    /// Returns the state of a response.
    public func state(index : Nat) : State = base.state(index);

    /// Waits for a response to reach a specified state.
    public func wait(index : Nat, state : { #called; #responded }) : async* () = async* await* base.wait(index, state);
  };
};
