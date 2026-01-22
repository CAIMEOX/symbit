///|
pub enum Expr {
  Number(@symnum.BigRational)
  Symbol(String)
  Add(Array[Expr])
  Mul(Array[Expr])
  Pow(Expr, Expr)
  Function(String, Array[Expr])
}

///|
pub fn number(value : @symnum.BigRational) -> Expr {
  Expr::Number(value)
}

///|
pub fn int(value : Int) -> Expr {
  Expr::Number(@symnum.BigRational::from_int(value))
}

///|
pub fn rational_from_ints(
  num : Int,
  den : Int,
) -> Expr raise @symnum.RationalError {
  Expr::Number(
    @symnum.BigRational::new(BigInt::from_int(num), BigInt::from_int(den)),
  )
}

///|
pub fn symbol(name : String) -> Expr {
  Expr::Symbol(name)
}

///|
pub fn add(args : Array[Expr]) -> Expr {
  let flat : Array[Expr] = Array::new()
  let mut const_sum = @symnum.BigRational::zero()
  for arg in args {
    match arg {
      Expr::Add(inner) =>
        for child in inner {
          match child {
            Expr::Number(n) => const_sum = const_sum.add_r(n)
            _ => flat.push(child)
          }
        }
      Expr::Number(n) => const_sum = const_sum.add_r(n)
      _ => flat.push(arg)
    }
  }
  if !const_sum.is_zero() {
    flat.push(Expr::Number(const_sum))
  }
  sort_exprs_in_place(flat)
  match flat.length() {
    0 => Expr::Number(@symnum.BigRational::zero())
    1 => flat[0]
    _ => Expr::Add(flat)
  }
}

///|
pub fn mul(args : Array[Expr]) -> Expr {
  let flat : Array[Expr] = Array::new()
  let mut const_prod = @symnum.BigRational::one()
  for arg in args {
    match arg {
      Expr::Mul(inner) =>
        for child in inner {
          match child {
            Expr::Number(n) => {
              if n.is_zero() {
                return Expr::Number(@symnum.BigRational::zero())
              }
              const_prod = const_prod.mul_r(n)
            }
            _ => flat.push(child)
          }
        }
      Expr::Number(n) => {
        if n.is_zero() {
          return Expr::Number(@symnum.BigRational::zero())
        }
        const_prod = const_prod.mul_r(n)
      }
      _ => flat.push(arg)
    }
  }
  if !const_prod.is_one() {
    flat.push(Expr::Number(const_prod))
  }
  sort_exprs_in_place(flat)
  match flat.length() {
    0 => Expr::Number(@symnum.BigRational::one())
    1 => flat[0]
    _ => Expr::Mul(flat)
  }
}

///|
pub fn pow(base : Expr, exp : Expr) -> Expr {
  match exp {
    Expr::Number(n) if n.is_zero() => Expr::Number(@symnum.BigRational::one())
    Expr::Number(n) if n.is_one() => base
    _ =>
      match base {
        Expr::Number(n) if n.is_zero() =>
          Expr::Number(@symnum.BigRational::zero())
        _ => Expr::Pow(base, exp)
      }
  }
}

///|
pub fn function(name : String, args : Array[Expr]) -> Expr {
  Expr::Function(name, args.map(child => child))
}
