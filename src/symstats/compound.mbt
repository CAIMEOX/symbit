///|
/// Compound random variables (finite mixtures).

///|
fn normalize_mixture(
  items : Array[(@symnum.BigRational, RandomVar)],
) -> Array[(@symnum.BigRational, RandomVar)] {
  let kept : Array[(@symnum.BigRational, RandomVar)] = Array::new()
  let mut total = @symnum.BigRational::zero()
  for pair in items {
    let (w, rv) = pair
    if !w.is_zero() {
      kept.push((w, rv))
      total = total.add_r(w)
    }
  }
  if kept.is_empty() {
    return kept
  }
  if total.is_one() {
    return kept
  }
  let out : Array[(@symnum.BigRational, RandomVar)] = Array::new()
  for pair in kept {
    let (w, rv) = pair
    out.push((try! w.div_r(total), rv))
  }
  out
}

///|
pub fn compound_rv(
  name : String,
  components : Array[(@symnum.BigRational, RandomVar)],
) -> RandomVar {
  random_var(name, RVKind::Compound(normalize_mixture(components)))
}

///|
pub fn compound_components(
  rv : RandomVar,
) -> Array[(@symnum.BigRational, RandomVar)]? {
  match rv.kind {
    RVKind::Compound(items) => Some(items)
    _ => None
  }
}
