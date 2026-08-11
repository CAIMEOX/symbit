///|
/// Core symbolic expression tree used across Symbit.
///
/// Current Limits:
/// - `symcore` defines structure and canonical construction, not the full
///   mathematical behavior of every subsystem.
/// - textual mathematics should go through `symparse` rather than raw head
///   construction.
/// - several higher-level object families are easier to use through their own
///   package front doors.
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
impl Show for Expr with fn to_string(self) {
  match self {
    Number(n) => Show::to_string(n)
    Float(f) => Show::to_string(f)
    ComplexFloat(z) => Show::to_string(z)
    NumberSymbol(kind) => number_symbol_name(kind)
    Boolean(true) => "True"
    Boolean(false) => "False"
    IdentityFunction => "Lambda(_x, _x)"
    Symbol(s) => s
    Dummy(name, _) => dummy_display_name(name)
    Wild(name, _, _) => wild_display_name(name)
    WildFunction(name, _) => wild_display_name(name)
    FunctionHead(name) => standalone_function_head_display_name(name)
    UndefinedFunction(name) => name
    Apply(head, args) =>
      Show::to_string(head) +
      "(" +
      args.map(child => Show::to_string(child)).join(", ") +
      ")"
    Add(args) =>
      "(" + args.map(child => Show::to_string(child)).join(" + ") + ")"
    Mul(args) =>
      "(" + args.map(child => Show::to_string(child)).join(" * ") + ")"
    Pow(base, exp) =>
      "(" + Show::to_string(base) + " ** " + Show::to_string(exp) + ")"
    Mod(lhs, rhs) =>
      "Mod(" + Show::to_string(lhs) + ", " + Show::to_string(rhs) + ")"
    Tuple(args) =>
      "Tuple(" + args.map(child => Show::to_string(child)).join(", ") + ")"
    Dict(items) => {
      let rendered : Array[String] = []
      for item in sorted_dict_entries(items) {
        let (key, value) = item
        rendered.push(Show::to_string(key) + ": " + Show::to_string(value))
      }
      "{" + rendered.join(", ") + "}"
    }
    Relational(op, lhs, rhs) => {
      let name = match op {
        Eq => "Eq"
        Ne => "Ne"
        Lt => "Lt"
        Le => "Le"
        Gt => "Gt"
        Ge => "Ge"
      }
      name + "(" + Show::to_string(lhs) + ", " + Show::to_string(rhs) + ")"
    }
    Derivative(inner, deriv_args) => {
      let deriv_args = canonical_derivative_args(deriv_args)
      let args : Array[String] = [Show::to_string(inner)]
      let pair_count = deriv_args.length() / 2
      for i in 0..<pair_count {
        let wrt = deriv_args[i * 2]
        let order = deriv_args[i * 2 + 1]
        match order {
          Number(n) if n == @symnum.BigRational::one() =>
            args.push(Show::to_string(wrt))
          _ => args.push(Show::to_string(Expr::Tuple([wrt, order])))
        }
      }
      "Derivative(" + args.join(", ") + ")"
    }
    Subs(inner, variable, value) =>
      "Subs(" +
      Show::to_string(inner) +
      ", " +
      Show::to_string(variable) +
      ", " +
      Show::to_string(value) +
      ")"
    Lambda(vars, body) =>
      "Lambda(" + Show::to_string(vars) + ", " + Show::to_string(body) + ")"
    Function(name, args) =>
      Show::to_string(normalize_legacy_function(name, args))
  }
}

///|
/// Keep the `Expr::to_string` dot-style API explicit now that trait
/// implementations are no longer promoted to methods implicitly.
#deprecated
pub extend Expr with Show::{to_string}

///|
pub impl Add for Expr with fn add(self, other) {
  add([self, other])
}

///|
pub impl Mul for Expr with fn mul(self, other) {
  mul([self, other])
}

///|
pub impl Sub for Expr with fn sub(self, other) {
  add([self, mul([int(-1), other])])
}

///|
impl Show for Expr with fn output(self, logger) {
  logger.write_string(Show::to_string(self))
}

///|
pub impl BitXOr for Expr with fn lxor(self, other) {
  pow(self, other)
}

///|
/// Build an exact integer atom.
///
/// - Does: Creates a number expression representing an exact integer.
/// - Input: A MoonBit `Int`.
/// - Returns: `Expr::Number`.
/// - Limits: This front door accepts machine-sized `Int` input only.
///
/// ```mbt check
/// test "symcore int builds an exact integer expression" {
///   inspect(@symprint.pretty_string(int(3)), content="3")
/// }
/// ```
pub fn int(value : Int) -> Expr {
  Number(@symnum.BigRational::from_int(value))
}

///|
/// Build an exact rational atom from a numerator and denominator.
///
/// - Does: Creates a rational expression with exact arithmetic.
/// - Input: Two MoonBit `Int` values.
/// - Returns: `Expr::Number`.
/// - Limits: Raises `@symnum.RationalError` when the denominator is zero.
pub fn rational_from_ints(
  num : Int,
  den : Int,
) -> Expr raise @symnum.RationalError {
  Number(@symnum.BigRational::from_ints(num, den))
}

///|
fn atomic_numeric_expr_to_exact_rational(expr : Expr) -> @symnum.BigRational? {
  match normalize_legacy_expr(expr) {
    Number(value) => Some(value)
    Float(value) => {
      let (num, den) = value.to_rational() catch { _ => return None }
      Some(@symnum.BigRational::new(num, den) catch { _ => return None })
    }
    Boolean(true) => Some(@symnum.BigRational::one())
    Boolean(false) => Some(@symnum.BigRational::zero())
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
    base_value = base.reciprocal() catch { _ => return None }
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
    Add(args) => {
      let mut acc = @symnum.BigRational::zero()
      for arg in args {
        match exact_numeric_expr_to_rational(arg) {
          Some(value) => acc = acc.add_r(value)
          None => return None
        }
      }
      Some(acc)
    }
    Mul(args) => {
      let mut acc = @symnum.BigRational::one()
      for arg in args {
        match exact_numeric_expr_to_rational(arg) {
          Some(value) => acc = acc.mul_r(value)
          None => return None
        }
      }
      Some(acc)
    }
    Pow(base, exp) =>
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
  Number(@symnum.BigRational::from_bigint(truncated))
}

///|
fn constructor_integer_value(arg : Expr) -> Expr {
  match exact_numeric_expr_to_rational(arg) {
    Some(value) => trunc_exact_rational(value)
    None =>
      match evalf(normalize_legacy_expr(arg)) {
        Float(value) => {
          let (num, den) = value.to_rational() catch {
            _ => return Apply(FunctionHead("Integer"), [arg])
          }
          trunc_exact_rational(
            @symnum.BigRational::new(num, den) catch {
              _ => return Apply(FunctionHead("Integer"), [arg])
            },
          )
        }
        Number(value) => trunc_exact_rational(value)
        _ => Apply(FunctionHead("Integer"), [arg])
      }
  }
}

///|
fn constructor_integer(args : Array[Expr]) -> Expr {
  match args {
    [arg] => constructor_integer_value(arg)
    _ => Apply(FunctionHead("Integer"), args)
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
        Some(value) => Number(value)
        None => Apply(FunctionHead("Rational"), args)
      }
    [lhs, rhs] =>
      match (exact_rational_input(lhs), exact_rational_input(rhs)) {
        (Some(lhs_value), Some(rhs_value)) =>
          if rhs_value.is_zero() {
            if lhs_value.is_zero() {
              NumberSymbol(NaN)
            } else {
              NumberSymbol(ComplexInfinity)
            }
          } else {
            Number(
              lhs_value.div_r(rhs_value) catch {
                _ => return Apply(FunctionHead("Rational"), args)
              },
            )
          }
        _ => Apply(FunctionHead("Rational"), args)
      }
    _ => Apply(FunctionHead("Rational"), args)
  }
}

///|
fn constructor_float(args : Array[Expr]) -> Expr {
  let exact_integer_atom = fn(arg : Expr) -> BigInt? {
    match normalize_legacy_expr(arg) {
      Number(value) if value.is_integral() => Some(value.numerator())
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
      NumberSymbol(NaN)
    } else if value == @symnum.finf {
      NumberSymbol(Infinity)
    } else if value == @symnum.fninf {
      NumberSymbol(NegativeInfinity)
    } else if @symnum.is_zero(value) {
      int(0)
    } else {
      Float(Float::from_mpf(value, prec~))
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
        None => return Apply(FunctionHead("Float"), fallback_args)
      }
    }
    match ints {
      [sign, man, exp] => {
        let sign_i = match small_int(sign) {
          Some(value) => value
          None => return Apply(FunctionHead("Float"), fallback_args)
        }
        let exp_i = match small_int(exp) {
          Some(value) => value
          None => return Apply(FunctionHead("Float"), fallback_args)
        }
        guard (sign_i == 0 || sign_i == 1) && man.compare(0N) >= 0 else {
          return Apply(FunctionHead("Float"), fallback_args)
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
          None => return Apply(FunctionHead("Float"), fallback_args)
        }
        let exp_i = match small_int(exp) {
          Some(value) => value
          None => return Apply(FunctionHead("Float"), fallback_args)
        }
        let bc_i = match small_int(bc) {
          Some(value) => value
          None => return Apply(FunctionHead("Float"), fallback_args)
        }
        if man.compare(0N) == 0 {
          match bc_i {
            -1 => return NumberSymbol(NaN)
            -2 | -3 =>
              return NumberSymbol(
                if sign_i == 1 {
                  NegativeInfinity
                } else {
                  Infinity
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
      _ => Apply(FunctionHead("Float"), fallback_args)
    }
  }
  let float_from_numeric = fn(
    arg : Expr,
    prec : Int,
    fallback_args : Array[Expr],
  ) -> Expr {
    match exact_numeric_expr_to_rational(arg) {
      Some(value) =>
        Float(
          Float::from_exact(value, prec~) catch {
            _ => return Apply(FunctionHead("Float"), fallback_args)
          },
        )
      None =>
        match evalf(normalize_legacy_expr(arg), prec~) {
          Float(value) => Float(value)
          NumberSymbol(Infinity) => NumberSymbol(Infinity)
          NumberSymbol(NegativeInfinity) => NumberSymbol(NegativeInfinity)
          NumberSymbol(NaN) => NumberSymbol(NaN)
          _ => Apply(FunctionHead("Float"), fallback_args)
        }
    }
  }
  match args {
    [Float(value)] => Float(value)
    [Tuple(items)] => float_from_tuple(items, 53, args)
    [arg] => float_from_numeric(arg, 53, args)
    [Tuple(items), Number(prec)] if prec.is_integral() &&
      prec.numerator().compare(0N) > 0 =>
      float_from_tuple(
        items,
        @symnum.dps_to_prec(prec.numerator().to_int()),
        args,
      )
    [arg, Number(prec)] if prec.is_integral() &&
      prec.numerator().compare(0N) > 0 =>
      float_from_numeric(
        arg,
        @symnum.dps_to_prec(prec.numerator().to_int()),
        args,
      )
    _ => Apply(FunctionHead("Float"), args)
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
  Dummy(name, next_dummy_id())
}

///|
pub fn applied_undefined_function(name : String, args : Array[Expr]) -> Expr {
  applied_undefined_function_canonical(name, args.map(normalize_legacy_expr))
}

///|
fn wild_function_accepts_arity(nargs : Array[Int], arity : Int) -> Bool {
  nargs.is_empty() || nargs.contains(arity)
}

///|
fn applied_undefined_function_canonical(
  name : String,
  args : Array[Expr],
) -> Expr {
  Apply(UndefinedFunction(name), args)
}

///|
fn raw_apply_canonical(head : Expr, args : Array[Expr]) -> Expr? {
  match head {
    IdentityFunction => if args.length() == 1 { Some(args[0]) } else { None }
    Lambda(vars, body) => apply_lambda_expr(vars, body, args)
    UndefinedFunction(name) =>
      Some(applied_undefined_function_canonical(name, args))
    WildFunction(name, nargs) =>
      if wild_function_accepts_arity(nargs, args.length()) {
        Some(Apply(WildFunction(name, nargs), args))
      } else {
        None
      }
    FunctionHead(name) => Some(raw_function_canonical(name, args))
    _ => None
  }
}

///|
pub fn raw_apply(head : Expr, args : Array[Expr]) -> Expr? {
  let head = normalize_legacy_expr(head)
  let args = args.map(normalize_legacy_expr)
  raw_apply_canonical(head, args)
}

///|
fn apply_canonical(head : Expr, args : Array[Expr]) -> Expr? {
  match head {
    IdentityFunction => if args.length() == 1 { Some(args[0]) } else { None }
    Lambda(vars, body) => apply_lambda_expr(vars, body, args)
    UndefinedFunction(name) =>
      Some(applied_undefined_function_canonical(name, args))
    WildFunction(name, nargs) =>
      if wild_function_accepts_arity(nargs, args.length()) {
        Some(Apply(WildFunction(name, nargs), args))
      } else {
        None
      }
    FunctionHead(name) =>
      Some(
        if current_evaluate() {
          function_canonical(name, args)
        } else {
          raw_function_canonical(name, args)
        },
      )
    _ => None
  }
}

///|
pub fn apply(head : Expr, args : Array[Expr]) -> Expr? {
  let head = normalize_legacy_expr(head)
  let args = args.map(normalize_legacy_expr)
  apply_canonical(head, args)
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
    Number(value) => Some((value, int(1)))
    Mul(items) => {
      let mut coeff = @symnum.BigRational::one()
      let rest : Array[Expr] = []
      for item in items {
        match item {
          Number(value) => coeff = coeff.mul_r(value)
          Float(_) | ComplexFloat(_) => return None
          _ => rest.push(item)
        }
      }
      let base = match rest.length() {
        0 => int(1)
        1 => rest[0]
        _ => Mul(rest)
      }
      Some((coeff, base))
    }
    Float(_) | ComplexFloat(_) => None
    _ => Some((@symnum.BigRational::one(), term))
  }
}

///|
fn canonical_base_index_get(
  base_index : Map[Int, Array[Int]],
  bases : Array[Expr],
  base : Expr,
) -> Int? {
  let hash = hash_expr_normalized(base)
  match base_index.get(hash) {
    Some(bucket) => {
      for index in bucket {
        if compare_expr_normalized(bases[index], base) == 0 {
          return Some(index)
        }
      }
      None
    }
    None => None
  }
}

///|
fn canonical_base_index_put(
  base_index : Map[Int, Array[Int]],
  base : Expr,
  index : Int,
) -> Unit {
  let hash = hash_expr_normalized(base)
  match base_index.get(hash) {
    Some(bucket) => {
      bucket.push(index)
      base_index[hash] = bucket
    }
    None => base_index[hash] = [index]
  }
}

///|
fn add_term_has_implicit_unit_coeff(term : Expr) -> Bool {
  match term {
    Number(_) | Float(_) | ComplexFloat(_) => false
    Mul(items) =>
      !items.any(item => {
        match item {
          Number(_) | Float(_) | ComplexFloat(_) => true
          _ => false
        }
      })
    _ => true
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
/// Build a symbolic sum and apply standard constructor canonicalization.
///
/// - Does: Constructs an additive expression from child expressions.
/// - Input: `Array[Expr]`.
/// - Returns: A single canonicalized `Expr`.
/// - Limits: This is expression construction, not a full simplification pass.
///
/// ```mbt check
/// test "symcore add constructs readable sums" {
///   let x = Expr::Symbol("x")
///   inspect(@symprint.pretty_string(add([x, int(1)])), content="x + 1")
/// }
/// ```
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
      Add(inner) =>
        for child in inner {
          match child {
            Number(n) =>
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
            Float(f) =>
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
            ComplexFloat(z) =>
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
      Number(n) =>
        match complex_sum {
          Some(current) => complex_sum = Some(add_exact_to_complex(current, n))
          None =>
            match float_sum {
              Some(current) => float_sum = Some(add_exact_to_float(current, n))
              None => const_sum = const_sum.add_r(n)
            }
        }
      Float(f) =>
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
      ComplexFloat(z) =>
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
  if flat.all(add_term_has_implicit_unit_coeff) {
    sort_exprs_in_place(flat)
    let merged : Array[Expr] = []
    let mut i = 0
    while i < flat.length() {
      let term = flat[i]
      let mut multiplicity = 1
      while i + multiplicity < flat.length() &&
            compare_expr_normalized(flat[i + multiplicity], term) == 0 {
        multiplicity += 1
      }
      if multiplicity == 1 {
        merged.push(term)
      } else {
        merged.push(
          mul([Number(@symnum.BigRational::from_int(multiplicity)), term]),
        )
      }
      i += multiplicity
    }
    flat.clear()
    for term in merged {
      flat.push(term)
    }
  } else {
    let bases : Array[Expr] = []
    let coeffs : Array[@symnum.BigRational] = []
    let base_index : Map[Int, Array[Int]] = Map([])
    let passthrough : Array[Expr] = []
    for term in flat {
      match split_add_term_coeff(term) {
        Some((coeff, base)) => {
          let base = normalize_legacy_expr(base)
          match canonical_base_index_get(base_index, bases, base) {
            Some(index) => coeffs[index] = coeffs[index].add_r(coeff)
            None => {
              let index = bases.length()
              bases.push(base)
              coeffs.push(coeff)
              canonical_base_index_put(base_index, base, index)
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
        flat.push(Number(coeff))
      } else if coeff.is_one() {
        flat.push(base)
      } else {
        flat.push(mul([Number(coeff), base]))
      }
    }
    for term in passthrough {
      flat.push(term)
    }
  }
  match complex_sum {
    Some(value) =>
      if !(@symnum.is_zero(value.to_mpc().real) &&
        @symnum.is_zero(value.to_mpc().imag)) {
        flat.push(ComplexFloat(value))
      }
    None =>
      match float_sum {
        Some(value) =>
          if !@symnum.is_zero(value.to_mpf()) {
            flat.push(Float(value))
          }
        None => if !const_sum.is_zero() { flat.push(Number(const_sum)) }
      }
  }
  sort_exprs_in_place(flat)
  match flat.length() {
    0 =>
      match complex_sum {
        Some(value) => ComplexFloat(value)
        None =>
          match float_sum {
            Some(value) => Float(value)
            None => Number(@symnum.BigRational::zero())
          }
      }
    1 => flat[0]
    _ => Add(flat)
  }
}

///|
fn expr_is_zero(expr : Expr) -> Bool {
  match expr {
    Number(n) => n.is_zero()
    Float(f) => @symnum.is_zero(f.to_mpf())
    ComplexFloat(z) =>
      @symnum.is_zero(z.to_mpc().real) && @symnum.is_zero(z.to_mpc().imag)
    _ => false
  }
}

///|
fn expr_is_one(expr : Expr) -> Bool {
  match expr {
    Number(n) => n.is_one()
    Float(f) => @symnum.mpf_eq(f.to_mpf(), @symnum.fone)
    ComplexFloat(z) =>
      @symnum.mpf_eq(z.to_mpc().real, @symnum.fone) &&
      @symnum.is_zero(z.to_mpc().imag)
    _ => false
  }
}

///|
/// Build a symbolic product and apply standard constructor canonicalization.
///
/// - Does: Constructs a multiplicative expression from child expressions.
/// - Input: `Array[Expr]`.
/// - Returns: A single canonicalized `Expr`.
/// - Limits: It does not replace targeted simplifiers such as rational or
///   trigonometric normalization.
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
      Mul(inner) =>
        for child in inner {
          match child {
            Number(n) =>
              match complex_prod {
                Some(current) =>
                  if n.is_zero() {
                    return ComplexFloat(
                      complex_from_exact_unchecked(n, current.precision()),
                    )
                  } else {
                    complex_prod = Some(mul_exact_to_complex(current, n))
                  }
                None =>
                  match float_prod {
                    Some(current) =>
                      if n.is_zero() {
                        return Number(@symnum.BigRational::zero())
                      } else {
                        float_prod = Some(mul_exact_to_float(current, n))
                      }
                    None => {
                      if n.is_zero() {
                        return Number(@symnum.BigRational::zero())
                      }
                      const_prod = const_prod.mul_r(n)
                    }
                  }
              }
            Float(f) =>
              if @symnum.is_zero(f.to_mpf()) {
                return Float(f)
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
            ComplexFloat(z) =>
              if expr_is_zero(ComplexFloat(z)) {
                return ComplexFloat(z)
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
            NumberSymbol(Infinity)
            | NumberSymbol(NegativeInfinity)
            | NumberSymbol(ComplexInfinity)
            | NumberSymbol(NaN) => flat.push(child)
            _ => flat.push(child)
          }
        }
      Number(n) =>
        match complex_prod {
          Some(current) =>
            if n.is_zero() {
              return ComplexFloat(
                complex_from_exact_unchecked(n, current.precision()),
              )
            } else {
              complex_prod = Some(mul_exact_to_complex(current, n))
            }
          None =>
            match float_prod {
              Some(current) =>
                if n.is_zero() {
                  return Number(@symnum.BigRational::zero())
                } else {
                  float_prod = Some(mul_exact_to_float(current, n))
                }
              None => {
                if n.is_zero() {
                  return Number(@symnum.BigRational::zero())
                }
                const_prod = const_prod.mul_r(n)
              }
            }
        }
      Float(f) =>
        if @symnum.is_zero(f.to_mpf()) {
          return Float(f)
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
      ComplexFloat(z) =>
        if expr_is_zero(ComplexFloat(z)) {
          return ComplexFloat(z)
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
      NumberSymbol(Infinity)
      | NumberSymbol(NegativeInfinity)
      | NumberSymbol(ComplexInfinity)
      | NumberSymbol(NaN) => flat.push(arg)
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
      NumberSymbol(Infinity) => return NumberSymbol(NegativeInfinity)
      NumberSymbol(NegativeInfinity) => return NumberSymbol(Infinity)
      _ => ()
    }
  }
  if current_distribute() && complex_prod is None && merged.length() == 1 {
    match merged[0] {
      Add(add_args) =>
        match float_prod {
          Some(value) =>
            if value.is_finite() && !expr_is_one(Float(value)) {
              return add(add_args.map(term => mul([Float(value), term])))
            }
          None =>
            if !const_prod.is_one() {
              return add(add_args.map(term => mul([Number(const_prod), term])))
            }
        }
      _ => ()
    }
  }
  match complex_prod {
    Some(value) =>
      if merged.is_empty() {
        ComplexFloat(value)
      } else if expr_is_one(ComplexFloat(value)) {
        match merged.length() {
          1 => merged[0]
          _ => Mul(merged)
        }
      } else {
        let out : Array[Expr] = Array::new()
        out.push(ComplexFloat(value))
        for v in merged {
          out.push(v)
        }
        match out.length() {
          1 => out[0]
          _ => Mul(out)
        }
      }
    None =>
      match float_prod {
        Some(value) =>
          if merged.is_empty() {
            Float(value)
          } else if expr_is_one(Float(value)) {
            match merged.length() {
              1 => merged[0]
              _ => Mul(merged)
            }
          } else {
            let out : Array[Expr] = Array::new()
            out.push(Float(value))
            for v in merged {
              out.push(v)
            }
            match out.length() {
              1 => out[0]
              _ => Mul(out)
            }
          }
        None =>
          if merged.is_empty() {
            if const_prod.is_one() {
              Number(@symnum.BigRational::one())
            } else {
              Number(const_prod)
            }
          } else if const_prod.is_one() {
            match merged.length() {
              1 => merged[0]
              _ => Mul(merged)
            }
          } else {
            let out : Array[Expr] = Array::new()
            out.push(Number(const_prod))
            for v in merged {
              out.push(v)
            }
            match out.length() {
              1 => out[0]
              _ => Mul(out)
            }
          }
      }
  }
}

///|
fn is_zero_base_expr(expr : Expr) -> Bool {
  match expr {
    Number(n) => n.is_zero()
    Float(f) => @symnum.is_zero(f.to_mpf())
    ComplexFloat(z) =>
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
      let imag = Expr::NumberSymbol(ImaginaryUnit)
      Some(
        match rem {
          0 => Number(@symnum.BigRational::one())
          1 => imag
          2 => Number(@symnum.BigRational::from_int(-1))
          _ => mul([Number(@symnum.BigRational::from_int(-1)), imag])
        },
      )
    }
    _ => None
  }
}

///|
fn sqrt_bigint_if_square(value : BigInt) -> BigInt? {
  if value < 0N {
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
    Number(n) => {
      let negative = n.compare(@symnum.BigRational::zero()) < 0
      let abs_n = if negative { n.neg_r() } else { n }
      let num_root = match sqrt_bigint_if_square(abs_n.numerator()) {
        Some(root) => root
        None =>
          if negative {
            let imag = Expr::NumberSymbol(ImaginaryUnit)
            return Some(mul([imag, function("sqrt", [Number(abs_n)])]))
          } else {
            return None
          }
      }
      let den_root = match sqrt_bigint_if_square(abs_n.denominator()) {
        Some(root) => root
        None =>
          if negative {
            let imag = Expr::NumberSymbol(ImaginaryUnit)
            return Some(mul([imag, function("sqrt", [Number(abs_n)])]))
          } else {
            return None
          }
      }
      let rat = @symnum.BigRational::new(num_root, den_root) catch {
        _ => return None
      }
      let root_expr = Expr::Number(rat)
      if negative {
        let imag = Expr::NumberSymbol(ImaginaryUnit)
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
          ComplexFloat(z) => ComplexFloat(z)
          Float(f) => Float(f)
          _ => Number(@symnum.BigRational::zero())
        },
      )
    _ => None
  }
}

///|
/// Build a symbolic power expression.
///
/// - Does: Constructs `base**exp` using the core power front door.
/// - Input: A base `Expr` and an exponent `Expr`.
/// - Returns: A single `Expr`.
/// - Limits: Advanced algebraic normalization lives in higher-level packages.
pub fn pow(base : Expr, exp : Expr) -> Expr {
  let base = normalize_legacy_expr(base)
  let exp = normalize_legacy_expr(exp)
  if !current_evaluate() {
    return raw_pow(base, exp)
  }
  if expr_is_zero(exp) {
    Number(@symnum.BigRational::one())
  } else if expr_is_one(base) {
    base
  } else if expr_is_one(exp) {
    base
  } else if exact_numeric_half_power(base, exp) is Some(value) {
    value
  } else {
    match base {
      NumberSymbol(ImaginaryUnit) =>
        match imag_unit_pow(exp) {
          Some(value) => value
          None => Pow(base, exp)
        }
      Pow(inner_base, inner_exp) =>
        match exact_numeric_expr_num_den(exp) {
          Some((_, den)) if den.compare(1N) == 0 =>
            pow(inner_base, mul([inner_exp, exp]))
          _ =>
            match base {
              _ if is_zero_base_expr(base) =>
                match zero_base_pow_value(base, exp) {
                  Some(value) => value
                  None => Pow(base, exp)
                }
              _ => Pow(base, exp)
            }
        }
      _ if is_zero_base_expr(base) =>
        match zero_base_pow_value(base, exp) {
          Some(value) => value
          None => Pow(base, exp)
        }
      _ => Pow(base, exp)
    }
  }
}

///|
pub fn mod_expr(lhs : Expr, rhs : Expr) -> Expr {
  Mod(lhs, rhs)
}

///|
fn constructor_relational(op : RelOp, lhs : Expr, rhs : Expr) -> Expr {
  match op {
    Eq => if lhs == rhs { Boolean(true) } else { Relational(op, lhs, rhs) }
    Ne => if lhs == rhs { Boolean(false) } else { Relational(op, lhs, rhs) }
    Lt =>
      match (lhs, rhs) {
        (Number(lhs_num), Number(rhs_num)) =>
          Boolean(lhs_num.compare(rhs_num) < 0)
        _ => Relational(op, lhs, rhs)
      }
    Le =>
      match (lhs, rhs) {
        (Number(lhs_num), Number(rhs_num)) =>
          Boolean(lhs_num.compare(rhs_num) <= 0)
        _ => Relational(op, lhs, rhs)
      }
    Gt =>
      match (lhs, rhs) {
        (Number(lhs_num), Number(rhs_num)) =>
          Boolean(lhs_num.compare(rhs_num) > 0)
        _ => Relational(op, lhs, rhs)
      }
    Ge =>
      match (lhs, rhs) {
        (Number(lhs_num), Number(rhs_num)) =>
          Boolean(lhs_num.compare(rhs_num) >= 0)
        _ => Relational(op, lhs, rhs)
      }
  }
}

///|
fn constructor_derivative(name : String, args : Array[Expr]) -> Expr {
  if args.length() < 2 {
    return Apply(FunctionHead(name), args)
  }
  derivative_constructor_expr(args[0], args[1:])
}

///|
fn constructor_singleton_registry(name : String, args : Array[Expr]) -> Expr {
  match args.length() {
    0 => Apply(FunctionHead(name), args)
    given if given <= 6 => normalize_legacy_expr(args[0])
    _ => Apply(FunctionHead(name), args)
  }
}

///|
/// Build a named symbolic function application.
///
/// - Does: Constructs expressions such as `sin(x)`, `log(x)`, or `f(x)`.
/// - Input: A function name `String` and `Array[Expr]` arguments.
/// - Returns: A single application `Expr`.
/// - Limits: The head name is taken literally; this front door does not parse
///   textual mathematics.
///
/// ```mbt check
/// test "symcore function builds named applications" {
///   let x = Expr::Symbol("x")
///   inspect(@symprint.pretty_string(function("sin", [x])), content="sin(x)")
/// }
/// ```
pub fn function(name : String, args : Array[Expr]) -> Expr {
  if !current_evaluate() {
    return raw_function(name, args)
  }
  let args = args.map(normalize_legacy_expr)
  function_canonical(name, args)
}

///|
fn function_canonical(name : String, args : Array[Expr]) -> Expr {
  match (name, args) {
    ("True", []) => Boolean(true)
    ("False", []) => Boolean(false)
    ("Tuple", _) => Tuple(args)
    ("S", _) => constructor_singleton_registry(name, args)
    ("Integer", _) => constructor_integer(args)
    ("Rational", _) => constructor_rational(args)
    ("Float", _) => constructor_float(args)
    ("sqrt", [arg]) =>
      match exact_sqrt_expr(arg) {
        Some(value) => value
        None => Apply(FunctionHead(name), args)
      }
    ("Eq", [lhs, rhs]) => constructor_relational(Eq, lhs, rhs)
    ("Ne", [lhs, rhs]) => constructor_relational(Ne, lhs, rhs)
    ("Lt", [lhs, rhs]) => constructor_relational(Lt, lhs, rhs)
    ("Le", [lhs, rhs]) => constructor_relational(Le, lhs, rhs)
    ("Gt", [lhs, rhs]) => constructor_relational(Gt, lhs, rhs)
    ("Ge", [lhs, rhs]) => constructor_relational(Ge, lhs, rhs)
    ("Mod", [lhs, rhs]) => mod_expr(lhs, rhs)
    ("Derivative", _) => constructor_derivative(name, args)
    ("Subs", [expr, variable, value]) => subs_expr(expr, variable, value)
    ("Lambda", [vars, body]) => lambda_expr(vars, body)
    ("exp", [arg]) if current_exp_is_pow() => pow(NumberSymbol(Exp1), arg)
    ("Dict", items) => {
      let entries : Array[(Expr, Expr)] = []
      for item in items {
        match tuple_items(item) {
          Some([key, value]) => entries.push((key, value))
          _ => return Apply(FunctionHead(name), args)
        }
      }
      Dict(entries)
    }
    _ => Apply(FunctionHead(name), args)
  }
}

///|
/// Build `Add` directly without flattening, sorting, or constant folding.
pub fn raw_add(args : Array[Expr]) -> Expr {
  Add(args.map(child => child))
}

///|
pub fn raw_mul(args : Array[Expr]) -> Expr {
  Mul(args.map(child => child))
}

///|
pub fn raw_pow(base : Expr, exp : Expr) -> Expr {
  Pow(base, exp)
}

///|
pub fn raw_mod_expr(lhs : Expr, rhs : Expr) -> Expr {
  Mod(lhs, rhs)
}

///|
pub fn raw_dict_expr(items : Array[(Expr, Expr)]) -> Expr {
  Dict(items.map(item => item))
}

///|
pub fn raw_function(name : String, args : Array[Expr]) -> Expr {
  let args = args.map(normalize_legacy_expr)
  raw_function_canonical(name, args)
}

///|
fn raw_function_canonical(name : String, args : Array[Expr]) -> Expr {
  match (name, args) {
    ("True", []) => Boolean(true)
    ("False", []) => Boolean(false)
    ("Tuple", _) => Tuple(args)
    ("S", _) => constructor_singleton_registry(name, args)
    ("Integer", _) => constructor_integer(args)
    ("Rational", _) => constructor_rational(args)
    ("Float", _) => constructor_float(args)
    ("Eq", [lhs, rhs]) => Relational(Eq, lhs, rhs)
    ("Ne", [lhs, rhs]) => Relational(Ne, lhs, rhs)
    ("Lt", [lhs, rhs]) => Relational(Lt, lhs, rhs)
    ("Le", [lhs, rhs]) => Relational(Le, lhs, rhs)
    ("Gt", [lhs, rhs]) => Relational(Gt, lhs, rhs)
    ("Ge", [lhs, rhs]) => Relational(Ge, lhs, rhs)
    ("Mod", [lhs, rhs]) => Mod(lhs, rhs)
    ("Derivative", _) => constructor_derivative(name, args)
    ("Subs", [expr, variable, value]) => subs_expr(expr, variable, value)
    ("Lambda", [vars, body]) => lambda_expr(vars, body)
    ("Dict", items) => {
      let entries : Array[(Expr, Expr)] = []
      for item in items {
        match tuple_items(item) {
          Some([key, value]) => entries.push((key, value))
          _ => return Apply(FunctionHead(name), args)
        }
      }
      Dict(entries)
    }
    _ => Apply(FunctionHead(name), args)
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
  debug_inspect(
    arr,
    content=(
      #|[
      #|  [3, 6],
      #|  [0],
      #|  [0, 0],
      #|  [9, 6, 7],
      #|  [1, 5],
      #|  [3],
      #|  [6],
      #|  [0],
      #|  [8, 7],
      #|  [8, 7],
      #|]
    ),
  )
}

///|
test "symbolized" {
  let x = Expr::Symbol("x")
  let y = Expr::Symbol("y")
  let expr = x + (y ^ int(10))
  inspect(expr, content="(x + (y ** 10))")
}
