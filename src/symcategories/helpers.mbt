///|
fn normalize_names(items : Array[String]) -> Array[String] {
  let out : Array[String] = []
  for item in items {
    if !out.any(existing => existing == item) {
      out.push(item)
    }
  }
  out.sort()
  out
}

///|
fn compare_name_arrays(xs : Array[String], ys : Array[String]) -> Int {
  let min_len = if xs.length() < ys.length() {
    xs.length()
  } else {
    ys.length()
  }
  for i in 0..<min_len {
    let cmp = xs[i].compare(ys[i])
    if cmp != 0 {
      return cmp
    }
  }
  xs.length() - ys.length()
}

///|
fn normalize_objects(items : Array[Object]) -> Array[Object] {
  let out : Array[Object] = []
  for item in items {
    if !out.any(existing => existing == item) {
      out.push(item)
    }
  }
  out.sort_by(compare_object)
  out
}

///|
fn compare_object_arrays(xs : Array[Object], ys : Array[Object]) -> Int {
  let min_len = if xs.length() < ys.length() {
    xs.length()
  } else {
    ys.length()
  }
  for i in 0..<min_len {
    let cmp = compare_object(xs[i], ys[i])
    if cmp != 0 {
      return cmp
    }
  }
  xs.length() - ys.length()
}

///|
fn contains_object(items : Array[Object], obj : Object) -> Bool {
  items.any(item => item == obj)
}

///|
fn object_subset_of(items : Array[Object], superset : Array[Object]) -> Bool {
  for item in items {
    if !contains_object(superset, item) {
      return false
    }
  }
  true
}

///|
fn normalize_property_set(items : Array[String]) -> Array[String] {
  normalize_names(items)
}

///|
fn singleton_property(name : String) -> Array[String] {
  if name == "" {
    []
  } else {
    [name]
  }
}

///|
fn property_union(lhs : Array[String], rhs : Array[String]) -> Array[String] {
  let out : Array[String] = Array::new()
  for item in lhs {
    out.push(item)
  }
  for item in rhs {
    out.push(item)
  }
  normalize_property_set(out)
}

///|
fn property_intersection(
  lhs : Array[String],
  rhs : Array[String],
) -> Array[String] {
  let out : Array[String] = Array::new()
  for item in lhs {
    if rhs.any(other => other == item) {
      out.push(item)
    }
  }
  normalize_property_set(out)
}

///|
fn compare_property_set(lhs : Array[String], rhs : Array[String]) -> Int {
  compare_name_arrays(lhs, rhs)
}

///|
fn[K : Compare, V] map_keys_sorted(map : Map[K, V]) -> Array[K] {
  let out : Array[K] = Array::new()
  for key in map.keys() {
    out.push(key)
  }
  out.sort()
  out
}

///|
fn normalize_diagrams(items : Array[Diagram]) -> Array[Diagram] {
  let out : Array[Diagram] = Array::new()
  for item in items {
    if !out.any(existing => existing == item) {
      out.push(item)
    }
  }
  out.sort_by(compare_diagram)
  out
}

///|
pub fn show_object_array(items : Array[Object]) -> String {
  "[" + items.map(item => Show::to_string(item)).join(", ") + "]"
}

///|
pub fn show_morphism_array(items : Array[Morphism]) -> String {
  "[" + items.map(item => Show::to_string(item)).join(", ") + "]"
}

///|
fn show_property_set(items : Array[String]) -> String {
  if items.is_empty() {
    "EmptySet"
  } else {
    "{" + items.join(", ") + "}"
  }
}

///|
pub fn generic_hints(transpose? : Bool = false) -> GridHints {
  { layout: Generic, transpose }
}

///|
pub fn sequential_hints(transpose? : Bool = false) -> GridHints {
  { layout: Sequential, transpose }
}

///|
pub fn transpose_hints() -> GridHints {
  { layout: Generic, transpose: true }
}

///|
pub fn group_layout(objects : Array[Object], hints : GridHints?) -> GroupLayout {
  { objects: normalize_objects(objects), hints }
}

///|
pub fn grid_group_object(obj : Object) -> GridGroup {
  Single(obj)
}

///|
pub fn grid_group(layout : GroupLayout) -> GridGroup {
  Group(layout)
}
