///|
pub fn ask_predicate(
  expr : @symcore.Expr,
  predicate : Predicate,
  env? : AssumeEnv = {},
) -> Tri {
  match predicate {
    Predicate::IsZero => is_zero(expr, env~)
    Predicate::IsNonzero => is_nonzero(expr, env~)
    Predicate::IsInteger => is_integer(expr, env~)
    Predicate::IsRational => is_rational(expr, env~)
    Predicate::IsReal => is_real(expr, env~)
    Predicate::IsPositive => is_positive(expr, env~)
    Predicate::IsNonnegative => is_nonnegative(expr, env~)
  }
}

///|
pub fn is_zero(expr : @symcore.Expr, env? : AssumeEnv = {}) -> Tri {
  match expr {
    @symcore.Expr::Number(n) => tri_of_bool(n.is_zero())
    @symcore.Expr::Symbol(name) => env_get(env, name).is_zero
    @symcore.Expr::Add(args) => add_is_zero(args, env)
    @symcore.Expr::Mul(args) => mul_is_zero(args, env)
    @symcore.Expr::Pow(base, exp) => pow_is_zero(base, exp, env)
    @symcore.Expr::Function(name, args) => function_is_zero(name, args, env)
  }
}

///|
pub fn is_nonzero(expr : @symcore.Expr, env? : AssumeEnv = {}) -> Tri {
  match expr {
    @symcore.Expr::Number(n) => tri_of_bool(!n.is_zero())
    @symcore.Expr::Symbol(name) => env_get(env, name).is_nonzero
    @symcore.Expr::Add(args) => add_is_nonzero(args, env)
    @symcore.Expr::Mul(args) => mul_is_nonzero(args, env)
    @symcore.Expr::Pow(base, exp) => pow_is_nonzero(base, exp, env)
    @symcore.Expr::Function(name, args) => function_is_nonzero(name, args, env)
  }
}

///|
pub fn is_integer(expr : @symcore.Expr, env? : AssumeEnv = {}) -> Tri {
  match expr {
    @symcore.Expr::Number(n) => tri_of_bool(n.is_integral())
    @symcore.Expr::Symbol(name) => env_get(env, name).is_integer
    @symcore.Expr::Add(args) | @symcore.Expr::Mul(args) =>
      all_predicate(args, child => is_integer(child, env~))
    @symcore.Expr::Pow(base, exp) => pow_is_integer(base, exp, env)
    @symcore.Expr::Function(name, args) => function_is_integer(name, args, env)
  }
}

///|
pub fn is_rational(expr : @symcore.Expr, env? : AssumeEnv = {}) -> Tri {
  match expr {
    @symcore.Expr::Number(_) => Tri::True
    @symcore.Expr::Symbol(name) => env_get(env, name).is_rational
    @symcore.Expr::Add(args) | @symcore.Expr::Mul(args) =>
      all_predicate(args, child => is_rational(child, env~))
    @symcore.Expr::Pow(base, exp) => pow_is_rational(base, exp, env)
    @symcore.Expr::Function(name, args) => function_is_rational(name, args, env)
  }
}

///|
pub fn is_real(expr : @symcore.Expr, env? : AssumeEnv = {}) -> Tri {
  match expr {
    @symcore.Expr::Number(_) => Tri::True
    @symcore.Expr::Symbol(name) => env_get(env, name).is_real
    @symcore.Expr::Add(args) | @symcore.Expr::Mul(args) =>
      all_predicate(args, child => is_real(child, env~))
    @symcore.Expr::Pow(base, exp) => pow_is_real(base, exp, env)
    @symcore.Expr::Function(name, args) => function_is_real(name, args, env)
  }
}

///|
pub fn is_positive(expr : @symcore.Expr, env? : AssumeEnv = {}) -> Tri {
  match expr {
    @symcore.Expr::Number(n) => tri_of_bool(n.compare(@symnum.BigRational::zero()) > 0)
    @symcore.Expr::Symbol(name) => env_get(env, name).is_positive
    @symcore.Expr::Add(args) => add_is_positive(args, env)
    @symcore.Expr::Mul(args) => mul_is_positive(args, env)
    @symcore.Expr::Pow(base, exp) => pow_is_positive(base, exp, env)
    @symcore.Expr::Function(name, args) => function_is_positive(name, args, env)
  }
}

///|
pub fn is_nonnegative(expr : @symcore.Expr, env? : AssumeEnv = {}) -> Tri {
  match expr {
    @symcore.Expr::Number(n) =>
      tri_of_bool(n.compare(@symnum.BigRational::zero()) >= 0)
    @symcore.Expr::Symbol(name) => env_get(env, name).is_nonnegative
    @symcore.Expr::Add(args) => add_is_nonnegative(args, env)
    @symcore.Expr::Mul(args) => mul_is_nonnegative(args, env)
    @symcore.Expr::Pow(base, exp) => pow_is_nonnegative(base, exp, env)
    @symcore.Expr::Function(name, args) =>
      function_is_nonnegative(name, args, env)
  }
}

///|
fn all_predicate(
  args : Array[@symcore.Expr],
  pred : (@symcore.Expr) -> Tri,
) -> Tri {
  let mut saw_unknown = false
  for arg in args {
    match pred(arg) {
      Tri::False => return Tri::False
      Tri::Unknown => saw_unknown = true
      Tri::True => ()
    }
  }
  if saw_unknown {
    Tri::Unknown
  } else {
    Tri::True
  }
}

///|
fn add_is_zero(args : Array[@symcore.Expr], env : AssumeEnv) -> Tri {
  if args.is_empty() {
    return Tri::True
  }
  if args.length() == 1 {
    return is_zero(args[0], env=env)
  }
  let mut nonzero_count = 0
  let mut all_zero = true
  let mut all_zero_or_nonzero = true
  for arg in args {
    let z = is_zero(arg, env=env)
    let nz = is_nonzero(arg, env=env)
    match z {
      Tri::True => ()
      Tri::False => all_zero = false
      Tri::Unknown => {
        all_zero = false
        all_zero_or_nonzero = false
      }
    }
    match nz {
      Tri::True => nonzero_count += 1
      Tri::False => ()
      Tri::Unknown => all_zero_or_nonzero = false
    }
  }
  if all_zero {
    Tri::True
  } else if nonzero_count == 1 && all_zero_or_nonzero {
    Tri::False
  } else {
    Tri::Unknown
  }
}

///|
fn mul_is_zero(args : Array[@symcore.Expr], env : AssumeEnv) -> Tri {
  let mut all_nonzero = true
  for arg in args {
    match is_zero(arg, env=env) {
      Tri::True => return Tri::True
      Tri::False => ()
      Tri::Unknown => ()
    }
    if is_nonzero(arg, env=env) != Tri::True {
      all_nonzero = false
    }
  }
  if all_nonzero {
    Tri::False
  } else {
    Tri::Unknown
  }
}

///|
fn pow_is_zero(base : @symcore.Expr, exp : @symcore.Expr, env : AssumeEnv) -> Tri {
  match exp {
    @symcore.Expr::Number(n) if n.is_zero() => return Tri::False
    _ => ()
  }
  if is_zero(base, env=env) == Tri::True && is_positive(exp, env=env) == Tri::True {
    Tri::True
  } else if is_nonzero(base, env=env) == Tri::True {
    Tri::False
  } else {
    Tri::Unknown
  }
}

///|
fn add_is_nonzero(args : Array[@symcore.Expr], env : AssumeEnv) -> Tri {
  if args.is_empty() {
    return Tri::False
  }
  if args.length() == 1 {
    return is_nonzero(args[0], env=env)
  }
  let mut nonzero_count = 0
  let mut all_zero = true
  let mut all_zero_or_nonzero = true
  for arg in args {
    let z = is_zero(arg, env=env)
    let nz = is_nonzero(arg, env=env)
    match z {
      Tri::True => ()
      Tri::False => all_zero = false
      Tri::Unknown => {
        all_zero = false
        all_zero_or_nonzero = false
      }
    }
    match nz {
      Tri::True => nonzero_count += 1
      Tri::False => ()
      Tri::Unknown => all_zero_or_nonzero = false
    }
  }
  if all_zero {
    Tri::False
  } else if nonzero_count == 1 && all_zero_or_nonzero {
    Tri::True
  } else {
    Tri::Unknown
  }
}

///|
fn mul_is_nonzero(args : Array[@symcore.Expr], env : AssumeEnv) -> Tri {
  let mut saw_unknown = false
  for arg in args {
    match is_nonzero(arg, env=env) {
      Tri::True => ()
      Tri::False => return Tri::False
      Tri::Unknown => saw_unknown = true
    }
  }
  if saw_unknown {
    Tri::Unknown
  } else {
    Tri::True
  }
}

///|
fn pow_is_nonzero(
  base : @symcore.Expr,
  exp : @symcore.Expr,
  env : AssumeEnv,
) -> Tri {
  match exp {
    @symcore.Expr::Number(n) if n.is_zero() => return Tri::True
    _ => ()
  }
  if is_nonzero(base, env=env) == Tri::True {
    Tri::True
  } else if is_zero(base, env=env) == Tri::True && is_positive(exp, env=env) == Tri::True {
    Tri::False
  } else {
    Tri::Unknown
  }
}

///|
fn pow_is_integer(base : @symcore.Expr, exp : @symcore.Expr, env : AssumeEnv) -> Tri {
  let exp_is_integer = is_integer(exp, env=env)
  if exp_is_integer == Tri::False {
    return Tri::False
  }
  let base_is_integer = is_integer(base, env=env)
  match nonnegative_integer_literal(exp) {
    Some(true) =>
      if base_is_integer == Tri::True {
        Tri::True
      } else if base_is_integer == Tri::False {
        Tri::False
      } else {
        Tri::Unknown
      }
    Some(false) =>
      if base_is_integer == Tri::True && is_nonzero(base, env=env) == Tri::True {
        Tri::Unknown
      } else {
        Tri::Unknown
      }
    None => Tri::Unknown
  }
}

///|
fn pow_is_rational(
  base : @symcore.Expr,
  exp : @symcore.Expr,
  env : AssumeEnv,
) -> Tri {
  if is_integer(exp, env=env) == Tri::False {
    return Tri::False
  }
  let base_is_rational = is_rational(base, env=env)
  if base_is_rational == Tri::False {
    return Tri::False
  }
  match nonnegative_integer_literal(exp) {
    Some(true) => base_is_rational
    Some(false) =>
      if base_is_rational == Tri::True && is_nonzero(base, env=env) == Tri::True {
        Tri::True
      } else {
        Tri::Unknown
      }
    None => Tri::Unknown
  }
}

///|
fn pow_is_real(base : @symcore.Expr, exp : @symcore.Expr, env : AssumeEnv) -> Tri {
  let base_real = is_real(base, env=env)
  if base_real == Tri::False {
    return Tri::False
  }
  if is_integer(exp, env=env) == Tri::True {
    match nonnegative_integer_literal(exp) {
      Some(true) => base_real
      Some(false) =>
        if base_real == Tri::True && is_nonzero(base, env=env) == Tri::True {
          Tri::True
        } else {
          Tri::Unknown
        }
      None => Tri::Unknown
    }
  } else {
    Tri::Unknown
  }
}

///|
fn add_is_positive(args : Array[@symcore.Expr], env : AssumeEnv) -> Tri {
  if args.is_empty() {
    return Tri::False
  }
  let mut all_nonnegative = true
  let mut any_positive = false
  let mut all_zero = true
  for arg in args {
    let nn = is_nonnegative(arg, env=env)
    let p = is_positive(arg, env=env)
    let z = is_zero(arg, env=env)
    if nn != Tri::True {
      all_nonnegative = false
    }
    if p == Tri::True {
      any_positive = true
    }
    if z != Tri::True {
      all_zero = false
    }
  }
  if all_zero {
    Tri::False
  } else if all_nonnegative && any_positive {
    Tri::True
  } else {
    Tri::Unknown
  }
}

///|
fn mul_is_positive(args : Array[@symcore.Expr], env : AssumeEnv) -> Tri {
  if args.is_empty() {
    return Tri::True
  }
  let mut all_positive = true
  let mut all_nonnegative = true
  let mut all_nonzero = true
  for arg in args {
    if is_zero(arg, env=env) == Tri::True {
      return Tri::False
    }
    if is_positive(arg, env=env) != Tri::True {
      all_positive = false
    }
    if is_nonnegative(arg, env=env) != Tri::True {
      all_nonnegative = false
    }
    if is_nonzero(arg, env=env) != Tri::True {
      all_nonzero = false
    }
  }
  if all_positive {
    Tri::True
  } else if all_nonnegative && all_nonzero {
    Tri::True
  } else {
    Tri::Unknown
  }
}

///|
fn pow_is_positive(
  base : @symcore.Expr,
  exp : @symcore.Expr,
  env : AssumeEnv,
) -> Tri {
  match exp {
    @symcore.Expr::Number(n) if n.is_zero() => return Tri::True
    _ => ()
  }
  if is_positive(base, env=env) == Tri::True {
    return Tri::True
  }
  match even_integer_literal(exp) {
    Some(true) =>
      if is_real(base, env=env) == Tri::True && is_nonzero(base, env=env) == Tri::True {
        Tri::True
      } else if is_zero(base, env=env) == Tri::True {
        Tri::False
      } else {
        Tri::Unknown
      }
    Some(false) =>
      if is_positive(base, env=env) == Tri::True {
        Tri::True
      } else {
        Tri::Unknown
      }
    None => Tri::Unknown
  }
}

///|
fn add_is_nonnegative(args : Array[@symcore.Expr], env : AssumeEnv) -> Tri {
  if args.is_empty() {
    return Tri::True
  }
  let mut all_nonnegative = true
  let mut all_zero = true
  for arg in args {
    let nn = is_nonnegative(arg, env=env)
    let z = is_zero(arg, env=env)
    if nn != Tri::True {
      all_nonnegative = false
    }
    if z != Tri::True {
      all_zero = false
    }
  }
  if all_nonnegative || all_zero {
    Tri::True
  } else {
    Tri::Unknown
  }
}

///|
fn mul_is_nonnegative(args : Array[@symcore.Expr], env : AssumeEnv) -> Tri {
  if args.is_empty() {
    return Tri::True
  }
  let mut all_nonnegative = true
  for arg in args {
    if is_zero(arg, env=env) == Tri::True {
      return Tri::True
    }
    if is_nonnegative(arg, env=env) != Tri::True {
      all_nonnegative = false
    }
  }
  if all_nonnegative {
    Tri::True
  } else {
    Tri::Unknown
  }
}

///|
fn pow_is_nonnegative(
  base : @symcore.Expr,
  exp : @symcore.Expr,
  env : AssumeEnv,
) -> Tri {
  match exp {
    @symcore.Expr::Number(n) if n.is_zero() => return Tri::True
    _ => ()
  }
  match even_integer_literal(exp) {
    Some(true) =>
      if is_real(base, env=env) == Tri::True {
        Tri::True
      } else {
        Tri::Unknown
      }
    _ =>
      if is_nonnegative(base, env=env) == Tri::True &&
        nonnegative_integer_or_unknown(exp, env) != Tri::False {
        Tri::True
      } else if is_positive(base, env=env) == Tri::True {
        Tri::True
      } else {
        Tri::Unknown
      }
  }
}

///|
fn function_is_zero(
  name : String,
  args : Array[@symcore.Expr],
  env : AssumeEnv,
) -> Tri {
  match (name, args.length()) {
    ("exp", 1) => Tri::False
    ("Abs", 1) | ("abs", 1) => is_zero(args[0], env=env)
    ("sqrt", 1) => is_zero(args[0], env=env)
    _ => Tri::Unknown
  }
}

///|
fn function_is_nonzero(
  name : String,
  args : Array[@symcore.Expr],
  env : AssumeEnv,
) -> Tri {
  match (name, args.length()) {
    ("exp", 1) => Tri::True
    ("Abs", 1) | ("abs", 1) => is_nonzero(args[0], env=env)
    ("sqrt", 1) => is_nonzero(args[0], env=env)
    _ => Tri::Unknown
  }
}

///|
fn function_is_integer(
  name : String,
  args : Array[@symcore.Expr],
  env : AssumeEnv,
) -> Tri {
  match (name, args.length()) {
    ("floor", 1) | ("ceiling", 1) => Tri::True
    ("Abs", 1) | ("abs", 1) => is_integer(args[0], env=env)
    _ => Tri::Unknown
  }
}

///|
fn function_is_rational(
  name : String,
  args : Array[@symcore.Expr],
  env : AssumeEnv,
) -> Tri {
  match (name, args.length()) {
    ("Abs", 1) | ("abs", 1) => is_rational(args[0], env=env)
    _ => Tri::Unknown
  }
}

///|
fn function_is_real(
  name : String,
  args : Array[@symcore.Expr],
  env : AssumeEnv,
) -> Tri {
  match (name, args.length()) {
    ("Abs", 1) | ("abs", 1) => Tri::True
    ("sqrt", 1) =>
      if is_nonnegative(args[0], env=env) == Tri::True {
        Tri::True
      } else {
        Tri::Unknown
      }
    ("log", 1) =>
      if is_positive(args[0], env=env) == Tri::True {
        Tri::True
      } else {
        Tri::Unknown
      }
    ("exp", 1) =>
      if is_real(args[0], env=env) == Tri::True {
        Tri::True
      } else {
        Tri::Unknown
      }
    ("sin", 1) | ("cos", 1) | ("tan", 1) => is_real(args[0], env=env)
    ("re", 1) | ("im", 1) => Tri::True
    _ => Tri::Unknown
  }
}

///|
fn function_is_positive(
  name : String,
  args : Array[@symcore.Expr],
  env : AssumeEnv,
) -> Tri {
  match (name, args.length()) {
    ("exp", 1) =>
      if is_real(args[0], env=env) == Tri::True {
        Tri::True
      } else {
        Tri::Unknown
      }
    ("Abs", 1) | ("abs", 1) =>
      if is_nonzero(args[0], env=env) == Tri::True {
        Tri::True
      } else if is_zero(args[0], env=env) == Tri::True {
        Tri::False
      } else {
        Tri::Unknown
      }
    ("sqrt", 1) =>
      if is_positive(args[0], env=env) == Tri::True {
        Tri::True
      } else if is_zero(args[0], env=env) == Tri::True {
        Tri::False
      } else {
        Tri::Unknown
      }
    _ => Tri::Unknown
  }
}

///|
fn function_is_nonnegative(
  name : String,
  args : Array[@symcore.Expr],
  env : AssumeEnv,
) -> Tri {
  match (name, args.length()) {
    ("Abs", 1) | ("abs", 1) => Tri::True
    ("sqrt", 1) =>
      if is_nonnegative(args[0], env=env) == Tri::True {
        Tri::True
      } else {
        Tri::Unknown
      }
    ("exp", 1) =>
      if is_real(args[0], env=env) == Tri::True {
        Tri::True
      } else {
        Tri::Unknown
      }
    _ => Tri::Unknown
  }
}

///|
fn even_integer_literal(expr : @symcore.Expr) -> Bool? {
  match expr {
    @symcore.Expr::Number(n) if n.is_integral() => {
      let two = BigInt::from_int(2)
      Some(n.numerator().mod(two).is_zero())
    }
    _ => None
  }
}

///|
fn nonnegative_integer_literal(expr : @symcore.Expr) -> Bool? {
  match expr {
    @symcore.Expr::Number(n) if n.is_integral() =>
      Some(n.numerator().compare(BigInt::from_int(0)) >= 0)
    _ => None
  }
}

///|
fn nonnegative_integer_or_unknown(expr : @symcore.Expr, env : AssumeEnv) -> Tri {
  match nonnegative_integer_literal(expr) {
    Some(true) => Tri::True
    Some(false) => Tri::False
    None =>
      if is_integer(expr, env=env) == Tri::True {
        Tri::Unknown
      } else {
        Tri::False
      }
  }
}
