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
fn gf_triple_repr(pair : (Array[Int], Array[Int], Array[Int])) -> String {
  let (a, b, c) = pair
  "(\{gf_repr(a)},\{gf_repr(b)},\{gf_repr(c)})"
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
test "galoistools modular algorithm ops" {
  let p = 5
  assert_eq(gf_repr(@sympolys.gf_diff([3, 2, 4], p)), gf_diff([3, 2, 4], p))
  assert_eq(@sympolys.gf_eval([3, 2, 4], 2, p), gf_eval([3, 2, 4], 2, p))
  assert_eq(
    gf_repr(@sympolys.gf_multi_eval([3, 2, 4], [0, 1, 2, 3, 4], p)),
    gf_multi_eval([3, 2, 4], [0, 1, 2, 3, 4], p),
  )
  assert_eq(
    gf_repr(@sympolys.gf_compose([3, 2, 4], [2, 2, 2], p)),
    gf_compose([3, 2, 4], [2, 2, 2], p),
  )
  assert_eq(
    gf_repr(@sympolys.gf_compose_mod([3, 2, 4], [2, 2, 2], [4, 3], p)),
    gf_compose_mod([3, 2, 4], [2, 2, 2], [4, 3], p),
  )
  assert_eq(
    gf_repr(@sympolys.gf_pow_mod([3, 2, 4], 3, [1, 1], p)),
    gf_pow_mod([3, 2, 4], 3, [1, 1], p),
  )
  assert_eq(
    gf_repr(@sympolys.gf_lcm([3, 2, 4], [2, 2, 3], p)),
    gf_lcm([3, 2, 4], [2, 2, 3], p),
  )
  assert_eq(
    gf_triple_repr(@sympolys.gf_cofactors([3, 2, 4], [2, 2, 3], p)),
    gf_cofactors([3, 2, 4], [2, 2, 3], p),
  )
  assert_eq(
    gf_triple_repr(@sympolys.gf_gcdex([1, 8, 7], [1, 7, 1, 7], 11)),
    gf_gcdex([1, 8, 7], [1, 7, 1, 7], 11),
  )
  let residues = [49, 76, 65]
  let moduli = [99, 97, 95]
  assert_eq(@sympolys.gf_crt(residues, moduli), gf_crt(residues, moduli))
  let (crt_p, crt_e, crt_s) = @sympolys.gf_crt1(moduli)
  assert_eq("(\{crt_p},\{gf_repr(crt_e)},\{gf_repr(crt_s)})", gf_crt1(moduli))
  assert_eq(
    @sympolys.gf_crt2(residues, moduli, crt_p, crt_e, crt_s),
    gf_crt2(residues, moduli, crt_p, crt_e, crt_s),
  )
  assert_eq(@sympolys.gf_value([1, 7, 2, 4], 11), gf_value([1, 7, 2, 4], 11))
  assert_eq(
    gf_repr(@sympolys.linear_congruence(3, 12, 15)),
    linear_congruence(3, 12, 15),
  )
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
