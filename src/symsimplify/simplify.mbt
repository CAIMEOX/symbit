///|
pub fn simplify(
  expr : @symcore.Expr,
  plan? : SimplifyPlan = SimplifyPlan::Default,
  max_passes? : Int = 8,
) -> @symcore.Expr {
  simplify_with_patterns(expr, plan_patterns(plan), max_passes~)
}

///|
pub fn powsimp(
  expr : @symcore.Expr,
  max_passes? : Int = 6,
) -> @symcore.Expr {
  simplify_with_patterns(
    expr,
    [
      SimplifyPattern::FoldConstants,
      SimplifyPattern::PowDenest,
      SimplifyPattern::MulLikeBases,
      SimplifyPattern::FoldConstants,
    ],
    max_passes~,
  )
}

///|
pub fn trigsimp(
  expr : @symcore.Expr,
  max_passes? : Int = 6,
) -> @symcore.Expr {
  simplify_with_patterns(
    expr,
    [
      SimplifyPattern::FoldConstants,
      SimplifyPattern::FunctionIdentities,
      SimplifyPattern::TrigPythagorean,
      SimplifyPattern::FoldConstants,
    ],
    max_passes~,
  )
}

///|
pub fn signsimp(
  expr : @symcore.Expr,
  max_passes? : Int = 6,
) -> @symcore.Expr {
  simplify_with_patterns(
    expr,
    [
      SimplifyPattern::FoldConstants,
      SimplifyPattern::AddLikeTerms,
      SimplifyPattern::FoldConstants,
    ],
    max_passes~,
  )
}

///|
pub fn simplify_with_patterns(
  expr : @symcore.Expr,
  patterns : Array[SimplifyPattern],
  max_passes? : Int = 8,
) -> @symcore.Expr {
  let passes = if max_passes <= 0 { 1 } else { max_passes }
  let mut cur = expr
  for _ in 0..<passes {
    let next = apply_patterns_once(cur, patterns)
    if next == cur {
      return next
    }
    cur = next
  }
  cur
}

///|
pub fn apply_patterns_once(
  expr : @symcore.Expr,
  patterns : Array[SimplifyPattern],
) -> @symcore.Expr {
  let mut cur = expr
  for pattern in patterns {
    cur = rewrite_bottom_up(cur, pattern)
  }
  cur
}

///|
fn rewrite_bottom_up(
  expr : @symcore.Expr,
  pattern : SimplifyPattern,
) -> @symcore.Expr {
  let rewritten = @symcore.map_children(
    expr,
    child => rewrite_bottom_up(child, pattern),
  )
  apply_pattern(pattern, rewritten)
}

///|
pub fn apply_pattern(
  pattern : SimplifyPattern,
  expr : @symcore.Expr,
) -> @symcore.Expr {
  match pattern {
    SimplifyPattern::FoldConstants => fold_constants(expr)
    SimplifyPattern::AddLikeTerms => add_like_terms(expr)
    SimplifyPattern::MulLikeBases => mul_like_bases(expr)
    SimplifyPattern::PowDenest => pow_denest(expr)
    SimplifyPattern::TrigPythagorean => trig_pythagorean(expr)
    SimplifyPattern::FunctionIdentities => function_identities(expr)
  }
}

///|
fn fold_constants(expr : @symcore.Expr) -> @symcore.Expr {
  match expr {
    @symcore.Expr::Add(args) => @symcore.add(args)
    @symcore.Expr::Mul(args) => @symcore.mul(args)
    @symcore.Expr::Pow(base, exp) => @symcore.pow(base, exp)
    _ => expr
  }
}

///|
priv struct AddTerm {
  base : @symcore.Expr
  coeff : @symnum.BigRational
}

///|
fn add_like_terms(expr : @symcore.Expr) -> @symcore.Expr {
  match expr {
    @symcore.Expr::Add(args) => {
      let minus_one = @symnum.BigRational::from_int(-1)
      let mut const_term = @symnum.BigRational::zero()
      let terms : Map[String, AddTerm] = {}
      for arg in args {
        let (coeff, base_opt) = split_add_term(arg)
        match base_opt {
          None => const_term = const_term.add_r(coeff)
          Some(base_expr) => {
            let key = @symprint.debug_repr(base_expr)
            match terms.get(key) {
              Some(acc) =>
                terms[key] = AddTerm::{
                  base: acc.base,
                  coeff: acc.coeff.add_r(coeff),
                }
              None => terms[key] = AddTerm::{ base: base_expr, coeff }
            }
          }
        }
      }
      let out : Array[@symcore.Expr] = Array::new()
      for _, acc in terms {
        if acc.coeff.is_zero() {
          continue
        }
        if acc.coeff.is_one() {
          out.push(acc.base)
        } else if acc.coeff.compare(minus_one) == 0 {
          out.push(@symcore.mul([@symcore.int(-1), acc.base]))
        } else {
          out.push(@symcore.mul([@symcore.number(acc.coeff), acc.base]))
        }
      }
      if !const_term.is_zero() {
        out.push(@symcore.number(const_term))
      }
      @symcore.add(out)
    }
    _ => expr
  }
}

///|
fn split_add_term(
  term : @symcore.Expr,
) -> (@symnum.BigRational, @symcore.Expr?) {
  match term {
    @symcore.Expr::Number(n) => (n, None)
    @symcore.Expr::Mul(args) => {
      let mut coeff = @symnum.BigRational::one()
      let factors : Array[@symcore.Expr] = Array::new()
      for arg in args {
        match arg {
          @symcore.Expr::Number(n) => coeff = coeff.mul_r(n)
          _ => factors.push(arg)
        }
      }
      if factors.is_empty() {
        (coeff, None)
      } else if factors.length() == 1 {
        (coeff, Some(factors[0]))
      } else {
        (coeff, Some(@symcore.mul(factors)))
      }
    }
    _ => (@symnum.BigRational::one(), Some(term))
  }
}

///|
priv struct BasePow {
  base : @symcore.Expr
  exp : @symnum.BigRational
}

///|
fn mul_like_bases(expr : @symcore.Expr) -> @symcore.Expr {
  match expr {
    @symcore.Expr::Mul(args) => {
      let mut const_factor = @symnum.BigRational::one()
      let powers : Map[String, BasePow] = {}
      for arg in args {
        match arg {
          @symcore.Expr::Number(n) => const_factor = const_factor.mul_r(n)
          @symcore.Expr::Pow(base, @symcore.Expr::Number(exp)) => {
            let key = @symprint.debug_repr(base)
            match powers.get(key) {
              Some(acc) =>
                powers[key] = BasePow::{
                  base: acc.base,
                  exp: acc.exp.add_r(exp),
                }
              None => powers[key] = BasePow::{ base, exp }
            }
          }
          _ => {
            let key = @symprint.debug_repr(arg)
            match powers.get(key) {
              Some(acc) =>
                powers[key] = BasePow::{
                  base: acc.base,
                  exp: acc.exp.add_r(@symnum.BigRational::one()),
                }
              None =>
                powers[key] = BasePow::{
                  base: arg,
                  exp: @symnum.BigRational::one(),
                }
            }
          }
        }
      }
      if const_factor.is_zero() {
        return @symcore.int(0)
      }
      let factors : Array[@symcore.Expr] = Array::new()
      for _, acc in powers {
        if acc.exp.is_zero() {
          continue
        }
        if acc.exp.is_one() {
          factors.push(acc.base)
        } else {
          factors.push(@symcore.pow(acc.base, @symcore.number(acc.exp)))
        }
      }
      if factors.is_empty() || !const_factor.is_one() {
        factors.push(@symcore.number(const_factor))
      }
      @symcore.mul(factors)
    }
    _ => expr
  }
}

///|
fn pow_denest(expr : @symcore.Expr) -> @symcore.Expr {
  match expr {
    @symcore.Expr::Pow(@symcore.Expr::Pow(base, @symcore.Expr::Number(a)), @symcore.Expr::Number(b)) =>
      @symcore.pow(base, @symcore.number(a.mul_r(b)))
    @symcore.Expr::Pow(@symcore.Expr::Number(base), @symcore.Expr::Number(exp)) =>
      match eval_numeric_pow(base, exp) {
        Some(v) => @symcore.number(v)
        None => expr
      }
    _ => expr
  }
}

///|
fn eval_numeric_pow(
  base : @symnum.BigRational,
  exp : @symnum.BigRational,
) -> @symnum.BigRational? {
  if !exp.is_integral() {
    return None
  }
  let n = exp.numerator().to_int()
  if n < 0 && base.is_zero() {
    return None
  }
  let abs_n = if n < 0 { -n } else { n }
  let mut out = @symnum.BigRational::one()
  for _ in 0..<abs_n {
    out = out.mul_r(base)
  }
  if n >= 0 {
    Some(out)
  } else {
    Some(try! @symnum.BigRational::one().div_r(out))
  }
}

///|
fn function_identities(expr : @symcore.Expr) -> @symcore.Expr {
  match expr {
    @symcore.Expr::Function(name, [arg]) =>
      match (name, arg) {
        ("sin", @symcore.Expr::Number(n)) if n.is_zero() => @symcore.int(0)
        ("cos", @symcore.Expr::Number(n)) if n.is_zero() => @symcore.int(1)
        ("tan", @symcore.Expr::Number(n)) if n.is_zero() => @symcore.int(0)
        ("exp", @symcore.Expr::Number(n)) if n.is_zero() => @symcore.int(1)
        ("log", @symcore.Expr::Number(n)) if n.is_one() => @symcore.int(0)
        ("log", @symcore.Expr::Symbol(name)) if name == "E" => @symcore.int(1)
        ("sqrt", @symcore.Expr::Number(n)) if n.is_zero() => @symcore.int(0)
        ("sqrt", @symcore.Expr::Number(n)) if n.is_one() => @symcore.int(1)
        ("Abs", @symcore.Expr::Number(n)) =>
          if n.compare(@symnum.BigRational::zero()) < 0 {
            @symcore.number(n.neg_r())
          } else {
            @symcore.number(n)
          }
        ("abs", @symcore.Expr::Number(n)) =>
          if n.compare(@symnum.BigRational::zero()) < 0 {
            @symcore.number(n.neg_r())
          } else {
            @symcore.number(n)
          }
        _ => expr
      }
    _ => expr
  }
}

///|
fn trig_pythagorean(expr : @symcore.Expr) -> @symcore.Expr {
  match expr {
    @symcore.Expr::Add([a, b]) =>
      match (trig_square_arg(a, "sin"), trig_square_arg(b, "cos")) {
        (Some(lhs), Some(rhs)) if lhs == rhs => @symcore.int(1)
        _ =>
          match (trig_square_arg(a, "cos"), trig_square_arg(b, "sin")) {
            (Some(lhs), Some(rhs)) if lhs == rhs => @symcore.int(1)
            _ => expr
          }
      }
    _ => expr
  }
}

///|
fn trig_square_arg(term : @symcore.Expr, name : String) -> @symcore.Expr? {
  match term {
    @symcore.Expr::Pow(@symcore.Expr::Function(func, [arg]), @symcore.Expr::Number(exp)) =>
      if func == name && exp.compare(@symnum.BigRational::from_int(2)) == 0 {
        Some(arg)
      } else {
        None
      }
    _ => None
  }
}
