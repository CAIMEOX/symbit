///|
fn gf_repr(f : Array[Int]) -> String {
  if f.is_empty() {
    return "[]"
  }
  let parts = f.map(x => x.to_string()).join(",")
  "[\{parts}]"
}

///|
fn gf_pair_repr(pair : (Array[Int], Array[Int])) -> String {
  let (q, r) = pair
  "(\{gf_repr(q)},\{gf_repr(r)})"
}

///|
fn gf_map_repr(values : Map[Int, Int]) -> String {
  let items : Array[(Int, Int)] = []
  for key, value in values {
    items.push((key, value))
  }
  items.sort_by((lhs, rhs) => lhs.0 - rhs.0)
  "{" + items.map(item => "\{item.0}: \{item.1}").join(", ") + "}"
}

///|
test "galoistools basic ops" {
  let f = [1, 2, 3]
  let g = [4, 0, 1]
  let p = 5
  let ours_strip = gf_repr(@sympolys.gf_strip([0, 0, 3, 1]))
  let oracle_strip = gf_strip([0, 0, 3, 1])
  assert_eq(ours_strip, oracle_strip)
  let ours_trunc = gf_repr(@sympolys.gf_trunc([7, -2, 3], p))
  let oracle_trunc = gf_trunc([7, -2, 3], p)
  assert_eq(ours_trunc, oracle_trunc)
  let ours_add = gf_repr(@sympolys.gf_add(f, g, p))
  let oracle_add = gf_add(f, g, p)
  assert_eq(ours_add, oracle_add)
  let ours_sub = gf_repr(@sympolys.gf_sub(f, g, p))
  let oracle_sub = gf_sub(f, g, p)
  assert_eq(ours_sub, oracle_sub)
  let ours_mul = gf_repr(@sympolys.gf_mul(f, g, p))
  let oracle_mul = gf_mul(f, g, p)
  assert_eq(ours_mul, oracle_mul)
}

///|
test "galoistools conversion scalar and power ops" {
  let p = 5
  assert_eq(@sympolys.gf_int(5, 7), gf_int(5, 7))
  assert_eq(
    gf_repr(@sympolys.gf_normal([5, 10, 21, -3], p)),
    gf_normal([5, 10, 21, -3], p),
  )
  let sparse : Map[Int, Int] = { 10: 4, 4: 33, 0: -1 }
  let dense = @sympolys.gf_from_dict(sparse, p)
  assert_eq(gf_repr(dense), gf_from_dict(sparse, p))
  assert_eq(
    remove_spaces(gf_map_repr(@sympolys.gf_to_dict(dense, p))),
    remove_spaces(gf_to_dict(dense, p)),
  )
  assert_eq(
    remove_spaces(gf_map_repr(@sympolys.gf_to_dict(dense, p, symmetric=false))),
    remove_spaces(gf_to_dict(dense, p, symmetric=false)),
  )
  assert_eq(
    gf_repr(@sympolys.gf_from_int_poly([7, -2, 3], p)),
    gf_from_int_poly([7, -2, 3], p),
  )
  assert_eq(
    gf_repr(@sympolys.gf_to_int_poly([2, 3, 3], p)),
    gf_to_int_poly([2, 3, 3], p),
  )
  assert_eq(gf_repr(@sympolys.gf_neg([3, 2, 1, 0], p)), gf_neg([3, 2, 1, 0], p))
  assert_eq(
    gf_repr(@sympolys.gf_add_ground([3, 2, 4], 2, p)),
    gf_add_ground([3, 2, 4], 2, p),
  )
  assert_eq(
    gf_repr(@sympolys.gf_sub_ground([3, 2, 4], 2, p)),
    gf_sub_ground([3, 2, 4], 2, p),
  )
  assert_eq(
    gf_repr(@sympolys.gf_mul_ground([3, 2, 4], 2, p)),
    gf_mul_ground([3, 2, 4], 2, p),
  )
  assert_eq(
    gf_repr(@sympolys.gf_quo_ground([3, 2, 4], 2, p)),
    gf_quo_ground([3, 2, 4], 2, p),
  )
  assert_eq(gf_repr(@sympolys.gf_sqr([3, 2, 4], p)), gf_sqr([3, 2, 4], p))
  assert_eq(
    gf_repr(@sympolys.gf_add_mul([3, 2, 4], [2, 2, 2], [1, 4], p)),
    gf_add_mul([3, 2, 4], [2, 2, 2], [1, 4], p),
  )
  assert_eq(
    gf_repr(@sympolys.gf_sub_mul([3, 2, 4], [2, 2, 2], [1, 4], p)),
    gf_sub_mul([3, 2, 4], [2, 2, 2], [1, 4], p),
  )
  assert_eq(
    gf_repr(@sympolys.gf_exquo([1, 0, 3, 2, 3], [2, 2, 2], p)),
    gf_exquo([1, 0, 3, 2, 3], [2, 2, 2], p),
  )
  assert_eq(gf_repr(@sympolys.gf_lshift([3, 2, 4], 4)), gf_lshift([3, 2, 4], 4))
  assert_eq(
    gf_pair_repr(@sympolys.gf_rshift([1, 2, 3, 4, 0], 3)),
    gf_rshift([1, 2, 3, 4, 0], 3),
  )
  assert_eq(gf_repr(@sympolys.gf_pow([3, 2, 4], 3, p)), gf_pow([3, 2, 4], 3, p))
}

///|
test "galoistools div/gcd" {
  let f = [1, 0, 4, 2]
  let g = [1, 2]
  let p = 5
  let ours_div = gf_pair_repr(@sympolys.gf_div(f, g, p))
  let oracle_div = gf_div(f, g, p)
  assert_eq(ours_div, oracle_div)
  let ours_gcd = gf_repr(@sympolys.gf_gcd(f, g, p))
  let oracle_gcd = gf_gcd(f, g, p)
  assert_eq(ours_gcd, oracle_gcd)
}
