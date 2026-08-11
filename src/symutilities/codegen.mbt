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
} derive(Eq, Debug)

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
  match @symcore.application_parts(expr) {
    Some((head, call_args)) => {
      let out = free_symbols(head)
      for arg in call_args {
        for name in free_symbols(arg) {
          out.push(name)
        }
      }
      return sort_unique_symbols(out)
    }
    None => ()
  }
  match @symcore.expr_form(expr) {
    Number(_) | Float(_) | ComplexFloat(_) | NumberSymbol(_) | Boolean(_) => []
    Symbol(name) => [name]
    Dummy(name, _) => [@symcore.dummy_display_name(name)]
    Wild(name, _, _) => [@symcore.wild_display_name(name)]
    FunctionHead(_) => []
    UndefinedFunction(_) => []
    Add(args) | Mul(args) | Tuple(args) => {
      let out : Array[String] = []
      for arg in args {
        for name in free_symbols(arg) {
          out.push(name)
        }
      }
      sort_unique_symbols(out)
    }
    Dict(items) => {
      let out : Array[String] = []
      for item in items {
        let (key, value) = item
        for name in free_symbols(key) {
          out.push(name)
        }
        for name in free_symbols(value) {
          out.push(name)
        }
      }
      sort_unique_symbols(out)
    }
    Pow(base, exp) =>
      sort_unique_symbols(free_symbols(base) + free_symbols(exp))
    Mod(lhs, rhs) => sort_unique_symbols(free_symbols(lhs) + free_symbols(rhs))
    Relational(_, lhs, rhs) =>
      sort_unique_symbols(free_symbols(lhs) + free_symbols(rhs))
    Derivative(inner, deriv_args) => {
      let out = free_symbols(inner)
      for arg in deriv_args {
        for name in free_symbols(arg) {
          out.push(name)
        }
      }
      sort_unique_symbols(out)
    }
    Subs(inner, variable, value) =>
      sort_unique_symbols(
        free_symbols(inner) + free_symbols(variable) + free_symbols(value),
      )
    Lambda(vars, body) =>
      sort_unique_symbols(free_symbols(vars) + free_symbols(body))
    _ => []
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
    Julia | Octave => value.format()
    _ =>
      raise Unsupported(
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
    Eq => "=="
    Ne => "!="
    Lt => "<"
    Le => "<="
    Gt => ">"
    Ge => ">="
  }
  print_expr_prec(lhs, language, 0) +
  " " +
  symbol +
  " " +
  print_expr_prec(rhs, language, 0)
}

///|
fn print_derivative_expr(expr : Expr) -> String raise UtilitiesError {
  raise Unsupported(
    "codegen does not support derivative expressions yet: " +
    @symprint.pretty_string(expr),
  )
}

///|
fn print_lambda_like_expr(expr : Expr) -> String raise UtilitiesError {
  raise Unsupported(
    "codegen does not support higher-order expressions yet: " +
    @symprint.pretty_string(expr),
  )
}

///|
fn print_expr_prec(
  expr : Expr,
  language : TargetLanguage,
  parent_prec : Int,
) -> String raise UtilitiesError {
  match @symcore.application_parts(expr) {
    Some((head, call_args)) =>
      match @symcore.function_head_name(head) {
        Some(name) => {
          let rendered = call_args
            .map(arg => print_expr_prec(arg, language, 5))
            .join(", ")
          return "\{sanitize_name(name, language)}(\{rendered})"
        }
        None =>
          return print_expr_prec(head, language, 5) +
            "(" +
            call_args.map(arg => print_expr_prec(arg, language, 0)).join(", ") +
            ")"
      }
    None => ()
  }
  match @symcore.expr_form(expr) {
    Number(n) => expr_number_to_code(n)
    Float(value) => expr_float_to_code(value)
    ComplexFloat(value) => expr_complex_float_to_code(value, language)
    NumberSymbol(kind) =>
      sanitize_name(@symcore.number_symbol_name(kind), language)
    Symbol(name) => sanitize_name(name, language)
    Dummy(name, _) => sanitize_name(@symcore.dummy_display_name(name), language)
    Wild(name, _, _) =>
      sanitize_name(@symcore.wild_display_name(name), language)
    FunctionHead(name) => sanitize_name(name, language)
    UndefinedFunction(name) => sanitize_name(name, language)
    Boolean(true) => "true"
    Boolean(false) => "false"
    Add(args) => {
      let text = args.map(arg => print_expr_prec(arg, language, 0)).join(" + ")
      parenthesize_if_needed(text, 0, parent_prec)
    }
    Mul(args) => {
      let text = args.map(arg => print_expr_prec(arg, language, 1)).join("*")
      parenthesize_if_needed(text, 1, parent_prec)
    }
    Pow(base, exp) => {
      let text = match language {
        Rust =>
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
    Mod(lhs, rhs) => {
      let text = match language {
        Julia | Octave =>
          "mod(" +
          print_expr_prec(lhs, language, 0) +
          ", " +
          print_expr_prec(rhs, language, 0) +
          ")"
        _ =>
          print_expr_prec(lhs, language, 2) +
          " % " +
          print_expr_prec(rhs, language, 2)
      }
      parenthesize_if_needed(text, 2, parent_prec)
    }
    Tuple(args) =>
      "(" + args.map(arg => print_expr_prec(arg, language, 0)).join(", ") + ")"
    Dict(_) => print_lambda_like_expr(expr)
    Relational(op, lhs, rhs) =>
      parenthesize_if_needed(
        print_relational_expr(op, lhs, rhs, language),
        0,
        parent_prec,
      )
    Derivative(_, _) => print_derivative_expr(expr)
    Subs(_, _, _) | Lambda(_, _) => print_lambda_like_expr(expr)
    _ => print_lambda_like_expr(expr)
  }
}

///|
fn sanitize_name(name : String, language : TargetLanguage) -> String {
  let reserved = match language {
    C89 | C99 => ["if", "while", "typedef", "return"]
    Julia => ["function", "end", "if"]
    Octave => ["function", "end", "if"]
    Rust => ["fn", "if", "while", "type", "return"]
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
    "c" => C99
    "c89" => C89
    "c99" => C99
    "julia" | "jl" => Julia
    "octave" | "matlab" | "m" => Octave
    "rust" | "rs" => Rust
    other => raise Unsupported("unknown codegen language " + other)
  }
}

///|
pub fn make_routine(
  name : String,
  exprs : Array[RoutineResult],
  argument_sequence? : Array[String]? = None,
) -> Routine raise UtilitiesError {
  if exprs.is_empty() {
    raise InvalidArgument("routine needs at least one result")
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
          raise InvalidArgument(
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
        C89 | C99 => "double " + sanitized
        Julia | Octave => sanitized
        Rust => sanitized + ": f64"
      }
    })
    .join(", ")
  match language {
    C89 | C99 => "double " + routine.name + "(" + args + ")"
    Julia => routine.name + "(" + args + ")"
    Octave => routine.name + "(" + args + ")"
    Rust => "fn " + routine.name + "(" + args + ") -> f64"
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
    C89 | C99 => {
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
    Julia =>
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
    Octave =>
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
    Rust =>
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
    C89 | C99 => {
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
    C89 | C99 =>
      [
        (prefix + ".c", self.dump_source(routines, prefix, header~, empty~)),
        (prefix + ".h", self.dump_header(routines, prefix, header~)),
      ]
    Julia =>
      [(prefix + ".jl", self.dump_source(routines, prefix, header~, empty~))]
    Octave =>
      [(prefix + ".m", self.dump_source(routines, prefix, header~, empty~))]
    Rust =>
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
