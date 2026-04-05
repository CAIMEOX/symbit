///|
fn assert_cell(
  grid : DiagramGrid,
  row : Int,
  col : Int,
  expected : Object?,
) -> Unit raise {
  assert_eq(grid.get(row, col), expected)
}

///|
test "growable grid supports append and prepend operations" {
  let grid : GrowableGrid[String] = growable_grid(1, 2)
  assert_eq(grid.width(), 1)
  assert_eq(grid.height(), 2)
  assert_eq(grid.get(0, 0), None)
  assert_eq(grid.get(1, 0), None)

  grid.set(0, 0, Some("one"))
  grid.set(1, 0, Some("two"))
  assert_eq(grid.get(0, 0), Some("one"))
  assert_eq(grid.get(1, 0), Some("two"))

  grid.append_row()
  assert_eq(grid.height(), 3)
  assert_eq(grid.get(2, 0), None)

  grid.append_column()
  assert_eq(grid.width(), 2)
  assert_eq(grid.get(0, 1), None)
  assert_eq(grid.get(1, 1), None)
  assert_eq(grid.get(2, 1), None)

  let grid2 : GrowableGrid[String] = growable_grid(1, 2)
  grid2.set(0, 0, Some("one"))
  grid2.set(1, 0, Some("two"))
  grid2.prepend_row()
  assert_eq(grid2.get(0, 0), None)
  assert_eq(grid2.get(1, 0), Some("one"))
  assert_eq(grid2.get(2, 0), Some("two"))

  grid2.prepend_column()
  assert_eq(grid2.width(), 2)
  assert_eq(grid2.get(1, 1), Some("one"))
  assert_eq(grid2.get(2, 1), Some("two"))
}

///|
test "diagram grid handles generic sequential and grouped layouts" {
  let a = object("A")
  let b = object("B")
  let c = object("C")
  let d = object("D")
  let e = object("E")

  let f = named_morphism(a, b, "f") catch { _ => fail("f") }
  let g = named_morphism(b, c, "g") catch { _ => fail("g") }
  let h_back = named_morphism(d, a, "h") catch { _ => fail("h") }
  let k = named_morphism(d, b, "k") catch { _ => fail("k") }

  let one = diagram_grid(
    diagram(premises=morphism_list([f])) catch {
      _ => fail("one-diagram")
    },
  ) catch {
    _ => fail("one-grid")
  }
  assert_eq(one.width(), 2)
  assert_eq(one.height(), 1)
  assert_cell(one, 0, 0, Some(a))
  assert_cell(one, 0, 1, Some(b))

  let triangle_props : Map[Morphism, Array[String]] = {}
  triangle_props[g * f] = ["unique"]
  let triangle = diagram_grid(
    diagram(
      premises=morphism_list([f, g]),
      conclusions=morphism_props(triangle_props),
    ) catch {
      _ => fail("triangle-diagram")
    },
  ) catch {
    _ => fail("triangle-grid")
  }
  assert_eq(triangle.width(), 2)
  assert_eq(triangle.height(), 2)
  assert_cell(triangle, 0, 0, Some(a))
  assert_cell(triangle, 0, 1, Some(b))
  assert_cell(triangle, 1, 0, Some(c))
  assert_cell(triangle, 1, 1, None)

  let loop_a = named_morphism(a, a, "l_A") catch { _ => fail("loopA") }
  let loop_grid = diagram_grid(
    diagram(premises=morphism_list([f, g, loop_a])) catch {
      _ => fail("loop-diagram")
    },
  ) catch {
    _ => fail("loop-grid")
  }
  assert_eq(loop_grid.width(), 2)
  assert_eq(loop_grid.height(), 2)
  assert_cell(loop_grid, 0, 0, Some(a))
  assert_cell(loop_grid, 0, 1, Some(b))
  assert_cell(loop_grid, 1, 0, None)
  assert_cell(loop_grid, 1, 1, Some(c))

  let simple = diagram_grid(
    diagram(premises=morphism_list([f, g, h_back, k])) catch {
      _ => fail("simple-diagram")
    },
  ) catch {
    _ => fail("simple-grid")
  }
  assert_eq(simple.width(), 3)
  assert_eq(simple.height(), 2)
  assert_eq(
    simple.to_string(),
    "[[Object(\"A\"), Object(\"B\"), Object(\"D\")], [None, Object(\"C\"), None]]",
  )

  let h = named_morphism(c, d, "h") catch { _ => fail("chain_h") }
  let i = named_morphism(d, e, "i") catch { _ => fail("chain_i") }
  let chain = diagram(premises=morphism_list([f, g, h, i])) catch {
    _ => fail("chain-diagram")
  }
  let chain_grid = diagram_grid(chain) catch { _ => fail("chain-grid") }
  assert_eq(chain_grid.width(), 3)
  assert_eq(chain_grid.height(), 3)
  assert_cell(chain_grid, 0, 0, Some(a))
  assert_cell(chain_grid, 0, 1, Some(b))
  assert_cell(chain_grid, 1, 1, Some(c))
  assert_cell(chain_grid, 1, 2, Some(d))
  assert_cell(chain_grid, 2, 2, Some(e))

  let sequential = diagram_grid(chain, hints=sequential_hints()) catch {
    _ => fail("sequential-grid")
  }
  assert_eq(sequential.width(), 5)
  assert_eq(sequential.height(), 1)
  assert_cell(sequential, 0, 0, Some(a))
  assert_cell(sequential, 0, 1, Some(b))
  assert_cell(sequential, 0, 2, Some(c))
  assert_cell(sequential, 0, 3, Some(d))
  assert_cell(sequential, 0, 4, Some(e))

  let sequential_t = diagram_grid(chain, hints=sequential_hints(transpose=true)) catch {
    _ => fail("sequential-grid-t")
  }
  assert_eq(sequential_t.width(), 1)
  assert_eq(sequential_t.height(), 5)
  assert_cell(sequential_t, 0, 0, Some(a))
  assert_cell(sequential_t, 1, 0, Some(b))
  assert_cell(sequential_t, 4, 0, Some(e))

  let m1 = named_morphism(a, b, "m1") catch { _ => fail("m1") }
  let m2 = named_morphism(a, c, "m2") catch { _ => fail("m2") }
  let s1 = named_morphism(b, d, "s1") catch { _ => fail("s1") }
  let s2 = named_morphism(c, d, "s2") catch { _ => fail("s2") }
  let f1 = named_morphism(e, b, "f1") catch { _ => fail("f1") }
  let f2 = named_morphism(e, c, "f2") catch { _ => fail("f2") }
  let pullback = named_morphism(e, a, "g") catch { _ => fail("pullback") }
  let pullback_conc : Map[Morphism, Array[String]] = {}
  pullback_conc[pullback] = ["unique"]
  let pullback_diagram = diagram(
    premises=morphism_list([m1, m2, s1, s2, f1, f2]),
    conclusions=morphism_props(pullback_conc),
  ) catch {
    _ => fail("pullback-diagram")
  }
  let pullback_grouped = diagram_grid(pullback_diagram, groups=[
    grid_group_object(e),
    grid_group(group_layout([a, b, c, d], None)),
  ]) catch {
    _ => fail("pullback-grouped")
  }
  assert_eq(pullback_grouped.width(), 3)
  assert_eq(pullback_grouped.height(), 2)
  assert_cell(pullback_grouped, 0, 0, Some(e))
  assert_cell(pullback_grouped, 0, 1, Some(a))
  assert_cell(pullback_grouped, 0, 2, Some(b))
  assert_cell(pullback_grouped, 1, 1, Some(c))
  assert_cell(pullback_grouped, 1, 2, Some(d))

  let g2 = named_morphism(c, d, "g2") catch { _ => fail("g2") }
  let disconnected = diagram_grid(
    diagram(premises=morphism_list([f, g2])) catch {
      _ => fail("disconnected-diagram")
    },
  ) catch {
    _ => fail("disconnected-grid")
  }
  assert_eq(disconnected.width(), 4)
  assert_eq(disconnected.height(), 1)
  assert_cell(disconnected, 0, 0, Some(a))
  assert_cell(disconnected, 0, 1, Some(b))
  assert_cell(disconnected, 0, 2, Some(c))
  assert_cell(disconnected, 0, 3, Some(d))
}

///|
test "arrow string description matches xy-pic encoding" {
  let astr = arrow_string_description(
    "cm",
    "",
    None,
    "",
    "",
    "d",
    "r",
    "_",
    "f",
  )
  assert_eq(astr.to_string(), "\\ar[dr]_{f}")

  let curved = arrow_string_description(
    "cm",
    "^",
    Some(12),
    "",
    "",
    "d",
    "r",
    "_",
    "f",
  )
  assert_eq(curved.to_string(), "\\ar@/^12cm/[dr]_{f}")

  let looped = arrow_string_description(
    "cm",
    "",
    Some(12),
    "r",
    "u",
    "d",
    "r",
    "_",
    "f",
  )
  assert_eq(looped.to_string(), "\\ar@(r,u)[dr]_{f}")

  looped.set_arrow_style("{-->}")
  assert_eq(looped.to_string(), "\\ar@(r,u)@{-->}[dr]_{f}")

  let styled = arrow_string_description(
    "cm",
    "_",
    Some(12),
    "",
    "",
    "d",
    "r",
    "_",
    "f",
  )
  styled.set_arrow_style("{-->}")
  assert_eq(styled.to_string(), "\\ar@/_12cm/@{-->}[dr]_{f}")
}

///|
test "xypic drawer handles line triangle and curves" {
  let a = object("A")
  let b = object("B")
  let c = object("C")
  let d = object("D")
  let e = object("E")

  let f = named_morphism(a, b, "f") catch { _ => fail("f") }
  let g = named_morphism(b, c, "g") catch { _ => fail("g") }
  let h = named_morphism(c, d, "h") catch { _ => fail("h") }
  let i = named_morphism(d, e, "i") catch { _ => fail("i") }
  let line = diagram(premises=morphism_list([f, g, h, i])) catch {
    _ => fail("line")
  }
  let line_grid = diagram_grid(line, hints=sequential_hints()) catch {
    _ => fail("line-grid")
  }
  let drawer = xypic_diagram_drawer()
  assert_eq(
    drawer.draw(line, line_grid),
    "\\xymatrix{\n" +
    "A \\ar[r]^{f} & B \\ar[r]^{g} & C \\ar[r]^{h} & D \\ar[r]^{i} & E \n" +
    "}\n",
  )

  let triangle_props : Map[Morphism, Array[String]] = {}
  triangle_props[g * f] = ["unique"]
  let triangle = diagram(
    premises=morphism_list([f, g]),
    conclusions=morphism_props(triangle_props),
  ) catch {
    _ => fail("triangle")
  }
  let triangle_grid = diagram_grid(triangle, hints=transpose_hints()) catch {
    _ => fail("triangle-grid")
  }
  assert_eq(
    drawer.draw(triangle, triangle_grid),
    "\\xymatrix{\n" +
    "A \\ar[r]^{g\\circ f} \\ar[d]_{f} & C \\\\\n" +
    "B \\ar[ru]_{g} & \n" +
    "}\n",
  )

  assert_eq(
    drawer.draw(triangle, triangle_grid, masked=[g]),
    "\\xymatrix{\n" +
    "A \\ar[r]^{g\\circ f} \\ar[d]_{f} & C \\\\\n" +
    "B & \n" +
    "}\n",
  )

  drawer.set_arrow_formatter("unique", astr => {
    astr.set_label("\\exists !" + astr.label)
    astr.set_arrow_style("{-->}")
  })
  assert_eq(
    drawer.draw(triangle, triangle_grid),
    "\\xymatrix{\n" +
    "A \\ar@{-->}[r]^{\\exists !g\\circ f} \\ar[d]_{f} & C \\\\\n" +
    "B \\ar[ru]_{g} & \n" +
    "}\n",
  )

  drawer.set_default_arrow_formatter(
    Some(astr => astr.set_label_displacement("(0.45)")),
  )
  assert_eq(
    drawer.draw(triangle, triangle_grid),
    "\\xymatrix{\n" +
    "A \\ar@{-->}[r]^(0.45){\\exists !g\\circ f} \\ar[d]_(0.45){f} & C \\\\\n" +
    "B \\ar[ru]_(0.45){g} & \n" +
    "}\n",
  )

  let back = named_morphism(d, a, "h") catch { _ => fail("back") }
  let side = named_morphism(d, b, "k") catch { _ => fail("side") }
  let curved = diagram(premises=morphism_list([f, g, back, side])) catch {
    _ => fail("curved")
  }
  let curved_grid = diagram_grid(curved) catch { _ => fail("curved-grid") }
  let curved_drawer = xypic_diagram_drawer()
  assert_eq(
    curved_drawer.draw(curved, curved_grid),
    "\\xymatrix{\n" +
    "A \\ar[r]_{f} & B \\ar[d]^{g} & D \\ar[l]^{k} \\ar@/_3mm/[ll]_{h} \\\\\n" +
    "& C & \n" +
    "}\n",
  )
}

///|
test "xypic draw helper delegates to diagram grid and drawer" {
  let a = object("A")
  let b = object("B")
  let c = object("C")
  let f = named_morphism(a, b, "f") catch { _ => fail("f") }
  let g = named_morphism(b, c, "g") catch { _ => fail("g") }
  let props : Map[Morphism, Array[String]] = {}
  props[g * f] = ["unique"]
  let diag = diagram(
    premises=morphism_list([f, g]),
    conclusions=morphism_props(props),
  ) catch {
    _ => fail("diag")
  }
  let via_helper = xypic_draw_diagram(diag) catch { _ => fail("helper") }
  let grid = diagram_grid(diag) catch { _ => fail("grid") }
  let drawer = xypic_diagram_drawer()
  assert_eq(via_helper, drawer.draw(diag, grid))
}
