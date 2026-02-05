///|
test "pc groups basic collector" {
  let g = cyclic_group(3)
  let gen = g.generators()[0]
  let pc = try! PolycyclicGroup::new([gen], [g], [3])
  assert_true(pc.is_prime_order())
  assert_eq(pc.length(), 1)
  let coll = pc.collector
  let x0 = coll.free_group.generators()[0]
  let word = try! x0.pow(5)
  let sub = coll.minimal_uncollected_subword(word)
  assert_true(sub is Some(_))
  let exp = try! coll.exponent_vector(gen)
  assert_eq(exp[0], 1)
}
