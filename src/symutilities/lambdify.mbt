///|\
/// Numeric evaluator aligned with the most common `sympy.utilities.lambdify`
/// use-case: turning a symbolic scalar expression into a callable.

///|
pub struct LambdaFn {
  args : Array[String]
  expr : Expr
} derive(Eq)

///|
pub struct ImplementedFunction {
  name : String
} derive(Eq)

///|
let implemented_registry : Ref[Map[String, (Array[Double]) -> Double]] = {
  val: {},
}

///|
fn expr_number_to_double(n : @symnum.BigRational) -> Double {
  let num = try! @strconv.parse_double(n.numerator().to_string())
  let den = try! @strconv.parse_double(n.denominator().to_string())
  num / den
}

///|
fn eval_builtin_function(name : String, vals : Array[Double]) -> Double? {
  match (name, vals) {
    ("sin", [x]) => Some(@math.sin(x))
    ("cos", [x]) => Some(@math.cos(x))
    ("tan", [x]) => Some(@math.tan(x))
    ("asin", [x]) => Some(@math.asin(x))
    ("acos", [x]) => Some(@math.acos(x))
    ("atan", [x]) => Some(@math.atan(x))
    ("exp", [x]) => Some(@math.exp(x))
    ("log", [x]) => Some(@math.ln(x))
    ("sqrt", [x]) => Some(@math.pow(x, 0.5))
    ("Abs", [x]) => Some(x.abs())
    ("abs", [x]) => Some(x.abs())
    ("sinh", [x]) => Some(@math.sinh(x))
    ("cosh", [x]) => Some(@math.cosh(x))
    ("tanh", [x]) => Some(@math.tanh(x))
    ("asinh", [x]) => Some(@math.asinh(x))
    ("acosh", [x]) => Some(@math.acosh(x))
    ("atanh", [x]) => Some(@math.atanh(x))
    ("Min", [x, y]) => Some(if x < y { x } else { y })
    ("Max", [x, y]) => Some(if x > y { x } else { y })
    _ => None
  }
}

///|
fn eval_double(
  expr : Expr,
  env : Map[String, Double],
) -> Double raise UtilitiesError {
  match expr {
    Expr::Number(n) => expr_number_to_double(n)
    Expr::Symbol(name) =>
      match env.get(name) {
        Some(v) => v
        None =>
          raise UtilitiesError::MissingValue(
            "missing numeric value for " + name,
          )
      }
    Expr::Add(args) => {
      let mut acc = 0.0
      for arg in args {
        acc += eval_double(arg, env)
      }
      acc
    }
    Expr::Mul(args) => {
      let mut acc = 1.0
      for arg in args {
        acc *= eval_double(arg, env)
      }
      acc
    }
    Expr::Pow(base, exp) =>
      @math.pow(eval_double(base, env), eval_double(exp, env))
    Expr::Function(name, args) => {
      let vals = args.map(arg => eval_double(arg, env))
      match eval_builtin_function(name, vals) {
        Some(value) => value
        None =>
          match implemented_registry.val.get(name) {
            Some(imp) => imp(vals)
            None =>
              raise UtilitiesError::Unsupported(
                "lambdify does not yet support function " + name,
              )
          }
      }
    }
  }
}

///|
pub fn lambdify(args : Array[String], expr : Expr) -> LambdaFn {
  { args: args.map(x => x), expr }
}

///|
fn lambdastr_prec(expr : Expr, parent_prec : Int) -> String {
  let current_prec = match expr {
    Expr::Add(_) => 0
    Expr::Mul(_) => 1
    Expr::Pow(_, _) => 2
    Expr::Number(_)
    | Expr::Symbol(_)
    | Expr::Function(_, _) => 3
  }
  let text = match expr {
    Expr::Number(n) =>
      if n.denominator().to_string() == "1" {
        n.numerator().to_string()
      } else {
        "(" +
        n.numerator().to_string() +
        "/" +
        n.denominator().to_string() +
        ")"
      }
    Expr::Symbol(name) => name
    Expr::Add(args) =>
      args.map(arg => lambdastr_prec(arg, current_prec)).join(" + ")
    Expr::Mul(args) =>
      args.map(arg => lambdastr_prec(arg, current_prec)).join("*")
    Expr::Pow(base, exp) =>
      lambdastr_prec(base, current_prec) +
      "**" +
      lambdastr_prec(exp, current_prec)
    Expr::Function(name, args) =>
      name + "(" + args.map(arg => lambdastr_prec(arg, 0)).join(", ") + ")"
  }
  if current_prec < parent_prec {
    "(" + text + ")"
  } else {
    text
  }
}

///|
pub fn lambdastr(args : Array[String], expr : Expr) -> String {
  "lambda " + args.join(", ") + ": " + lambdastr_prec(expr, 0)
}

///|
pub fn implemented_function(
  name : String,
  implementation : (Array[Double]) -> Double,
) -> ImplementedFunction {
  implemented_registry.val[name] = implementation
  { name, }
}

///|
pub fn ImplementedFunction::apply(
  self : ImplementedFunction,
  args : Array[Expr],
) -> Expr {
  @symcore.function(self.name, args)
}

///|
pub fn LambdaFn::call(
  self : LambdaFn,
  values : Array[Double],
) -> Double raise UtilitiesError {
  if values.length() != self.args.length() {
    raise UtilitiesError::InvalidArgument("lambdify argument count mismatch")
  }
  let env : Map[String, Double] = {}
  for i in 0..<self.args.length() {
    env[self.args[i]] = values[i]
  }
  eval_double(self.expr, env)
}

///|
pub fn LambdaFn::call_map(
  self : LambdaFn,
  values : Map[String, Double],
) -> Double raise UtilitiesError {
  eval_double(self.expr, values)
}
