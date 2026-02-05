///|
fn assert_oracle(result : Result[String, Error], expected : String) -> Unit raise {
  match result {
    Ok(value) => assert_eq(value, expected)
    Err(e) => raise e
  }
}

///|
test "array basic printing and oracle" {
  let data = [@symcore.int(1), @symcore.int(2), @symcore.int(3), @symcore.int(4)]
  let arr = dense([2, 2], data)
  let s = to_string(arr)
  assert_eq(s, "[[1, 2], [3, 4]]")
  assert_oracle(try? @sympy_tensor.array_str(arr), s)
}

///|
test "array tensorproduct" {
  let a = dense([2], [@symcore.int(1), @symcore.int(2)])
  let b = dense([2], [@symcore.int(3), @symcore.int(4)])
  let prod = tensorproduct([a, b])
  let s = to_string(prod)
  assert_eq(s, "[[3, 4], [6, 8]]")
}

///|
test "array contraction" {
  let arr = dense([2, 2], [@symcore.int(1), @symcore.int(2), @symcore.int(3), @symcore.int(4)])
  let contracted = tensorcontraction(arr, [(0, 1)])
  let s = to_string(contracted)
  assert_eq(s, "5")
}

///|
test "array permutedims" {
  let arr = dense([2, 3], [
    @symcore.int(1), @symcore.int(2), @symcore.int(3),
    @symcore.int(4), @symcore.int(5), @symcore.int(6),
  ])
  let perm = permutedims(arr, [1, 0])
  let s = to_string(perm)
  assert_eq(s, "[[1, 4], [2, 5], [3, 6]]")
}

///|
test "array reshape and eye" {
  let arr = dense([2, 2], [@symcore.int(1), @symcore.int(2), @symcore.int(3), @symcore.int(4)])
  let reshaped = reshape(arr, [4])
  assert_eq(to_string(reshaped), "[1, 2, 3, 4]")
  let ident = eye(3)
  assert_eq(to_string(ident), "[[1, 0, 0], [0, 1, 0], [0, 0, 1]]")
}
