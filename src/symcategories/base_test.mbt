///|
fn assert_morphism_array_eq(
  actual : Array[Morphism],
  expected : Array[Morphism],
) -> Unit raise {
  let lhs = actual.map(item => item.to_string()).join(" | ")
  let rhs = expected.map(item => item.to_string()).join(" | ")
  assert_true(lhs == rhs)
}

///|
test "morphisms follow sympy composition semantics" {
  let a = object("A")
  let b = object("B")
  let c = object("C")
  let d = object("D")

  let f = named_morphism(a, b, "f") catch { _ => fail("f") }
  let g = named_morphism(b, c, "g") catch { _ => fail("g") }
  let h = named_morphism(c, d, "h") catch { _ => fail("h") }

  assert_true(f.domain() == a)
  assert_true(f.codomain() == b)
  assert_true(f == (named_morphism(a, b, "f") catch { _ => fail("f2") }))

  let id_a = identity_morphism(a)
  let id_b = identity_morphism(b)
  assert_true(id_a.domain() == a)
  assert_true(id_a.codomain() == a)
  assert_true(id_a == identity_morphism(a))
  assert_true(id_a != id_b)

  assert_true(g.name() == Some("g"))
  assert_true(g != f)
  assert_true(
    g != (named_morphism(b, c, "f") catch { _ => fail("wrong-name") }),
  )

  let k = g.compose(f) catch { _ => fail("compose") }
  assert_true(k.domain() == a)
  assert_true(k.codomain() == c)
  assert_morphism_array_eq(k.components(), [f, g])
  assert_true(g * f == k)
  assert_true(
    (composite_morphism([f, g]) catch { _ => fail("composite") }) == k,
  )
  assert_true(
    (composite_morphism([g * f]) catch { _ => fail("composite1") }) == g * f,
  )

  let p = h * g
  let u = h * g * f
  assert_true(h * k == u)
  assert_true(p * f == u)
  assert_true(
    (composite_morphism([f, g, h]) catch { _ => fail("composite3") }) == u,
  )

  let u2 = u.flatten("u") catch { _ => fail("flatten") }
  assert_true(u2.name() == Some("u"))
  assert_true(u2.domain() == a)
  assert_true(u2.codomain() == d)

  assert_true(f * id_a == f)
  assert_true(id_b * f == f)
  assert_true(id_a * id_a == id_a)
  assert_true(
    (composite_morphism([id_a]) catch { _ => fail("id-composite") }) == id_a,
  )

  try composite_morphism([g, f]) catch {
    _ => ()
  } noraise {
    _ => fail("expected invalid composition to raise")
  }

  try named_morphism(a, b, "") catch {
    _ => ()
  } noraise {
    _ => fail("expected empty morphism name to raise")
  }
}

///|
test "diagram builds closure properties and subdiagrams" {
  let a = object("A")
  let b = object("B")
  let c = object("C")
  let d = object("D")

  let f = named_morphism(a, b, "f") catch { _ => fail("f") }
  let g = named_morphism(b, c, "g") catch { _ => fail("g") }
  let id_a = identity_morphism(a)
  let id_b = identity_morphism(b)

  let d1 = diagram(premises=morphism_list([f])) catch { _ => fail("d1") }
  assert_true(d1.objects == [a, b])
  assert_morphism_array_eq(d1.hom(a, b).0, [f])
  assert_morphism_array_eq(d1.hom(a, a).0, [id_a])
  assert_morphism_array_eq(d1.hom(b, b).0, [id_b])
  assert_true(
    d1 ==
    (diagram(premises=morphism_list([id_a, f])) catch { _ => fail("d1-id") }),
  )
  assert_true(
    d1 ==
    (diagram(premises=morphism_list([f, f])) catch { _ => fail("d1-dup") }),
  )

  let d2 = diagram(premises=morphism_list([f, g])) catch { _ => fail("d2") }
  assert_true(d2.objects == [a, b, c])
  assert_true(d2.premises.contains(g * f))
  assert_morphism_array_eq(d2.hom(a, c).0, [g * f])

  let unique_props : Map[Morphism, Array[String]] = Map([])
  unique_props[g * f] = ["unique"]
  let with_unique = diagram(
    premises=morphism_list([f, g]),
    conclusions=morphism_props(unique_props),
  ) catch {
    _ => fail("with_unique")
  }
  assert_true(with_unique.conclusions[g * f] == ["unique"])
  assert_morphism_array_eq(with_unique.hom(a, c).0, [g * f])
  assert_morphism_array_eq(with_unique.hom(a, c).1, [g * f])

  let premise_props : Map[Morphism, Array[String]] = Map([])
  premise_props[f] = ["unique", "isomorphism"]
  premise_props[g] = ["unique"]
  let prop_diagram = diagram(premises=morphism_props(premise_props)) catch {
    _ => fail("prop_diagram")
  }
  assert_true(prop_diagram.premises[g * f] == ["unique"])

  let bad_conclusion_props : Map[Morphism, Array[String]] = Map([])
  bad_conclusion_props[g] = []
  let d_bad = diagram(
    premises=morphism_list([f]),
    conclusions=morphism_props(bad_conclusion_props),
  ) catch {
    _ => fail("d_bad")
  }
  assert_true(d_bad.conclusions.length() == 0)

  let empty = diagram() catch { _ => fail("empty") }
  assert_true(empty.premises.length() == 0)
  assert_true(empty.conclusions.length() == 0)
  assert_true(empty.objects.length() == 0)

  let from_composite = diagram(premises=morphism_list([g * f])) catch {
    _ => fail("from_composite")
  }
  assert_true(from_composite.premises.contains(f))
  assert_true(from_composite.premises.contains(g))

  let sub = diagram(premises=morphism_list([f])) catch { _ => fail("sub") }
  assert_true(with_unique.is_subdiagram(sub))
  assert_false(sub.is_subdiagram(with_unique))

  let richer_conc : Map[Morphism, Array[String]] = Map([])
  richer_conc[g * f] = ["something", "unique"]
  let d_richer = diagram(
    premises=morphism_list([f, g]),
    conclusions=morphism_props(richer_conc),
  ) catch {
    _ => fail("d_richer")
  }
  assert_false(with_unique.is_subdiagram(d_richer))
  assert_false(d_richer.is_subdiagram(with_unique))

  let fprime = named_morphism(b, a, "f'") catch { _ => fail("fprime") }
  let wrong = diagram(premises=morphism_list([fprime])) catch {
    _ => fail("wrong")
  }
  assert_false(wrong.is_subdiagram(sub))
  assert_false(sub.is_subdiagram(wrong))

  let conc_props : Map[Morphism, Array[String]] = Map([])
  conc_props[f] = ["unique"]
  conc_props[g * f] = ["veryunique"]
  let d3 = diagram(
    premises=morphism_list([f, g]),
    conclusions=morphism_props(conc_props),
  ) catch {
    _ => fail("d3")
  }
  let d3_sub = d3.subdiagram_from_objects([a, b]) catch { _ => fail("d3_sub") }
  let expected_props : Map[Morphism, Array[String]] = Map([])
  expected_props[f] = ["unique"]
  let expected = diagram(
    premises=morphism_list([f]),
    conclusions=morphism_props(expected_props),
  ) catch {
    _ => fail("expected")
  }
  assert_true(d3_sub == expected)

  try d3.subdiagram_from_objects([a, d]) catch {
    _ => ()
  } noraise {
    _ => fail("expected disconnected subdiagram to raise")
  }

  let id_props : Map[Morphism, Array[String]] = Map([])
  id_props[identity_morphism(a)] = ["unique"]
  try diagram(premises=morphism_props(id_props)) catch {
    _ => ()
  } noraise {
    _ => fail("expected identity premise properties to raise")
  }
}

///|
test "category keeps normalized objects and diagrams" {
  let a = object("A")
  let b = object("B")
  let c = object("C")
  let f = named_morphism(a, b, "f") catch { _ => fail("f") }
  let g = named_morphism(b, c, "g") catch { _ => fail("g") }

  let d1 = diagram(premises=morphism_list([f, g])) catch { _ => fail("d1") }
  let d2 = diagram(premises=morphism_list([f])) catch { _ => fail("d2") }
  let kcat = category("K", objects=[a, b, c, a], commutative_diagrams=[
    d1, d2, d1,
  ]) catch {
    _ => fail("kcat")
  }

  assert_true(kcat.name == "K")
  assert_true(kcat.objects == category_class([a, b, c]))
  assert_true(kcat.commutative_diagrams.length() == 2)
  assert_true(kcat.commutative_diagrams[0] == d2)
  assert_true(kcat.commutative_diagrams[1] == d1)

  try category("") catch {
    _ => ()
  } noraise {
    _ => fail("expected empty category name to raise")
  }
}
