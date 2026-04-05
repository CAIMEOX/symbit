///|
fn py_string_literal(src : String) -> String {
  "\"" + src.replace(old="\\", new="\\\\").replace(old="\"", new="\\\"") + "\""
}

///|
fn cat_ref(name : String) -> String {
  "__import__('sympy.categories', fromlist=['" + name + "'])." + name
}

///|
fn py_object(obj : @symcategories.Object) -> String {
  cat_ref("Object") + "(" + py_string_literal(obj.name) + ")"
}

///|
fn py_morphism(morphism : @symcategories.Morphism) -> String {
  match morphism {
    @symcategories.Morphism::Identity(obj) =>
      cat_ref("IdentityMorphism") + "(" + py_object(obj) + ")"
    @symcategories.Morphism::Named(dom, cod, name) =>
      cat_ref("NamedMorphism") +
      "(" +
      py_object(dom) +
      ", " +
      py_object(cod) +
      ", " +
      py_string_literal(name) +
      ")"
    @symcategories.Morphism::Composite(items) =>
      cat_ref("CompositeMorphism") +
      "([" +
      items.map(py_morphism).join(", ") +
      "])"
  }
}

///|
fn py_property_set(items : Array[String]) -> String {
  if items.is_empty() {
    "sympy.EmptySet"
  } else {
    "sympy.FiniteSet(" + items.map(py_string_literal).join(", ") + ")"
  }
}

///|
fn py_morphism_map(
  items : Map[@symcategories.Morphism, Array[String]],
) -> String {
  let parts : Array[String] = Array::new()
  let keys = items.keys().to_array()
  keys.sort()
  for morphism in keys {
    parts.push(py_morphism(morphism) + ": " + py_property_set(items[morphism]))
  }
  "{" + parts.join(", ") + "}"
}

///|
fn py_diagram(diagram : @symcategories.Diagram) -> String {
  if diagram.premises.is_empty() && diagram.conclusions.is_empty() {
    cat_ref("Diagram") + "()"
  } else {
    let args : Array[String] = [py_morphism_map(diagram.premises)]
    if !diagram.conclusions.is_empty() {
      args.push(py_morphism_map(diagram.conclusions))
    }
    cat_ref("Diagram") + "(" + args.join(", ") + ")"
  }
}

///|
fn py_objects_set(objects : Array[@symcategories.Object]) -> String {
  if objects.is_empty() {
    "sympy.EmptySet"
  } else {
    "sympy.FiniteSet(" + objects.map(py_object).join(", ") + ")"
  }
}

///|
fn py_category(category : @symcategories.Category) -> String {
  let args : Array[String] = [
    py_string_literal(category.name),
    py_objects_set(category.objects.objects),
  ]
  let diagrams = "[" +
    category.commutative_diagrams.map(py_diagram).join(", ") +
    "]"
  args.push("commutative_diagrams=" + diagrams)
  cat_ref("Category") + "(" + args.join(", ") + ")"
}

///|
fn py_hints_kwargs(hints : @symcategories.GridHints) -> Array[(String, String)] {
  let kwargs : Array[(String, String)] = Array::new()
  match hints.layout {
    @symcategories.LayoutKind::Sequential =>
      kwargs.push(("layout", py_string_literal("sequential")))
    @symcategories.LayoutKind::Generic => ()
  }
  if hints.transpose {
    kwargs.push(("transpose", "True"))
  }
  kwargs
}

///|
fn py_group_key(group : @symcategories.GridGroup) -> String {
  match group {
    @symcategories.GridGroup::Single(obj) => py_object(obj)
    @symcategories.GridGroup::Group(layout) => py_objects_set(layout.objects)
  }
}

///|
fn py_groups(groups : Array[@symcategories.GridGroup]) -> String? {
  if groups.is_empty() {
    return None
  }

  let has_local_hints = groups.any(group => {
    match group {
      @symcategories.GridGroup::Group(layout) => layout.hints is Some(_)
      _ => false
    }
  })

  if has_local_hints {
    let parts : Array[String] = Array::new()
    for group in groups {
      let hint_kwargs = match group {
        @symcategories.GridGroup::Group(layout) =>
          match layout.hints {
            Some(hints) => py_hints_kwargs(hints)
            None => []
          }
        _ => []
      }
      let hint_text = "{" +
        hint_kwargs
        .map(item => py_string_literal(item.0) + ": " + item.1)
        .join(", ") +
        "}"
      parts.push(py_group_key(group) + ": " + hint_text)
    }
    Some("{" + parts.join(", ") + "}")
  } else {
    Some("[" + groups.map(py_group_key).join(", ") + "]")
  }
}

///|
fn py_kwargs_text(kwargs : Array[(String, String)]) -> String {
  if kwargs.is_empty() {
    ""
  } else {
    ", " + kwargs.map(item => item.0 + "=" + item.1).join(", ")
  }
}

///|
fn py_grid_call(
  diagram : @symcategories.Diagram,
  groups : Array[@symcategories.GridGroup],
  hints : @symcategories.GridHints,
) -> String {
  let kwargs = py_hints_kwargs(hints)
  let kwargs_with_groups : Array[(String, String)] = Array::new()
  for item in kwargs {
    kwargs_with_groups.push(item)
  }
  match py_groups(groups) {
    Some(groups_code) => kwargs_with_groups.push(("groups", groups_code))
    None => ()
  }
  cat_ref("DiagramGrid") +
  "(" +
  py_diagram(diagram) +
  py_kwargs_text(kwargs_with_groups) +
  ")"
}

///|
pub fn object_repr(obj : @symcategories.Object) -> String raise {
  @sympy_utilities.utilities_eval_repr(py_object(obj))
}

///|
pub fn morphism_repr(morphism : @symcategories.Morphism) -> String raise {
  @sympy_utilities.utilities_eval_repr(py_morphism(morphism))
}

///|
pub fn diagram_summary_repr(diagram : @symcategories.Diagram) -> String raise {
  @sympy_utilities.utilities_eval_repr(
    "(lambda d: (" +
    "[(repr(m), repr(d.premises[m])) for m in sorted(d.premises, key=sympy.default_sort_key)], " +
    "[(repr(m), repr(d.conclusions[m])) for m in sorted(d.conclusions, key=sympy.default_sort_key)], " +
    "[repr(o) for o in sorted(d.objects, key=sympy.default_sort_key)]" +
    "))(" +
    py_diagram(diagram) +
    ")",
  )
}

///|
pub fn diagram_summary_text(diagram : @symcategories.Diagram) -> String raise {
  @sympy_utilities.utilities_eval_str(
    "(lambda d: " +
    "\"premises=\" + \"|\".join(repr(m) + \"=>\" + repr(d.premises[m]) for m in sorted(d.premises, key=sympy.default_sort_key)) + " +
    "\";conclusions=\" + \"|\".join(repr(m) + \"=>\" + repr(d.conclusions[m]) for m in sorted(d.conclusions, key=sympy.default_sort_key)) + " +
    "\";objects=\" + \"|\".join(repr(o) for o in sorted(d.objects, key=sympy.default_sort_key))" +
    ")(" +
    py_diagram(diagram) +
    ")",
  )
}

///|
pub fn diagram_hom_repr(
  diagram : @symcategories.Diagram,
  domain : @symcategories.Object,
  codomain : @symcategories.Object,
) -> String raise {
  @sympy_utilities.utilities_eval_repr(
    "(lambda d: d.hom(" +
    py_object(domain) +
    ", " +
    py_object(codomain) +
    "))(" +
    py_diagram(diagram) +
    ")",
  )
}

///|
pub fn category_summary_repr(
  category : @symcategories.Category,
) -> String raise {
  @sympy_utilities.utilities_eval_repr(
    "(lambda c: (c.name, repr(c.objects), repr(c.commutative_diagrams)))(" +
    py_category(category) +
    ")",
  )
}

///|
pub fn category_summary_text(
  category : @symcategories.Category,
) -> String raise {
  @sympy_utilities.utilities_eval_str(
    "(lambda c: " +
    "\"name=\" + c.name + " +
    "\";objects=\" + repr(c.objects) + " +
    "\";commutative=\" + repr(c.commutative_diagrams)" +
    ")(" +
    py_category(category) +
    ")",
  )
}

///|
pub fn diagram_grid_summary_repr(
  diagram : @symcategories.Diagram,
  groups? : Array[@symcategories.GridGroup] = [],
  hints? : @symcategories.GridHints = @symcategories.generic_hints(),
) -> String raise {
  @sympy_utilities.utilities_eval_repr(
    "(lambda g: (" +
    "g.width, " +
    "g.height, " +
    "[[None if g[i, j] is None else repr(g[i, j]) for j in range(g.width)] for i in range(g.height)], " +
    "[(repr(m), repr(g.morphisms[m])) for m in sorted(g.morphisms, key=sympy.default_sort_key)]" +
    "))(" +
    py_grid_call(diagram, groups, hints) +
    ")",
  )
}

///|
pub fn diagram_grid_summary_text(
  diagram : @symcategories.Diagram,
  groups? : Array[@symcategories.GridGroup] = [],
  hints? : @symcategories.GridHints = @symcategories.generic_hints(),
) -> String raise {
  @sympy_utilities.utilities_eval_str(
    "(lambda g: " +
    "\"size=\" + str(g.width) + \"x\" + str(g.height) + " +
    "\";rows=\" + \"|\".join(\",\".join(\"None\" if g[i, j] is None else repr(g[i, j]) for j in range(g.width)) for i in range(g.height)) + " +
    "\";morphisms=\" + \"|\".join(repr(m) + \"=>\" + repr(g.morphisms[m]) for m in sorted(g.morphisms, key=sympy.default_sort_key))" +
    ")(" +
    py_grid_call(diagram, groups, hints) +
    ")",
  )
}

///|
pub fn xypic_draw_str(
  diagram : @symcategories.Diagram,
  masked? : Array[@symcategories.Morphism] = [],
  diagram_format? : String = "",
  groups? : Array[@symcategories.GridGroup] = [],
  hints? : @symcategories.GridHints = @symcategories.generic_hints(),
) -> String raise {
  let kwargs : Array[(String, String)] = py_hints_kwargs(hints)
  let kwargs2 : Array[(String, String)] = Array::new()
  for item in kwargs {
    kwargs2.push(item)
  }
  if !masked.is_empty() {
    kwargs2.push(("masked", "[" + masked.map(py_morphism).join(", ") + "]"))
  }
  if diagram_format != "" {
    kwargs2.push(("diagram_format", py_string_literal(diagram_format)))
  }
  match py_groups(groups) {
    Some(groups_code) => kwargs2.push(("groups", groups_code))
    None => ()
  }
  @sympy_utilities.utilities_eval_str(
    cat_ref("xypic_draw_diagram") +
    "(" +
    py_diagram(diagram) +
    py_kwargs_text(kwargs2) +
    ")",
  )
}
