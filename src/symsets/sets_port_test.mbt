///|
fn set_str(set : Set) -> String {
  to_string(set)
}

///|
fn sympy_set_str(set : Set) -> String {
  try! @sympy_sets.set_str(set)
}

///|
fn sympy_union_str(sets : Array[Set]) -> String {
  try! @sympy_sets.union_str(sets)
}

///|
fn sympy_intersection_str(sets : Array[Set]) -> String {
  try! @sympy_sets.intersection_str(sets)
}

///|
fn sympy_complement_str(a : Set, b : Set) -> String {
  try! @sympy_sets.complement_str(a, b)
}

///|
fn sympy_contains_str(set : Set, elem : @symcore.Expr) -> String {
  try! @sympy_sets.contains_str(set, elem)
}

///|
fn setbool_str(val : SetBool) -> String {
  setbool_to_string(val)
}

///|
test "symsets interval parity" {
  let zero = @symcore.int(0)
  let one = @symcore.int(1)
  let closed = interval(zero, one)
  assert_eq(set_str(closed), sympy_set_str(closed))
  let lopen = interval(zero, one, left_open=true)
  assert_eq(set_str(lopen), sympy_set_str(lopen))
  let ropen = interval(zero, one, right_open=true)
  assert_eq(set_str(ropen), sympy_set_str(ropen))
  let open = interval(zero, one, left_open=true, right_open=true)
  assert_eq(set_str(open), sympy_set_str(open))
  let point = interval(zero, zero)
  assert_eq(set_str(point), sympy_set_str(point))
  let empty = interval(zero, zero, left_open=true)
  assert_eq(set_str(empty), sympy_set_str(empty))
}

///|
test "symsets finite set parity" {
  let fs = finite_set([@symcore.int(2), @symcore.int(1), @symcore.int(1)])
  assert_eq(set_str(fs), sympy_set_str(fs))
}

///|
test "symsets union parity" {
  let a = interval(@symcore.int(0), @symcore.int(1))
  let b = interval(@symcore.int(1), @symcore.int(2))
  let ours = union([a, b])
  let sympy = sympy_union_str([a, b])
  assert_eq(set_str(ours), sympy)
  let f1 = finite_set([@symcore.int(2), @symcore.int(3)])
  let f2 = finite_set([@symcore.int(3), @symcore.int(4)])
  let ours2 = union([f1, f2])
  let sympy2 = sympy_union_str([f1, f2])
  assert_eq(set_str(ours2), sympy2)
}

///|
test "symsets intersection parity" {
  let a = interval(@symcore.int(0), @symcore.int(2))
  let b = interval(@symcore.int(1), @symcore.int(3))
  let ours = intersection([a, b])
  let sympy = sympy_intersection_str([a, b])
  assert_eq(set_str(ours), sympy)
  let f1 = finite_set([@symcore.int(1), @symcore.int(2)])
  let f2 = finite_set([@symcore.int(2), @symcore.int(3)])
  let ours2 = intersection([f1, f2])
  let sympy2 = sympy_intersection_str([f1, f2])
  assert_eq(set_str(ours2), sympy2)
}

///|
test "symsets complement parity" {
  let a = interval(@symcore.int(0), @symcore.int(2))
  let b = interval(@symcore.int(1), @symcore.int(3))
  let ours = complement(a, b)
  let sympy = sympy_complement_str(a, b)
  assert_eq(set_str(ours), sympy)
  let f1 = finite_set([@symcore.int(1), @symcore.int(2), @symcore.int(3)])
  let f2 = finite_set([@symcore.int(2)])
  let ours2 = complement(f1, f2)
  let sympy2 = sympy_complement_str(f1, f2)
  assert_eq(set_str(ours2), sympy2)
}

///|
test "symsets contains parity" {
  let set = interval(@symcore.int(0), @symcore.int(1))
  let res = contains(set, @symcore.int(0))
  let sympy = sympy_contains_str(set, @symcore.int(0))
  assert_eq(setbool_str(res), sympy)
  let res2 = contains(set, @symcore.int(2))
  let sympy2 = sympy_contains_str(set, @symcore.int(2))
  assert_eq(setbool_str(res2), sympy2)
}
