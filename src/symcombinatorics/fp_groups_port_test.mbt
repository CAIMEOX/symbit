///|
fn unwrap_table(table : Array[Array[Int?]]) -> Array[Array[Int]] {
  let out : Array[Array[Int]] = Array::new()
  for row in table {
    let r : Array[Int] = Array::new()
    for v in row {
      r.push(v.unwrap())
    }
    out.push(r)
  }
  out
}

///|
test "fp group reduce parity" {
  let (free_group, gens) = free_group("x, y")
  let symbols = free_group.symbols()
  let x = gens[0]
  let y = gens[1]
  let r1 = try! x.pow(2)
  let r2 = try! y.pow(3)
  let r3 = try! x.mul(y).pow(2)
  let rels = [r1, r2, r3]
  let group = FpGroup::new(free_group, rels)
  let word = try! x.mul(y).mul(x).mul(y)
  let reduced = try! group.reduce(word)
  let rel_forms = rels.map(r => r.array_form())
  let word_form = word.array_form()
  assert_oracle(try? @sympy_combinatorics.fp_group_reduce_equiv(
    symbols,
    rel_forms,
    word_form,
    reduced.array_form(),
  ))
}

///|
test "fp group coset table parity (relator based)" {
  let (free_group, gens) = free_group("x, y")
  let symbols = free_group.symbols()
  let x = gens[0]
  let y = gens[1]
  let r1 = try! x.pow(2)
  let r2 = try! y.pow(3)
  let r3 = try! x.mul(y).pow(2)
  let rels = [r1, r2, r3]
  let group = FpGroup::new(free_group, rels)
  let coset_table = try! coset_enumeration_r(group, [])
  coset_table.compress()
  coset_table.standardize()
  let table = unwrap_table(coset_table.table)
  let rel_forms = rels.map(r => r.array_form())
  assert_oracle(try? @sympy_combinatorics.fp_group_coset_table_equiv(
    symbols,
    rel_forms,
    [],
    "relator_based",
    table,
  ))
}
