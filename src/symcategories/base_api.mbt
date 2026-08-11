///|
pub fn object(name : String) -> Object {
  { name, }
}

///|
pub fn category_class(objects : Array[Object]) -> Class {
  { objects: normalize_objects(objects) }
}

///|
pub fn property(name : String) -> Array[String] {
  singleton_property(name)
}

///|
pub fn property_set(items : Array[String]) -> Array[String] {
  normalize_property_set(items)
}

///|
pub fn morphism_list(items : Array[Morphism]) -> MorphismSpec {
  List(items)
}

///|
pub fn morphism_props(items : Map[Morphism, Array[String]]) -> MorphismSpec {
  let normalized : Map[Morphism, Array[String]] = Map([])
  for key in items.keys() {
    normalized[key] = normalize_property_set(items[key])
  }
  Props(normalized)
}

///|
pub fn identity_morphism(domain : Object) -> Morphism {
  Identity(domain)
}

///|
pub fn named_morphism(
  domain : Object,
  codomain : Object,
  name : String,
) -> Morphism raise CategoryError {
  guard name != "" else {
    raise ValueError("Empty morphism names not allowed.")
  }
  Named(domain, codomain, name)
}

///|
fn composite_add_morphism(
  items : Array[Morphism],
  morphism : Morphism,
) -> Array[Morphism] {
  let out : Array[Morphism] = Array::new()
  for item in items {
    out.push(item)
  }
  match morphism {
    Composite(parts) =>
      for part in parts {
        out.push(part)
      }
    Identity(_) => ()
    _ => out.push(morphism)
  }
  out
}

///|
pub fn composite_morphism(
  components : Array[Morphism],
) -> Morphism raise CategoryError {
  guard !components.is_empty() else {
    raise ValueError("CompositeMorphism requires components.")
  }
  let mut normalized : Array[Morphism] = []
  for i in 0..<(components.length() - 1) {
    let current = components[i]
    let following = components[i + 1]
    if current.codomain() != following.domain() {
      raise ValueError("Uncomposable morphisms.")
    }
    normalized = composite_add_morphism(normalized, current)
  }
  normalized = composite_add_morphism(
    normalized,
    components[components.length() - 1],
  )
  if normalized.is_empty() {
    components[0]
  } else if normalized.length() == 1 {
    normalized[0]
  } else {
    Composite(normalized)
  }
}

///|
pub fn Morphism::domain(self : Morphism) -> Object {
  match self {
    Identity(domain) => domain
    Named(domain, _, _) => domain
    Composite(items) =>
      if items.is_empty() {
        abort("CompositeMorphism requires components.")
      } else {
        items[0].domain()
      }
  }
}

///|
pub fn Morphism::codomain(self : Morphism) -> Object {
  match self {
    Identity(domain) => domain
    Named(_, codomain, _) => codomain
    Composite(items) =>
      if items.is_empty() {
        abort("CompositeMorphism requires components.")
      } else {
        items[items.length() - 1].codomain()
      }
  }
}

///|
pub fn Morphism::name(self : Morphism) -> String? {
  match self {
    Named(_, _, name) => Some(name)
    _ => None
  }
}

///|
pub fn Morphism::components(self : Morphism) -> Array[Morphism] {
  match self {
    Composite(items) => items
    _ => [self]
  }
}

///|
pub fn Morphism::compose(
  self : Morphism,
  other : Morphism,
) -> Morphism raise CategoryError {
  composite_morphism([other, self])
}

///|
pub impl Mul for Morphism with fn mul(self, other : Morphism) -> Morphism {
  self.compose(other) catch {
    err => abort(Show::to_string(err))
  }
}

///|
pub fn Morphism::flatten(
  self : Morphism,
  new_name : String,
) -> Morphism raise CategoryError {
  named_morphism(self.domain(), self.codomain(), new_name)
}

///|
fn diagram_set_dict_union(
  dict : Map[Morphism, Array[String]],
  key : Morphism,
  value : Array[String],
) -> Bool {
  if dict.contains(key) {
    dict[key] = property_union(dict[key], value)
    true
  } else {
    dict[key] = value
    false
  }
}

///|
fn diagram_add_morphism_closure(
  morphisms : Map[Morphism, Array[String]],
  morphism : Morphism,
  props : Array[String],
  add_identities? : Bool = true,
  recurse_composites? : Bool = true,
) -> Unit raise CategoryError {
  if !diagram_set_dict_union(morphisms, morphism, props) {
    match morphism {
      Identity(_) => {
        if !props.is_empty() {
          raise ValueError(
            "Instances of IdentityMorphism cannot have properties.",
          )
        }
        return
      }
      _ => ()
    }

    if add_identities {
      ignore(
        diagram_set_dict_union(
          morphisms,
          identity_morphism(morphism.domain()),
          [],
        ),
      )
      ignore(
        diagram_set_dict_union(
          morphisms,
          identity_morphism(morphism.codomain()),
          [],
        ),
      )
    }

    let existing_keys = map_keys_sorted(morphisms)
    for existing in existing_keys {
      let new_props = property_intersection(morphisms[existing], props)
      if morphism.domain() == existing.codomain() {
        let left = morphism * existing
        ignore(diagram_set_dict_union(morphisms, left, new_props))
      }
      if morphism.codomain() == existing.domain() {
        let right = existing * morphism
        ignore(diagram_set_dict_union(morphisms, right, new_props))
      }
    }

    if recurse_composites {
      match morphism {
        Composite(items) =>
          for item in items {
            diagram_add_morphism_closure(morphisms, item, [], add_identities~)
          }
        _ => ()
      }
    }
  }
}

///|
fn diagram_collect_objects(spec : MorphismSpec) -> Array[Object] {
  let out : Array[Object] = Array::new()
  match spec {
    List(items) =>
      for morphism in items {
        out.push(morphism.domain())
        out.push(morphism.codomain())
      }
    Props(items) =>
      for morphism in items.keys() {
        out.push(morphism.domain())
        out.push(morphism.codomain())
      }
  }
  normalize_objects(out)
}

///|
fn diagram_from_specs(
  premises : MorphismSpec,
  conclusions : MorphismSpec,
) -> Diagram raise CategoryError {
  let premise_map : Map[Morphism, Array[String]] = Map([])
  let conclusion_map : Map[Morphism, Array[String]] = Map([])
  let objects = diagram_collect_objects(premises)

  match premises {
    List(items) =>
      for morphism in items {
        diagram_add_morphism_closure(premise_map, morphism, [])
      }
    Props(items) =>
      for morphism in items.keys() {
        diagram_add_morphism_closure(
          premise_map,
          morphism,
          normalize_property_set(items[morphism]),
        )
      }
  }

  match conclusions {
    List(items) =>
      for morphism in items {
        if contains_object(objects, morphism.domain()) &&
          contains_object(objects, morphism.codomain()) {
          diagram_add_morphism_closure(
            conclusion_map,
            morphism,
            [],
            add_identities=false,
            recurse_composites=false,
          )
        }
      }
    Props(items) =>
      for morphism in items.keys() {
        if contains_object(objects, morphism.domain()) &&
          contains_object(objects, morphism.codomain()) {
          diagram_add_morphism_closure(
            conclusion_map,
            morphism,
            normalize_property_set(items[morphism]),
            add_identities=false,
            recurse_composites=false,
          )
        }
      }
  }

  let result : Diagram = {
    premises: premise_map,
    conclusions: conclusion_map,
    objects,
  }
  result
}

///|
pub fn diagram(
  premises? : MorphismSpec = List([]),
  conclusions? : MorphismSpec = List([]),
) -> Diagram raise CategoryError {
  diagram_from_specs(premises, conclusions)
}

///|
pub fn Diagram::hom(
  self : Diagram,
  domain : Object,
  codomain : Object,
) -> (Array[Morphism], Array[Morphism]) {
  let premise_set : Array[Morphism] = Array::new()
  let conclusion_set : Array[Morphism] = Array::new()

  for morphism in self.premises.keys() {
    if morphism.domain() == domain && morphism.codomain() == codomain {
      premise_set.push(morphism)
    }
  }
  for morphism in self.conclusions.keys() {
    if morphism.domain() == domain && morphism.codomain() == codomain {
      conclusion_set.push(morphism)
    }
  }

  premise_set.sort()
  conclusion_set.sort()
  (premise_set, conclusion_set)
}

///|
pub fn Diagram::is_subdiagram(self : Diagram, other : Diagram) -> Bool {
  for morphism in other.premises.keys() {
    if !self.premises.contains(morphism) ||
      self.premises[morphism] != other.premises[morphism] {
      return false
    }
  }
  for morphism in other.conclusions.keys() {
    if !self.conclusions.contains(morphism) ||
      self.conclusions[morphism] != other.conclusions[morphism] {
      return false
    }
  }
  true
}

///|
pub fn Diagram::subdiagram_from_objects(
  self : Diagram,
  objects : Array[Object],
) -> Diagram raise CategoryError {
  let normalized = normalize_objects(objects)
  guard object_subset_of(normalized, self.objects) else {
    raise ValueError("Supplied objects should all belong to the diagram.")
  }

  let new_premises : Map[Morphism, Array[String]] = Map([])
  for morphism in self.premises.keys() {
    if contains_object(normalized, morphism.domain()) &&
      contains_object(normalized, morphism.codomain()) {
      new_premises[morphism] = self.premises[morphism]
    }
  }

  let new_conclusions : Map[Morphism, Array[String]] = Map([])
  for morphism in self.conclusions.keys() {
    if contains_object(normalized, morphism.domain()) &&
      contains_object(normalized, morphism.codomain()) {
      new_conclusions[morphism] = self.conclusions[morphism]
    }
  }

  diagram_from_specs(Props(new_premises), Props(new_conclusions))
}

///|
pub fn category(
  name : String,
  objects? : Array[Object] = [],
  commutative_diagrams? : Array[Diagram] = [],
) -> Category raise CategoryError {
  guard name != "" else {
    raise ValueError("A Category cannot have an empty name.")
  }
  let result : Category = {
    name,
    objects: category_class(objects),
    commutative_diagrams: normalize_diagrams(commutative_diagrams),
  }
  result
}

///|
pub fn Category::hom(
  _self : Category,
  _domain : Object,
  _codomain : Object,
) -> Unit raise CategoryError {
  raise NotImplemented("hom-sets are not implemented in Category.")
}

///|
pub fn Category::all_morphisms(_self : Category) -> Unit raise CategoryError {
  raise NotImplemented(
    "Obtaining the class of morphisms is not implemented in Category.",
  )
}
