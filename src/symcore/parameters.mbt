///|
let evaluate_ref : Ref[Bool] = { val: true }

///|
pub fn current_evaluate() -> Bool {
  evaluate_ref.val
}

///|
pub fn[T] with_evaluate(value : Bool, thunk : () -> T) -> T {
  let old = evaluate_ref.val
  evaluate_ref.val = value
  let result = thunk()
  evaluate_ref.val = old
  result
}
