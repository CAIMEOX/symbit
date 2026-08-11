///|
/// Evaluate one primitive predicate directly on an expression.
///
/// This entry point bypasses the richer query language and only handles the
/// unary predicates listed by [`Predicate`](#predicate). It is useful for fast
/// local checks such as “is this expression real?” or “is this expression zero?”
pub fn ask_predicate(
  expr : Expr,
  predicate : Predicate,
  env? : AssumeEnv = {},
) -> Tri {
  match predicate {
    IsZero => is_zero(expr, env~)
    IsNonzero => is_nonzero(expr, env~)
    IsInteger => is_integer(expr, env~)
    IsRational => is_rational(expr, env~)
    IsReal => is_real(expr, env~)
    IsPositive => is_positive(expr, env~)
    IsNonnegative => is_nonnegative(expr, env~)
  }
}

///|
fn ordinary_application_name_args(expr : Expr) -> (String, Array[Expr])? {
  match @symcore.application_parts(expr) {
    Some((head, args)) =>
      match @symcore.function_head_name(head) {
        Some(name) => Some((name, args))
        None => None
      }
    None => None
  }
}

///|
/// Decide whether an expression is exactly zero.
pub fn is_zero(expr : Expr, env? : AssumeEnv = {}) -> Tri {
  match ordinary_application_name_args(expr) {
    Some((name, args)) => return function_is_zero(name, args, env)
    None => ()
  }
  match @symcore.expr_form(expr) {
    Number(n) => tri_of_bool(n.is_zero())
    Float(f) => tri_of_bool(@symnum.is_zero(f.to_mpf()))
    ComplexFloat(z) =>
      tri_of_bool(
        @symnum.is_zero(z.to_mpc().real) && @symnum.is_zero(z.to_mpc().imag),
      )
    NumberSymbol(kind) => number_symbol_is_zero(kind)
    Symbol(name) => env_get(env, name).is_zero
    Dummy(_, _) | Wild(_, _, _) | FunctionHead(_) => Unknown
    UndefinedFunction(_) => Unknown
    Boolean(value) => tri_of_bool(!value)
    Add(args) => add_is_zero(args, env)
    Mul(args) => mul_is_zero(args, env)
    Pow(base, exp) => pow_is_zero(base, exp, env)
    Mod(lhs, rhs) => function_is_zero("Mod", [lhs, rhs], env)
    Tuple(_) | Dict(_) => False
    Relational(_, _, _) => False
    Derivative(_, _) => function_is_zero("Derivative", @symcore.args(expr), env)
    Subs(_, _, _) => function_is_zero("Subs", @symcore.args(expr), env)
    Lambda(_, _) => function_is_zero("Lambda", @symcore.args(expr), env)
    _ => Unknown
  }
}

///|
/// Decide whether an expression is definitely not zero.
pub fn is_nonzero(expr : Expr, env? : AssumeEnv = {}) -> Tri {
  match ordinary_application_name_args(expr) {
    Some((name, args)) => return function_is_nonzero(name, args, env)
    None => ()
  }
  match @symcore.expr_form(expr) {
    Number(n) => tri_of_bool(!n.is_zero())
    Float(f) => tri_of_bool(!@symnum.is_zero(f.to_mpf()))
    ComplexFloat(z) =>
      tri_of_bool(
        !(@symnum.is_zero(z.to_mpc().real) && @symnum.is_zero(z.to_mpc().imag)),
      )
    NumberSymbol(kind) => number_symbol_is_nonzero(kind)
    Symbol(name) => env_get(env, name).is_nonzero
    Dummy(_, _) | Wild(_, _, _) | FunctionHead(_) => Unknown
    UndefinedFunction(_) => Unknown
    Boolean(value) => tri_of_bool(value)
    Add(args) => add_is_nonzero(args, env)
    Mul(args) => mul_is_nonzero(args, env)
    Pow(base, exp) => pow_is_nonzero(base, exp, env)
    Mod(lhs, rhs) => function_is_nonzero("Mod", [lhs, rhs], env)
    Tuple(_) | Dict(_) => True
    Relational(_, _, _) => True
    Derivative(_, _) =>
      function_is_nonzero("Derivative", @symcore.args(expr), env)
    Subs(_, _, _) => function_is_nonzero("Subs", @symcore.args(expr), env)
    Lambda(_, _) => function_is_nonzero("Lambda", @symcore.args(expr), env)
    _ => Unknown
  }
}

///|
/// Decide whether an expression is an integer.
pub fn is_integer(expr : Expr, env? : AssumeEnv = {}) -> Tri {
  match ordinary_application_name_args(expr) {
    Some((name, args)) => return function_is_integer(name, args, env)
    None => ()
  }
  match @symcore.expr_form(expr) {
    Number(n) => tri_of_bool(n.is_integral())
    Float(_) | ComplexFloat(_) => Unknown
    NumberSymbol(kind) => number_symbol_is_integer(kind)
    Symbol(name) => env_get(env, name).is_integer
    Dummy(_, _) | Wild(_, _, _) | FunctionHead(_) => Unknown
    UndefinedFunction(_) => Unknown
    Boolean(_) => True
    Add(args) | Mul(args) =>
      all_predicate(args, child => is_integer(child, env~))
    Pow(base, exp) => pow_is_integer(base, exp, env)
    Mod(lhs, rhs) => function_is_integer("Mod", [lhs, rhs], env)
    Tuple(_) | Dict(_) => False
    Relational(_, _, _) => False
    Derivative(_, _) =>
      function_is_integer("Derivative", @symcore.args(expr), env)
    Subs(_, _, _) => function_is_integer("Subs", @symcore.args(expr), env)
    Lambda(_, _) => function_is_integer("Lambda", @symcore.args(expr), env)
    _ => Unknown
  }
}

///|
/// Decide whether an expression is a rational number.
pub fn is_rational(expr : Expr, env? : AssumeEnv = {}) -> Tri {
  match ordinary_application_name_args(expr) {
    Some((name, args)) => return function_is_rational(name, args, env)
    None => ()
  }
  match @symcore.expr_form(expr) {
    Number(_) => True
    Float(_) | ComplexFloat(_) => Unknown
    NumberSymbol(kind) => number_symbol_is_rational(kind)
    Symbol(name) => env_get(env, name).is_rational
    Dummy(_, _) | Wild(_, _, _) | FunctionHead(_) => Unknown
    UndefinedFunction(_) => Unknown
    Boolean(_) => True
    Add(args) | Mul(args) =>
      all_predicate(args, child => is_rational(child, env~))
    Pow(base, exp) => pow_is_rational(base, exp, env)
    Mod(lhs, rhs) => function_is_rational("Mod", [lhs, rhs], env)
    Tuple(_) | Dict(_) => False
    Relational(_, _, _) => False
    Derivative(_, _) =>
      function_is_rational("Derivative", @symcore.args(expr), env)
    Subs(_, _, _) => function_is_rational("Subs", @symcore.args(expr), env)
    Lambda(_, _) => function_is_rational("Lambda", @symcore.args(expr), env)
    _ => Unknown
  }
}

///|
/// Decide whether an expression is real-valued.
pub fn is_real(expr : Expr, env? : AssumeEnv = {}) -> Tri {
  match ordinary_application_name_args(expr) {
    Some((name, args)) => return function_is_real(name, args, env)
    None => ()
  }
  match @symcore.expr_form(expr) {
    Number(_) | Float(_) => True
    ComplexFloat(z) => tri_of_bool(@symnum.is_zero(z.to_mpc().imag))
    NumberSymbol(kind) => number_symbol_is_real(kind)
    Symbol(name) => env_get(env, name).is_real
    Dummy(_, _) | Wild(_, _, _) | FunctionHead(_) => Unknown
    UndefinedFunction(_) => Unknown
    Boolean(_) => True
    Add(args) | Mul(args) => all_predicate(args, child => is_real(child, env~))
    Pow(base, exp) => pow_is_real(base, exp, env)
    Mod(lhs, rhs) => function_is_real("Mod", [lhs, rhs], env)
    Tuple(_) | Dict(_) => False
    Relational(_, _, _) => False
    Derivative(_, _) => function_is_real("Derivative", @symcore.args(expr), env)
    Subs(_, _, _) => function_is_real("Subs", @symcore.args(expr), env)
    Lambda(_, _) => function_is_real("Lambda", @symcore.args(expr), env)
    _ => Unknown
  }
}

///|
/// Decide whether an expression is strictly positive.
pub fn is_positive(expr : Expr, env? : AssumeEnv = {}) -> Tri {
  match ordinary_application_name_args(expr) {
    Some((name, args)) => return function_is_positive(name, args, env)
    None => ()
  }
  match @symcore.expr_form(expr) {
    Number(n) => tri_of_bool(n.compare(@symnum.BigRational::zero()) > 0)
    Float(f) => tri_of_bool(@symnum.mpf_sign(f.to_mpf()) > 0)
    ComplexFloat(z) =>
      if @symnum.is_zero(z.to_mpc().imag) {
        tri_of_bool(@symnum.mpf_sign(z.to_mpc().real) > 0)
      } else {
        False
      }
    NumberSymbol(kind) => number_symbol_is_positive(kind)
    Symbol(name) => env_get(env, name).is_positive
    Dummy(_, _) | Wild(_, _, _) | FunctionHead(_) => Unknown
    UndefinedFunction(_) => Unknown
    Boolean(value) => tri_of_bool(value)
    Add(args) => add_is_positive(args, env)
    Mul(args) => mul_is_positive(args, env)
    Pow(base, exp) => pow_is_positive(base, exp, env)
    Mod(lhs, rhs) => function_is_positive("Mod", [lhs, rhs], env)
    Tuple(_) | Dict(_) => False
    Relational(_, _, _) => False
    Derivative(_, _) =>
      function_is_positive("Derivative", @symcore.args(expr), env)
    Subs(_, _, _) => function_is_positive("Subs", @symcore.args(expr), env)
    Lambda(_, _) => function_is_positive("Lambda", @symcore.args(expr), env)
    _ => Unknown
  }
}

///|
/// Decide whether an expression is greater than or equal to zero.
pub fn is_nonnegative(expr : Expr, env? : AssumeEnv = {}) -> Tri {
  match ordinary_application_name_args(expr) {
    Some((name, args)) => return function_is_nonnegative(name, args, env)
    None => ()
  }
  match @symcore.expr_form(expr) {
    Number(n) => tri_of_bool(n.compare(@symnum.BigRational::zero()) >= 0)
    Float(f) => tri_of_bool(@symnum.mpf_sign(f.to_mpf()) >= 0)
    ComplexFloat(z) =>
      if @symnum.is_zero(z.to_mpc().imag) {
        tri_of_bool(@symnum.mpf_sign(z.to_mpc().real) >= 0)
      } else {
        False
      }
    NumberSymbol(kind) => number_symbol_is_nonnegative(kind)
    Symbol(name) => env_get(env, name).is_nonnegative
    Dummy(_, _) | Wild(_, _, _) | FunctionHead(_) => Unknown
    UndefinedFunction(_) => Unknown
    Boolean(_) => True
    Add(args) => add_is_nonnegative(args, env)
    Mul(args) => mul_is_nonnegative(args, env)
    Pow(base, exp) => pow_is_nonnegative(base, exp, env)
    Mod(lhs, rhs) => function_is_nonnegative("Mod", [lhs, rhs], env)
    Tuple(_) | Dict(_) => False
    Relational(_, _, _) => False
    Derivative(_, _) =>
      function_is_nonnegative("Derivative", @symcore.args(expr), env)
    Subs(_, _, _) => function_is_nonnegative("Subs", @symcore.args(expr), env)
    Lambda(_, _) => function_is_nonnegative("Lambda", @symcore.args(expr), env)
    _ => Unknown
  }
}

///|
fn all_predicate(args : Array[Expr], pred : (Expr) -> Tri) -> Tri {
  let mut saw_unknown = false
  for arg in args {
    match pred(arg) {
      False => return False
      Unknown => saw_unknown = true
      True => ()
    }
  }
  if saw_unknown {
    Unknown
  } else {
    True
  }
}

///|
fn add_is_zero(args : Array[Expr], env : AssumeEnv) -> Tri {
  if args.is_empty() {
    return True
  }
  if args.length() == 1 {
    return is_zero(args[0], env~)
  }
  let mut nonzero_count = 0
  let mut all_zero = true
  let mut all_zero_or_nonzero = true
  for arg in args {
    let z = is_zero(arg, env~)
    let nz = is_nonzero(arg, env~)
    match z {
      True => ()
      False => all_zero = false
      Unknown => {
        all_zero = false
        all_zero_or_nonzero = false
      }
    }
    match nz {
      True => nonzero_count += 1
      False => ()
      Unknown => all_zero_or_nonzero = false
    }
  }
  if all_zero {
    True
  } else if nonzero_count == 1 && all_zero_or_nonzero {
    False
  } else {
    Unknown
  }
}

///|
fn mul_is_zero(args : Array[Expr], env : AssumeEnv) -> Tri {
  let mut all_nonzero = true
  for arg in args {
    match is_zero(arg, env~) {
      True => return True
      False => ()
      Unknown => ()
    }
    if is_nonzero(arg, env~) != True {
      all_nonzero = false
    }
  }
  if all_nonzero {
    False
  } else {
    Unknown
  }
}

///|
fn pow_is_zero(base : Expr, exp : Expr, env : AssumeEnv) -> Tri {
  match exp {
    Number(n) if n.is_zero() => return False
    _ => ()
  }
  if is_zero(base, env~) == True && is_positive(exp, env~) == True {
    True
  } else if is_nonzero(base, env~) == True {
    False
  } else {
    Unknown
  }
}

///|
fn add_is_nonzero(args : Array[Expr], env : AssumeEnv) -> Tri {
  if args.is_empty() {
    return False
  }
  if args.length() == 1 {
    return is_nonzero(args[0], env~)
  }
  let mut nonzero_count = 0
  let mut all_zero = true
  let mut all_zero_or_nonzero = true
  for arg in args {
    let z = is_zero(arg, env~)
    let nz = is_nonzero(arg, env~)
    match z {
      True => ()
      False => all_zero = false
      Unknown => {
        all_zero = false
        all_zero_or_nonzero = false
      }
    }
    match nz {
      True => nonzero_count += 1
      False => ()
      Unknown => all_zero_or_nonzero = false
    }
  }
  if all_zero {
    False
  } else if nonzero_count == 1 && all_zero_or_nonzero {
    True
  } else {
    Unknown
  }
}

///|
fn mul_is_nonzero(args : Array[Expr], env : AssumeEnv) -> Tri {
  let mut saw_unknown = false
  for arg in args {
    match is_nonzero(arg, env~) {
      True => ()
      False => return False
      Unknown => saw_unknown = true
    }
  }
  if saw_unknown {
    Unknown
  } else {
    True
  }
}

///|
fn pow_is_nonzero(base : Expr, exp : Expr, env : AssumeEnv) -> Tri {
  match exp {
    Number(n) if n.is_zero() => return True
    _ => ()
  }
  if is_nonzero(base, env~) == True {
    True
  } else if is_zero(base, env~) == True && is_positive(exp, env~) == True {
    False
  } else {
    Unknown
  }
}

///|
fn pow_is_integer(base : Expr, exp : Expr, env : AssumeEnv) -> Tri {
  let exp_is_integer = is_integer(exp, env~)
  if exp_is_integer == False {
    return False
  }
  let base_is_integer = is_integer(base, env~)
  match nonnegative_integer_literal(exp) {
    Some(true) =>
      if base_is_integer == True {
        True
      } else if base_is_integer == False {
        False
      } else {
        Unknown
      }
    Some(false) =>
      if base_is_integer == True && is_nonzero(base, env~) == True {
        Unknown
      } else {
        Unknown
      }
    None => Unknown
  }
}

///|
fn pow_is_rational(base : Expr, exp : Expr, env : AssumeEnv) -> Tri {
  if is_integer(exp, env~) == False {
    return False
  }
  let base_is_rational = is_rational(base, env~)
  if base_is_rational == False {
    return False
  }
  match nonnegative_integer_literal(exp) {
    Some(true) => base_is_rational
    Some(false) =>
      if base_is_rational == True && is_nonzero(base, env~) == True {
        True
      } else {
        Unknown
      }
    None => Unknown
  }
}

///|
fn pow_is_real(base : Expr, exp : Expr, env : AssumeEnv) -> Tri {
  let base_real = is_real(base, env~)
  if base_real == False {
    return False
  }
  if is_integer(exp, env~) == True {
    match nonnegative_integer_literal(exp) {
      Some(true) => base_real
      Some(false) =>
        if base_real == True && is_nonzero(base, env~) == True {
          True
        } else {
          Unknown
        }
      None => Unknown
    }
  } else {
    Unknown
  }
}

///|
fn add_is_positive(args : Array[Expr], env : AssumeEnv) -> Tri {
  if args.is_empty() {
    return False
  }
  let mut all_nonnegative = true
  let mut any_positive = false
  let mut all_zero = true
  for arg in args {
    let nn = is_nonnegative(arg, env~)
    let p = is_positive(arg, env~)
    let z = is_zero(arg, env~)
    if nn != True {
      all_nonnegative = false
    }
    if p == True {
      any_positive = true
    }
    if z != True {
      all_zero = false
    }
  }
  if all_zero {
    False
  } else if all_nonnegative && any_positive {
    True
  } else {
    Unknown
  }
}

///|
fn mul_is_positive(args : Array[Expr], env : AssumeEnv) -> Tri {
  if args.is_empty() {
    return True
  }
  let mut all_positive = true
  let mut all_nonnegative = true
  let mut all_nonzero = true
  for arg in args {
    if is_zero(arg, env~) == True {
      return False
    }
    if is_positive(arg, env~) != True {
      all_positive = false
    }
    if is_nonnegative(arg, env~) != True {
      all_nonnegative = false
    }
    if is_nonzero(arg, env~) != True {
      all_nonzero = false
    }
  }
  if all_positive {
    True
  } else if all_nonnegative && all_nonzero {
    True
  } else {
    Unknown
  }
}

///|
fn pow_is_positive(base : Expr, exp : Expr, env : AssumeEnv) -> Tri {
  match exp {
    Number(n) if n.is_zero() => return True
    _ => ()
  }
  if is_positive(base, env~) == True {
    return True
  }
  match even_integer_literal(exp) {
    Some(true) =>
      if is_real(base, env~) == True && is_nonzero(base, env~) == True {
        True
      } else if is_zero(base, env~) == True {
        False
      } else {
        Unknown
      }
    Some(false) => if is_positive(base, env~) == True { True } else { Unknown }
    None => Unknown
  }
}

///|
fn add_is_nonnegative(args : Array[Expr], env : AssumeEnv) -> Tri {
  if args.is_empty() {
    return True
  }
  let mut all_nonnegative = true
  let mut all_zero = true
  for arg in args {
    let nn = is_nonnegative(arg, env~)
    let z = is_zero(arg, env~)
    if nn != True {
      all_nonnegative = false
    }
    if z != True {
      all_zero = false
    }
  }
  if all_nonnegative || all_zero {
    True
  } else {
    Unknown
  }
}

///|
fn mul_is_nonnegative(args : Array[Expr], env : AssumeEnv) -> Tri {
  if args.is_empty() {
    return True
  }
  let mut all_nonnegative = true
  for arg in args {
    if is_zero(arg, env~) == True {
      return True
    }
    if is_nonnegative(arg, env~) != True {
      all_nonnegative = false
    }
  }
  if all_nonnegative {
    True
  } else {
    Unknown
  }
}

///|
fn pow_is_nonnegative(base : Expr, exp : Expr, env : AssumeEnv) -> Tri {
  match exp {
    Number(n) if n.is_zero() => return True
    _ => ()
  }
  match even_integer_literal(exp) {
    Some(true) => if is_real(base, env~) == True { True } else { Unknown }
    _ =>
      if is_nonnegative(base, env~) == True &&
        nonnegative_integer_or_unknown(exp, env) != False {
        True
      } else if is_positive(base, env~) == True {
        True
      } else {
        Unknown
      }
  }
}

///|
fn function_is_zero(name : String, args : Array[Expr], env : AssumeEnv) -> Tri {
  match (name, args.length()) {
    ("exp", 1) => False
    ("Abs", 1) | ("abs", 1) => is_zero(args[0], env~)
    ("sqrt", 1) => is_zero(args[0], env~)
    _ => Unknown
  }
}

///|
fn function_is_nonzero(
  name : String,
  args : Array[Expr],
  env : AssumeEnv,
) -> Tri {
  match (name, args.length()) {
    ("exp", 1) => True
    ("Abs", 1) | ("abs", 1) => is_nonzero(args[0], env~)
    ("sqrt", 1) => is_nonzero(args[0], env~)
    _ => Unknown
  }
}

///|
fn function_is_integer(
  name : String,
  args : Array[Expr],
  env : AssumeEnv,
) -> Tri {
  match (name, args.length()) {
    ("floor", 1) | ("ceiling", 1) => True
    ("Abs", 1) | ("abs", 1) => is_integer(args[0], env~)
    _ => Unknown
  }
}

///|
fn function_is_rational(
  name : String,
  args : Array[Expr],
  env : AssumeEnv,
) -> Tri {
  match (name, args.length()) {
    ("Abs", 1) | ("abs", 1) => is_rational(args[0], env~)
    _ => Unknown
  }
}

///|
fn function_is_real(name : String, args : Array[Expr], env : AssumeEnv) -> Tri {
  match (name, args.length()) {
    ("Abs", 1) | ("abs", 1) => True
    ("sqrt", 1) =>
      if is_nonnegative(args[0], env~) == True {
        True
      } else {
        Unknown
      }
    ("log", 1) =>
      if is_positive(args[0], env~) == True {
        True
      } else {
        Unknown
      }
    ("exp", 1) => if is_real(args[0], env~) == True { True } else { Unknown }
    ("sin", 1) | ("cos", 1) | ("tan", 1) => is_real(args[0], env~)
    ("re", 1) | ("im", 1) => True
    _ => Unknown
  }
}

///|
fn function_is_positive(
  name : String,
  args : Array[Expr],
  env : AssumeEnv,
) -> Tri {
  match (name, args.length()) {
    ("exp", 1) => if is_real(args[0], env~) == True { True } else { Unknown }
    ("Abs", 1) | ("abs", 1) =>
      if is_nonzero(args[0], env~) == True {
        True
      } else if is_zero(args[0], env~) == True {
        False
      } else {
        Unknown
      }
    ("sqrt", 1) =>
      if is_positive(args[0], env~) == True {
        True
      } else if is_zero(args[0], env~) == True {
        False
      } else {
        Unknown
      }
    _ => Unknown
  }
}

///|
fn function_is_nonnegative(
  name : String,
  args : Array[Expr],
  env : AssumeEnv,
) -> Tri {
  match (name, args.length()) {
    ("Abs", 1) | ("abs", 1) => True
    ("sqrt", 1) =>
      if is_nonnegative(args[0], env~) == True {
        True
      } else {
        Unknown
      }
    ("exp", 1) => if is_real(args[0], env~) == True { True } else { Unknown }
    _ => Unknown
  }
}

///|
fn even_integer_literal(expr : Expr) -> Bool? {
  match expr {
    Number(n) if n.is_integral() => {
      let two = BigInt::from_int(2)
      Some(n.numerator().mod(two).is_zero())
    }
    _ => None
  }
}

///|
fn nonnegative_integer_literal(expr : Expr) -> Bool? {
  match expr {
    Number(n) if n.is_integral() =>
      Some(n.numerator().compare(BigInt::from_int(0)) >= 0)
    _ => None
  }
}

///|
fn nonnegative_integer_or_unknown(expr : Expr, env : AssumeEnv) -> Tri {
  match nonnegative_integer_literal(expr) {
    Some(true) => True
    Some(false) => False
    None => if is_integer(expr, env~) == True { Unknown } else { False }
  }
}

///|
fn number_symbol_is_zero(kind : @symcore.NumberSymbolKind) -> Tri {
  match kind {
    NaN => Unknown
    _ => False
  }
}

///|
fn number_symbol_is_nonzero(kind : @symcore.NumberSymbolKind) -> Tri {
  match kind {
    Pi | Exp1 | EulerGamma | GoldenRatio | Catalan | ImaginaryUnit => True
    Infinity | NegativeInfinity | ComplexInfinity | NaN => Unknown
  }
}

///|
fn number_symbol_is_integer(kind : @symcore.NumberSymbolKind) -> Tri {
  match kind {
    NaN => Unknown
    _ => False
  }
}

///|
fn number_symbol_is_rational(kind : @symcore.NumberSymbolKind) -> Tri {
  match kind {
    NaN => Unknown
    _ => False
  }
}

///|
fn number_symbol_is_real(kind : @symcore.NumberSymbolKind) -> Tri {
  match kind {
    ImaginaryUnit | ComplexInfinity => False
    Pi
    | Exp1
    | EulerGamma
    | GoldenRatio
    | Catalan
    | Infinity
    | NegativeInfinity => True
    NaN => Unknown
  }
}

///|
fn number_symbol_is_positive(kind : @symcore.NumberSymbolKind) -> Tri {
  match kind {
    Pi | Exp1 | EulerGamma | GoldenRatio | Catalan | Infinity => True
    ImaginaryUnit | NegativeInfinity | ComplexInfinity => False
    NaN => Unknown
  }
}

///|
fn number_symbol_is_nonnegative(kind : @symcore.NumberSymbolKind) -> Tri {
  match kind {
    Pi | Exp1 | EulerGamma | GoldenRatio | Catalan | Infinity => True
    ImaginaryUnit | NegativeInfinity | ComplexInfinity => False
    NaN => Unknown
  }
}
