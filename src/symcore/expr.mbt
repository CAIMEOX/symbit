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
impl Show for Expr with to_string(self) {
  match self {
    Expr::Number(n) => n.to_string()
    Expr::Symbol(s) => s
    Expr::Add(args) =>
      "(" + args.map(child => child.to_string()).join(" + ") + ")"
    Expr::Mul(args) =>
      "(" + args.map(child => child.to_string()).join(" * ") + ")"
    Expr::Pow(base, exp) =>
      "(" + base.to_string() + " ** " + exp.to_string() + ")"
    Expr::Function(name, args) =>
      name + "(" + args.map(child => child.to_string()).join(", ") + ")"
  }
}

///|
pub impl Add for Expr with add(self, other) {
  add([self, other])
}

///|
pub impl Mul for Expr with mul(self, other) {
  mul([self, other])
}

///|
pub impl Sub for Expr with sub(self, other) {
  add([self, mul([int(-1), other])])
}

///|
impl Show for Expr with output(self, logger) {
  logger.write_string(self.to_string())
}

///|
pub impl BitXOr for Expr with lxor(self, other) {
  pow(self, other)
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
  sort_exprs_in_place(flat)
  if !const_sum.is_zero() {
    flat.push(Expr::Number(const_sum))
  }
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
  sort_exprs_in_place(flat)
  if flat.is_empty() {
    if const_prod.is_one() {
      Expr::Number(@symnum.BigRational::one())
    } else {
      Expr::Number(const_prod)
    }
  } else if const_prod.is_one() {
    match flat.length() {
      1 => flat[0]
      _ => Expr::Mul(flat)
    }
  } else {
    let out : Array[Expr] = Array::new()
    out.push(Expr::Number(const_prod))
    for v in flat {
      out.push(v)
    }
    match out.length() {
      1 => out[0]
      _ => Expr::Mul(out)
    }
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

///|
/// Raw constructors without canonicalization (used by strategies).
pub fn raw_add(args : Array[Expr]) -> Expr {
  Expr::Add(args.map(child => child))
}

///|
pub fn raw_mul(args : Array[Expr]) -> Expr {
  Expr::Mul(args.map(child => child))
}

///|
pub fn raw_pow(base : Expr, exp : Expr) -> Expr {
  Expr::Pow(base, exp)
}

///|
pub fn raw_function(name : String, args : Array[Expr]) -> Expr {
  Expr::Function(name, args.map(child => child))
}

///|
pub fn arbitrary_polys() -> @qc.Gen[Expr] {
  let available_symbols = ["x", "y", "z", "w", "a", "b", "c"]
  let var_gen = @qc.one_of_array(available_symbols).fmap(symbol)
  letrec f = (size : Int) => {
    match size.abs() {
      n if n <= 0 => var_gen
      n => {
        let sub = f(n / 2)
        @qc.frequency([
          (10, var_gen),
          (5, @qc.int_bound(100).fmap(int)),
          (10, arbitrary_array_use_gen(n / 2 + 2, sub).fmap(x => Mul(x))),
          (10, arbitrary_array_use_gen(n / 2 + 2, sub).fmap(x => Add(x))),
          (
            5,
            var_gen.bind(base => {
              @qc.int_bound(100).bind(exp => @qc.pure(pow(base, int(exp))))
            }),
          ),
        ])
      }
    }
  }

  @qc.sized(f)
}

///|
pub fn[T] arbitrary_array_use_gen(
  bound : Int,
  elem_gen : @qc.Gen[T],
) -> @qc.Gen[Array[T]] {
  @qc.Gen::new((i, rs) => {
    let l = @qc.int_range(1, bound).run(0, rs)
    Array::makei(l, idx => elem_gen.run(i + idx, rs))
  })
}

///|
test "arbitrary array use gen" {
  let gen = arbitrary_array_use_gen(5, @qc.int_bound(10))
  let arr = gen.samples(size=10, seed=101)
  inspect(
    arr,
    content="[[3, 6], [0], [0, 0], [9, 6, 7], [1, 5], [3], [6], [0], [8, 7], [8, 7]]",
  )
}

///|
test "symbolized" {
  let x = symbol("x")
  let y = symbol("y")
  let expr = x + (y ^ int(10))
  inspect(expr, content="(x + (y ** 10))")
}
