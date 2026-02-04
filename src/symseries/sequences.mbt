///|
/// Minimal sequence types.

///|
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
  match expr {
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
              @symcore.number(rational_pow(nb, exp_int))
            } else {
              @symcore.pow(b, e)
            }
          }
        }
        _ => @symcore.pow(b, e)
      }
    }
    @symcore.Expr::Function(name, args) =>
      @symcore.function(name, args.map(eval_numeric))
    _ => expr
  }
}

///|
pub fn sequence(
  expr : @symcore.Expr,
  var_name? : String = "n",
  start? : Int = 0,
  stop? : Int = -1,
) -> Sequence {
  Sequence::SeqFormula(expr, var_name, start, stop)
}

///|
pub fn seq_per(
  values : Array[@symcore.Expr],
  start? : Int = 0,
  stop? : Int = -1,
) -> Sequence {
  Sequence::SeqPer(values, start, stop)
}

///|
pub fn seq_add(a : Sequence, b : Sequence) -> Sequence {
  Sequence::SeqAdd(a, b)
}

///|
pub fn seq_mul(a : Sequence, b : Sequence) -> Sequence {
  Sequence::SeqMul(a, b)
}

///|
pub fn Sequence::coeff(self : Sequence, n : Int) -> @symcore.Expr raise {
  match self {
    Sequence::SeqFormula(expr, var_name, start, stop) => {
      if n < start {
        fail("sequence index below start")
      }
      if stop >= 0 && n > stop {
        fail("sequence index above stop")
      }
      let env : Map[String, @symcore.Expr] = {}
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
