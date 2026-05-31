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
    @symcore.RelOp::Eq => "Equality"
    @symcore.RelOp::Ne => "Unequality"
    @symcore.RelOp::Lt => "StrictLessThan"
    @symcore.RelOp::Le => "LessThan"
    @symcore.RelOp::Gt => "StrictGreaterThan"
    @symcore.RelOp::Ge => "GreaterThan"
  }
}

///|
fn srepr_expr(expr : Expr) -> String {
  match ordinary_application_name_args(expr) {
    Some((name, args)) => return "\{name}(\{args.map(srepr_expr).join(", ")})"
    None => ()
  }
  match @symcore.expr_form(expr) {
    @symcore.ExprForm::Number(n) => exact_number_srepr(n)
    @symcore.ExprForm::Float(f) => "Float(\{quote_single(f.to_string())})"
    @symcore.ExprForm::ComplexFloat(z) =>
      "ComplexFloat(\{quote_single(z.to_string())})"
    @symcore.ExprForm::NumberSymbol(kind) => @symcore.number_symbol_name(kind)
    @symcore.ExprForm::Symbol(name) => "Symbol(\{quote_single(name)})"
    @symcore.ExprForm::Dummy(name, _) => "Dummy(\{quote_single(name)})"
    @symcore.ExprForm::Wild(name, _, _) => "Wild(\{quote_single(name)})"
    @symcore.ExprForm::WildFunction(name, _) =>
      "WildFunction(\{quote_single(name)})"
    @symcore.ExprForm::IdentityFunction => "Lambda(Symbol('_x'), Symbol('_x'))"
    @symcore.ExprForm::FunctionHead(name) => "Function(\{quote_single(name)})"
    @symcore.ExprForm::UndefinedFunction(name) =>
      "UndefinedFunction(\{quote_single(name)})"
    @symcore.ExprForm::Boolean(true) => "true"
    @symcore.ExprForm::Boolean(false) => "false"
    @symcore.ExprForm::Add(args) => "Add(\{args.map(srepr_expr).join(", ")})"
    @symcore.ExprForm::Mul(args) => "Mul(\{args.map(srepr_expr).join(", ")})"
    @symcore.ExprForm::Pow(base, exp) =>
      "Pow(\{srepr_expr(base)}, \{srepr_expr(exp)})"
    @symcore.ExprForm::Mod(lhs, rhs) =>
      "Mod(\{srepr_expr(lhs)}, \{srepr_expr(rhs)})"
    @symcore.ExprForm::Tuple(args) =>
      "Tuple(\{args.map(srepr_expr).join(", ")})"
    @symcore.ExprForm::Dict(items) => {
      let rendered : Array[String] = []
      for item in @symcore.sorted_dict_entries(items) {
        let (key, value) = item
        rendered.push("Tuple(\{srepr_expr(key)}, \{srepr_expr(value)})")
      }
      "Dict(\{rendered.join(", ")})"
    }
    @symcore.ExprForm::Relational(op, lhs, rhs) =>
      "\{srepr_name_for_relop(op)}(\{srepr_expr(lhs)}, \{srepr_expr(rhs)})"
    @symcore.ExprForm::Derivative(inner, deriv_args) =>
      "Derivative(\{derivative_call_args(inner, deriv_args).map(srepr_expr).join(", ")})"
    @symcore.ExprForm::Subs(inner, variable, value) =>
      "Subs(\{srepr_expr(inner)}, \{srepr_expr(variable)}, \{srepr_expr(value)})"
    @symcore.ExprForm::Lambda(vars, body) =>
      "Lambda(\{srepr_expr(vars)}, \{srepr_expr(body)})"
    @symcore.ExprForm::Apply(head, args) =>
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
    @symcore.ExprForm::Number(_) => "number"
    @symcore.ExprForm::Float(_) => "float"
    @symcore.ExprForm::ComplexFloat(_) => "complex"
    @symcore.ExprForm::NumberSymbol(_) => "constant"
    @symcore.ExprForm::Symbol(_) => "symbol"
    @symcore.ExprForm::Dummy(_, _) => "dummy"
    @symcore.ExprForm::Wild(_, _, _) => "wild"
    @symcore.ExprForm::WildFunction(_, _) => "wildfunction"
    @symcore.ExprForm::FunctionHead(name)
    | @symcore.ExprForm::UndefinedFunction(name) => name
    @symcore.ExprForm::Boolean(_) => "boolean"
    @symcore.ExprForm::Add(_) => "plus"
    @symcore.ExprForm::Mul(_) => "times"
    @symcore.ExprForm::Pow(_, _) => "power"
    @symcore.ExprForm::Mod(_, _) => "rem"
    @symcore.ExprForm::Tuple(_) => "tuple"
    @symcore.ExprForm::Dict(_) => "dict"
    @symcore.ExprForm::Relational(op, _, _) =>
      match op {
        @symcore.RelOp::Eq => "eq"
        @symcore.RelOp::Ne => "neq"
        @symcore.RelOp::Lt => "lt"
        @symcore.RelOp::Le => "leq"
        @symcore.RelOp::Gt => "gt"
        @symcore.RelOp::Ge => "geq"
      }
    @symcore.ExprForm::Derivative(_, _) => "diff"
    @symcore.ExprForm::Subs(_, _, _) => "subs"
    @symcore.ExprForm::Lambda(_, _) => "lambda"
    @symcore.ExprForm::IdentityFunction => "lambda"
    @symcore.ExprForm::Apply(head, _) => mathml_name(head)
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
    @symcore.ExprForm::Number(_) | @symcore.ExprForm::Float(_) =>
      "<cn>\{xml_escape(pretty_string(expr))}</cn>"
    @symcore.ExprForm::ComplexFloat(_) =>
      "<cn type=\"complex-cartesian\">\{xml_escape(pretty_string(expr))}</cn>"
    @symcore.ExprForm::NumberSymbol(_) =>
      "<csymbol>\{xml_escape(pretty_string(expr))}</csymbol>"
    @symcore.ExprForm::Symbol(name) => "<ci>\{xml_escape(name)}</ci>"
    @symcore.ExprForm::Dummy(name, _) =>
      "<ci>\{xml_escape(@symcore.dummy_display_name(name))}</ci>"
    @symcore.ExprForm::Wild(name, _, _) =>
      "<ci>\{xml_escape(@symcore.wild_display_name(name))}</ci>"
    @symcore.ExprForm::WildFunction(name, _) =>
      "<ci>\{xml_escape(@symcore.wild_display_name(name))}</ci>"
    @symcore.ExprForm::FunctionHead(name)
    | @symcore.ExprForm::UndefinedFunction(name) =>
      "<ci>\{xml_escape(name)}</ci>"
    @symcore.ExprForm::Boolean(value) =>
      if value {
        "<true/>"
      } else {
        "<false/>"
      }
    @symcore.ExprForm::Add(args) =>
      "<apply><plus/>\{args.map(mathml_content).join("")}</apply>"
    @symcore.ExprForm::Mul(args) =>
      "<apply><times/>\{args.map(mathml_content).join("")}</apply>"
    @symcore.ExprForm::Pow(base, exp) =>
      "<apply><power/>\{mathml_content(base)}\{mathml_content(exp)}</apply>"
    @symcore.ExprForm::Mod(lhs, rhs) =>
      "<apply><rem/>\{mathml_content(lhs)}\{mathml_content(rhs)}</apply>"
    @symcore.ExprForm::Tuple(args) =>
      "<tuple>\{args.map(mathml_content).join("")}</tuple>"
    @symcore.ExprForm::Dict(items) => {
      let rendered : Array[String] = []
      for item in @symcore.sorted_dict_entries(items) {
        let (key, value) = item
        rendered.push(
          "<list>\{mathml_content(key)}\{mathml_content(value)}</list>",
        )
      }
      "<map>\{rendered.join("")}</map>"
    }
    @symcore.ExprForm::Relational(_, lhs, rhs) =>
      "<apply><\{mathml_name(expr)}/>\{mathml_content(lhs)}\{mathml_content(rhs)}</apply>"
    @symcore.ExprForm::Derivative(inner, deriv_args) =>
      "<apply><diff/>\{derivative_call_args(inner, deriv_args).map(mathml_content).join("")}</apply>"
    @symcore.ExprForm::Subs(inner, variable, value) =>
      "<apply><subs/>\{mathml_content(inner)}\{mathml_content(variable)}\{mathml_content(value)}</apply>"
    @symcore.ExprForm::Lambda(vars, body) =>
      "<lambda>\{mathml_content(vars)}\{mathml_content(body)}</lambda>"
    @symcore.ExprForm::IdentityFunction =>
      "<lambda><ci>_x</ci><ci>_x</ci></lambda>"
    @symcore.ExprForm::Apply(head, args) =>
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
    CodeLanguage::C
    | CodeLanguage::Cxx
    | CodeLanguage::Fortran
    | CodeLanguage::JavaScript
    | CodeLanguage::Rust
    | CodeLanguage::GLSL => true
    _ => false
  }
}

///|
fn code_symbol(name : String, language : CodeLanguage) -> String {
  match language {
    CodeLanguage::Mathematica => if name.length() == 0 { name } else { name }
    _ => name
  }
}

///|
fn code_function_name(name : String, language : CodeLanguage) -> String {
  match language {
    CodeLanguage::Python =>
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
    CodeLanguage::Mathematica =>
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
    CodeLanguage::Maple =>
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
    CodeLanguage::Python =>
      "\{code_expr(base, language, 4)}**\{code_expr(exp, language, 4)}"
    CodeLanguage::R
    | CodeLanguage::Julia
    | CodeLanguage::Octave
    | CodeLanguage::Maple =>
      "\{code_expr(base, language, 4)}^\{code_expr(exp, language, 4)}"
    CodeLanguage::Fortran =>
      "\{code_expr(base, language, 4)}**\{code_expr(exp, language, 4)}"
    CodeLanguage::Rust =>
      "\{code_expr(base, language, 5)}.powf(\{code_expr(exp, language, 0)})"
    CodeLanguage::Mathematica =>
      "\{code_expr(base, language, 4)}^\{code_expr(exp, language, 4)}"
    CodeLanguage::SMTLib =>
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
        CodeLanguage::Mathematica => "\{fname}[\{rendered}]"
        CodeLanguage::SMTLib =>
          "(\{fname}\{if rendered == "" { "" } else { " " + args.map(arg => code_expr(arg, language, 0)).join(" ") }})"
        _ => "\{fname}(\{rendered})"
      }
    }
    None => ()
  }
  match @symcore.expr_form(expr) {
    @symcore.ExprForm::Number(n) =>
      exact_number_code(n, code_language_uses_float_literals(language))
    @symcore.ExprForm::Float(f) => f.to_string()
    @symcore.ExprForm::ComplexFloat(z) => z.to_string()
    @symcore.ExprForm::NumberSymbol(kind) =>
      match language {
        CodeLanguage::C
        | CodeLanguage::Cxx
        | CodeLanguage::JavaScript
        | CodeLanguage::GLSL => @symcore.number_symbol_name(kind)
        CodeLanguage::Rust =>
          match kind {
            @symcore.NumberSymbolKind::Pi => "std::f64::consts::PI"
            @symcore.NumberSymbolKind::Exp1 => "std::f64::consts::E"
            _ => @symcore.number_symbol_name(kind)
          }
        CodeLanguage::Mathematica =>
          match kind {
            @symcore.NumberSymbolKind::Pi => "Pi"
            @symcore.NumberSymbolKind::ImaginaryUnit => "I"
            @symcore.NumberSymbolKind::Infinity => "Infinity"
            _ => @symcore.number_symbol_name(kind)
          }
        _ => @symcore.number_symbol_name(kind)
      }
    @symcore.ExprForm::Symbol(name) => code_symbol(name, language)
    @symcore.ExprForm::Dummy(name, _) =>
      code_symbol(@symcore.dummy_display_name(name), language)
    @symcore.ExprForm::Wild(name, _, _) =>
      code_symbol(@symcore.wild_display_name(name), language)
    @symcore.ExprForm::WildFunction(name, _) =>
      code_symbol(@symcore.wild_display_name(name), language)
    @symcore.ExprForm::FunctionHead(name)
    | @symcore.ExprForm::UndefinedFunction(name) =>
      code_function_name(name, language)
    @symcore.ExprForm::Boolean(true) =>
      match language {
        CodeLanguage::Python => "True"
        CodeLanguage::Mathematica => "True"
        CodeLanguage::SMTLib => "true"
        _ => "true"
      }
    @symcore.ExprForm::Boolean(false) =>
      match language {
        CodeLanguage::Python => "False"
        CodeLanguage::Mathematica => "False"
        CodeLanguage::SMTLib => "false"
        _ => "false"
      }
    @symcore.ExprForm::Add(args) =>
      match language {
        CodeLanguage::SMTLib =>
          "(+ \{args.map(arg => code_expr(arg, language, 0)).join(" ")})"
        _ => code_join_operator(args, " + ", language, parent_prec, 2)
      }
    @symcore.ExprForm::Mul(args) =>
      match language {
        CodeLanguage::SMTLib =>
          "(* \{args.map(arg => code_expr(arg, language, 0)).join(" ")})"
        _ => code_join_operator(args, "*", language, parent_prec, 3)
      }
    @symcore.ExprForm::Pow(base, exp) =>
      code_power(base, exp, language, parent_prec)
    @symcore.ExprForm::Mod(lhs, rhs) =>
      match language {
        CodeLanguage::SMTLib =>
          "(mod \{code_expr(lhs, language, 0)} \{code_expr(rhs, language, 0)})"
        _ =>
          code_parens(
            "\{code_expr(lhs, language, 4)} % \{code_expr(rhs, language, 4)}",
            4,
            parent_prec,
          )
      }
    @symcore.ExprForm::Tuple(args) =>
      "(\{args.map(arg => code_expr(arg, language, 0)).join(", ")})"
    @symcore.ExprForm::Dict(_) => pretty_string(expr)
    @symcore.ExprForm::Relational(op, lhs, rhs) => {
      let op_text = match op {
        @symcore.RelOp::Eq =>
          if language is CodeLanguage::SMTLib {
            "="
          } else {
            "=="
          }
        @symcore.RelOp::Ne =>
          if language is CodeLanguage::SMTLib {
            "distinct"
          } else {
            "!="
          }
        @symcore.RelOp::Lt => "<"
        @symcore.RelOp::Le => "<="
        @symcore.RelOp::Gt => ">"
        @symcore.RelOp::Ge => ">="
      }
      match language {
        CodeLanguage::SMTLib =>
          "(\{op_text} \{code_expr(lhs, language, 0)} \{code_expr(rhs, language, 0)})"
        _ =>
          code_parens(
            "\{code_expr(lhs, language, 1)} \{op_text} \{code_expr(rhs, language, 1)}",
            1,
            parent_prec,
          )
      }
    }
    @symcore.ExprForm::Derivative(_, _)
    | @symcore.ExprForm::Subs(_, _, _)
    | @symcore.ExprForm::Lambda(_, _) => pretty_string(expr)
    @symcore.ExprForm::IdentityFunction => "lambda x: x"
    @symcore.ExprForm::Apply(head, args) => {
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
        CodeLanguage::SMTLib => "(assert (= \{name} \{text}))"
        CodeLanguage::Fortran => "\{name} = \{text}"
        _ => "\{name} = \{text};"
      }
  }
}

///|
pub fn pycode(expr : Expr) -> String {
  code_expr(expr, CodeLanguage::Python, 0)
}

///|
fn python_symbol_declarations(expr : Expr) -> Array[String] {
  let lines : Array[String] = []
  for symbol in @symcore.free_symbols(expr) {
    match @symcore.expr_form(symbol) {
      @symcore.ExprForm::Symbol(name) =>
        lines.push("\{name} = Symbol(\{quote_single(name)})")
      @symcore.ExprForm::Dummy(name, _) => {
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
  code_assign(code_expr(expr, CodeLanguage::C, 0), assign_to, CodeLanguage::C)
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
  code_assign(
    code_expr(expr, CodeLanguage::Cxx, 0),
    assign_to,
    CodeLanguage::Cxx,
  )
}

///|
pub fn fcode(expr : Expr, assign_to? : String? = None) -> String {
  code_assign(
    code_expr(expr, CodeLanguage::Fortran, 0),
    assign_to,
    CodeLanguage::Fortran,
  )
}

///|
pub fn print_fcode(expr : Expr) -> String {
  fcode(expr)
}

///|
pub fn rcode(expr : Expr, assign_to? : String? = None) -> String {
  code_assign(code_expr(expr, CodeLanguage::R, 0), assign_to, CodeLanguage::R)
}

///|
pub fn print_rcode(expr : Expr) -> String {
  rcode(expr)
}

///|
pub fn jscode(expr : Expr, assign_to? : String? = None) -> String {
  code_assign(
    code_expr(expr, CodeLanguage::JavaScript, 0),
    assign_to,
    CodeLanguage::JavaScript,
  )
}

///|
pub fn print_jscode(expr : Expr) -> String {
  jscode(expr)
}

///|
pub fn julia_code(expr : Expr, assign_to? : String? = None) -> String {
  code_assign(
    code_expr(expr, CodeLanguage::Julia, 0),
    assign_to,
    CodeLanguage::Julia,
  )
}

///|
pub fn octave_code(expr : Expr, assign_to? : String? = None) -> String {
  code_assign(
    code_expr(expr, CodeLanguage::Octave, 0),
    assign_to,
    CodeLanguage::Octave,
  )
}

///|
pub fn rust_code(expr : Expr, assign_to? : String? = None) -> String {
  code_assign(
    code_expr(expr, CodeLanguage::Rust, 0),
    assign_to,
    CodeLanguage::Rust,
  )
}

///|
pub fn glsl_code(expr : Expr, assign_to? : String? = None) -> String {
  code_assign(
    code_expr(expr, CodeLanguage::GLSL, 0),
    assign_to,
    CodeLanguage::GLSL,
  )
}

///|
pub fn print_glsl(expr : Expr) -> String {
  glsl_code(expr)
}

///|
pub fn mathematica_code(expr : Expr) -> String {
  code_expr(expr, CodeLanguage::Mathematica, 0)
}

///|
pub fn maple_code(expr : Expr, assign_to? : String? = None) -> String {
  code_assign(
    code_expr(expr, CodeLanguage::Maple, 0),
    assign_to,
    CodeLanguage::Maple,
  )
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
  let body = code_expr(expr, CodeLanguage::SMTLib, 0)
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
