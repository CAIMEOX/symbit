///|
pub fn compare_object(a : Object, b : Object) -> Int {
  a.name.compare(b.name)
}

///|
fn morphism_variant_rank(morphism : Morphism) -> Int {
  match morphism {
    Composite(_) => 0
    Identity(_) => 1
    Named(_, _, _) => 2
  }
}

///|
fn compare_morphism_arrays(xs : Array[Morphism], ys : Array[Morphism]) -> Int {
  let min_len = if xs.length() < ys.length() {
    xs.length()
  } else {
    ys.length()
  }
  for i in 0..<min_len {
    let cmp = compare_morphism(xs[i], ys[i])
    if cmp != 0 {
      return cmp
    }
  }
  xs.length() - ys.length()
}

///|
pub fn compare_morphism(a : Morphism, b : Morphism) -> Int {
  let rank_cmp = morphism_variant_rank(a) - morphism_variant_rank(b)
  if rank_cmp != 0 {
    return rank_cmp
  }
  match (a, b) {
    (Identity(obj_a), Identity(obj_b)) => compare_object(obj_a, obj_b)
    (Named(dom_a, cod_a, name_a), Named(dom_b, cod_b, name_b)) => {
      let dom_cmp = compare_object(dom_a, dom_b)
      if dom_cmp != 0 {
        return dom_cmp
      }
      let cod_cmp = compare_object(cod_a, cod_b)
      if cod_cmp != 0 {
        return cod_cmp
      }
      name_a.compare(name_b)
    }
    (Composite(xs), Composite(ys)) => compare_morphism_arrays(xs, ys)
    _ => 0
  }
}

///|
fn compare_diagram_maps(
  lhs : Map[Morphism, Array[String]],
  rhs : Map[Morphism, Array[String]],
) -> Int {
  let lhs_keys = map_keys_sorted(lhs)
  let rhs_keys = map_keys_sorted(rhs)
  let len_cmp = lhs_keys.length() - rhs_keys.length()
  if len_cmp != 0 {
    return len_cmp
  }
  let key_cmp = compare_morphism_arrays(lhs_keys, rhs_keys)
  if key_cmp != 0 {
    return key_cmp
  }
  for key in lhs_keys {
    let cmp = compare_property_set(lhs[key], rhs[key])
    if cmp != 0 {
      return cmp
    }
  }
  0
}

///|
pub fn compare_diagram(a : Diagram, b : Diagram) -> Int {
  let premise_cmp = compare_diagram_maps(a.premises, b.premises)
  if premise_cmp != 0 {
    return premise_cmp
  }
  let conclusion_cmp = compare_diagram_maps(a.conclusions, b.conclusions)
  if conclusion_cmp != 0 {
    return conclusion_cmp
  }
  compare_object_arrays(a.objects, b.objects)
}

///|
fn compare_class(a : Class, b : Class) -> Int {
  compare_object_arrays(a.objects, b.objects)
}

///|
pub fn compare_category(a : Category, b : Category) -> Int {
  let name_cmp = a.name.compare(b.name)
  if name_cmp != 0 {
    return name_cmp
  }
  let obj_cmp = compare_class(a.objects, b.objects)
  if obj_cmp != 0 {
    return obj_cmp
  }
  let min_len = if a.commutative_diagrams.length() <
    b.commutative_diagrams.length() {
    a.commutative_diagrams.length()
  } else {
    b.commutative_diagrams.length()
  }
  for i in 0..<min_len {
    let cmp = compare_diagram(
      a.commutative_diagrams[i],
      b.commutative_diagrams[i],
    )
    if cmp != 0 {
      return cmp
    }
  }
  a.commutative_diagrams.length() - b.commutative_diagrams.length()
}

///|
pub impl Compare for Object with fn compare(self, other : Object) -> Int {
  compare_object(self, other)
}

///|
pub impl Eq for Object with fn equal(self, other : Object) -> Bool {
  compare_object(self, other) == 0
}

///|
pub impl Eq for Object with fn not_equal(self, other : Object) -> Bool {
  !Eq::equal(self, other)
}

///|
pub impl Hash for Object with fn hash(self) -> Int {
  let hasher = Hasher()
  Hash::hash_combine(self, hasher)
  hasher.finalize()
}

///|
pub impl Hash for Object with fn hash_combine(self, hasher : Hasher) -> Unit {
  hasher.combine_string(self.name)
}

///|
pub impl Show for Object with fn to_string(self) -> String {
  "Object(\"" + self.name + "\")"
}

///|
pub impl Show for Object with fn output(self, logger : &Logger) -> Unit {
  logger.write_string(Show::to_string(self))
}

///|
pub impl Compare for Morphism with fn compare(self, other : Morphism) -> Int {
  compare_morphism(self, other)
}

///|
pub impl Eq for Morphism with fn equal(self, other : Morphism) -> Bool {
  compare_morphism(self, other) == 0
}

///|
pub impl Eq for Morphism with fn not_equal(self, other : Morphism) -> Bool {
  !Eq::equal(self, other)
}

///|
pub impl Hash for Morphism with fn hash(self) -> Int {
  let hasher = Hasher()
  Hash::hash_combine(self, hasher)
  hasher.finalize()
}

///|
pub impl Hash for Morphism with fn hash_combine(self, hasher : Hasher) -> Unit {
  hasher.combine_int(morphism_variant_rank(self))
  match self {
    Identity(obj) => Hash::hash_combine(obj, hasher)
    Named(dom, cod, name) => {
      Hash::hash_combine(dom, hasher)
      Hash::hash_combine(cod, hasher)
      hasher.combine_string(name)
    }
    Composite(items) =>
      for item in items {
        Hash::hash_combine(item, hasher)
      }
  }
}

///|
pub impl Show for Morphism with fn to_string(self) -> String {
  match self {
    Identity(obj) => "IdentityMorphism(" + Show::to_string(obj) + ")"
    Named(dom, cod, name) =>
      "NamedMorphism(" +
      Show::to_string(dom) +
      ", " +
      Show::to_string(cod) +
      ", \"" +
      name +
      "\")"
    Composite(items) =>
      "CompositeMorphism((" +
      items.map(item => Show::to_string(item)).join(", ") +
      "))"
  }
}

///|
pub impl Show for Morphism with fn output(self, logger : &Logger) -> Unit {
  logger.write_string(Show::to_string(self))
}

///|
pub impl Compare for Class with fn compare(self, other : Class) -> Int {
  compare_class(self, other)
}

///|
pub impl Eq for Class with fn equal(self, other : Class) -> Bool {
  compare_class(self, other) == 0
}

///|
pub impl Eq for Class with fn not_equal(self, other : Class) -> Bool {
  !Eq::equal(self, other)
}

///|
pub impl Show for Class with fn to_string(self) -> String {
  "Class({" + self.objects.map(item => Show::to_string(item)).join(", ") + "})"
}

///|
pub impl Show for Class with fn output(self, logger : &Logger) -> Unit {
  logger.write_string(Show::to_string(self))
}

///|
pub impl Compare for Diagram with fn compare(self, other : Diagram) -> Int {
  compare_diagram(self, other)
}

///|
pub impl Eq for Diagram with fn equal(self, other : Diagram) -> Bool {
  compare_diagram(self, other) == 0
}

///|
pub impl Eq for Diagram with fn not_equal(self, other : Diagram) -> Bool {
  !Eq::equal(self, other)
}

///|
pub impl Hash for Diagram with fn hash(self) -> Int {
  let hasher = Hasher()
  Hash::hash_combine(self, hasher)
  hasher.finalize()
}

///|
pub impl Hash for Diagram with fn hash_combine(self, hasher : Hasher) -> Unit {
  for key in map_keys_sorted(self.premises) {
    Hash::hash_combine(key, hasher)
    for prop in self.premises[key] {
      hasher.combine_string(prop)
    }
  }
  hasher.combine_int(17)
  for key in map_keys_sorted(self.conclusions) {
    Hash::hash_combine(key, hasher)
    for prop in self.conclusions[key] {
      hasher.combine_string(prop)
    }
  }
}

///|
fn show_diagram_map(items : Map[Morphism, Array[String]]) -> String {
  let parts : Array[String] = Array::new()
  for key in map_keys_sorted(items) {
    parts.push(Show::to_string(key) + ": " + show_property_set(items[key]))
  }
  "{" + parts.join(", ") + "}"
}

///|
pub impl Show for Diagram with fn to_string(self) -> String {
  "Diagram(" +
  show_diagram_map(self.premises) +
  ", " +
  show_diagram_map(self.conclusions) +
  ", {" +
  self.objects.map(item => Show::to_string(item)).join(", ") +
  "})"
}

///|
pub impl Show for Diagram with fn output(self, logger : &Logger) -> Unit {
  logger.write_string(Show::to_string(self))
}

///|
pub impl Compare for Category with fn compare(self, other : Category) -> Int {
  compare_category(self, other)
}

///|
pub impl Eq for Category with fn equal(self, other : Category) -> Bool {
  compare_category(self, other) == 0
}

///|
pub impl Eq for Category with fn not_equal(self, other : Category) -> Bool {
  !Eq::equal(self, other)
}

///|
pub impl Hash for Category with fn hash(self) -> Int {
  let hasher = Hasher()
  Hash::hash_combine(self, hasher)
  hasher.finalize()
}

///|
pub impl Hash for Category with fn hash_combine(self, hasher : Hasher) -> Unit {
  hasher.combine_string(self.name)
  for item in self.objects.objects {
    Hash::hash_combine(item, hasher)
  }
  hasher.combine_int(29)
  for item in self.commutative_diagrams {
    Hash::hash_combine(item, hasher)
  }
}

///|
pub impl Show for Category with fn to_string(self) -> String {
  "Category(\"" + self.name + "\")"
}

///|
pub impl Show for Category with fn output(self, logger : &Logger) -> Unit {
  logger.write_string(Show::to_string(self))
}
