///|
let evaluate_ref : Ref[Bool] = { val: true }
///|
let distribute_ref : Ref[Bool] = { val: true }
///|
let exp_is_pow_ref : Ref[Bool] = { val: false }

///|
pub fn current_evaluate() -> Bool {
  evaluate_ref.val
}

///|
pub fn current_distribute() -> Bool {
  distribute_ref.val
}

///|
pub fn current_exp_is_pow() -> Bool {
  exp_is_pow_ref.val
}

///|
pub fn[T] with_evaluate(value : Bool, thunk : () -> T) -> T {
  let old = evaluate_ref.val
  evaluate_ref.val = value
  let result = thunk()
  evaluate_ref.val = old
  result
}

///|
pub fn[T] with_distribute(value : Bool, thunk : () -> T) -> T {
  let old = distribute_ref.val
  distribute_ref.val = value
  let result = thunk()
  distribute_ref.val = old
  result
}

///|
pub fn[T] with_exp_is_pow(value : Bool, thunk : () -> T) -> T {
  let old = exp_is_pow_ref.val
  exp_is_pow_ref.val = value
  let result = thunk()
  exp_is_pow_ref.val = old
  result
}
