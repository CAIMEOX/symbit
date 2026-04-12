///|
pub(all) enum Expr {
  Number(@symnum.BigRational)
  Float(Float)
  ComplexFloat(ComplexFloat)
  NumberSymbol(NumberSymbolKind)
  Boolean(Bool)
  IdentityFunction
  Symbol(String)
  Dummy(String, Int)
  Wild(String, Array[Expr], Array[WildProperty])
  WildFunction(String, Array[Int])
  FunctionHead(String)
  UndefinedFunction(String)
  Apply(Expr, Array[Expr])
  Add(Array[Expr])
  Mul(Array[Expr])
  Pow(Expr, Expr)
  Mod(Expr, Expr)
  Tuple(Array[Expr])
  Dict(Array[(Expr, Expr)])
  Relational(RelOp, Expr, Expr)
  Derivative(Expr, Array[Expr])
  Subs(Expr, Expr, Expr)
  Lambda(Expr, Expr)
  Function(String, Array[Expr])
}

///|
impl Show for Expr with to_string(self) {
  match self {
    Expr::Number(n) => n.to_string()
    Expr::Float(f) => f.to_string()
    Expr::ComplexFloat(z) => z.to_string()
    Expr::NumberSymbol(kind) => number_symbol_name(kind)
    Expr::Boolean(true) => "True"
    Expr::Boolean(false) => "False"
    Expr::IdentityFunction => "Lambda(_x, _x)"
    Expr::Symbol(s) => s
    Expr::Dummy(name, _) => dummy_display_name(name)
    Expr::Wild(name, _, _) => wild_display_name(name)
    Expr::WildFunction(name, _) => wild_display_name(name)
    Expr::FunctionHead(name) => standalone_function_head_display_name(name)
    Expr::UndefinedFunction(name) => name
    Expr::Apply(head, args) =>
      head.to_string() +
      "(" +
      args.map(child => child.to_string()).join(", ") +
      ")"
    Expr::Add(args) =>
      "(" + args.map(child => child.to_string()).join(" + ") + ")"
    Expr::Mul(args) =>
      "(" + args.map(child => child.to_string()).join(" * ") + ")"
    Expr::Pow(base, exp) =>
      "(" + base.to_string() + " ** " + exp.to_string() + ")"
    Expr::Mod(lhs, rhs) =>
      "Mod(" + lhs.to_string() + ", " + rhs.to_string() + ")"
    Expr::Tuple(args) =>
      "Tuple(" + args.map(child => child.to_string()).join(", ") + ")"
    Expr::Dict(items) => {
      let rendered : Array[String] = []
      for item in sorted_dict_entries(items) {
        let (key, value) = item
        rendered.push(key.to_string() + ": " + value.to_string())
      }
      "{" + rendered.join(", ") + "}"
    }
    Expr::Relational(op, lhs, rhs) => {
      let name = match op {
        RelOp::Eq => "Eq"
        RelOp::Ne => "Ne"
        RelOp::Lt => "Lt"
        RelOp::Le => "Le"
        RelOp::Gt => "Gt"
        RelOp::Ge => "Ge"
      }
      name + "(" + lhs.to_string() + ", " + rhs.to_string() + ")"
    }
    Expr::Derivative(inner, deriv_args) => {
      let deriv_args = canonical_derivative_args(deriv_args)
      let args : Array[String] = [inner.to_string()]
      let pair_count = deriv_args.length() / 2
      for i in 0..<pair_count {
        let wrt = deriv_args[i * 2]
        let order = deriv_args[i * 2 + 1]
        match order {
          Expr::Number(n) if n == @symnum.BigRational::one() =>
            args.push(wrt.to_string())
          _ => args.push(Expr::Tuple([wrt, order]).to_string())
        }
      }
      "Derivative(" + args.join(", ") + ")"
    }
    Expr::Subs(inner, variable, value) =>
      "Subs(" +
      inner.to_string() +
      ", " +
      variable.to_string() +
      ", " +
      value.to_string() +
      ")"
    Expr::Lambda(vars, body) =>
      "Lambda(" + vars.to_string() + ", " + body.to_string() + ")"
    Expr::Function(name, args) =>
      normalize_legacy_function(name, args).to_string()
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
pub fn int(value : Int) -> Expr {
  Expr::Number(@symnum.BigRational::from_int(value))
}

///|
pub fn rational_from_ints(
  num : Int,
  den : Int,
) -> Expr raise @symnum.RationalError {
  Expr::Number(@symnum.BigRational::from_ints(num, den))
}

///|
fn atomic_numeric_expr_to_exact_rational(expr : Expr) -> @symnum.BigRational? {
  match normalize_legacy_expr(expr) {
    Expr::Number(value) => Some(value)
    Expr::Float(value) => {
      let exact : Result[(BigInt, BigInt), @symnum.MpfError] = try? value.to_rational()
      match exact {
        Ok((num, den)) => {
          let rational : Result[@symnum.BigRational, @symnum.RationalError] = try? @symnum.BigRational::new(
            num, den,
          )
          match rational {
            Ok(value) => Some(value)
            Err(_) => None
          }
        }
        Err(_) => None
      }
    }
    Expr::Boolean(true) => Some(@symnum.BigRational::one())
    Expr::Boolean(false) => Some(@symnum.BigRational::zero())
    _ => None
  }
}

///|
fn pow_exact_rational(
  base : @symnum.BigRational,
  exponent : BigInt,
) -> @symnum.BigRational? {
  if exponent.is_zero() {
    return Some(@symnum.BigRational::one())
  }
  let mut power = exponent
  let mut base_value = base
  if power.compare(0N) < 0 {
    power = power.neg()
    let reciprocal : Result[@symnum.BigRational, @symnum.RationalError] = try? base.reciprocal()
    match reciprocal {
      Ok(value) => base_value = value
      Err(_) => return None
    }
  }
  let mut acc = @symnum.BigRational::one()
  while power.compare(0N) > 0 {
    if power.mod(2N).compare(0N) != 0 {
      acc = acc.mul_r(base_value)
    }
    power = power.div(2N)
    if power.compare(0N) > 0 {
      base_value = base_value.mul_r(base_value)
    }
  }
  Some(acc)
}

///|
fn exact_numeric_expr_to_rational(expr : Expr) -> @symnum.BigRational? {
  match normalize_legacy_expr(expr) {
    Expr::Add(args) => {
      let mut acc = @symnum.BigRational::zero()
      for arg in args {
        match exact_numeric_expr_to_rational(arg) {
          Some(value) => acc = acc.add_r(value)
          None => return None
        }
      }
      Some(acc)
    }
    Expr::Mul(args) => {
      let mut acc = @symnum.BigRational::one()
      for arg in args {
        match exact_numeric_expr_to_rational(arg) {
          Some(value) => acc = acc.mul_r(value)
          None => return None
        }
      }
      Some(acc)
    }
    Expr::Pow(base, exp) =>
      match
        (
          exact_numeric_expr_to_rational(base),
          exact_numeric_expr_to_rational(exp),
        ) {
        (Some(base_value), Some(exp_value)) if exp_value.is_integral() =>
          pow_exact_rational(base_value, exp_value.numerator())
        _ => None
      }
    other => atomic_numeric_expr_to_exact_rational(other)
  }
}

///|
pub fn exact_numeric_expr_num_den(expr : Expr) -> (BigInt, BigInt)? {
  match exact_numeric_expr_to_rational(expr) {
    Some(value) => Some((value.numerator(), value.denominator()))
    None => None
  }
}

///|
fn trunc_exact_rational(value : @symnum.BigRational) -> Expr {
  let truncated = value.numerator().div(value.denominator())
  Expr::Number(@symnum.BigRational::from_bigint(truncated))
}

///|
fn constructor_integer_value(arg : Expr) -> Expr {
  match exact_numeric_expr_to_rational(arg) {
    Some(value) => trunc_exact_rational(value)
    None =>
      match evalf(normalize_legacy_expr(arg)) {
        Expr::Float(value) => {
          let exact : Result[(BigInt, BigInt), @symnum.MpfError] = try? value.to_rational()
          match exact {
            Ok((num, den)) =>
              trunc_exact_rational(
                @symnum.BigRational::new(num, den) catch {
                  _ => return Expr::Apply(Expr::FunctionHead("Integer"), [arg])
                },
              )
            Err(_) => Expr::Apply(Expr::FunctionHead("Integer"), [arg])
          }
        }
        Expr::Number(value) => trunc_exact_rational(value)
        _ => Expr::Apply(Expr::FunctionHead("Integer"), [arg])
      }
  }
}

///|
fn constructor_integer(args : Array[Expr]) -> Expr {
  match args {
    [arg] => constructor_integer_value(arg)
    _ => Expr::Apply(Expr::FunctionHead("Integer"), args)
  }
}

///|
fn constructor_rational(args : Array[Expr]) -> Expr {
  let exact_rational_input = fn(arg : Expr) {
    if current_evaluate() {
      exact_numeric_expr_to_rational(arg)
    } else {
      atomic_numeric_expr_to_exact_rational(arg)
    }
  }
  match args {
    [arg] =>
      match exact_rational_input(arg) {
        Some(value) => Expr::Number(value)
        None => Expr::Apply(Expr::FunctionHead("Rational"), args)
      }
    [lhs, rhs] =>
      match (exact_rational_input(lhs), exact_rational_input(rhs)) {
        (Some(lhs_value), Some(rhs_value)) =>
          if rhs_value.is_zero() {
            if lhs_value.is_zero() {
              Expr::NumberSymbol(NumberSymbolKind::NaN)
            } else {
              Expr::NumberSymbol(NumberSymbolKind::ComplexInfinity)
            }
          } else {
            let exact : Result[@symnum.BigRational, @symnum.RationalError] = try? lhs_value.div_r(
              rhs_value,
            )
            match exact {
              Ok(value) => Expr::Number(value)
              Err(_) => Expr::Apply(Expr::FunctionHead("Rational"), args)
            }
          }
        _ => Expr::Apply(Expr::FunctionHead("Rational"), args)
      }
    _ => Expr::Apply(Expr::FunctionHead("Rational"), args)
  }
}

///|
fn constructor_float(args : Array[Expr]) -> Expr {
  let exact_integer_atom = fn(arg : Expr) -> BigInt? {
    match normalize_legacy_expr(arg) {
      Expr::Number(value) if value.is_integral() => Some(value.numerator())
      _ => None
    }
  }
  let small_int = fn(value : BigInt) -> Int? {
    if value.bit_length() > 30 {
      None
    } else {
      Some(value.to_int())
    }
  }
  let float_from_mpf = fn(value : @symnum.Mpf, prec : Int) -> Expr {
    if value == @symnum.fnan {
      Expr::NumberSymbol(NumberSymbolKind::NaN)
    } else if value == @symnum.finf {
      Expr::NumberSymbol(NumberSymbolKind::Infinity)
    } else if value == @symnum.fninf {
      Expr::NumberSymbol(NumberSymbolKind::NegativeInfinity)
    } else if @symnum.is_zero(value) {
      int(0)
    } else {
      Expr::Float(Float::from_mpf(value, prec~))
    }
  }
  let float_from_tuple = fn(
    items : Array[Expr],
    prec : Int,
    fallback_args : Array[Expr],
  ) -> Expr {
    let ints : Array[BigInt] = []
    for item in items {
      match exact_integer_atom(item) {
        Some(value) => ints.push(value)
        None => return Expr::Apply(Expr::FunctionHead("Float"), fallback_args)
      }
    }
    match ints {
      [sign, man, exp] => {
        let sign_i = match small_int(sign) {
          Some(value) => value
          None => return Expr::Apply(Expr::FunctionHead("Float"), fallback_args)
        }
        let exp_i = match small_int(exp) {
          Some(value) => value
          None => return Expr::Apply(Expr::FunctionHead("Float"), fallback_args)
        }
        guard (sign_i == 0 || sign_i == 1) && man.compare(0N) >= 0 else {
          return Expr::Apply(Expr::FunctionHead("Float"), fallback_args)
        }
        let bc = man.bit_length()
        float_from_mpf(
          @symnum.mpf_normalize(
            sign_i, man, exp_i, bc, prec, @symnum.round_nearest,
          ),
          prec,
        )
      }
      [sign, man, exp, bc] => {
        let sign_i = match small_int(sign) {
          Some(value) => value
          None => return Expr::Apply(Expr::FunctionHead("Float"), fallback_args)
        }
        let exp_i = match small_int(exp) {
          Some(value) => value
          None => return Expr::Apply(Expr::FunctionHead("Float"), fallback_args)
        }
        let bc_i = match small_int(bc) {
          Some(value) => value
          None => return Expr::Apply(Expr::FunctionHead("Float"), fallback_args)
        }
        if man.compare(0N) == 0 {
          match bc_i {
            -1 => return Expr::NumberSymbol(NumberSymbolKind::NaN)
            -2 | -3 =>
              return Expr::NumberSymbol(
                if sign_i == 1 {
                  NumberSymbolKind::NegativeInfinity
                } else {
                  NumberSymbolKind::Infinity
                },
              )
            _ => ()
          }
        }
        float_from_mpf(
          @symnum.mpf_normalize(
            sign_i, man, exp_i, bc_i, prec, @symnum.round_nearest,
          ),
          prec,
        )
      }
      _ => Expr::Apply(Expr::FunctionHead("Float"), fallback_args)
    }
  }
  let float_from_numeric = fn(
    arg : Expr,
    prec : Int,
    fallback_args : Array[Expr],
  ) -> Expr {
    match exact_numeric_expr_to_rational(arg) {
      Some(value) => {
        let approx : Result[Float, @symnum.MpfError] = try? Float::from_exact(
          value,
          prec~,
        )
        match approx {
          Ok(value) => Expr::Float(value)
          Err(_) => Expr::Apply(Expr::FunctionHead("Float"), fallback_args)
        }
      }
      None =>
        match evalf(normalize_legacy_expr(arg), prec~) {
          Expr::Float(value) => Expr::Float(value)
          Expr::NumberSymbol(NumberSymbolKind::Infinity) =>
            Expr::NumberSymbol(NumberSymbolKind::Infinity)
          Expr::NumberSymbol(NumberSymbolKind::NegativeInfinity) =>
            Expr::NumberSymbol(NumberSymbolKind::NegativeInfinity)
          Expr::NumberSymbol(NumberSymbolKind::NaN) =>
            Expr::NumberSymbol(NumberSymbolKind::NaN)
          _ => Expr::Apply(Expr::FunctionHead("Float"), fallback_args)
        }
    }
  }
  match args {
    [Expr::Float(value)] => Expr::Float(value)
    [Expr::Tuple(items)] => float_from_tuple(items, 53, args)
    [arg] => float_from_numeric(arg, 53, args)
    [Expr::Tuple(items), Expr::Number(prec)] if prec.is_integral() &&
      prec.numerator().compare(0N) > 0 =>
      float_from_tuple(
        items,
        @symnum.dps_to_prec(prec.numerator().to_int()),
        args,
      )
    [arg, Expr::Number(prec)] if prec.is_integral() &&
      prec.numerator().compare(0N) > 0 =>
      float_from_numeric(
        arg,
        @symnum.dps_to_prec(prec.numerator().to_int()),
        args,
      )
    _ => Expr::Apply(Expr::FunctionHead("Float"), args)
  }
}

///|
let dummy_id_counter_ref : Ref[Int] = { val: 0 }

///|
fn next_dummy_id() -> Int {
  let id = dummy_id_counter_ref.val
  dummy_id_counter_ref.val = id + 1
  id
}

///|
pub fn dummy(name? : String = "Dummy") -> Expr {
  Expr::Dummy(name, next_dummy_id())
}

///|
pub fn applied_undefined_function(name : String, args : Array[Expr]) -> Expr {
  Expr::Apply(Expr::UndefinedFunction(name), args.map(normalize_legacy_expr))
}

///|
fn wild_function_accepts_arity(nargs : Array[Int], arity : Int) -> Bool {
  nargs.is_empty() || nargs.contains(arity)
}

///|
pub fn raw_apply(head : Expr, args : Array[Expr]) -> Expr? {
  let head = normalize_legacy_expr(head)
  let args = args.map(normalize_legacy_expr)
  match head {
    Expr::IdentityFunction =>
      if args.length() == 1 {
        Some(args[0])
      } else {
        None
      }
    Expr::Lambda(vars, body) => apply_lambda_expr(vars, body, args)
    Expr::UndefinedFunction(name) =>
      Some(Expr::Apply(Expr::UndefinedFunction(name), args))
    Expr::WildFunction(name, nargs) =>
      if wild_function_accepts_arity(nargs, args.length()) {
        Some(Expr::Apply(Expr::WildFunction(name, nargs), args))
      } else {
        None
      }
    Expr::FunctionHead(name) => Some(raw_function(name, args))
    _ => None
  }
}

///|
pub fn apply(head : Expr, args : Array[Expr]) -> Expr? {
  let head = normalize_legacy_expr(head)
  let args = args.map(normalize_legacy_expr)
  match head {
    Expr::IdentityFunction =>
      if args.length() == 1 {
        Some(args[0])
      } else {
        None
      }
    Expr::Lambda(vars, body) => apply_lambda_expr(vars, body, args)
    Expr::UndefinedFunction(name) =>
      Some(applied_undefined_function(name, args))
    Expr::WildFunction(name, nargs) =>
      if wild_function_accepts_arity(nargs, args.length()) {
        Some(Expr::Apply(Expr::WildFunction(name, nargs), args))
      } else {
        None
      }
    Expr::FunctionHead(name) =>
      Some(
        if current_evaluate() {
          function(name, args)
        } else {
          raw_function(name, args)
        },
      )
    _ => None
  }
}

///|
fn float_from_exact_unchecked(value : @symnum.BigRational, prec : Int) -> Float {
  Float::from_rational(value.numerator(), value.denominator(), prec) catch {
    _ => Float::from_mpf(@symnum.fnan, prec~)
  }
}

///|
fn float_with_prec(value : Float, prec : Int) -> Float {
  let p = if prec > value.precision() { prec } else { value.precision() }
  if p == value.precision() {
    value
  } else {
    Float::from_mpf(
      @symnum.mpf_pos(value.to_mpf(), p, @symnum.round_nearest),
      prec=p,
    )
  }
}

///|
fn add_float(lhs : Float, rhs : Float) -> Float {
  let p = if lhs.precision() > rhs.precision() {
    lhs.precision()
  } else {
    rhs.precision()
  }
  let left = float_with_prec(lhs, p)
  let right = float_with_prec(rhs, p)
  Float::from_mpf(
    @symnum.mpf_add(left.to_mpf(), right.to_mpf(), p, @symnum.round_nearest),
    prec=p,
  )
}

///|
fn mul_float(lhs : Float, rhs : Float) -> Float {
  let p = if lhs.precision() > rhs.precision() {
    lhs.precision()
  } else {
    rhs.precision()
  }
  let left = float_with_prec(lhs, p)
  let right = float_with_prec(rhs, p)
  Float::from_mpf(
    @symnum.mpf_mul(left.to_mpf(), right.to_mpf(), p, @symnum.round_nearest),
    prec=p,
  )
}

///|
fn add_exact_to_float(lhs : Float, rhs : @symnum.BigRational) -> Float {
  add_float(lhs, float_from_exact_unchecked(rhs, lhs.precision()))
}

///|
fn mul_exact_to_float(lhs : Float, rhs : @symnum.BigRational) -> Float {
  mul_float(lhs, float_from_exact_unchecked(rhs, lhs.precision()))
}

///|
fn split_add_term_coeff(term : Expr) -> (@symnum.BigRational, Expr)? {
  match term {
    Expr::Number(value) => Some((value, int(1)))
    Expr::Mul(items) => {
      let mut coeff = @symnum.BigRational::one()
      let rest : Array[Expr] = []
      for item in items {
        match item {
          Expr::Number(value) => coeff = coeff.mul_r(value)
          Expr::Float(_) | Expr::ComplexFloat(_) => return None
          _ => rest.push(item)
        }
      }
      let base = match rest.length() {
        0 => int(1)
        1 => rest[0]
        _ => Expr::Mul(rest)
      }
      Some((coeff, base))
    }
    Expr::Float(_) | Expr::ComplexFloat(_) => None
    _ => Some((@symnum.BigRational::one(), term))
  }
}

///|
fn complex_from_exact_unchecked(
  value : @symnum.BigRational,
  prec : Int,
) -> ComplexFloat {
  ComplexFloat::from_exact_parts(value, @symnum.BigRational::zero(), prec~)
}

///|
fn complex_from_float(value : Float) -> ComplexFloat {
  ComplexFloat::from_real(value)
}

///|
fn complex_with_prec(value : ComplexFloat, prec : Int) -> ComplexFloat {
  let p = if prec > value.precision() { prec } else { value.precision() }
  if p == value.precision() {
    value
  } else {
    ComplexFloat::from_parts(
      @symnum.mpf_pos(value.to_mpc().real, p, @symnum.round_nearest),
      @symnum.mpf_pos(value.to_mpc().imag, p, @symnum.round_nearest),
      prec=p,
    )
  }
}

///|
fn add_complex(lhs : ComplexFloat, rhs : ComplexFloat) -> ComplexFloat {
  let p = if lhs.precision() > rhs.precision() {
    lhs.precision()
  } else {
    rhs.precision()
  }
  let left = complex_with_prec(lhs, p)
  let right = complex_with_prec(rhs, p)
  ComplexFloat::from_mpc(
    @symnum.mpc_add(left.to_mpc(), right.to_mpc(), p, @symnum.round_nearest),
    prec=p,
  )
}

///|
fn mul_complex(lhs : ComplexFloat, rhs : ComplexFloat) -> ComplexFloat {
  let p = if lhs.precision() > rhs.precision() {
    lhs.precision()
  } else {
    rhs.precision()
  }
  let left = complex_with_prec(lhs, p)
  let right = complex_with_prec(rhs, p)
  ComplexFloat::from_mpc(
    @symnum.mpc_mul(left.to_mpc(), right.to_mpc(), p, @symnum.round_nearest),
    prec=p,
  )
}

///|
fn add_exact_to_complex(
  lhs : ComplexFloat,
  rhs : @symnum.BigRational,
) -> ComplexFloat {
  add_complex(lhs, complex_from_exact_unchecked(rhs, lhs.precision()))
}

///|
fn add_float_to_complex(lhs : ComplexFloat, rhs : Float) -> ComplexFloat {
  add_complex(lhs, complex_from_float(rhs))
}

///|
fn mul_exact_to_complex(
  lhs : ComplexFloat,
  rhs : @symnum.BigRational,
) -> ComplexFloat {
  mul_complex(lhs, complex_from_exact_unchecked(rhs, lhs.precision()))
}

///|
fn mul_float_to_complex(lhs : ComplexFloat, rhs : Float) -> ComplexFloat {
  mul_complex(lhs, complex_from_float(rhs))
}

///|
pub fn add(args : Array[Expr]) -> Expr {
  if !current_evaluate() {
    return raw_add(args.map(normalize_legacy_expr))
  }
  let flat : Array[Expr] = Array::new()
  let mut const_sum = @symnum.BigRational::zero()
  let mut float_sum : Float? = None
  let mut complex_sum : ComplexFloat? = None
  for arg in args {
    match arg {
      Expr::Add(inner) =>
        for child in inner {
          match child {
            Expr::Number(n) =>
              match complex_sum {
                Some(current) =>
                  complex_sum = Some(add_exact_to_complex(current, n))
                None =>
                  match float_sum {
                    Some(current) =>
                      float_sum = Some(add_exact_to_float(current, n))
                    None => const_sum = const_sum.add_r(n)
                  }
              }
            Expr::Float(f) =>
              match complex_sum {
                Some(current) =>
                  complex_sum = Some(add_float_to_complex(current, f))
                None =>
                  match float_sum {
                    Some(current) => float_sum = Some(add_float(current, f))
                    None => {
                      let seeded = if const_sum.is_zero() {
                        f
                      } else {
                        add_exact_to_float(f, const_sum)
                      }
                      const_sum = @symnum.BigRational::zero()
                      float_sum = Some(seeded)
                    }
                  }
              }
            Expr::ComplexFloat(z) =>
              match complex_sum {
                Some(current) => complex_sum = Some(add_complex(current, z))
                None => {
                  let seeded = match float_sum {
                    Some(current) => add_float_to_complex(z, current)
                    None =>
                      if const_sum.is_zero() {
                        z
                      } else {
                        add_exact_to_complex(z, const_sum)
                      }
                  }
                  const_sum = @symnum.BigRational::zero()
                  float_sum = None
                  complex_sum = Some(seeded)
                }
              }
            _ => flat.push(child)
          }
        }
      Expr::Number(n) =>
        match complex_sum {
          Some(current) => complex_sum = Some(add_exact_to_complex(current, n))
          None =>
            match float_sum {
              Some(current) => float_sum = Some(add_exact_to_float(current, n))
              None => const_sum = const_sum.add_r(n)
            }
        }
      Expr::Float(f) =>
        match complex_sum {
          Some(current) => complex_sum = Some(add_float_to_complex(current, f))
          None =>
            match float_sum {
              Some(current) => float_sum = Some(add_float(current, f))
              None => {
                let seeded = if const_sum.is_zero() {
                  f
                } else {
                  add_exact_to_float(f, const_sum)
                }
                const_sum = @symnum.BigRational::zero()
                float_sum = Some(seeded)
              }
            }
        }
      Expr::ComplexFloat(z) =>
        match complex_sum {
          Some(current) => complex_sum = Some(add_complex(current, z))
          None => {
            let seeded = match float_sum {
              Some(current) => add_float_to_complex(z, current)
              None =>
                if const_sum.is_zero() {
                  z
                } else {
                  add_exact_to_complex(z, const_sum)
                }
            }
            const_sum = @symnum.BigRational::zero()
            float_sum = None
            complex_sum = Some(seeded)
          }
        }
      _ => flat.push(arg)
    }
  }
  let bases : Array[Expr] = []
  let coeffs : Array[@symnum.BigRational] = []
  let base_index : Map[Expr, Int] = {}
  let passthrough : Array[Expr] = []
  for term in flat {
    match split_add_term_coeff(term) {
      Some((coeff, base)) => {
        match base_index.get(base) {
          Some(index) => coeffs[index] = coeffs[index].add_r(coeff)
          None => {
            let index = bases.length()
            bases.push(base)
            coeffs.push(coeff)
            base_index[base] = index
          }
        }
      }
      None => passthrough.push(term)
    }
  }
  flat.clear()
  for i in 0..<bases.length() {
    let coeff = coeffs[i]
    if coeff.is_zero() {
      continue
    }
    let base = bases[i]
    if expr_is_one(base) {
      flat.push(Expr::Number(coeff))
    } else if coeff.is_one() {
      flat.push(base)
    } else {
      flat.push(mul([Expr::Number(coeff), base]))
    }
  }
  for term in passthrough {
    flat.push(term)
  }
  match complex_sum {
    Some(value) =>
      if !(@symnum.is_zero(value.to_mpc().real) &&
        @symnum.is_zero(value.to_mpc().imag)) {
        flat.push(Expr::ComplexFloat(value))
      }
    None =>
      match float_sum {
        Some(value) =>
          if !@symnum.is_zero(value.to_mpf()) {
            flat.push(Expr::Float(value))
          }
        None => if !const_sum.is_zero() { flat.push(Expr::Number(const_sum)) }
      }
  }
  sort_exprs_in_place(flat)
  match flat.length() {
    0 =>
      match complex_sum {
        Some(value) => Expr::ComplexFloat(value)
        None =>
          match float_sum {
            Some(value) => Expr::Float(value)
            None => Expr::Number(@symnum.BigRational::zero())
          }
      }
    1 => flat[0]
    _ => Expr::Add(flat)
  }
}

///|
fn expr_is_zero(expr : Expr) -> Bool {
  match expr {
    Expr::Number(n) => n.is_zero()
    Expr::Float(f) => @symnum.is_zero(f.to_mpf())
    Expr::ComplexFloat(z) =>
      @symnum.is_zero(z.to_mpc().real) && @symnum.is_zero(z.to_mpc().imag)
    _ => false
  }
}

///|
fn expr_is_one(expr : Expr) -> Bool {
  match expr {
    Expr::Number(n) => n.is_one()
    Expr::Float(f) => @symnum.mpf_eq(f.to_mpf(), @symnum.fone)
    Expr::ComplexFloat(z) =>
      @symnum.mpf_eq(z.to_mpc().real, @symnum.fone) &&
      @symnum.is_zero(z.to_mpc().imag)
    _ => false
  }
}

///|
pub fn mul(args : Array[Expr]) -> Expr {
  if !current_evaluate() {
    return raw_mul(args.map(normalize_legacy_expr))
  }
  let flat : Array[Expr] = Array::new()
  let mut const_prod = @symnum.BigRational::one()
  let mut float_prod : Float? = None
  let mut complex_prod : ComplexFloat? = None
  for arg in args {
    match arg {
      Expr::Mul(inner) =>
        for child in inner {
          match child {
            Expr::Number(n) =>
              match complex_prod {
                Some(current) =>
                  if n.is_zero() {
                    return Expr::ComplexFloat(
                      complex_from_exact_unchecked(n, current.precision()),
                    )
                  } else {
                    complex_prod = Some(mul_exact_to_complex(current, n))
                  }
                None =>
                  match float_prod {
                    Some(current) =>
                      if n.is_zero() {
                        return Expr::Number(@symnum.BigRational::zero())
                      } else {
                        float_prod = Some(mul_exact_to_float(current, n))
                      }
                    None => {
                      if n.is_zero() {
                        return Expr::Number(@symnum.BigRational::zero())
                      }
                      const_prod = const_prod.mul_r(n)
                    }
                  }
              }
            Expr::Float(f) =>
              if @symnum.is_zero(f.to_mpf()) {
                return Expr::Float(f)
              } else {
                match complex_prod {
                  Some(current) =>
                    complex_prod = Some(mul_float_to_complex(current, f))
                  None =>
                    match float_prod {
                      Some(current) => float_prod = Some(mul_float(current, f))
                      None => {
                        let seeded = if const_prod.is_one() {
                          f
                        } else {
                          mul_exact_to_float(f, const_prod)
                        }
                        const_prod = @symnum.BigRational::one()
                        float_prod = Some(seeded)
                      }
                    }
                }
              }
            Expr::ComplexFloat(z) =>
              if expr_is_zero(Expr::ComplexFloat(z)) {
                return Expr::ComplexFloat(z)
              } else {
                match complex_prod {
                  Some(current) => complex_prod = Some(mul_complex(current, z))
                  None => {
                    let seeded = match float_prod {
                      Some(current) => mul_float_to_complex(z, current)
                      None =>
                        if const_prod.is_one() {
                          z
                        } else {
                          mul_exact_to_complex(z, const_prod)
                        }
                    }
                    const_prod = @symnum.BigRational::one()
                    float_prod = None
                    complex_prod = Some(seeded)
                  }
                }
              }
            Expr::NumberSymbol(NumberSymbolKind::Infinity)
            | Expr::NumberSymbol(NumberSymbolKind::NegativeInfinity)
            | Expr::NumberSymbol(NumberSymbolKind::ComplexInfinity)
            | Expr::NumberSymbol(NumberSymbolKind::NaN) => flat.push(child)
            _ => flat.push(child)
          }
        }
      Expr::Number(n) =>
        match complex_prod {
          Some(current) =>
            if n.is_zero() {
              return Expr::ComplexFloat(
                complex_from_exact_unchecked(n, current.precision()),
              )
            } else {
              complex_prod = Some(mul_exact_to_complex(current, n))
            }
          None =>
            match float_prod {
              Some(current) =>
                if n.is_zero() {
                  return Expr::Number(@symnum.BigRational::zero())
                } else {
                  float_prod = Some(mul_exact_to_float(current, n))
                }
              None => {
                if n.is_zero() {
                  return Expr::Number(@symnum.BigRational::zero())
                }
                const_prod = const_prod.mul_r(n)
              }
            }
        }
      Expr::Float(f) =>
        if @symnum.is_zero(f.to_mpf()) {
          return Expr::Float(f)
        } else {
          match complex_prod {
            Some(current) =>
              complex_prod = Some(mul_float_to_complex(current, f))
            None =>
              match float_prod {
                Some(current) => float_prod = Some(mul_float(current, f))
                None => {
                  let seeded = if const_prod.is_one() {
                    f
                  } else {
                    mul_exact_to_float(f, const_prod)
                  }
                  const_prod = @symnum.BigRational::one()
                  float_prod = Some(seeded)
                }
              }
          }
        }
      Expr::ComplexFloat(z) =>
        if expr_is_zero(Expr::ComplexFloat(z)) {
          return Expr::ComplexFloat(z)
        } else {
          match complex_prod {
            Some(current) => complex_prod = Some(mul_complex(current, z))
            None => {
              let seeded = match float_prod {
                Some(current) => mul_float_to_complex(z, current)
                None =>
                  if const_prod.is_one() {
                    z
                  } else {
                    mul_exact_to_complex(z, const_prod)
                  }
              }
              const_prod = @symnum.BigRational::one()
              float_prod = None
              complex_prod = Some(seeded)
            }
          }
        }
      Expr::NumberSymbol(NumberSymbolKind::Infinity)
      | Expr::NumberSymbol(NumberSymbolKind::NegativeInfinity)
      | Expr::NumberSymbol(NumberSymbolKind::ComplexInfinity)
      | Expr::NumberSymbol(NumberSymbolKind::NaN) => flat.push(arg)
      _ => flat.push(arg)
    }
  }
  sort_exprs_in_place(flat)
  let merged : Array[Expr] = Array::new()
  let mut idx = 0
  while idx < flat.length() {
    let factor = flat[idx]
    let mut count = 1
    while idx + count < flat.length() &&
          compare_expr(flat[idx + count], factor) == 0 {
      count += 1
    }
    if count == 1 {
      merged.push(factor)
    } else {
      merged.push(pow(factor, int(count)))
    }
    idx += count
  }
  if const_prod == @symnum.BigRational::from_int(-1) && merged.length() == 1 {
    match merged[0] {
      Expr::NumberSymbol(NumberSymbolKind::Infinity) =>
        return Expr::NumberSymbol(NumberSymbolKind::NegativeInfinity)
      Expr::NumberSymbol(NumberSymbolKind::NegativeInfinity) =>
        return Expr::NumberSymbol(NumberSymbolKind::Infinity)
      _ => ()
    }
  }
  if current_distribute() && complex_prod is None && merged.length() == 1 {
    match merged[0] {
      Expr::Add(add_args) =>
        match float_prod {
          Some(value) =>
            if value.is_finite() && !expr_is_one(Expr::Float(value)) {
              return add(add_args.map(term => mul([Expr::Float(value), term])))
            }
          None =>
            if !const_prod.is_one() {
              return add(
                add_args.map(term => mul([Expr::Number(const_prod), term])),
              )
            }
        }
      _ => ()
    }
  }
  match complex_prod {
    Some(value) =>
      if merged.is_empty() {
        Expr::ComplexFloat(value)
      } else if expr_is_one(Expr::ComplexFloat(value)) {
        match merged.length() {
          1 => merged[0]
          _ => Expr::Mul(merged)
        }
      } else {
        let out : Array[Expr] = Array::new()
        out.push(Expr::ComplexFloat(value))
        for v in merged {
          out.push(v)
        }
        match out.length() {
          1 => out[0]
          _ => Expr::Mul(out)
        }
      }
    None =>
      match float_prod {
        Some(value) =>
          if merged.is_empty() {
            Expr::Float(value)
          } else if expr_is_one(Expr::Float(value)) {
            match merged.length() {
              1 => merged[0]
              _ => Expr::Mul(merged)
            }
          } else {
            let out : Array[Expr] = Array::new()
            out.push(Expr::Float(value))
            for v in merged {
              out.push(v)
            }
            match out.length() {
              1 => out[0]
              _ => Expr::Mul(out)
            }
          }
        None =>
          if merged.is_empty() {
            if const_prod.is_one() {
              Expr::Number(@symnum.BigRational::one())
            } else {
              Expr::Number(const_prod)
            }
          } else if const_prod.is_one() {
            match merged.length() {
              1 => merged[0]
              _ => Expr::Mul(merged)
            }
          } else {
            let out : Array[Expr] = Array::new()
            out.push(Expr::Number(const_prod))
            for v in merged {
              out.push(v)
            }
            match out.length() {
              1 => out[0]
              _ => Expr::Mul(out)
            }
          }
      }
  }
}

///|
fn is_zero_base_expr(expr : Expr) -> Bool {
  match expr {
    Expr::Number(n) => n.is_zero()
    Expr::Float(f) => @symnum.is_zero(f.to_mpf())
    Expr::ComplexFloat(z) =>
      @symnum.is_zero(z.to_mpc().real) && @symnum.is_zero(z.to_mpc().imag)
    _ => false
  }
}

///|
fn imag_unit_pow(exp : Expr) -> Expr? {
  match exact_numeric_expr_num_den(exp) {
    Some((num, den)) if den == 1N && num.bit_length() <= 30 => {
      let raw = num.to_int()
      let rem = (raw % 4 + 4) % 4
      let imag = Expr::NumberSymbol(NumberSymbolKind::ImaginaryUnit)
      Some(
        match rem {
          0 => Expr::Number(@symnum.BigRational::one())
          1 => imag
          2 => Expr::Number(@symnum.BigRational::from_int(-1))
          _ => mul([Expr::Number(@symnum.BigRational::from_int(-1)), imag])
        },
      )
    }
    _ => None
  }
}

///|
fn sqrt_bigint_if_square(value : BigInt) -> BigInt? {
  if value.op_lt(0N) {
    return None
  }
  let root = @symnum.isqrt(value) catch { _ => return None }
  if root.mul(root).compare(value) == 0 {
    Some(root)
  } else {
    None
  }
}

///|
fn exact_sqrt_expr(arg : Expr) -> Expr? {
  match arg {
    Expr::Number(n) => {
      let negative = n.compare(@symnum.BigRational::zero()) < 0
      let abs_n = if negative { n.neg_r() } else { n }
      let num_root = match sqrt_bigint_if_square(abs_n.numerator()) {
        Some(root) => root
        None =>
          if negative {
            let imag = Expr::NumberSymbol(NumberSymbolKind::ImaginaryUnit)
            return Some(mul([imag, function("sqrt", [Expr::Number(abs_n)])]))
          } else {
            return None
          }
      }
      let den_root = match sqrt_bigint_if_square(abs_n.denominator()) {
        Some(root) => root
        None =>
          if negative {
            let imag = Expr::NumberSymbol(NumberSymbolKind::ImaginaryUnit)
            return Some(mul([imag, function("sqrt", [Expr::Number(abs_n)])]))
          } else {
            return None
          }
      }
      let rat = @symnum.BigRational::new(num_root, den_root) catch {
        _ => return None
      }
      let root_expr = Expr::Number(rat)
      if negative {
        let imag = Expr::NumberSymbol(NumberSymbolKind::ImaginaryUnit)
        Some(mul([root_expr, imag]))
      } else {
        Some(root_expr)
      }
    }
    _ => None
  }
}

///|
fn exact_numeric_half_power(base : Expr, exp : Expr) -> Expr? {
  match exact_numeric_expr_num_den(exp) {
    Some((num, den)) if num == 1N && den == 2N => exact_sqrt_expr(base)
    _ => None
  }
}

///|
fn zero_base_pow_value(base : Expr, exp : Expr) -> Expr? {
  match exact_numeric_expr_num_den(exp) {
    Some((num, den)) if den.compare(1N) == 0 && num.compare(0N) > 0 =>
      Some(
        match base {
          Expr::ComplexFloat(z) => Expr::ComplexFloat(z)
          Expr::Float(f) => Expr::Float(f)
          _ => Expr::Number(@symnum.BigRational::zero())
        },
      )
    _ => None
  }
}

///|
pub fn pow(base : Expr, exp : Expr) -> Expr {
  let base = normalize_legacy_expr(base)
  let exp = normalize_legacy_expr(exp)
  if !current_evaluate() {
    return raw_pow(base, exp)
  }
  if expr_is_zero(exp) {
    Expr::Number(@symnum.BigRational::one())
  } else if expr_is_one(base) {
    base
  } else if expr_is_one(exp) {
    base
  } else if exact_numeric_half_power(base, exp) is Some(value) {
    value
  } else {
    match base {
      Expr::NumberSymbol(NumberSymbolKind::ImaginaryUnit) =>
        match imag_unit_pow(exp) {
          Some(value) => value
          None => Expr::Pow(base, exp)
        }
      Expr::Pow(inner_base, inner_exp) =>
        match exact_numeric_expr_num_den(exp) {
          Some((_, den)) if den.compare(1N) == 0 =>
            pow(inner_base, mul([inner_exp, exp]))
          _ =>
            match base {
              _ if is_zero_base_expr(base) =>
                match zero_base_pow_value(base, exp) {
                  Some(value) => value
                  None => Expr::Pow(base, exp)
                }
              _ => Expr::Pow(base, exp)
            }
        }
      _ if is_zero_base_expr(base) =>
        match zero_base_pow_value(base, exp) {
          Some(value) => value
          None => Expr::Pow(base, exp)
        }
      _ => Expr::Pow(base, exp)
    }
  }
}

///|
pub fn mod_expr(lhs : Expr, rhs : Expr) -> Expr {
  Expr::Mod(lhs, rhs)
}

///|
fn constructor_relational(op : RelOp, lhs : Expr, rhs : Expr) -> Expr {
  match op {
    RelOp::Eq =>
      if lhs == rhs {
        Expr::Boolean(true)
      } else {
        Expr::Relational(op, lhs, rhs)
      }
    RelOp::Ne =>
      if lhs == rhs {
        Expr::Boolean(false)
      } else {
        Expr::Relational(op, lhs, rhs)
      }
    RelOp::Lt =>
      match (lhs, rhs) {
        (Expr::Number(lhs_num), Expr::Number(rhs_num)) =>
          Expr::Boolean(lhs_num.compare(rhs_num) < 0)
        _ => Expr::Relational(op, lhs, rhs)
      }
    RelOp::Le =>
      match (lhs, rhs) {
        (Expr::Number(lhs_num), Expr::Number(rhs_num)) =>
          Expr::Boolean(lhs_num.compare(rhs_num) <= 0)
        _ => Expr::Relational(op, lhs, rhs)
      }
    RelOp::Gt =>
      match (lhs, rhs) {
        (Expr::Number(lhs_num), Expr::Number(rhs_num)) =>
          Expr::Boolean(lhs_num.compare(rhs_num) > 0)
        _ => Expr::Relational(op, lhs, rhs)
      }
    RelOp::Ge =>
      match (lhs, rhs) {
        (Expr::Number(lhs_num), Expr::Number(rhs_num)) =>
          Expr::Boolean(lhs_num.compare(rhs_num) >= 0)
        _ => Expr::Relational(op, lhs, rhs)
      }
  }
}

///|
fn constructor_derivative(name : String, args : Array[Expr]) -> Expr {
  if args.length() < 2 {
    return Expr::Apply(Expr::FunctionHead(name), args)
  }
  derivative_constructor_expr(args[0], args[1:])
}

///|
fn constructor_singleton_registry(name : String, args : Array[Expr]) -> Expr {
  match args.length() {
    0 => Expr::Apply(Expr::FunctionHead(name), args)
    given if given <= 6 => normalize_legacy_expr(args[0])
    _ => Expr::Apply(Expr::FunctionHead(name), args)
  }
}

///|
pub fn function(name : String, args : Array[Expr]) -> Expr {
  if !current_evaluate() {
    return raw_function(name, args)
  }
  let args = args.map(normalize_legacy_expr)
  match (name, args) {
    ("True", []) => Expr::Boolean(true)
    ("False", []) => Expr::Boolean(false)
    ("Tuple", _) => Expr::Tuple(args)
    ("S", _) => constructor_singleton_registry(name, args)
    ("Integer", _) => constructor_integer(args)
    ("Rational", _) => constructor_rational(args)
    ("Float", _) => constructor_float(args)
    ("sqrt", [arg]) =>
      match exact_sqrt_expr(arg) {
        Some(value) => value
        None => Expr::Apply(Expr::FunctionHead(name), args)
      }
    ("Eq", [lhs, rhs]) => constructor_relational(RelOp::Eq, lhs, rhs)
    ("Ne", [lhs, rhs]) => constructor_relational(RelOp::Ne, lhs, rhs)
    ("Lt", [lhs, rhs]) => constructor_relational(RelOp::Lt, lhs, rhs)
    ("Le", [lhs, rhs]) => constructor_relational(RelOp::Le, lhs, rhs)
    ("Gt", [lhs, rhs]) => constructor_relational(RelOp::Gt, lhs, rhs)
    ("Ge", [lhs, rhs]) => constructor_relational(RelOp::Ge, lhs, rhs)
    ("Mod", [lhs, rhs]) => mod_expr(lhs, rhs)
    ("Derivative", _) => constructor_derivative(name, args)
    ("Subs", [expr, variable, value]) => subs_expr(expr, variable, value)
    ("Lambda", [vars, body]) => lambda_expr(vars, body)
    ("exp", [arg]) if current_exp_is_pow() =>
      pow(Expr::NumberSymbol(NumberSymbolKind::Exp1), arg)
    ("Dict", items) => {
      let entries : Array[(Expr, Expr)] = []
      for item in items {
        match tuple_items(item) {
          Some([key, value]) => entries.push((key, value))
          _ => return Expr::Apply(Expr::FunctionHead(name), args)
        }
      }
      Expr::Dict(entries)
    }
    _ => Expr::Apply(Expr::FunctionHead(name), args)
  }
}

///|
/// Build `Add` directly without flattening, sorting, or constant folding.
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
pub fn raw_mod_expr(lhs : Expr, rhs : Expr) -> Expr {
  Expr::Mod(lhs, rhs)
}

///|
pub fn raw_dict_expr(items : Array[(Expr, Expr)]) -> Expr {
  Expr::Dict(items.map(item => item))
}

///|
pub fn raw_function(name : String, args : Array[Expr]) -> Expr {
  let args = args.map(normalize_legacy_expr)
  match (name, args) {
    ("True", []) => Expr::Boolean(true)
    ("False", []) => Expr::Boolean(false)
    ("Tuple", _) => Expr::Tuple(args)
    ("S", _) => constructor_singleton_registry(name, args)
    ("Integer", _) => constructor_integer(args)
    ("Rational", _) => constructor_rational(args)
    ("Float", _) => constructor_float(args)
    ("Eq", [lhs, rhs]) => Expr::Relational(RelOp::Eq, lhs, rhs)
    ("Ne", [lhs, rhs]) => Expr::Relational(RelOp::Ne, lhs, rhs)
    ("Lt", [lhs, rhs]) => Expr::Relational(RelOp::Lt, lhs, rhs)
    ("Le", [lhs, rhs]) => Expr::Relational(RelOp::Le, lhs, rhs)
    ("Gt", [lhs, rhs]) => Expr::Relational(RelOp::Gt, lhs, rhs)
    ("Ge", [lhs, rhs]) => Expr::Relational(RelOp::Ge, lhs, rhs)
    ("Mod", [lhs, rhs]) => Expr::Mod(lhs, rhs)
    ("Derivative", _) => constructor_derivative(name, args)
    ("Subs", [expr, variable, value]) => subs_expr(expr, variable, value)
    ("Lambda", [vars, body]) => lambda_expr(vars, body)
    ("Dict", items) => {
      let entries : Array[(Expr, Expr)] = []
      for item in items {
        match tuple_items(item) {
          Some([key, value]) => entries.push((key, value))
          _ => return Expr::Apply(Expr::FunctionHead(name), args)
        }
      }
      Expr::Dict(entries)
    }
    _ => Expr::Apply(Expr::FunctionHead(name), args)
  }
}

///|
pub fn arbitrary_polys() -> @qc.Gen[Expr] {
  let available_symbols = ["x", "y", "z", "w", "a", "b", "c"]
  let var_gen = @qc.one_of_array(available_symbols).fmap(x => Expr::Symbol(x))
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
  let x = Expr::Symbol("x")
  let y = Expr::Symbol("y")
  let expr = x + (y ^ int(10))
  inspect(expr, content="(x + (y ** 10))")
}
