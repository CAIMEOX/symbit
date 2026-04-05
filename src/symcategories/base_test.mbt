///|
fn assert_morphism_array_eq(
  actual : Array[Morphism],
  expected : Array[Morphism],
) -> Unit raise {
  let lhs = actual.map(item => item.to_string()).join(" | ")
  let rhs = expected.map(item => item.to_string()).join(" | ")
  assert_eq(lhs, rhs)
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

  assert_eq(f.domain(), a)
  assert_eq(f.codomain(), b)
  assert_eq(f, named_morphism(a, b, "f") catch { _ => fail("f2") })

  let id_a = identity_morphism(a)
  let id_b = identity_morphism(b)
  assert_eq(id_a.domain(), a)
  assert_eq(id_a.codomain(), a)
  assert_eq(id_a, identity_morphism(a))
  assert_not_eq(id_a, id_b)

  assert_eq(g.name(), Some("g"))
  assert_not_eq(g, f)
  assert_not_eq(g, named_morphism(b, c, "f") catch { _ => fail("wrong-name") })

  let k = g.compose(f) catch { _ => fail("compose") }
  assert_eq(k.domain(), a)
  assert_eq(k.codomain(), c)
  assert_morphism_array_eq(k.components(), [f, g])
  assert_eq(g * f, k)
  assert_eq(composite_morphism([f, g]) catch { _ => fail("composite") }, k)
  assert_eq(
    composite_morphism([g * f]) catch {
      _ => fail("composite1")
    },
    g * f,
  )

  let p = h * g
  let u = h * g * f
  assert_eq(h * k, u)
  assert_eq(p * f, u)
  assert_eq(composite_morphism([f, g, h]) catch { _ => fail("composite3") }, u)

  let u2 = u.flatten("u") catch { _ => fail("flatten") }
  assert_eq(u2.name(), Some("u"))
  assert_eq(u2.domain(), a)
  assert_eq(u2.codomain(), d)

  assert_eq(f * id_a, f)
  assert_eq(id_b * f, f)
  assert_eq(id_a * id_a, id_a)
  assert_eq(
    composite_morphism([id_a]) catch {
      _ => fail("id-composite")
    },
    id_a,
  )

  let bad_comp : Result[Morphism, CategoryError] = try? composite_morphism([
    g, f,
  ])
  assert_true(bad_comp is Err(_))

  let bad_name : Result[Morphism, CategoryError] = try? named_morphism(a, b, "")
  assert_true(bad_name is Err(_))
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
  assert_eq(d1.objects, [a, b])
  assert_morphism_array_eq(d1.hom(a, b).0, [f])
  assert_morphism_array_eq(d1.hom(a, a).0, [id_a])
  assert_morphism_array_eq(d1.hom(b, b).0, [id_b])
  assert_eq(
    d1,
    diagram(premises=morphism_list([id_a, f])) catch {
      _ => fail("d1-id")
    },
  )
  assert_eq(
    d1,
    diagram(premises=morphism_list([f, f])) catch {
      _ => fail("d1-dup")
    },
  )

  let d2 = diagram(premises=morphism_list([f, g])) catch { _ => fail("d2") }
  assert_eq(d2.objects, [a, b, c])
  assert_true(d2.premises.contains(g * f))
  assert_morphism_array_eq(d2.hom(a, c).0, [g * f])

  let unique_props : Map[Morphism, Array[String]] = {}
  unique_props[g * f] = ["unique"]
  let with_unique = diagram(
    premises=morphism_list([f, g]),
    conclusions=morphism_props(unique_props),
  ) catch {
    _ => fail("with_unique")
  }
  assert_eq(with_unique.conclusions[g * f], ["unique"])
  assert_morphism_array_eq(with_unique.hom(a, c).0, [g * f])
  assert_morphism_array_eq(with_unique.hom(a, c).1, [g * f])

  let premise_props : Map[Morphism, Array[String]] = {}
  premise_props[f] = ["unique", "isomorphism"]
  premise_props[g] = ["unique"]
  let prop_diagram = diagram(premises=morphism_props(premise_props)) catch {
    _ => fail("prop_diagram")
  }
  assert_eq(prop_diagram.premises[g * f], ["unique"])

  let bad_conclusion_props : Map[Morphism, Array[String]] = {}
  bad_conclusion_props[g] = []
  let d_bad = diagram(
    premises=morphism_list([f]),
    conclusions=morphism_props(bad_conclusion_props),
  ) catch {
    _ => fail("d_bad")
  }
  assert_eq(d_bad.conclusions.length(), 0)

  let empty = diagram() catch { _ => fail("empty") }
  assert_eq(empty.premises.length(), 0)
  assert_eq(empty.conclusions.length(), 0)
  assert_eq(empty.objects.length(), 0)

  let from_composite = diagram(premises=morphism_list([g * f])) catch {
    _ => fail("from_composite")
  }
  assert_true(from_composite.premises.contains(f))
  assert_true(from_composite.premises.contains(g))

  let sub = diagram(premises=morphism_list([f])) catch { _ => fail("sub") }
  assert_true(with_unique.is_subdiagram(sub))
  assert_false(sub.is_subdiagram(with_unique))

  let richer_conc : Map[Morphism, Array[String]] = {}
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

  let conc_props : Map[Morphism, Array[String]] = {}
  conc_props[f] = ["unique"]
  conc_props[g * f] = ["veryunique"]
  let d3 = diagram(
    premises=morphism_list([f, g]),
    conclusions=morphism_props(conc_props),
  ) catch {
    _ => fail("d3")
  }
  let d3_sub = d3.subdiagram_from_objects([a, b]) catch { _ => fail("d3_sub") }
  let expected_props : Map[Morphism, Array[String]] = {}
  expected_props[f] = ["unique"]
  let expected = diagram(
    premises=morphism_list([f]),
    conclusions=morphism_props(expected_props),
  ) catch {
    _ => fail("expected")
  }
  assert_eq(d3_sub, expected)

  let bad_sub : Result[Diagram, CategoryError] = try? d3.subdiagram_from_objects([
      a, d,
    ],
  )
  assert_true(bad_sub is Err(_))

  let id_props : Map[Morphism, Array[String]] = {}
  id_props[identity_morphism(a)] = ["unique"]
  let id_result : Result[Diagram, CategoryError] = try? diagram(
    premises=morphism_props(id_props),
  )
  assert_true(id_result is Err(_))
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

  assert_eq(kcat.name, "K")
  assert_eq(kcat.objects, category_class([a, b, c]))
  assert_eq(kcat.commutative_diagrams.length(), 2)
  assert_eq(kcat.commutative_diagrams[0], d2)
  assert_eq(kcat.commutative_diagrams[1], d1)

  let bad_category : Result[Category, CategoryError] = try? category("")
  assert_true(bad_category is Err(_))
}
