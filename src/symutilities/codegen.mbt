///|
/// Lightweight routine/code-generation helpers aligned with the high-value
/// scalar surface of `sympy.utilities.codegen`.
///
/// This implementation targets Symbit's minimal `Expr` core.  It covers the
/// friendly `codegen` workflow, a generic `Routine` description, and concrete
/// emitters for C, Julia, Octave, and Rust source strings.

///|
pub enum TargetLanguage {
  C89
  C99
  Julia
  Octave
  Rust
} derive(Eq, Show)

///|
pub struct RoutineResult {
  name : String
  expr : Expr
} derive(Eq)

///|
pub struct Routine {
  name : String
  arguments : Array[String]
  results : Array[RoutineResult]
} derive(Eq)

///|
pub struct CodeGenerator {
  language : TargetLanguage
} derive(Eq)

///|
/// Construct a scalar routine result.
pub fn routine_result(name : String, expr : Expr) -> RoutineResult {
  { name, expr }
}

///|
fn sort_unique_symbols(values : Array[String]) -> Array[String] {
  let out : Array[String] = []
  for value in values {
    if !out.contains(value) {
      out.push(value)
    }
  }
  out.sort()
  out
}

///|
fn string_lower(value : String) -> String {
  let chars : Array[Char] = []
  for c in value {
    chars.push(c.to_ascii_lowercase())
  }
  String::from_array(chars)
}

///|
fn string_upper(value : String) -> String {
  let chars : Array[Char] = []
  for c in value {
    chars.push(c.to_ascii_uppercase())
  }
  String::from_array(chars)
}

///|
fn free_symbols(expr : Expr) -> Array[String] {
  match @symcore.expr_form(expr) {
    @symcore.ExprForm::Number(_)
    | @symcore.ExprForm::Float(_)
    | @symcore.ExprForm::ComplexFloat(_)
    | @symcore.ExprForm::Boolean(_) => []
    @symcore.ExprForm::Symbol(name) => [name]
    @symcore.ExprForm::Add(args)
    | @symcore.ExprForm::Mul(args)
    | @symcore.ExprForm::Tuple(args)
    | @symcore.ExprForm::Applied(_, args) => {
      let out : Array[String] = []
      for arg in args {
        for name in free_symbols(arg) {
          out.push(name)
        }
      }
      sort_unique_symbols(out)
    }
    @symcore.ExprForm::Pow(base, exp) =>
      sort_unique_symbols(free_symbols(base) + free_symbols(exp))
    @symcore.ExprForm::Relational(_, lhs, rhs) =>
      sort_unique_symbols(free_symbols(lhs) + free_symbols(rhs))
    @symcore.ExprForm::Derivative(inner, deriv_args) => {
      let out = free_symbols(inner)
      for arg in deriv_args {
        for name in free_symbols(arg) {
          out.push(name)
        }
      }
      sort_unique_symbols(out)
    }
    @symcore.ExprForm::Subs(inner, variable, value) =>
      sort_unique_symbols(
        free_symbols(inner) + free_symbols(variable) + free_symbols(value),
      )
    @symcore.ExprForm::Lambda(vars, body) =>
      sort_unique_symbols(free_symbols(vars) + free_symbols(body))
  }
}

///|
fn expr_float_to_code(value : @symcore.Float) -> String {
  value.format()
}

///|
fn expr_complex_float_to_code(
  value : @symcore.ComplexFloat,
  language : TargetLanguage,
) -> String raise UtilitiesError {
  let mpc = value.to_mpc()
  if @symnum.is_zero(mpc.imag) {
    return @symcore.Float::from_mpf(mpc.real, prec=value.precision()).format()
  }
  match language {
    TargetLanguage::Julia | TargetLanguage::Octave => value.format()
    _ =>
      raise UtilitiesError::Unsupported(
        "codegen does not support complex floating literals for this target",
      )
  }
}

///|
fn print_relational_expr(
  op : @symcore.RelOp,
  lhs : Expr,
  rhs : Expr,
  language : TargetLanguage,
) -> String raise UtilitiesError {
  let symbol = match op {
    @symcore.RelOp::Eq => "=="
    @symcore.RelOp::Ne => "!="
    @symcore.RelOp::Lt => "<"
    @symcore.RelOp::Le => "<="
    @symcore.RelOp::Gt => ">"
    @symcore.RelOp::Ge => ">="
  }
  print_expr_prec(lhs, language, 0) +
  " " +
  symbol +
  " " +
  print_expr_prec(rhs, language, 0)
}

///|
fn print_derivative_expr(expr : Expr) -> String raise UtilitiesError {
  raise UtilitiesError::Unsupported(
    "codegen does not support derivative expressions yet: " +
    @symprint.to_string(expr),
  )
}

///|
fn print_lambda_like_expr(expr : Expr) -> String raise UtilitiesError {
  raise UtilitiesError::Unsupported(
    "codegen does not support higher-order expressions yet: " +
    @symprint.to_string(expr),
  )
}

///|
fn print_expr_prec(
  expr : Expr,
  language : TargetLanguage,
  parent_prec : Int,
) -> String raise UtilitiesError {
  match @symcore.expr_form(expr) {
    @symcore.ExprForm::Number(n) => expr_number_to_code(n)
    @symcore.ExprForm::Float(value) => expr_float_to_code(value)
    @symcore.ExprForm::ComplexFloat(value) =>
      expr_complex_float_to_code(value, language)
    @symcore.ExprForm::Symbol(name) => sanitize_name(name, language)
    @symcore.ExprForm::Boolean(true) => "true"
    @symcore.ExprForm::Boolean(false) => "false"
    @symcore.ExprForm::Add(args) => {
      let text = args.map(arg => print_expr_prec(arg, language, 0)).join(" + ")
      parenthesize_if_needed(text, 0, parent_prec)
    }
    @symcore.ExprForm::Mul(args) => {
      let text = args.map(arg => print_expr_prec(arg, language, 1)).join("*")
      parenthesize_if_needed(text, 1, parent_prec)
    }
    @symcore.ExprForm::Pow(base, exp) => {
      let text = match language {
        TargetLanguage::Rust =>
          print_expr_prec(base, language, 3) +
          ".powf(" +
          print_expr_prec(exp, language, 0) +
          ")"
        _ =>
          "pow(" +
          print_expr_prec(base, language, 0) +
          ", " +
          print_expr_prec(exp, language, 0) +
          ")"
      }
      parenthesize_if_needed(text, 2, parent_prec)
    }
    @symcore.ExprForm::Tuple(args) =>
      "(" + args.map(arg => print_expr_prec(arg, language, 0)).join(", ") + ")"
    @symcore.ExprForm::Relational(op, lhs, rhs) =>
      parenthesize_if_needed(
        print_relational_expr(op, lhs, rhs, language),
        0,
        parent_prec,
      )
    @symcore.ExprForm::Derivative(_, _) => print_derivative_expr(expr)
    @symcore.ExprForm::Subs(_, _, _) | @symcore.ExprForm::Lambda(_, _) =>
      print_lambda_like_expr(expr)
    @symcore.ExprForm::Applied(name, args) =>
      print_function_name(name, language) +
      "(" +
      args.map(arg => print_expr_prec(arg, language, 0)).join(", ") +
      ")"
  }
}

///|
fn sanitize_name(name : String, language : TargetLanguage) -> String {
  let reserved = match language {
    TargetLanguage::C89 | TargetLanguage::C99 =>
      ["if", "while", "typedef", "return"]
    TargetLanguage::Julia => ["function", "end", "if"]
    TargetLanguage::Octave => ["function", "end", "if"]
    TargetLanguage::Rust => ["fn", "if", "while", "type", "return"]
  }
  if reserved.contains(name) {
    name + "_"
  } else {
    name
  }
}

///|
fn expr_number_to_code(n : @symnum.BigRational) -> String {
  if n.denominator().to_string() == "1" {
    n.numerator().to_string() + ".0"
  } else {
    n.numerator().to_string() + ".0/" + n.denominator().to_string() + ".0"
  }
}

///|
fn print_function_name(
  name : String,
  language : TargetLanguage,
) -> String raise UtilitiesError {
  match (language, name) {
    (_, "Abs") => "abs"
    (_, "abs") => "abs"
    (_, "sin") => "sin"
    (_, "cos") => "cos"
    (_, "tan") => "tan"
    (_, "asin") => "asin"
    (_, "acos") => "acos"
    (_, "atan") => "atan"
    (_, "exp") => "exp"
    (_, "log") => "log"
    (_, "sqrt") => "sqrt"
    (_, "sinh") => "sinh"
    (_, "cosh") => "cosh"
    (_, "tanh") => "tanh"
    (_, "asinh") => "asinh"
    (_, "acosh") => "acosh"
    (_, "atanh") => "atanh"
    _ =>
      raise UtilitiesError::Unsupported(
        "codegen does not support function " + name,
      )
  }
}

///|
fn parenthesize_if_needed(
  text : String,
  child_prec : Int,
  parent_prec : Int,
) -> String {
  if child_prec < parent_prec {
    "(" + text + ")"
  } else {
    text
  }
}

///|
fn print_expr(
  expr : Expr,
  language : TargetLanguage,
) -> String raise UtilitiesError {
  print_expr_prec(expr, language, 0)
}

///|
pub fn get_target_language(
  language : String,
) -> TargetLanguage raise UtilitiesError {
  match string_lower(language) {
    "c" => TargetLanguage::C99
    "c89" => TargetLanguage::C89
    "c99" => TargetLanguage::C99
    "julia" | "jl" => TargetLanguage::Julia
    "octave" | "matlab" | "m" => TargetLanguage::Octave
    "rust" | "rs" => TargetLanguage::Rust
    other =>
      raise UtilitiesError::Unsupported("unknown codegen language " + other)
  }
}

///|
pub fn make_routine(
  name : String,
  exprs : Array[RoutineResult],
  argument_sequence? : Array[String]? = None,
) -> Routine raise UtilitiesError {
  if exprs.is_empty() {
    raise UtilitiesError::InvalidArgument("routine needs at least one result")
  }
  let free : Array[String] = []
  for item in exprs {
    for symbol_name in free_symbols(item.expr) {
      free.push(symbol_name)
    }
  }
  let inferred = sort_unique_symbols(free)
  let arguments = match argument_sequence {
    Some(seq) => {
      let normalized = sort_unique_symbols(seq)
      for needed in inferred {
        if !normalized.contains(needed) {
          raise UtilitiesError::InvalidArgument(
            "symbols needed for output are not in input: " + needed,
          )
        }
      }
      seq
    }
    None => inferred
  }
  { name, arguments, results: exprs }
}

///|
pub fn get_code_generator(
  language : String,
) -> CodeGenerator raise UtilitiesError {
  { language: get_target_language(language) }
}

///|
fn c_header_guard(prefix : String) -> String {
  string_upper(prefix) + "__H"
}

///|
fn prototype(routine : Routine, language : TargetLanguage) -> String {
  let args = routine.arguments
    .map(arg => {
      let sanitized = sanitize_name(arg, language)
      match language {
        TargetLanguage::C89 | TargetLanguage::C99 => "double " + sanitized
        TargetLanguage::Julia | TargetLanguage::Octave => sanitized
        TargetLanguage::Rust => sanitized + ": f64"
      }
    })
    .join(", ")
  match language {
    TargetLanguage::C89 | TargetLanguage::C99 =>
      "double " + routine.name + "(" + args + ")"
    TargetLanguage::Julia => routine.name + "(" + args + ")"
    TargetLanguage::Octave => routine.name + "(" + args + ")"
    TargetLanguage::Rust => "fn " + routine.name + "(" + args + ") -> f64"
  }
}

///|
pub fn CodeGenerator::dump_source(
  self : CodeGenerator,
  routines : Array[Routine],
  prefix : String,
  header? : Bool = false,
  empty? : Bool = false,
) -> String raise UtilitiesError {
  ignore(header)
  let blocks : Array[String] = []
  match self.language {
    TargetLanguage::C89 | TargetLanguage::C99 => {
      blocks.push("#include \"" + prefix + ".h\"\n#include <math.h>\n")
      for routine in routines {
        let result = routine.results[0]
        let body = print_expr(result.expr, self.language)
        let block = [
          prototype(routine, self.language),
          " {\n",
          "   double ",
          result.name,
          ";\n",
          "   ",
          result.name,
          " = ",
          body,
          ";\n",
          "   return ",
          result.name,
          ";\n",
          "}\n",
        ].join("")
        blocks.push(block)
      }
    }
    TargetLanguage::Julia =>
      for routine in routines {
        let result = routine.results[0]
        let block = [
          "function ",
          prototype(routine, self.language),
          "\n    ",
          result.name,
          " = ",
          print_expr(result.expr, self.language),
          "\n    return ",
          result.name,
          "\nend\n",
        ].join("")
        blocks.push(block)
      }
    TargetLanguage::Octave =>
      for routine in routines {
        let result = routine.results[0]
        let block = [
          "function ",
          result.name,
          " = ",
          prototype(routine, self.language),
          "\n  ",
          result.name,
          " = ",
          print_expr(result.expr, self.language),
          ";\nend\n",
        ].join("")
        blocks.push(block)
      }
    TargetLanguage::Rust =>
      for routine in routines {
        let result = routine.results[0]
        let block = [
          prototype(routine, self.language),
          " {\n    let ",
          result.name,
          " = ",
          print_expr(result.expr, self.language),
          ";\n    ",
          result.name,
          "\n}\n",
        ].join("")
        blocks.push(block)
      }
  }
  let separator = if empty { "\n\n" } else { "" }
  blocks.join(separator)
}

///|
pub fn CodeGenerator::dump_header(
  self : CodeGenerator,
  routines : Array[Routine],
  prefix : String,
  header? : Bool = false,
) -> String {
  ignore(header)
  match self.language {
    TargetLanguage::C89 | TargetLanguage::C99 => {
      let macro_name = c_header_guard(prefix)
      let lines : Array[String] = [
        "#ifndef " + macro_name,
        "#define " + macro_name,
      ]
      for routine in routines {
        lines.push(prototype(routine, self.language) + ";")
      }
      lines.push("#endif")
      lines.join("\n") + "\n"
    }
    _ => ""
  }
}

///|
pub fn CodeGenerator::write(
  self : CodeGenerator,
  routines : Array[Routine],
  prefix : String,
  header? : Bool = false,
  empty? : Bool = false,
) -> Array[(String, String)] raise UtilitiesError {
  match self.language {
    TargetLanguage::C89 | TargetLanguage::C99 =>
      [
        (prefix + ".c", self.dump_source(routines, prefix, header~, empty~)),
        (prefix + ".h", self.dump_header(routines, prefix, header~)),
      ]
    TargetLanguage::Julia =>
      [(prefix + ".jl", self.dump_source(routines, prefix, header~, empty~))]
    TargetLanguage::Octave =>
      [(prefix + ".m", self.dump_source(routines, prefix, header~, empty~))]
    TargetLanguage::Rust =>
      [(prefix + ".rs", self.dump_source(routines, prefix, header~, empty~))]
  }
}

///|
/// Friendly scalar code-generation API.
///
/// Each `(name, expr)` pair becomes a routine named `name` returning a single
/// scalar `name_result` temporary.
pub fn codegen(
  entries : Array[(String, Expr)],
  language : String,
  prefix : String,
  header? : Bool = false,
  empty? : Bool = false,
) -> Array[(String, String)] raise UtilitiesError {
  let routines : Array[Routine] = []
  for entry in entries {
    let name = entry.0
    let expr = entry.1
    routines.push(make_routine(name, [routine_result(name + "_result", expr)]))
  }
  get_code_generator(language).write(routines, prefix, header~, empty~)
}
