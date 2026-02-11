///|
/// Joint random variables (independent product first).

///|
pub fn joint_independent(name : String, vars : Array[RandomVar]) -> RandomVar {
  random_var(name, RVKind::JointIndependent(vars))
}

///|
pub fn joint_components(rv : RandomVar) -> Array[RandomVar]? {
  match rv.kind {
    RVKind::JointIndependent(items) => Some(items)
    _ => None
  }
}

///|
pub fn marginal(rv : RandomVar, idx : Int) -> RandomVar? {
  match joint_components(rv) {
    Some(items) if 0 <= idx && idx < items.length() => Some(items[idx])
    _ => None
  }
}

///|
pub fn assume_independent(a : RandomVar, b : RandomVar) -> Bool {
  if a.name == b.name {
    return false
  }
  true
}
