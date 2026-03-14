///|
fn geometry_py_expr_text(expr : @symcore.Expr) -> String {
  @symprint.to_string(expr).replace(old="^", new="**")
}

///|
fn geometry_assert_expr_equal(
  lhs : @symcore.Expr,
  rhs : String,
  context : String,
) -> Unit raise {
  let ours = geometry_py_expr_text(lhs)
  guard (try! @sympy_geometry.geometry_expr_equal(ours, rhs)) else {
    fail("\{context}: ours=\{ours}; expected=\{rhs}")
  }
}

///|
fn geometry_assert_point_equal(
  lhs : Point,
  rhs_x : String,
  rhs_y : String,
  context : String,
) -> Unit raise {
  try! geometry_assert_expr_equal(lhs.x(), rhs_x, context + ".x")
  try! geometry_assert_expr_equal(lhs.y(), rhs_y, context + ".y")
}

///|
fn geometry_assert_point_set_equal(
  items : Array[GeometryEntity],
  expected : Array[(String, String)],
  context : String,
) -> Unit raise {
  guard items.length() == expected.length() else {
    fail(
      "\{context}: length mismatch ours=\{items.length()} expected=\{expected.length()}",
    )
  }
  let used : Array[Bool] = []
  for _ in 0..<expected.length() {
    used.push(false)
  }
  for item in items {
    let pt = match item {
      GeometryEntity::Point(value) => value
      _ => fail("\{context}: expected only point intersections")
    }
    let mut matched = false
    for i in 0..<expected.length() {
      if used[i] {
        continue
      }
      let ok_x = try! @sympy_geometry.geometry_expr_equal(
        geometry_py_expr_text(pt.x()),
        expected[i].0,
      )
      let ok_y = try! @sympy_geometry.geometry_expr_equal(
        geometry_py_expr_text(pt.y()),
        expected[i].1,
      )
      if ok_x && ok_y {
        used[i] = true
        matched = true
        break
      }
    }
    guard matched else { fail("\{context}: unmatched point \{pt.repr()}") }
  }
}

///|
fn geometry_entities_summary(
  items : Array[GeometryEntity],
) -> String raise GeometryError {
  let parts : Array[String] = []
  for item in items {
    parts.push(item.repr())
  }
  "[" + parts.join(", ") + "]"
}

///|
fn geometry_entity_set_summary(
  items : Array[GeometryEntity],
) -> String raise GeometryError {
  let parts : Array[String] = []
  for item in items {
    parts.push(item.repr())
  }
  let n = parts.length()
  for i in 0..<n {
    for j in (i + 1)..<n {
      if parts[i].compare(parts[j]) > 0 {
        let tmp = parts[i]
        parts[i] = parts[j]
        parts[j] = tmp
      }
    }
  }
  "{" + parts.join(", ") + "}"
}

///|
fn point_list_summary(items : Array[Point]) -> String {
  "[" + items.map(fn(point_obj) { point_obj.repr() }).join(", ") + "]"
}

///|
fn point_pair_set_summary(items : Array[(Point, Point)]) -> String {
  let parts : Array[String] = []
  for pair in items {
    parts.push("(" + pair.0.repr() + ", " + pair.1.repr() + ")")
  }
  "{" + parts.join(", ") + "}"
}

///|
fn point_chains_summary(chains : (Array[Point], Array[Point])) -> String {
  "(" + point_list_summary(chains.0) + ", " + point_list_summary(chains.1) + ")"
}

///|
fn expr_map_summary(items : Map[@symcore.Expr, @symcore.Expr]) -> String {
  let parts : Array[String] = []
  for item in items {
    parts.push(
      geometry_py_expr_text(item.0) + ": " + geometry_py_expr_text(item.1),
    )
  }
  let n = parts.length()
  for i in 0..<n {
    for j in (i + 1)..<n {
      if parts[i].compare(parts[j]) > 0 {
        let tmp = parts[i]
        parts[i] = parts[j]
        parts[j] = tmp
      }
    }
  }
  "{" + parts.join(", ") + "}"
}

///|
fn expr_set_summary(items : Array[@symcore.Expr]) -> String {
  let parts = items.map(geometry_py_expr_text)
  let n = parts.length()
  for i in 0..<n {
    for j in (i + 1)..<n {
      if parts[i].compare(parts[j]) > 0 {
        let tmp = parts[i]
        parts[i] = parts[j]
        parts[j] = tmp
      }
    }
  }
  "{" + parts.join(", ") + "}"
}

///|
fn string_set_summary(text : String) -> String {
  if !text.has_prefix("{") || !text.has_suffix("}") {
    return text
  }
  let inner = text[1:text.length() - 1].to_string()
  if inner.is_empty() {
    return "{}"
  }
  let parts = inner
    .split(",")
    .to_array()
    .map(fn(part) { part.trim().to_string() })
  let n = parts.length()
  for i in 0..<n {
    for j in (i + 1)..<n {
      if parts[i].compare(parts[j]) > 0 {
        let tmp = parts[i]
        parts[i] = parts[j]
        parts[j] = tmp
      }
    }
  }
  "{" + parts.join(", ") + "}"
}
