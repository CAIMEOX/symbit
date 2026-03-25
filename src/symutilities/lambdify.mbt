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
let implemented_registry : Ref[
  Map[String, (Array[Double]) -> Double raise UtilitiesError],
] = { val: {} }

///|
fn expr_number_to_double(
  n : @symnum.BigRational,
) -> Double raise UtilitiesError {
  let num = @strconv.parse_double(n.numerator().to_string()) catch {
    _ =>
      raise UtilitiesError::InvalidArgument("cannot parse rational numerator")
  }
  let den = @strconv.parse_double(n.denominator().to_string()) catch {
    _ =>
      raise UtilitiesError::InvalidArgument("cannot parse rational denominator")
  }
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
  match @symcore.expr_form(expr) {
    @symcore.ExprForm::Number(n) => expr_number_to_double(n)
    @symcore.ExprForm::Float(value) =>
      value.to_double() catch {
        _ =>
          raise UtilitiesError::InvalidArgument(
            "cannot convert floating constant to Double",
          )
      }
    @symcore.ExprForm::ComplexFloat(value) =>
      if @symnum.is_zero(value.to_mpc().imag) {
        @symcore.Float::from_mpf(value.to_mpc().real, prec=value.precision()).to_double() catch {
          _ =>
            raise UtilitiesError::InvalidArgument(
              "cannot convert real complex constant to Double",
            )
        }
      } else {
        raise UtilitiesError::Unsupported(
          "lambdify does not yet support non-real complex constants",
        )
      }
    @symcore.ExprForm::Symbol(name) =>
      match env.get(name) {
        Some(v) => v
        None =>
          raise UtilitiesError::MissingValue(
            "missing numeric value for " + name,
          )
      }
    @symcore.ExprForm::Add(args) => {
      let mut acc = 0.0
      for arg in args {
        acc += eval_double(arg, env)
      }
      acc
    }
    @symcore.ExprForm::Mul(args) => {
      let mut acc = 1.0
      for arg in args {
        acc *= eval_double(arg, env)
      }
      acc
    }
    @symcore.ExprForm::Pow(base, exp) =>
      @math.pow(eval_double(base, env), eval_double(exp, env))
    @symcore.ExprForm::Applied(name, args) => {
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
    _ =>
      raise UtilitiesError::Unsupported(
        "lambdify does not yet support expression " + @symprint.to_string(expr),
      )
  }
}

///|
pub fn lambdify(args : Array[String], expr : Expr) -> LambdaFn {
  { args: args.map(x => x), expr }
}

///|
fn lambdastr_prec(expr : Expr, parent_prec : Int) -> String {
  let current_prec = match @symcore.expr_form(expr) {
    @symcore.ExprForm::Add(_) => 0
    @symcore.ExprForm::Mul(_) => 1
    @symcore.ExprForm::Pow(_, _) => 2
    _ => 3
  }
  let text = match @symcore.expr_form(expr) {
    @symcore.ExprForm::Number(n) =>
      if n.denominator().to_string() == "1" {
        n.numerator().to_string()
      } else {
        "(" +
        n.numerator().to_string() +
        "/" +
        n.denominator().to_string() +
        ")"
      }
    @symcore.ExprForm::Float(value) => value.format()
    @symcore.ExprForm::ComplexFloat(value) =>
      if @symnum.is_zero(value.to_mpc().imag) {
        @symcore.Float::from_mpf(value.to_mpc().real, prec=value.precision()).format()
      } else {
        value.format()
      }
    @symcore.ExprForm::Symbol(name) => name
    @symcore.ExprForm::Boolean(true) => "True"
    @symcore.ExprForm::Boolean(false) => "False"
    @symcore.ExprForm::Add(args) =>
      args.map(arg => lambdastr_prec(arg, current_prec)).join(" + ")
    @symcore.ExprForm::Mul(args) =>
      args.map(arg => lambdastr_prec(arg, current_prec)).join("*")
    @symcore.ExprForm::Pow(base, exp) =>
      lambdastr_prec(base, current_prec) +
      "**" +
      lambdastr_prec(exp, current_prec)
    @symcore.ExprForm::Tuple(args) =>
      "(" + args.map(arg => lambdastr_prec(arg, 0)).join(", ") + ")"
    @symcore.ExprForm::Relational(op, lhs, rhs) => {
      let symbol = match op {
        @symcore.RelOp::Eq => "=="
        @symcore.RelOp::Ne => "!="
        @symcore.RelOp::Lt => "<"
        @symcore.RelOp::Le => "<="
        @symcore.RelOp::Gt => ">"
        @symcore.RelOp::Ge => ">="
      }
      lambdastr_prec(lhs, 0) + " " + symbol + " " + lambdastr_prec(rhs, 0)
    }
    @symcore.ExprForm::Applied(name, args) =>
      name + "(" + args.map(arg => lambdastr_prec(arg, 0)).join(", ") + ")"
    _ => @symprint.to_string(expr)
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
  implementation : (Array[Double]) -> Double raise UtilitiesError,
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
