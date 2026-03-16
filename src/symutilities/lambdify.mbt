///|\
/// Numeric evaluator aligned with the most common `sympy.utilities.lambdify`
/// use-case: turning a symbolic scalar expression into a callable.

///|
pub struct LambdaFn {
  args : Array[String]
  expr : @symcore.Expr
} derive(Eq)

///|
fn expr_number_to_double(n : @symnum.BigRational) -> Double {
  let num = try! @strconv.parse_double(n.numerator().to_string())
  let den = try! @strconv.parse_double(n.denominator().to_string())
  num / den
}

///|
fn eval_double(
  expr : @symcore.Expr,
  env : Map[String, Double],
) -> Double raise UtilitiesError {
  match expr {
    @symcore.Expr::Number(n) => expr_number_to_double(n)
    @symcore.Expr::Symbol(name) =>
      match env.get(name) {
        Some(v) => v
        None =>
          raise UtilitiesError::MissingValue(
            "missing numeric value for " + name,
          )
      }
    @symcore.Expr::Add(args) => {
      let mut acc = 0.0
      for arg in args {
        acc += eval_double(arg, env)
      }
      acc
    }
    @symcore.Expr::Mul(args) => {
      let mut acc = 1.0
      for arg in args {
        acc *= eval_double(arg, env)
      }
      acc
    }
    @symcore.Expr::Pow(base, exp) =>
      @math.pow(eval_double(base, env), eval_double(exp, env))
    @symcore.Expr::Function(name, args) => {
      let vals = args.map(arg => eval_double(arg, env))
      match (name, vals) {
        ("sin", [x]) => @math.sin(x)
        ("cos", [x]) => @math.cos(x)
        ("tan", [x]) => @math.tan(x)
        ("asin", [x]) => @math.asin(x)
        ("acos", [x]) => @math.acos(x)
        ("atan", [x]) => @math.atan(x)
        ("exp", [x]) => @math.exp(x)
        ("log", [x]) => @math.ln(x)
        ("sqrt", [x]) => @math.pow(x, 0.5)
        ("Abs", [x]) => x.abs()
        ("abs", [x]) => x.abs()
        ("sinh", [x]) => @math.sinh(x)
        ("cosh", [x]) => @math.cosh(x)
        ("asinh", [x]) => @math.asinh(x)
        ("acosh", [x]) => @math.acosh(x)
        _ =>
          raise UtilitiesError::Unsupported(
            "lambdify does not yet support function " + name,
          )
      }
    }
  }
}

///|
pub fn lambdify(args : Array[String], expr : @symcore.Expr) -> LambdaFn {
  { args: args.map(x => x), expr }
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
