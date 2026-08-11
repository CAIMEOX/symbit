///|
fn local_property_repr(items : Array[String]) -> String {
  if items.is_empty() {
    "EmptySet"
  } else {
    "{" + items.join(", ") + "}"
  }
}

///|
fn local_diagram_summary_text(diagram : @symcategories.Diagram) -> String {
  let premise_parts : Array[String] = Array::new()
  let premise_keys = diagram.premises.keys().to_array()
  premise_keys.sort()
  for morphism in premise_keys {
    premise_parts.push(
      Show::to_string(morphism) +
      "=>" +
      local_property_repr(diagram.premises[morphism]),
    )
  }

  let conclusion_parts : Array[String] = Array::new()
  let conclusion_keys = diagram.conclusions.keys().to_array()
  conclusion_keys.sort()
  for morphism in conclusion_keys {
    conclusion_parts.push(
      Show::to_string(morphism) +
      "=>" +
      local_property_repr(diagram.conclusions[morphism]),
    )
  }

  "premises=" +
  premise_parts.join("|") +
  ";conclusions=" +
  conclusion_parts.join("|") +
  ";objects=" +
  diagram.objects.map(item => Show::to_string(item)).join("|")
}

///|
fn local_grid_summary_text(grid : @symcategories.DiagramGrid) -> String {
  let rows : Array[String] = Array::new()
  for i in 0..<grid.height() {
    let cells : Array[String] = Array::new()
    for j in 0..<grid.width() {
      match grid.get(i, j) {
        Some(obj) => cells.push(Show::to_string(obj))
        None => cells.push("None")
      }
    }
    rows.push(cells.join(","))
  }

  let morphism_parts : Array[String] = Array::new()
  let keys = grid.morphisms().keys().to_array()
  keys.sort()
  for morphism in keys {
    morphism_parts.push(
      Show::to_string(morphism) +
      "=>" +
      local_property_repr(grid.morphisms()[morphism]),
    )
  }

  "size=" +
  grid.width().to_string() +
  "x" +
  grid.height().to_string() +
  ";rows=" +
  rows.join("|") +
  ";morphisms=" +
  morphism_parts.join("|")
}

///|
fn local_category_summary_text(category : @symcategories.Category) -> String {
  "name=" +
  category.name +
  ";objects=" +
  Show::to_string(category.objects) +
  ";commutative=FiniteSet(" +
  category.commutative_diagrams.map(item => Show::to_string(item)).join(", ") +
  ")"
}

///|
test "categories repr parity for objects morphisms diagrams and categories" {
  let a = @symcategories.object("A")
  let b = @symcategories.object("B")
  let c = @symcategories.object("C")
  let f = @symcategories.named_morphism(a, b, "f") catch { _ => fail("f") }
  let g = @symcategories.named_morphism(b, c, "g") catch { _ => fail("g") }
  let d1 = @symcategories.diagram(premises=@symcategories.morphism_list([f])) catch {
    _ => fail("d1")
  }
  let conc : Map[@symcategories.Morphism, Array[String]] = Map([])
  conc[g * f] = ["unique"]
  let d2 = @symcategories.diagram(
    premises=@symcategories.morphism_list([f, g]),
    conclusions=@symcategories.morphism_props(conc),
  ) catch {
    _ => fail("d2")
  }
  let kcat = @symcategories.category("K", objects=[a, b, c], commutative_diagrams=[
    d1, d2,
  ]) catch {
    _ => fail("kcat")
  }

  assert_eq(Show::to_string(a), object_repr(a))
  assert_eq(Show::to_string(f), morphism_repr(f))
  assert_eq(Show::to_string(g * f), morphism_repr(g * f))
  assert_eq(local_diagram_summary_text(d2), diagram_summary_text(d2))
  assert_eq(local_category_summary_text(kcat), category_summary_text(kcat))
}

///|
test "diagram grid summary parity for generic sequential and grouped cases" {
  let a = @symcategories.object("A")
  let b = @symcategories.object("B")
  let c = @symcategories.object("C")
  let d = @symcategories.object("D")
  let e = @symcategories.object("E")

  let f = @symcategories.named_morphism(a, b, "f") catch { _ => fail("f") }
  let g = @symcategories.named_morphism(b, c, "g") catch { _ => fail("g") }
  let h = @symcategories.named_morphism(c, d, "h") catch { _ => fail("h") }
  let i = @symcategories.named_morphism(d, e, "i") catch { _ => fail("i") }

  let triangle_conc : Map[@symcategories.Morphism, Array[String]] = Map([])
  triangle_conc[g * f] = ["unique"]
  let triangle = @symcategories.diagram(
    premises=@symcategories.morphism_list([f, g]),
    conclusions=@symcategories.morphism_props(triangle_conc),
  ) catch {
    _ => fail("triangle")
  }
  let triangle_grid = @symcategories.diagram_grid(triangle) catch {
    _ => fail("triangle-grid")
  }
  assert_eq(
    local_grid_summary_text(triangle_grid),
    diagram_grid_summary_text(triangle),
  )

  let chain = @symcategories.diagram(
    premises=@symcategories.morphism_list([f, g, h, i]),
  ) catch {
    _ => fail("chain")
  }
  let sequential = @symcategories.diagram_grid(
    chain,
    hints=@symcategories.sequential_hints(transpose=true),
  ) catch {
    _ => fail("sequential")
  }
  assert_eq(
    local_grid_summary_text(sequential),
    diagram_grid_summary_text(
      chain,
      hints=@symcategories.sequential_hints(transpose=true),
    ),
  )

  let m1 = @symcategories.named_morphism(a, b, "m1") catch { _ => fail("m1") }
  let m2 = @symcategories.named_morphism(a, c, "m2") catch { _ => fail("m2") }
  let s1 = @symcategories.named_morphism(b, d, "s1") catch { _ => fail("s1") }
  let s2 = @symcategories.named_morphism(c, d, "s2") catch { _ => fail("s2") }
  let f1 = @symcategories.named_morphism(e, b, "f1") catch { _ => fail("f1") }
  let f2 = @symcategories.named_morphism(e, c, "f2") catch { _ => fail("f2") }
  let pb = @symcategories.named_morphism(e, a, "g") catch { _ => fail("pb") }
  let pb_conc : Map[@symcategories.Morphism, Array[String]] = Map([])
  pb_conc[pb] = ["unique"]
  let pullback = @symcategories.diagram(
    premises=@symcategories.morphism_list([m1, m2, s1, s2, f1, f2]),
    conclusions=@symcategories.morphism_props(pb_conc),
  ) catch {
    _ => fail("pullback")
  }
  let groups = [
    @symcategories.grid_group_object(e),
    @symcategories.grid_group(@symcategories.group_layout([a, b, c, d], None)),
  ]
  let grouped = @symcategories.diagram_grid(pullback, groups~) catch {
    _ => fail("grouped")
  }
  assert_eq(
    local_grid_summary_text(grouped),
    diagram_grid_summary_text(pullback, groups~),
  )
}

///|
test "xypic output parity for representative diagrams" {
  let a = @symcategories.object("A")
  let b = @symcategories.object("B")
  let c = @symcategories.object("C")
  let d = @symcategories.object("D")
  let e = @symcategories.object("E")

  let f = @symcategories.named_morphism(a, b, "f") catch { _ => fail("f") }
  let g = @symcategories.named_morphism(b, c, "g") catch { _ => fail("g") }
  let triangle_conc : Map[@symcategories.Morphism, Array[String]] = Map([])
  triangle_conc[g * f] = ["unique"]
  let triangle = @symcategories.diagram(
    premises=@symcategories.morphism_list([f, g]),
    conclusions=@symcategories.morphism_props(triangle_conc),
  ) catch {
    _ => fail("triangle")
  }
  assert_eq(
    @symcategories.xypic_draw_diagram(triangle) catch {
      _ => fail("triangle-draw")
    },
    xypic_draw_str(triangle),
  )

  let h = @symcategories.named_morphism(c, d, "h") catch { _ => fail("h") }
  let i = @symcategories.named_morphism(d, e, "i") catch { _ => fail("i") }
  let chain = @symcategories.diagram(
    premises=@symcategories.morphism_list([f, g, h, i]),
  ) catch {
    _ => fail("chain")
  }
  assert_eq(
    @symcategories.xypic_draw_diagram(
      chain,
      hints=@symcategories.sequential_hints(),
    ) catch {
      _ => fail("chain-draw")
    },
    xypic_draw_str(chain, hints=@symcategories.sequential_hints()),
  )

  let back = @symcategories.named_morphism(d, a, "h") catch {
    _ => fail("back")
  }
  let side = @symcategories.named_morphism(d, b, "k") catch {
    _ => fail("side")
  }
  let curved = @symcategories.diagram(
    premises=@symcategories.morphism_list([f, g, back, side]),
  ) catch {
    _ => fail("curved")
  }
  assert_eq(
    @symcategories.xypic_draw_diagram(curved) catch {
      _ => fail("curved-draw")
    },
    xypic_draw_str(curved),
  )
}
