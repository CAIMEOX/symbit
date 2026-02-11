///|
/// Finite random variables and exact finite summations.

///|
fn half_rational() -> @symnum.BigRational {
  try! @symnum.BigRational::new(BigInt::from_int(1), BigInt::from_int(2))
}

///|
fn one_over(n : Int) -> @symnum.BigRational {
  try! @symnum.BigRational::new(BigInt::from_int(1), BigInt::from_int(n))
}

///|
fn normalize_atoms(
  atoms : Array[(@symcore.Expr, @symnum.BigRational)],
) -> Array[(@symcore.Expr, @symnum.BigRational)] {
  let nonzero : Array[(@symcore.Expr, @symnum.BigRational)] = Array::new()
  let mut total = @symnum.BigRational::zero()
  for item in atoms {
    let (value, p) = item
    if !p.is_zero() {
      nonzero.push((value, p))
      total = total.add_r(p)
    }
  }
  if nonzero.is_empty() {
    return nonzero
  }
  let out = nonzero
  out.sort_by((a, b) => @symcore.compare_expr(a.0, b.0))
  if total.is_one() {
    return out
  }
  let normalized : Array[(@symcore.Expr, @symnum.BigRational)] = Array::new()
  for item in out {
    let (value, p) = item
    normalized.push((value, try! p.div_r(total)))
  }
  normalized
}

///|
pub fn finite_rv(
  name : String,
  atoms : Array[(@symcore.Expr, @symnum.BigRational)],
) -> RandomVar {
  random_var(name, RVKind::Finite(normalize_atoms(atoms)))
}

///|
pub fn die(name : String, sides? : Int = 6) -> RandomVar {
  if sides <= 0 {
    return finite_rv(name, [])
  }
  let p = one_over(sides)
  let atoms : Array[(@symcore.Expr, @symnum.BigRational)] = Array::new()
  for i in 1..<=sides {
    atoms.push((@symcore.int(i), p))
  }
  finite_rv(name, atoms)
}

///|
pub fn coin(
  name : String,
  p_head? : @symnum.BigRational = half_rational(),
) -> RandomVar {
  let one = @symnum.BigRational::one()
  let p_tail = one.add_r(p_head.neg_r())
  finite_rv(name, [(@symcore.int(1), p_head), (@symcore.int(0), p_tail)])
}

///|
pub fn bernoulli(name : String, p : @symnum.BigRational) -> RandomVar {
  coin(name, p_head=p)
}

///|
pub fn discrete_uniform(
  name : String,
  values : Array[@symcore.Expr],
) -> RandomVar {
  if values.is_empty() {
    return finite_rv(name, [])
  }
  let p = one_over(values.length())
  let atoms : Array[(@symcore.Expr, @symnum.BigRational)] = Array::new()
  for value in values {
    atoms.push((value, p))
  }
  finite_rv(name, atoms)
}

///|
pub fn finite_atoms(
  rv : RandomVar,
) -> Array[(@symcore.Expr, @symnum.BigRational)]? {
  match rv.kind {
    RVKind::Finite(items) => Some(items)
    _ => None
  }
}

///|
pub fn finite_pmf(rv : RandomVar, value : @symcore.Expr) -> @symcore.Expr? {
  match finite_atoms(rv) {
    None => None
    Some(items) => {
      for item in items {
        let (atom, p) = item
        if @symcore.compare_expr(atom, value) == 0 {
          return Some(expr_from_big_rational(p))
        }
      }
      Some(expr_zero())
    }
  }
}

///|
pub fn finite_probability(rv : RandomVar, event : Event) -> @symcore.Expr? {
  match finite_atoms(rv) {
    None => None
    Some(items) => {
      let env : Map[String, @symcore.Expr] = {}
      let mut total = @symnum.BigRational::zero()
      for item in items {
        let (value, p) = item
        env[rv.name] = value
        match evaluate_event(event, env) {
          TriBool::True => total = total.add_r(p)
          TriBool::False => ()
          TriBool::Unknown => return None
        }
      }
      Some(expr_from_big_rational(total))
    }
  }
}

///|
pub fn finite_expectation(
  rv : RandomVar,
  expr? : @symcore.Expr = @symcore.symbol("_"),
) -> @symcore.Expr? {
  match finite_atoms(rv) {
    None => None
    Some(items) => {
      let base_expr = if expr == @symcore.symbol("_") {
        @symcore.symbol(rv.name)
      } else {
        expr
      }
      let terms : Array[@symcore.Expr] = Array::new()
      for item in items {
        let (value, p) = item
        let substituted = substitute_symbol(base_expr, rv.name, value)
        let evaled = eval_arith(substituted)
        let weighted = @symcore.mul([expr_from_big_rational(p), evaled])
        terms.push(eval_arith(weighted))
      }
      Some(eval_arith(@symcore.add(terms)))
    }
  }
}

///|
pub fn finite_variance(rv : RandomVar) -> @symcore.Expr? {
  match finite_expectation(rv) {
    None => None
    Some(mean) =>
      match finite_atoms(rv) {
        None => None
        Some(items) => {
          let terms : Array[@symcore.Expr] = Array::new()
          for item in items {
            let (value, p) = item
            let diff = eval_arith(
              @symcore.add([value, @symcore.mul([@symcore.int(-1), mean])]),
            )
            let sq = eval_arith(@symcore.pow(diff, @symcore.int(2)))
            terms.push(
              eval_arith(@symcore.mul([expr_from_big_rational(p), sq])),
            )
          }
          Some(eval_arith(@symcore.add(terms)))
        }
      }
  }
}
