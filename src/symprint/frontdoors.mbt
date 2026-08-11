///|
fn string_lower(value : String) -> String {
  let chars : Array[Char] = []
  for c in value {
    chars.push(c.to_ascii_lowercase())
  }
  String::from_array(chars)
}

///|
fn xml_escape(value : String) -> String {
  value
  .replace_all(old="&", new="&amp;")
  .replace_all(old="<", new="&lt;")
  .replace_all(old=">", new="&gt;")
  .replace_all(old="\"", new="&quot;")
}

///|
fn quote_single(value : String) -> String {
  "'" +
  value.replace_all(old="\\", new="\\\\").replace_all(old="'", new="\\'") +
  "'"
}

///|
fn exact_number_srepr(n : @symnum.BigRational) -> String {
  let num = n.numerator().to_string()
  let den = n.denominator().to_string()
  if den == "1" {
    "Integer(\{num})"
  } else {
    "Rational(\{num}, \{den})"
  }
}

///|
fn exact_number_code(n : @symnum.BigRational, float_literals : Bool) -> String {
  let num = n.numerator().to_string()
  let den = n.denominator().to_string()
  if den == "1" {
    if float_literals {
      num + ".0"
    } else {
      num
    }
  } else if float_literals {
    num + ".0/" + den + ".0"
  } else {
    num + "/" + den
  }
}

///|
fn srepr_name_for_relop(op : @symcore.RelOp) -> String {
  match op {
    Eq => "Equality"
    Ne => "Unequality"
    Lt => "StrictLessThan"
    Le => "LessThan"
    Gt => "StrictGreaterThan"
    Ge => "GreaterThan"
  }
}

///|
fn srepr_expr(expr : Expr) -> String {
  match ordinary_application_name_args(expr) {
    Some((name, args)) => return "\{name}(\{args.map(srepr_expr).join(", ")})"
    None => ()
  }
  match @symcore.expr_form(expr) {
    Number(n) => exact_number_srepr(n)
    Float(f) => "Float(\{quote_single(Show::to_string(f))})"
    ComplexFloat(z) => "ComplexFloat(\{quote_single(Show::to_string(z))})"
    NumberSymbol(kind) => @symcore.number_symbol_name(kind)
    Symbol(name) => "Symbol(\{quote_single(name)})"
    Dummy(name, _) => "Dummy(\{quote_single(name)})"
    Wild(name, _, _) => "Wild(\{quote_single(name)})"
    WildFunction(name, _) => "WildFunction(\{quote_single(name)})"
    IdentityFunction => "Lambda(Symbol('_x'), Symbol('_x'))"
    FunctionHead(name) => "Function(\{quote_single(name)})"
    UndefinedFunction(name) => "UndefinedFunction(\{quote_single(name)})"
    Boolean(true) => "true"
    Boolean(false) => "false"
    Add(args) => "Add(\{args.map(srepr_expr).join(", ")})"
    Mul(args) => "Mul(\{args.map(srepr_expr).join(", ")})"
    Pow(base, exp) => "Pow(\{srepr_expr(base)}, \{srepr_expr(exp)})"
    Mod(lhs, rhs) => "Mod(\{srepr_expr(lhs)}, \{srepr_expr(rhs)})"
    Tuple(args) => "Tuple(\{args.map(srepr_expr).join(", ")})"
    Dict(items) => {
      let rendered : Array[String] = []
      for item in @symcore.sorted_dict_entries(items) {
        let (key, value) = item
        rendered.push("Tuple(\{srepr_expr(key)}, \{srepr_expr(value)})")
      }
      "Dict(\{rendered.join(", ")})"
    }
    Relational(op, lhs, rhs) =>
      "\{srepr_name_for_relop(op)}(\{srepr_expr(lhs)}, \{srepr_expr(rhs)})"
    Derivative(inner, deriv_args) =>
      "Derivative(\{derivative_call_args(inner, deriv_args).map(srepr_expr).join(", ")})"
    Subs(inner, variable, value) =>
      "Subs(\{srepr_expr(inner)}, \{srepr_expr(variable)}, \{srepr_expr(value)})"
    Lambda(vars, body) => "Lambda(\{srepr_expr(vars)}, \{srepr_expr(body)})"
    Apply(head, args) =>
      "Apply(\{srepr_expr(head)}, \{args.map(srepr_expr).join(", ")})"
  }
}

///|
/// Return the standard string form of an expression.
pub fn sstr(expr : Expr) -> String {
  pretty_string(expr)
}

///|
/// Return a mixed string/repr form. For `Expr`, this is the standard string form.
pub fn sstrrepr(expr : Expr) -> String {
  pretty_string(expr)
}

///|
/// Return a structural representation of an expression.
pub fn srepr(expr : Expr) -> String {
  srepr_expr(expr)
}

///|
/// Return the plain-text pretty form.
pub fn pretty(
  expr : Expr,
  use_unicode? : Bool = true,
  wrap_line? : Bool = true,
  num_columns? : Int? = None,
) -> String {
  ignore(use_unicode)
  ignore(wrap_line)
  ignore(num_columns)
  pretty_string(expr)
}

///|
/// Return the plain-text pretty form.
pub fn pretty_print(
  expr : Expr,
  use_unicode? : Bool = true,
  wrap_line? : Bool = true,
  num_columns? : Int? = None,
) -> String {
  pretty(expr, use_unicode~, wrap_line~, num_columns~)
}

///|
/// Return the plain-text pretty form intended for pager display.
pub fn pager_print(expr : Expr) -> String {
  pretty_string(expr)
}

///|
pub fn print_latex(
  expr : Expr,
  mode? : String = "plain",
  full_prec? : Bool = false,
  fold_frac_powers? : Bool = false,
  fold_func_brackets? : Bool = false,
  fold_short_frac? : Bool? = None,
  inv_trig_style? : String = "abbreviated",
  itex? : Bool = false,
  ln_notation? : Bool = false,
  long_frac_ratio? : Int? = None,
  mul_symbol? : String? = None,
  root_notation? : Bool = true,
  imaginary_unit? : String = "i",
  diff_operator? : String = "d",
  parenthesize_super? : Bool = true,
  symbol_names? : Map[String, String] = {},
) -> String {
  latex(
    expr,
    mode~,
    full_prec~,
    fold_frac_powers~,
    fold_func_brackets~,
    fold_short_frac~,
    inv_trig_style~,
    itex~,
    ln_notation~,
    long_frac_ratio~,
    mul_symbol~,
    root_notation~,
    imaginary_unit~,
    diff_operator~,
    parenthesize_super~,
    symbol_names~,
  )
}

///|
pub fn multiline_latex(
  lhs : Expr,
  rhs : Expr,
  terms_per_line? : Int = 1,
  environment? : String = "align*",
  use_dots? : Bool = false,
) -> String {
  ignore(terms_per_line)
  let dots = if use_dots { " \\\\dots" } else { "" }
  "\\begin{\{environment}}\{latex(lhs)} &= \{latex(rhs)}\{dots}\\end{\{environment}}"
}

///|
fn mathml_name(expr : Expr) -> String {
  match @symcore.expr_form(expr) {
    Number(_) => "number"
    Float(_) => "float"
    ComplexFloat(_) => "complex"
    NumberSymbol(_) => "constant"
    Symbol(_) => "symbol"
    Dummy(_, _) => "dummy"
    Wild(_, _, _) => "wild"
    WildFunction(_, _) => "wildfunction"
    FunctionHead(name) | UndefinedFunction(name) => name
    Boolean(_) => "boolean"
    Add(_) => "plus"
    Mul(_) => "times"
    Pow(_, _) => "power"
    Mod(_, _) => "rem"
    Tuple(_) => "tuple"
    Dict(_) => "dict"
    Relational(op, _, _) =>
      match op {
        Eq => "eq"
        Ne => "neq"
        Lt => "lt"
        Le => "leq"
        Gt => "gt"
        Ge => "geq"
      }
    Derivative(_, _) => "diff"
    Subs(_, _, _) => "subs"
    Lambda(_, _) => "lambda"
    IdentityFunction => "lambda"
    Apply(head, _) => mathml_name(head)
  }
}

///|
fn mathml_content(expr : Expr) -> String {
  match ordinary_application_name_args(expr) {
    Some((name, args)) => {
      let rendered = args.map(mathml_content).join("")
      return "<apply><\{xml_escape(name)}/>\{rendered}</apply>"
    }
    None => ()
  }
  match @symcore.expr_form(expr) {
    Number(_) | Float(_) => "<cn>\{xml_escape(pretty_string(expr))}</cn>"
    ComplexFloat(_) =>
      "<cn type=\"complex-cartesian\">\{xml_escape(pretty_string(expr))}</cn>"
    NumberSymbol(_) => "<csymbol>\{xml_escape(pretty_string(expr))}</csymbol>"
    Symbol(name) => "<ci>\{xml_escape(name)}</ci>"
    Dummy(name, _) =>
      "<ci>\{xml_escape(@symcore.dummy_display_name(name))}</ci>"
    Wild(name, _, _) =>
      "<ci>\{xml_escape(@symcore.wild_display_name(name))}</ci>"
    WildFunction(name, _) =>
      "<ci>\{xml_escape(@symcore.wild_display_name(name))}</ci>"
    FunctionHead(name) | UndefinedFunction(name) =>
      "<ci>\{xml_escape(name)}</ci>"
    Boolean(value) => if value { "<true/>" } else { "<false/>" }
    Add(args) => "<apply><plus/>\{args.map(mathml_content).join("")}</apply>"
    Mul(args) => "<apply><times/>\{args.map(mathml_content).join("")}</apply>"
    Pow(base, exp) =>
      "<apply><power/>\{mathml_content(base)}\{mathml_content(exp)}</apply>"
    Mod(lhs, rhs) =>
      "<apply><rem/>\{mathml_content(lhs)}\{mathml_content(rhs)}</apply>"
    Tuple(args) => "<tuple>\{args.map(mathml_content).join("")}</tuple>"
    Dict(items) => {
      let rendered : Array[String] = []
      for item in @symcore.sorted_dict_entries(items) {
        let (key, value) = item
        rendered.push(
          "<list>\{mathml_content(key)}\{mathml_content(value)}</list>",
        )
      }
      "<map>\{rendered.join("")}</map>"
    }
    Relational(_, lhs, rhs) =>
      "<apply><\{mathml_name(expr)}/>\{mathml_content(lhs)}\{mathml_content(rhs)}</apply>"
    Derivative(inner, deriv_args) =>
      "<apply><diff/>\{derivative_call_args(inner, deriv_args).map(mathml_content).join("")}</apply>"
    Subs(inner, variable, value) =>
      "<apply><subs/>\{mathml_content(inner)}\{mathml_content(variable)}\{mathml_content(value)}</apply>"
    Lambda(vars, body) =>
      "<lambda>\{mathml_content(vars)}\{mathml_content(body)}</lambda>"
    IdentityFunction => "<lambda><ci>_x</ci><ci>_x</ci></lambda>"
    Apply(head, args) =>
      "<apply>\{mathml_content(head)}\{args.map(mathml_content).join("")}</apply>"
  }
}

///|
fn mathml_presentation(expr : Expr) -> String {
  "<mrow><mi>\{xml_escape(pretty_string(expr))}</mi></mrow>"
}

///|
pub fn mathml(expr : Expr, printer? : String = "content") -> String {
  match string_lower(printer) {
    "presentation" => mathml_presentation(expr)
    _ => mathml_content(expr)
  }
}

///|
pub fn print_mathml(expr : Expr, printer? : String = "content") -> String {
  mathml(expr, printer~)
}

///|
priv enum CodeLanguage {
  Python
  C
  Cxx
  Fortran
  R
  JavaScript
  Julia
  Mathematica
  Octave
  Rust
  GLSL
  Maple
  SMTLib
}

///|
fn code_language_uses_float_literals(language : CodeLanguage) -> Bool {
  match language {
    C | Cxx | Fortran | JavaScript | Rust | GLSL => true
    _ => false
  }
}

///|
fn code_symbol(name : String, language : CodeLanguage) -> String {
  match language {
    Mathematica => if name.length() == 0 { name } else { name }
    _ => name
  }
}

///|
fn code_function_name(name : String, language : CodeLanguage) -> String {
  match language {
    Python =>
      match name {
        "sin"
        | "cos"
        | "tan"
        | "asin"
        | "acos"
        | "atan"
        | "sinh"
        | "cosh"
        | "tanh"
        | "exp"
        | "log"
        | "sqrt" => "math." + name
        "Abs" | "abs" => "abs"
        other => other
      }
    Mathematica =>
      match name {
        "sin" => "Sin"
        "cos" => "Cos"
        "tan" => "Tan"
        "exp" => "Exp"
        "log" => "Log"
        "sqrt" => "Sqrt"
        "Abs" | "abs" => "Abs"
        other => other
      }
    Maple =>
      match name {
        "Abs" => "abs"
        other => other
      }
    _ =>
      match name {
        "Abs" => "abs"
        other => other
      }
  }
}

///|
fn code_parens(text : String, prec : Int, parent_prec : Int) -> String {
  if prec < parent_prec {
    "(\{text})"
  } else {
    text
  }
}

///|
fn code_join_operator(
  args : Array[Expr],
  op : String,
  language : CodeLanguage,
  parent_prec : Int,
  prec : Int,
) -> String {
  code_parens(
    args.map(arg => code_expr(arg, language, prec)).join(op),
    prec,
    parent_prec,
  )
}

///|
fn code_power(
  base : Expr,
  exp : Expr,
  language : CodeLanguage,
  parent_prec : Int,
) -> String {
  let body = match language {
    Python => "\{code_expr(base, language, 4)}**\{code_expr(exp, language, 4)}"
    R | Julia | Octave | Maple =>
      "\{code_expr(base, language, 4)}^\{code_expr(exp, language, 4)}"
    Fortran => "\{code_expr(base, language, 4)}**\{code_expr(exp, language, 4)}"
    Rust =>
      "\{code_expr(base, language, 5)}.powf(\{code_expr(exp, language, 0)})"
    Mathematica =>
      "\{code_expr(base, language, 4)}^\{code_expr(exp, language, 4)}"
    SMTLib =>
      "(^ \{code_expr(base, language, 0)} \{code_expr(exp, language, 0)})"
    _ => "pow(\{code_expr(base, language, 0)}, \{code_expr(exp, language, 0)})"
  }
  code_parens(body, 4, parent_prec)
}

///|
fn code_expr(expr : Expr, language : CodeLanguage, parent_prec : Int) -> String {
  match ordinary_application_name_args(expr) {
    Some((name, args)) => {
      let fname = code_function_name(name, language)
      let rendered = args.map(arg => code_expr(arg, language, 0)).join(", ")
      return match language {
        Mathematica => "\{fname}[\{rendered}]"
        SMTLib =>
          "(\{fname}\{if rendered == "" { "" } else { " " + args.map(arg => code_expr(arg, language, 0)).join(" ") }})"
        _ => "\{fname}(\{rendered})"
      }
    }
    None => ()
  }
  match @symcore.expr_form(expr) {
    Number(n) =>
      exact_number_code(n, code_language_uses_float_literals(language))
    Float(f) => Show::to_string(f)
    ComplexFloat(z) => Show::to_string(z)
    NumberSymbol(kind) =>
      match language {
        C | Cxx | JavaScript | GLSL => @symcore.number_symbol_name(kind)
        Rust =>
          match kind {
            Pi => "std::f64::consts::PI"
            Exp1 => "std::f64::consts::E"
            _ => @symcore.number_symbol_name(kind)
          }
        Mathematica =>
          match kind {
            Pi => "Pi"
            ImaginaryUnit => "I"
            Infinity => "Infinity"
            _ => @symcore.number_symbol_name(kind)
          }
        _ => @symcore.number_symbol_name(kind)
      }
    Symbol(name) => code_symbol(name, language)
    Dummy(name, _) => code_symbol(@symcore.dummy_display_name(name), language)
    Wild(name, _, _) => code_symbol(@symcore.wild_display_name(name), language)
    WildFunction(name, _) =>
      code_symbol(@symcore.wild_display_name(name), language)
    FunctionHead(name) | UndefinedFunction(name) =>
      code_function_name(name, language)
    Boolean(true) =>
      match language {
        Python => "True"
        Mathematica => "True"
        SMTLib => "true"
        _ => "true"
      }
    Boolean(false) =>
      match language {
        Python => "False"
        Mathematica => "False"
        SMTLib => "false"
        _ => "false"
      }
    Add(args) =>
      match language {
        SMTLib =>
          "(+ \{args.map(arg => code_expr(arg, language, 0)).join(" ")})"
        _ => code_join_operator(args, " + ", language, parent_prec, 2)
      }
    Mul(args) =>
      match language {
        SMTLib =>
          "(* \{args.map(arg => code_expr(arg, language, 0)).join(" ")})"
        _ => code_join_operator(args, "*", language, parent_prec, 3)
      }
    Pow(base, exp) => code_power(base, exp, language, parent_prec)
    Mod(lhs, rhs) =>
      match language {
        SMTLib =>
          "(mod \{code_expr(lhs, language, 0)} \{code_expr(rhs, language, 0)})"
        _ =>
          code_parens(
            "\{code_expr(lhs, language, 4)} % \{code_expr(rhs, language, 4)}",
            4,
            parent_prec,
          )
      }
    Tuple(args) =>
      "(\{args.map(arg => code_expr(arg, language, 0)).join(", ")})"
    Dict(_) => pretty_string(expr)
    Relational(op, lhs, rhs) => {
      let op_text = match op {
        Eq => if language is SMTLib { "=" } else { "==" }
        Ne => if language is SMTLib { "distinct" } else { "!=" }
        Lt => "<"
        Le => "<="
        Gt => ">"
        Ge => ">="
      }
      match language {
        SMTLib =>
          "(\{op_text} \{code_expr(lhs, language, 0)} \{code_expr(rhs, language, 0)})"
        _ =>
          code_parens(
            "\{code_expr(lhs, language, 1)} \{op_text} \{code_expr(rhs, language, 1)}",
            1,
            parent_prec,
          )
      }
    }
    Derivative(_, _) | Subs(_, _, _) | Lambda(_, _) => pretty_string(expr)
    IdentityFunction => "lambda x: x"
    Apply(head, args) => {
      let rendered = args.map(arg => code_expr(arg, language, 0)).join(", ")
      "\{code_expr(head, language, 5)}(\{rendered})"
    }
  }
}

///|
fn code_assign(
  text : String,
  assign_to : String?,
  language : CodeLanguage,
) -> String {
  match assign_to {
    None => text
    Some(name) =>
      match language {
        SMTLib => "(assert (= \{name} \{text}))"
        Fortran => "\{name} = \{text}"
        _ => "\{name} = \{text};"
      }
  }
}

///|
pub fn pycode(expr : Expr) -> String {
  code_expr(expr, Python, 0)
}

///|
fn python_symbol_declarations(expr : Expr) -> Array[String] {
  let lines : Array[String] = []
  for symbol in @symcore.free_symbols(expr) {
    match @symcore.expr_form(symbol) {
      Symbol(name) => lines.push("\{name} = Symbol(\{quote_single(name)})")
      Dummy(name, _) => {
        let shown = @symcore.dummy_display_name(name)
        lines.push("\{shown} = Dummy(\{quote_single(name)})")
      }
      _ => ()
    }
  }
  lines
}

///|
pub fn python(expr : Expr) -> String {
  let lines = python_symbol_declarations(expr)
  lines.push("e = \{pycode(expr)}")
  lines.join("\n")
}

///|
pub fn print_python(expr : Expr) -> String {
  python(expr)
}

///|
pub fn ccode(
  expr : Expr,
  assign_to? : String? = None,
  standard? : String = "c99",
) -> String {
  ignore(standard)
  code_assign(code_expr(expr, C, 0), assign_to, C)
}

///|
pub fn print_ccode(expr : Expr) -> String {
  ccode(expr)
}

///|
pub fn cxxcode(
  expr : Expr,
  assign_to? : String? = None,
  standard? : String = "c++11",
) -> String {
  ignore(standard)
  code_assign(code_expr(expr, Cxx, 0), assign_to, Cxx)
}

///|
pub fn fcode(expr : Expr, assign_to? : String? = None) -> String {
  code_assign(code_expr(expr, Fortran, 0), assign_to, Fortran)
}

///|
pub fn print_fcode(expr : Expr) -> String {
  fcode(expr)
}

///|
pub fn rcode(expr : Expr, assign_to? : String? = None) -> String {
  code_assign(code_expr(expr, R, 0), assign_to, R)
}

///|
pub fn print_rcode(expr : Expr) -> String {
  rcode(expr)
}

///|
pub fn jscode(expr : Expr, assign_to? : String? = None) -> String {
  code_assign(code_expr(expr, JavaScript, 0), assign_to, JavaScript)
}

///|
pub fn print_jscode(expr : Expr) -> String {
  jscode(expr)
}

///|
pub fn julia_code(expr : Expr, assign_to? : String? = None) -> String {
  code_assign(code_expr(expr, Julia, 0), assign_to, Julia)
}

///|
pub fn octave_code(expr : Expr, assign_to? : String? = None) -> String {
  code_assign(code_expr(expr, Octave, 0), assign_to, Octave)
}

///|
pub fn rust_code(expr : Expr, assign_to? : String? = None) -> String {
  code_assign(code_expr(expr, Rust, 0), assign_to, Rust)
}

///|
pub fn glsl_code(expr : Expr, assign_to? : String? = None) -> String {
  code_assign(code_expr(expr, GLSL, 0), assign_to, GLSL)
}

///|
pub fn print_glsl(expr : Expr) -> String {
  glsl_code(expr)
}

///|
pub fn mathematica_code(expr : Expr) -> String {
  code_expr(expr, Mathematica, 0)
}

///|
pub fn maple_code(expr : Expr, assign_to? : String? = None) -> String {
  code_assign(code_expr(expr, Maple, 0), assign_to, Maple)
}

///|
pub fn print_maple_code(expr : Expr) -> String {
  maple_code(expr)
}

///|
pub fn smtlib_code(
  expr : Expr,
  auto_assert? : Bool = true,
  auto_declare? : Bool = true,
) -> String {
  ignore(auto_declare)
  let body = code_expr(expr, SMTLib, 0)
  if auto_assert {
    "(assert \{body})"
  } else {
    body
  }
}

///|
pub fn print_gtk(x : Expr, start_viewer? : Bool = true) -> String {
  ignore(start_viewer)
  mathml(x, printer="presentation")
}

///|
pub fn preview(
  expr : Expr,
  output? : String = "png",
  viewer? : String? = None,
  filename? : String? = None,
) -> String {
  ignore(output)
  ignore(viewer)
  ignore(filename)
  latex(expr)
}

///|
fn tree_lines(expr : Expr, indent : String, out : Array[String]) -> Unit {
  out.push(indent + pretty_string(expr))
  for child in @symcore.children(expr) {
    tree_lines(child, indent + "  ", out)
  }
}

///|
pub fn print_tree(node : Expr, assumptions? : Bool = true) -> String {
  ignore(assumptions)
  let out : Array[String] = []
  tree_lines(node, "", out)
  out.join("\n")
}

///|
fn dot_label(expr : Expr) -> String {
  pretty_string(expr)
  .replace_all(old="\\", new="\\\\")
  .replace_all(old="\"", new="\\\"")
}

///|
fn dot_walk(expr : Expr, lines : Array[String], next_id : Array[Int]) -> Int {
  let id = next_id[0]
  next_id[0] = next_id[0] + 1
  lines.push("  n\{id} [label=\"\{dot_label(expr)}\"];")
  for child in @symcore.children(expr) {
    let child_id = dot_walk(child, lines, next_id)
    lines.push("  n\{id} -> n\{child_id};")
  }
  id
}

///|
pub fn dotprint(
  expr : Expr,
  maxdepth? : Int? = None,
  repeat? : Bool = true,
) -> String {
  ignore(maxdepth)
  ignore(repeat)
  let lines : Array[String] = ["digraph{"]
  let next_id = [0]
  ignore(dot_walk(expr, lines, next_id))
  lines.push("}")
  lines.join("\n")
}
