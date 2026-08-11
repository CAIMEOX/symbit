///|
/// Front doors for symbolic sequence objects.
///
/// Current Limits:
/// - The public API covers formula, periodic, additive, and multiplicative sequences.
/// - It does not expose the full sequence algebra found in larger computer algebra systems.

///|
/// Store one symbolic sequence.
///
/// - Does: Represents a formula sequence, a periodic sequence, or a sequence built from addition or multiplication.
/// - Input: Variant-specific fields such as a formula expression, periodic values, or child sequences.
/// - Returns: A `Sequence` value.
/// - Limits: Range bounds are stored but only enforced when coefficients are requested.
pub enum Sequence {
  SeqFormula(@symcore.Expr, String, Int, Int)
  SeqPer(Array[@symcore.Expr], Int, Int)
  SeqAdd(Sequence, Sequence)
  SeqMul(Sequence, Sequence)
}

///|
fn rational_pow(base : @symnum.BigRational, exp : Int) -> @symnum.BigRational {
  if exp == 0 {
    return @symnum.BigRational::one()
  }
  let mut e = exp
  let mut acc = @symnum.BigRational::one()
  let mut b = base
  while e > 0 {
    if e % 2 == 1 {
      acc = acc.mul_r(b)
    }
    e = e / 2
    if e > 0 {
      b = b.mul_r(b)
    }
  }
  acc
}

///|
fn eval_numeric(expr : @symcore.Expr) -> @symcore.Expr {
  let rebuilt = match expr {
    @symcore.Expr::Number(_) => expr
    @symcore.Expr::Add(args) => @symcore.add(args.map(eval_numeric))
    @symcore.Expr::Mul(args) => @symcore.mul(args.map(eval_numeric))
    @symcore.Expr::Pow(base, exp) => {
      let b = eval_numeric(base)
      let e = eval_numeric(exp)
      match (b, e) {
        (@symcore.Expr::Number(nb), @symcore.Expr::Number(ne)) if ne.is_integral() => {
          let num = ne.numerator()
          if num.bit_length() > 30 {
            @symcore.pow(b, e)
          } else {
            let exp_int = num.to_int()
            if exp_int >= 0 {
              @symcore.Expr::Number(rational_pow(nb, exp_int))
            } else {
              @symcore.pow(b, e)
            }
          }
        }
        _ => @symcore.pow(b, e)
      }
    }
    _ =>
      match @symcore.application_parts(expr) {
        Some((head, args)) =>
          match @symcore.apply(head, args.map(eval_numeric)) {
            Some(applied) => applied
            None => expr
          }
        None => expr
      }
  }
  let numeric = @symcore.evalf(rebuilt, prec=80)
  match numeric {
    @symcore.Expr::Float(_) | @symcore.Expr::ComplexFloat(_) => numeric
    _ => rebuilt
  }
}

///|
/// Build a formula-based sequence.
///
/// - Does: Wraps `expr` as a sequence in the index named by `var_name`.
/// - Input: `expr` is the term formula, `var_name` names the index, and `start` and `stop` bound the valid index range.
/// - Returns: One `Sequence::SeqFormula` value.
/// - Limits: The formula is not validated until coefficients are requested.
pub fn sequence(
  expr : @symcore.Expr,
  var_name? : String = "n",
  start? : Int = 0,
  stop? : Int = -1,
) -> Sequence {
  Sequence::SeqFormula(expr, var_name, start, stop)
}

///|
/// Build a periodic sequence.
///
/// - Does: Wraps the provided values as one repeating sequence block.
/// - Input: `values` is the repeating block and `start` and `stop` bound the valid index range.
/// - Returns: One `Sequence::SeqPer` value.
/// - Limits: An empty block is accepted here but will raise when coefficients are requested.
pub fn seq_per(
  values : Array[@symcore.Expr],
  start? : Int = 0,
  stop? : Int = -1,
) -> Sequence {
  Sequence::SeqPer(values, start, stop)
}

///|
/// Add two sequences symbolically.
///
/// - Does: Builds a sequence node representing pointwise addition.
/// - Input: Two `Sequence` values.
/// - Returns: One `Sequence::SeqAdd` value.
/// - Limits: No simplification is attempted at construction time.
pub fn seq_add(a : Sequence, b : Sequence) -> Sequence {
  Sequence::SeqAdd(a, b)
}

///|
/// Multiply two sequences symbolically.
///
/// - Does: Builds a sequence node representing pointwise multiplication.
/// - Input: Two `Sequence` values.
/// - Returns: One `Sequence::SeqMul` value.
/// - Limits: No simplification is attempted at construction time.
pub fn seq_mul(a : Sequence, b : Sequence) -> Sequence {
  Sequence::SeqMul(a, b)
}

///|
/// Evaluate one sequence coefficient.
///
/// - Does: Returns the term at index `n`, including recursive evaluation for additive and multiplicative sequence nodes.
/// - Input: One `Sequence` value and an integer index.
/// - Returns: One `Expr` for the requested term.
/// - Limits: Raises when `n` is outside the stored range or when a periodic sequence has an empty block.
pub fn Sequence::coeff(self : Sequence, n : Int) -> @symcore.Expr raise {
  match self {
    Sequence::SeqFormula(expr, var_name, start, stop) => {
      if n < start {
        fail("sequence index below start")
      }
      if stop >= 0 && n > stop {
        fail("sequence index above stop")
      }
      let env : Map[String, @symcore.Expr] = Map([])
      env[var_name] = @symcore.int(n)
      eval_numeric(@symcore.subst(expr, env))
    }
    Sequence::SeqPer(values, start, stop) => {
      if values.is_empty() {
        fail("empty periodic sequence")
      }
      if n < start {
        fail("sequence index below start")
      }
      if stop >= 0 && n > stop {
        fail("sequence index above stop")
      }
      let idx = (n - start) % values.length()
      values[idx]
    }
    Sequence::SeqAdd(a, b) => {
      let va = a.coeff(n)
      let vb = b.coeff(n)
      eval_numeric(@symcore.add([va, vb]))
    }
    Sequence::SeqMul(a, b) => {
      let va = a.coeff(n)
      let vb = b.coeff(n)
      eval_numeric(@symcore.mul([va, vb]))
    }
  }
}
