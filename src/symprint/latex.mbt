///|
/// Public configuration record for the LaTeX printer.
///
/// - Does: Stores printer options shared by `latex` and `latex_with_settings`.
/// - Input: Usually built with `latex_settings(...)`.
/// - Returns: A record carrying mode, fraction, trig, multiplication, root,
///   imaginary-unit, differential-operator, and symbol-name options.
/// - Limits: This config only affects the LaTeX printer; it does not change
///   `to_string` or `debug_repr`.
///
/// Current Limits:
/// - `symprint` currently exposes plain-text and LaTeX front doors only.
/// - some advanced expression families still fall back to generic function-style
///   notation.
pub struct LatexSettings {
  mode : String
  full_prec : Bool
  fold_frac_powers : Bool
  fold_func_brackets : Bool
  fold_short_frac : Bool
  inv_trig_style : String
  itex : Bool
  ln_notation : Bool
  long_frac_ratio : Int?
  mul_symbol : String?
  mul_symbol_latex : String
  mul_symbol_latex_numbers : String
  root_notation : Bool
  imaginary_unit : String
  imaginary_unit_latex : String
  diff_operator : String
  diff_operator_latex : String
  parenthesize_super : Bool
  symbol_names : Map[String, String]
}

///|
fn mul_symbol_latex(value : String?) -> String {
  match value {
    None => " "
    Some("dot") => " \\cdot "
    Some("times") => " \\times "
    Some("ldot") => " \\\\,.\\\\, "
    Some(other) => other
  }
}

///|
fn mul_symbol_latex_numbers(value : String?) -> String {
  match value {
    None => " \\cdot "
    Some("dot") => " \\cdot "
    Some("times") => " \\times "
    Some("ldot") => " \\\\,.\\\\, "
    Some(other) => other
  }
}

///|
fn imaginary_unit_latex(value : String) -> String {
  match value {
    "i" => "i"
    "ri" => "\\mathrm{i}"
    "ti" => "\\text{i}"
    "j" => "j"
    "rj" => "\\mathrm{j}"
    "tj" => "\\text{j}"
    other => other
  }
}

///|
fn diff_operator_latex(value : String) -> String {
  match value {
    "d" => "d"
    "rd" => "\\mathrm{d}"
    "td" => "\\text{d}"
    other => other
  }
}

///|
/// Build a reusable `LatexSettings` record.
///
/// - Does: Collects LaTeX printer keyword options into a single settings value.
/// - Input: Optional keyword arguments such as `mode`, `mul_symbol`,
///   `inv_trig_style`, `imaginary_unit`, and `symbol_names`.
/// - Returns: A `LatexSettings` record.
/// - Limits: String-valued knobs are permissive; unrecognized values are carried
///   through or fall back to generic rendering instead of being rejected.
pub fn latex_settings(
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
) -> LatexSettings {
  let resolved_fold_short_frac = match fold_short_frac {
    Some(value) => value
    None => mode == "inline"
  }
  LatexSettings::{
    mode,
    full_prec,
    fold_frac_powers,
    fold_func_brackets,
    fold_short_frac: resolved_fold_short_frac,
    inv_trig_style,
    itex,
    ln_notation,
    long_frac_ratio,
    mul_symbol,
    mul_symbol_latex: mul_symbol_latex(mul_symbol),
    mul_symbol_latex_numbers: mul_symbol_latex_numbers(mul_symbol),
    root_notation,
    imaginary_unit,
    imaginary_unit_latex: imaginary_unit_latex(imaginary_unit),
    diff_operator,
    diff_operator_latex: diff_operator_latex(diff_operator),
    parenthesize_super,
    symbol_names,
  }
}

///|
/// Render an expression as LaTeX using an explicit settings record.
///
/// - Does: Prints LaTeX from an expression and a prepared `LatexSettings`.
/// - Input: A `@symcore.Expr` and a `LatexSettings`.
/// - Returns: A `String`.
/// - Limits: It shares the same rendering coverage and fallback behavior as
///   `latex`.
pub fn latex_with_settings(expr : Expr, settings : LatexSettings) -> String {
  let body = latex_format_expr(expr, 0, settings)
  match settings.mode {
    "plain" => body
    "inline" => "$\{body}$"
    _ if settings.itex => "$$\{body}$$"
    "equation" => "\\begin{equation}\{body}\\end{equation}"
    "equation*" => "\\begin{equation*}\{body}\\end{equation*}"
    _ => body
  }
}

///|
/// Render an expression as LaTeX with convenience keyword arguments.
///
/// - Does: Prints LaTeX directly from an expression and printer options.
/// - Input: A `@symcore.Expr` plus optional printer settings.
/// - Returns: A `String`.
/// - Limits: Unknown mode strings fall back to the bare LaTeX body rather than
///   raising an error.
///
/// ```mbt check
/// test "symprint latex renders with inline mode and custom multiplication" {
///   let x = @symcore.Expr::Symbol("x")
///   let expr = @symcore.mul([@symcore.int(2), @symcore.pow(x, @symcore.int(2))])
///   inspect(
///     latex(expr, mode="inline", mul_symbol=Some("times")),
///     content="$2 \\times x^{2}$",
///   )
/// }
/// ```
pub fn latex(
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
  latex_with_settings(
    expr,
    latex_settings(
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
    ),
  )
}

///|
fn latex_parens(s : String) -> String {
  "\\left(\{s}\\right)"
}

///|
fn latex_parens_lspace(s : String) -> String {
  "\\left( \{s}\\right)"
}

///|
fn char_at(src : String, index : Int) -> Char? {
  src.get_char(index)
}

///|
fn first_index_of_char(src : String, target : Char, start? : Int = 0) -> Int? {
  let mut i = start
  while i < src.length() {
    match char_at(src, i) {
      Some(ch) if ch == target => return Some(i)
      _ => i += 1
    }
  }
  None
}

///|
fn contains_caret(src : String) -> Bool {
  first_index_of_char(src, '^') is Some(_)
}

///|
fn split_super_sub_name(
  text : String,
) -> (String, Array[String], Array[String]) {
  if text.length() == 0 || text.contains("{") {
    return (text, [], [])
  }
  let mut pos = 0
  let mut name : String? = None
  let supers : Array[String] = []
  let subs : Array[String] = []
  while pos < text.length() {
    let mut start = pos + 1
    let has_double_underscore = match
      (char_at(text, pos), char_at(text, pos + 1)) {
      (Some('_'), Some('_')) => true
      _ => false
    }
    if has_double_underscore {
      start += 1
    }
    let mut pos_hat = text.length()
    let mut pos_usc = text.length()
    let mut i = start
    while i < text.length() {
      match char_at(text, i) {
        Some('^') if pos_hat == text.length() => pos_hat = i
        Some('_') if pos_usc == text.length() => pos_usc = i
        _ => ()
      }
      if pos_hat != text.length() && pos_usc != text.length() {
        break
      }
      i += 1
    }
    let pos_next = if pos_hat < pos_usc { pos_hat } else { pos_usc }
    let part = text[pos:pos_next].to_string()
    pos = pos_next
    match name {
      None => name = Some(part)
      Some(_) =>
        if part.has_prefix("^") {
          supers.push(part[1:part.length()].to_string())
        } else if part.has_prefix("__") {
          supers.push(part[2:part.length()].to_string())
        } else if part.has_prefix("_") {
          subs.push(part[1:part.length()].to_string())
        } else {
          return (text, [], [])
        }
    }
  }
  let mut base = match name {
    Some(value) => value
    None => text
  }
  if base.length() == 0 {
    return (base, supers, subs)
  }
  let mut digit_start = base.length()
  let mut saw_digit = false
  let mut i = base.length() - 1
  while base.length() > 0 && i >= 0 {
    match char_at(base, i) {
      Some(ch) if ch.is_ascii_digit() => {
        saw_digit = true
        digit_start = i
      }
      _ => break
    }
    if i == 0 {
      break
    }
    i -= 1
  }
  if saw_digit && digit_start > 0 {
    let mut alpha_prefix = true
    for ch in base[:digit_start] {
      if !ch.is_ascii_alphabetic() {
        alpha_prefix = false
        break
      }
    }
    if alpha_prefix {
      let with_digit_sub : Array[String] = [
        base[digit_start:base.length()].to_string(),
      ]
      for item in subs {
        with_digit_sub.push(item)
      }
      base = base[:digit_start].to_string()
      return (base, supers, with_digit_sub)
    }
  }
  (base, supers, subs)
}

///|
fn translate_symbol_base(name : String) -> String? {
  match name {
    "Alpha" => Some("\\mathrm{A}")
    "Beta" => Some("\\mathrm{B}")
    "Gamma" => Some("\\Gamma")
    "Delta" => Some("\\Delta")
    "Epsilon" => Some("\\mathrm{E}")
    "Zeta" => Some("\\mathrm{Z}")
    "Eta" => Some("\\mathrm{H}")
    "Theta" => Some("\\Theta")
    "Iota" => Some("\\mathrm{I}")
    "Kappa" => Some("\\mathrm{K}")
    "Lambda" => Some("\\Lambda")
    "Mu" => Some("\\mathrm{M}")
    "Nu" => Some("\\mathrm{N}")
    "Xi" => Some("\\Xi")
    "omicron" => Some("o")
    "Omicron" => Some("\\mathrm{O}")
    "Pi" => Some("\\Pi")
    "Rho" => Some("\\mathrm{P}")
    "Sigma" => Some("\\Sigma")
    "Tau" => Some("\\mathrm{T}")
    "Upsilon" => Some("\\Upsilon")
    "Phi" => Some("\\Phi")
    "Chi" => Some("\\mathrm{X}")
    "Psi" => Some("\\Psi")
    "Omega" => Some("\\Omega")
    "alpha" => Some("\\alpha")
    "beta" => Some("\\beta")
    "gamma" => Some("\\gamma")
    "delta" => Some("\\delta")
    "epsilon" => Some("\\epsilon")
    "zeta" => Some("\\zeta")
    "eta" => Some("\\eta")
    "theta" => Some("\\theta")
    "iota" => Some("\\iota")
    "kappa" => Some("\\kappa")
    "lambda" | "lamda" => Some("\\lambda")
    "mu" => Some("\\mu")
    "nu" => Some("\\nu")
    "xi" => Some("\\xi")
    "pi" => Some("\\pi")
    "rho" => Some("\\rho")
    "sigma" => Some("\\sigma")
    "tau" => Some("\\tau")
    "upsilon" => Some("\\upsilon")
    "phi" => Some("\\phi")
    "chi" | "khi" => Some("\\chi")
    "psi" => Some("\\psi")
    "omega" => Some("\\omega")
    "varepsilon" => Some("\\varepsilon")
    "varkappa" => Some("\\varkappa")
    "varphi" => Some("\\varphi")
    "varpi" => Some("\\varpi")
    "varrho" => Some("\\varrho")
    "varsigma" => Some("\\varsigma")
    "vartheta" => Some("\\vartheta")
    "aleph" => Some("\\aleph")
    "beth" => Some("\\beth")
    "daleth" => Some("\\daleth")
    "gimel" => Some("\\gimel")
    "ell" => Some("\\ell")
    "eth" => Some("\\eth")
    "hbar" => Some("\\hbar")
    "hslash" => Some("\\hslash")
    "mho" => Some("\\mho")
    "wp" => Some("\\wp")
    _ => None
  }
}

///|
fn translate_symbol_name(name : String) -> String {
  match translate_symbol_base(name) {
    Some(tex) => tex
    None => {
      let lower = name.to_lower()
      if lower.has_suffix("ddddot") && name.length() > 6 {
        return "\\ddddot{\{translate_symbol_name(name[:name.length() - 6].to_string())}}"
      }
      if lower.has_suffix("dddot") && name.length() > 5 {
        return "\\dddot{\{translate_symbol_name(name[:name.length() - 5].to_string())}}"
      }
      if lower.has_suffix("ddot") && name.length() > 4 {
        return "\\ddot{\{translate_symbol_name(name[:name.length() - 4].to_string())}}"
      }
      if lower.has_suffix("dot") && name.length() > 3 {
        return "\\dot{\{translate_symbol_name(name[:name.length() - 3].to_string())}}"
      }
      if lower.has_suffix("tilde") && name.length() > 5 {
        return "\\tilde{\{translate_symbol_name(name[:name.length() - 5].to_string())}}"
      }
      if lower.has_suffix("hat") && name.length() > 3 {
        return "\\hat{\{translate_symbol_name(name[:name.length() - 3].to_string())}}"
      }
      if lower.has_suffix("bar") && name.length() > 3 {
        return "\\bar{\{translate_symbol_name(name[:name.length() - 3].to_string())}}"
      }
      if lower.has_suffix("vec") && name.length() > 3 {
        return "\\vec{\{translate_symbol_name(name[:name.length() - 3].to_string())}}"
      }
      if lower.has_suffix("prime") && name.length() > 5 {
        return "{\{translate_symbol_name(name[:name.length() - 5].to_string())}}'"
      }
      if lower.has_suffix("prm") && name.length() > 3 {
        return "{\{translate_symbol_name(name[:name.length() - 3].to_string())}}'"
      }
      if lower.has_suffix("bold") && name.length() > 4 {
        return "\\boldsymbol{\{translate_symbol_name(name[:name.length() - 4].to_string())}}"
      }
      if lower.has_suffix("bm") && name.length() > 2 {
        return "\\boldsymbol{\{translate_symbol_name(name[:name.length() - 2].to_string())}}"
      }
      if lower.has_suffix("cal") && name.length() > 3 {
        return "\\mathcal{\{translate_symbol_name(name[:name.length() - 3].to_string())}}"
      }
      if lower.has_suffix("scr") && name.length() > 3 {
        return "\\mathscr{\{translate_symbol_name(name[:name.length() - 3].to_string())}}"
      }
      if lower.has_suffix("frak") && name.length() > 4 {
        return "\\mathfrak{\{translate_symbol_name(name[:name.length() - 4].to_string())}}"
      }
      name
    }
  }
}

///|
fn deal_with_super_sub(name : String, style? : String = "plain") -> String {
  let (base_name, supers, subs) = split_super_sub_name(name)
  let mut base_tex = translate_symbol_name(base_name)
  if style == "bold" {
    base_tex = "\\mathbf{\{base_tex}}"
  }
  let mut out = base_tex
  if !supers.is_empty() {
    let items : Array[String] = []
    for item in supers {
      items.push(translate_symbol_name(item))
    }
    let supers_tex = items.join(" ")
    out += "^{\{supers_tex}}"
  }
  if !subs.is_empty() {
    let items : Array[String] = []
    for item in subs {
      items.push(translate_symbol_name(item))
    }
    let subs_tex = items.join(" ")
    out += "_{\{subs_tex}}"
  }
  out
}

///|
fn is_accepted_latex_function(name : String) -> Bool {
  match name {
    "arcsin"
    | "arccos"
    | "arctan"
    | "sin"
    | "cos"
    | "tan"
    | "sinh"
    | "cosh"
    | "tanh"
    | "sqrt"
    | "ln"
    | "log"
    | "sec"
    | "csc"
    | "cot"
    | "coth"
    | "re"
    | "im"
    | "frac"
    | "root"
    | "arg" => true
    _ => false
  }
}

///|
fn latex_hprint_function(name : String) -> String {
  let rendered = deal_with_super_sub(name)
  if is_accepted_latex_function(name) {
    return "\\\{name}"
  }
  let superscript_idx = first_index_of_char(rendered, '^')
  let subscript_idx = first_index_of_char(rendered, '_')
  let boundary = match (superscript_idx, subscript_idx) {
    (Some(a), Some(b)) => if a < b { Some(a) } else { Some(b) }
    (Some(a), None) => Some(a)
    (None, Some(b)) => Some(b)
    (None, None) => None
  }
  if rendered.length() == 1 || rendered.has_prefix("\\") || boundary == Some(1) {
    rendered
  } else {
    match boundary {
      Some(idx) =>
        "\\operatorname{\{rendered[:idx].to_string()}}\{rendered[idx:rendered.length()].to_string()}"
      None => "\\operatorname{\{rendered}}"
    }
  }
}

///|
fn latex_parenthesize_super(s : String, settings : LatexSettings) -> String {
  if contains_caret(s) {
    if settings.parenthesize_super {
      latex_parens(s)
    } else {
      "{\{s}}"
    }
  } else {
    s
  }
}

///|
fn latex_exact_number(
  num : BigInt,
  den : BigInt,
  settings : LatexSettings,
) -> String {
  if den.compare(1N) == 0 {
    num.to_string()
  } else if num.compare(0N) < 0 {
    if settings.fold_short_frac {
      "- \{(-num).to_string()} / \{den.to_string()}"
    } else {
      "- \\frac{\{(-num).to_string()}}{\{den.to_string()}}"
    }
  } else if settings.fold_short_frac {
    "\{num.to_string()} / \{den.to_string()}"
  } else {
    "\\frac{\{num.to_string()}}{\{den.to_string()}}"
  }
}

///|
fn latex_number(expr : Expr, settings : LatexSettings) -> String {
  match @symcore.exact_number_num_den(expr) {
    Some((num, den)) => latex_exact_number(num, den, settings)
    None => abort("latex_number expects exact number")
  }
}

///|
fn latex_float(value : @symcore.Float, settings : LatexSettings) -> String {
  if settings.full_prec {
    value.format(dps=@symnum.prec_to_dps(value.precision()))
  } else {
    value.to_string()
  }
}

///|
fn latex_complex_float(
  value : @symcore.ComplexFloat,
  settings : LatexSettings,
) -> String {
  let real = value.real_part()
  let imag = value.imag_part()
  let real_zero = @symnum.is_zero(real.to_mpf())
  let imag_zero = @symnum.is_zero(imag.to_mpf())
  let imag_negative = @symnum.mpf_sign(imag.to_mpf()) < 0
  if imag_zero {
    return latex_float(real, settings)
  }
  let imag_tex_raw = latex_float(imag, settings)
  let imag_tex = if imag_negative && imag_tex_raw.has_prefix("-") {
    imag_tex_raw[1:imag_tex_raw.length()].to_string()
  } else {
    imag_tex_raw
  }
  let imag_unit = settings.imaginary_unit_latex
  if real_zero {
    if imag_negative {
      "- \{imag_tex} \{imag_unit}"
    } else {
      "\{imag_tex} \{imag_unit}"
    }
  } else if imag_negative {
    "\{latex_float(real, settings)} - \{imag_tex} \{imag_unit}"
  } else {
    "\{latex_float(real, settings)} + \{imag_tex} \{imag_unit}"
  }
}

///|
fn latex_number_symbol(
  kind : @symcore.NumberSymbolKind,
  settings : LatexSettings,
) -> String {
  match kind {
    @symcore.NumberSymbolKind::ImaginaryUnit => settings.imaginary_unit_latex
    @symcore.NumberSymbolKind::Pi => "\\pi"
    @symcore.NumberSymbolKind::Exp1 => "e"
    @symcore.NumberSymbolKind::EulerGamma => "\\gamma"
    @symcore.NumberSymbolKind::GoldenRatio => "\\phi"
    @symcore.NumberSymbolKind::Catalan => "G"
    @symcore.NumberSymbolKind::Infinity => "\\infty"
    @symcore.NumberSymbolKind::NegativeInfinity => "-\\infty"
    @symcore.NumberSymbolKind::ComplexInfinity => "\\tilde{\\infty}"
    @symcore.NumberSymbolKind::NaN => "\\text{NaN}"
  }
}

///|
fn latex_singleton_set_constant(name : String) -> String? {
  match name {
    "EmptySet" => Some("\\emptyset")
    "UniversalSet" => Some("\\mathbb{U}")
    "Naturals" => Some("\\mathbb{N}")
    "Naturals0" => Some("\\mathbb{N}_0")
    "Integers" => Some("\\mathbb{Z}")
    "Rationals" => Some("\\mathbb{Q}")
    "Reals" => Some("\\mathbb{R}")
    "Complexes" => Some("\\mathbb{C}")
    _ => None
  }
}

///|
fn latex_singleton_set_rank(name : String) -> Int? {
  match name {
    "EmptySet" => Some(0)
    "Naturals" => Some(1)
    "Naturals0" => Some(2)
    "Integers" => Some(3)
    "Rationals" => Some(4)
    "Reals" => Some(5)
    "Complexes" => Some(6)
    "UniversalSet" => Some(7)
    _ => None
  }
}

///|
fn latex_singleton_set_expr_rank(expr : Expr) -> Int? {
  match @symcore.expr_form(expr) {
    @symcore.ExprForm::Symbol(name)
    | @symcore.ExprForm::FunctionHead(name)
    | @symcore.ExprForm::UndefinedFunction(name) =>
      latex_singleton_set_rank(name)
    _ => None
  }
}

///|
fn latex_is_atomic_index(expr : Expr) -> Bool {
  match @symcore.expr_form(expr) {
    @symcore.ExprForm::Number(_)
    | @symcore.ExprForm::NumberSymbol(_)
    | @symcore.ExprForm::Symbol(_)
    | @symcore.ExprForm::Dummy(_, _)
    | @symcore.ExprForm::Wild(_, _, _)
    | @symcore.ExprForm::WildFunction(_, _)
    | @symcore.ExprForm::FunctionHead(_)
    | @symcore.ExprForm::UndefinedFunction(_) => true
    _ => false
  }
}

///|
fn latex_sorted_exprs(items : Array[Expr]) -> Array[Expr] {
  let sorted = items.copy()
  sorted.sort_by((lhs, rhs) => {
    let lhs_is_number = @symcore.is_number_atom(lhs)
    let rhs_is_number = @symcore.is_number_atom(rhs)
    if lhs_is_number && !rhs_is_number {
      -1
    } else if !lhs_is_number && rhs_is_number {
      1
    } else {
      match
        (latex_singleton_set_expr_rank(lhs), latex_singleton_set_expr_rank(rhs)) {
        (Some(lhs_rank), Some(rhs_rank)) =>
          if lhs_rank < rhs_rank {
            -1
          } else if lhs_rank > rhs_rank {
            1
          } else {
            0
          }
        (Some(_), None) => -1
        (None, Some(_)) => 1
        (None, None) => @symcore.compare_expr(lhs, rhs)
      }
    }
  })
  sorted
}

///|
fn latex_needs_mul_brackets(expr : Expr) -> Bool {
  match @symcore.expr_form(expr) {
    @symcore.ExprForm::Add(_)
    | @symcore.ExprForm::Relational(_, _, _)
    | @symcore.ExprForm::Lambda(_, _)
    | @symcore.ExprForm::Subs(_, _, _) => true
    @symcore.ExprForm::ComplexFloat(value) =>
      !@symnum.is_zero(value.real_part().to_mpf()) &&
      !@symnum.is_zero(value.imag_part().to_mpf())
    _ => false
  }
}

///|
fn latex_needs_brackets(expr : Expr) -> Bool {
  match @symcore.expr_form(expr) {
    @symcore.ExprForm::Number(_) =>
      match @symcore.exact_number_num_den(expr) {
        Some((num, den)) => !(den.compare(1N) == 0 && num.compare(0N) >= 0)
        None => true
      }
    @symcore.ExprForm::Float(value) => @symnum.mpf_sign(value.to_mpf()) < 0
    @symcore.ExprForm::ComplexFloat(_) => true
    @symcore.ExprForm::NumberSymbol(@symcore.NumberSymbolKind::NegativeInfinity) =>
      true
    @symcore.ExprForm::Add(_)
    | @symcore.ExprForm::Relational(_, _, _)
    | @symcore.ExprForm::Lambda(_, _)
    | @symcore.ExprForm::Subs(_, _, _)
    | @symcore.ExprForm::Mod(_, _) => true
    _ => false
  }
}

///|
fn latex_needs_function_brackets(expr : Expr) -> Bool {
  if !latex_needs_brackets(expr) {
    return false
  }
  match @symcore.expr_form(expr) {
    @symcore.ExprForm::Mul(_) => false
    @symcore.ExprForm::Pow(base, _) => latex_needs_brackets(base)
    @symcore.ExprForm::Add(_)
    | @symcore.ExprForm::Apply(_, _)
    | @symcore.ExprForm::Relational(_, _, _)
    | @symcore.ExprForm::Lambda(_, _)
    | @symcore.ExprForm::Subs(_, _, _)
    | @symcore.ExprForm::Mod(_, _) => true
    _ => false
  }
}

///|
fn latex_wrap_power_base(
  expr : Expr,
  base_tex : String,
  settings : LatexSettings,
) -> String {
  match @symcore.expr_form(expr) {
    @symcore.ExprForm::Add(_)
    | @symcore.ExprForm::Mul(_)
    | @symcore.ExprForm::Pow(_, _)
    | @symcore.ExprForm::Mod(_, _)
    | @symcore.ExprForm::Relational(_, _, _)
    | @symcore.ExprForm::Apply(_, _)
    | @symcore.ExprForm::Derivative(_, _)
    | @symcore.ExprForm::Subs(_, _, _)
    | @symcore.ExprForm::Lambda(_, _) => latex_parens(base_tex)
    @symcore.ExprForm::Number(_) =>
      match @symcore.exact_number_num_den(expr) {
        Some((num, den)) if num.compare(0N) < 0 || den.compare(1N) != 0 =>
          latex_parens(base_tex)
        _ => base_tex
      }
    @symcore.ExprForm::Float(value) =>
      if @symnum.mpf_sign(value.to_mpf()) < 0 {
        latex_parens(base_tex)
      } else {
        base_tex
      }
    @symcore.ExprForm::ComplexFloat(_) => latex_parens(base_tex)
    _ => latex_parenthesize_super(base_tex, settings)
  }
}

///|
fn latex_tuple_items(expr : Expr) -> Array[Expr]? {
  match @symcore.expr_form(expr) {
    @symcore.ExprForm::Tuple(items) => Some(items)
    _ =>
      match ordinary_application_name_args(expr) {
        Some((name, args)) if name == "Tuple" => Some(args)
        _ => None
      }
  }
}

///|
fn latex_limit_items(expr : Expr) -> Array[Expr] {
  match latex_tuple_items(expr) {
    Some(items) => items
    None => [expr]
  }
}

///|
fn latex_mul_level_parenthesize(
  expr : Expr,
  settings : LatexSettings,
  is_neg? : Bool = false,
) -> String {
  let tex = latex_format_expr(expr, 0, settings)
  if is_neg || precedence(expr) < 3 {
    latex_parens(tex)
  } else {
    tex
  }
}

///|
fn latex_atomish_parenthesize(expr : Expr, settings : LatexSettings) -> String {
  let tex = latex_format_expr(expr, 0, settings)
  match @symcore.expr_form(expr) {
    @symcore.ExprForm::Number(_) =>
      match @symcore.exact_number_num_den(expr) {
        Some((num, den)) if den.compare(1N) == 0 && num.compare(0N) >= 0 => tex
        _ => latex_parens(tex)
      }
    @symcore.ExprForm::Float(value) =>
      if @symnum.mpf_sign(value.to_mpf()) < 0 {
        latex_parens(tex)
      } else {
        tex
      }
    @symcore.ExprForm::ComplexFloat(_) => latex_parens(tex)
    @symcore.ExprForm::NumberSymbol(@symcore.NumberSymbolKind::NegativeInfinity) =>
      latex_parens(tex)
    @symcore.ExprForm::Symbol(_)
    | @symcore.ExprForm::Dummy(_, _)
    | @symcore.ExprForm::Wild(_, _, _)
    | @symcore.ExprForm::WildFunction(_, _)
    | @symcore.ExprForm::IdentityFunction
    | @symcore.ExprForm::FunctionHead(_)
    | @symcore.ExprForm::UndefinedFunction(_) => tex
    _ => latex_parens(tex)
  }
}

///|
fn latex_integral_application(
  args : Array[Expr],
  settings : LatexSettings,
) -> String? {
  if args.is_empty() {
    return None
  }
  let integrand = args[0]
  let limits = args[1:args.length()].map(latex_limit_items)
  let mut tex = ""
  let symbols : Array[String] = []
  let mut all_single_limits = true
  for limit in limits {
    if limit.length() != 1 {
      all_single_limits = false
      break
    }
  }
  if !limits.is_empty() && limits.length() <= 4 && all_single_limits {
    let mut repeated_i = ""
    for _ in 0..<(limits.length() - 1) {
      repeated_i += "i"
    }
    tex = "\\i\{repeated_i}nt"
    for limit in limits {
      symbols.push(
        "\\, \{settings.diff_operator_latex}\{latex_format_expr(limit[0], 0, settings)}",
      )
    }
  } else {
    let mut i = limits.length()
    while i > 0 {
      i -= 1
      let limit = limits[i]
      if limit.is_empty() {
        return None
      }
      tex += "\\int"
      if limit.length() > 1 {
        if settings.mode != "inline" && !settings.itex {
          tex += "\\limits"
        }
        if limit.length() == 3 {
          tex += "_{\{latex_format_expr(limit[1], 0, settings)}}^{\{latex_format_expr(limit[2], 0, settings)}}"
        } else if limit.length() == 2 {
          tex += "^{\{latex_format_expr(limit[1], 0, settings)}}"
        }
      }
      symbols.insert(
        0,
        "\\, \{settings.diff_operator_latex}\{latex_format_expr(limit[0], 0, settings)}",
      )
    }
  }
  if tex == "" {
    tex = "\\int"
  }
  let body = latex_mul_level_parenthesize(
    integrand,
    settings,
    is_neg=split_negative_addend(integrand) is Some(_),
  )
  let symbols_tex = symbols.join("")
  Some("\{tex} \{body}\{symbols_tex}")
}

///|
fn latex_bigop_application(
  op_tex : String,
  args : Array[Expr],
  settings : LatexSettings,
) -> String? {
  if args.length() < 2 {
    return None
  }
  let func = args[0]
  let limits = args[1:args.length()].map(latex_limit_items)
  let head = if limits.length() == 1 {
    let limit = limits[0]
    if limit.length() == 3 {
      "\{op_tex}_{\{latex_format_expr(limit[0], 0, settings)}=\{latex_format_expr(limit[1], 0, settings)}}^{\{latex_format_expr(limit[2], 0, settings)}} "
    } else if limit.length() == 2 {
      "\{op_tex}_{\{latex_format_expr(limit[0], 0, settings)}=\{latex_format_expr(limit[1], 0, settings)}} "
    } else if limit.length() == 1 {
      "\{op_tex}_{\{latex_format_expr(limit[0], 0, settings)}} "
    } else {
      return None
    }
  } else {
    let rows : Array[String] = []
    for limit in limits {
      if limit.length() == 3 {
        rows.push(
          "\{latex_format_expr(limit[1], 0, settings)} \\leq \{latex_format_expr(limit[0], 0, settings)} \\leq \{latex_format_expr(limit[2], 0, settings)}",
        )
      } else {
        return None
      }
    }
    let rows_tex = rows.join("\\\\")
    "\{op_tex}_{\\substack{\{rows_tex}}} "
  }
  let body = match @symcore.expr_form(func) {
    @symcore.ExprForm::Add(_) =>
      latex_parens(latex_format_expr(func, 0, settings))
    _ => latex_format_expr(func, 0, settings)
  }
  Some(head + body)
}

///|
fn latex_limit_application(
  args : Array[Expr],
  settings : LatexSettings,
) -> String? {
  if args.length() < 3 {
    return None
  }
  let expr = args[0]
  let variable = args[1]
  let point = args[2]
  let dir = if args.length() >= 4 {
    match args[3] {
      @symcore.Expr::Symbol(name) => name
      _ => "+"
    }
  } else {
    "+"
  }
  let point_tex = latex_format_expr(point, 0, settings)
  let mut tex = "\\lim_{\{latex_format_expr(variable, 0, settings)} \\to "
  let point_is_infinite = match @symcore.expr_form(point) {
    @symcore.ExprForm::NumberSymbol(@symcore.NumberSymbolKind::Infinity)
    | @symcore.ExprForm::NumberSymbol(
      @symcore.NumberSymbolKind::NegativeInfinity
    ) => true
    _ => false
  }
  if dir == "+-" || point_is_infinite {
    tex += "\{point_tex}}"
  } else {
    tex += "\{point_tex}^\{dir}}"
  }
  let body = match @symcore.expr_form(expr) {
    @symcore.ExprForm::Add(_) | @symcore.ExprForm::Mul(_) =>
      latex_parens(latex_format_expr(expr, 0, settings))
    _ => latex_format_expr(expr, 0, settings)
  }
  Some("\{tex} \{body}")
}

///|
fn latex_variadic_named_application(
  latex_name : String,
  args : Array[Expr],
  settings : LatexSettings,
  exp? : String? = None,
) -> String {
  let rendered = args
    .map(child => latex_format_expr(child, 0, settings))
    .join(", ")
  let tex = "\\\{latex_name}\\left(\{rendered}\\right)"
  match exp {
    Some(power) => "\{tex}^{\{power}}"
    None => tex
  }
}

///|
fn latex_logic_is_compound(expr : Expr) -> Bool {
  match ordinary_application_name_args(expr) {
    Some((name, _)) =>
      match name {
        "And" | "Or" | "Xor" | "Implies" | "Equivalent" => true
        _ => false
      }
    None => false
  }
}

///|
fn latex_logic_arg(expr : Expr, settings : LatexSettings) -> String {
  let tex = latex_format_expr(expr, 0, settings)
  if latex_logic_is_compound(expr) {
    latex_parens(tex)
  } else {
    tex
  }
}

///|
fn latex_logical_operation(
  args : Array[Expr],
  settings : LatexSettings,
  char : String,
  sort? : Bool = false,
) -> String {
  let items = if sort { latex_sorted_exprs(args) } else { args.copy() }
  if items.is_empty() {
    return ""
  }
  let rendered : Array[String] = []
  for item in items {
    rendered.push(latex_logic_arg(item, settings))
  }
  rendered.join(" \{char} ")
}

///|
fn latex_piecewise_application(
  args : Array[Expr],
  settings : LatexSettings,
) -> String? {
  if args.is_empty() || args.length() % 2 != 0 {
    return None
  }
  let rows : Array[String] = []
  let mut i = 0
  while i < args.length() {
    let expr_tex = latex_format_expr(args[i], 0, settings)
    let cond = args[i + 1]
    let row = match @symcore.expr_form(cond) {
      @symcore.ExprForm::Boolean(true) if i + 2 == args.length() =>
        "\{expr_tex} & \\text{otherwise}"
      _ =>
        "\{expr_tex} & \\text{for}\\: \{latex_format_expr(cond, 0, settings)}"
    }
    rows.push(row)
    i += 2
  }
  let rows_tex = rows.join(" \\\\")
  Some("\\begin{cases} \{rows_tex} \\end{cases}")
}

///|
fn latex_unified_transform(
  symbol : String,
  args : Array[Expr],
  settings : LatexSettings,
  inverse? : Bool = false,
) -> String? {
  if args.length() < 3 {
    return None
  }
  let inverse_tex = if inverse { "^{-1}" } else { "" }
  Some(
    "\\mathcal{\{symbol}}\{inverse_tex}_{\{latex_format_expr(args[1], 0, settings)}}\\left[\{latex_format_expr(args[0], 0, settings)}\\right]\\left(\{latex_format_expr(args[2], 0, settings)}\\right)",
  )
}

///|
fn latex_is_universal_set_expr(expr : Expr) -> Bool {
  match @symcore.expr_form(expr) {
    @symcore.ExprForm::Symbol(name)
    | @symcore.ExprForm::FunctionHead(name)
    | @symcore.ExprForm::UndefinedFunction(name) => name == "UniversalSet"
    _ => false
  }
}

///|
fn latex_set_parenthesize(expr : Expr, settings : LatexSettings) -> String {
  let tex = latex_format_expr(expr, 0, settings)
  match ordinary_application_name_args(expr) {
    Some((name, _)) =>
      match name {
        "Union" | "Intersection" | "Complement" => latex_parens(tex)
        _ => tex
      }
    None => tex
  }
}

///|
fn latex_finite_set_application(
  args : Array[Expr],
  settings : LatexSettings,
) -> String {
  let items = latex_sorted_exprs(args)
  if items.is_empty() {
    return "\\emptyset"
  }
  let rendered = items
    .map(item => latex_format_expr(item, 0, settings))
    .join(", ")
  "\\left\\{\{rendered}\\right\\}"
}

///|
fn latex_interval_application(
  args : Array[Expr],
  settings : LatexSettings,
) -> String? {
  if args.length() < 2 {
    return None
  }
  let start = args[0]
  let end = args[1]
  if @symcore.compare_expr(start, end) == 0 {
    return Some("\\left\\{\{latex_format_expr(start, 0, settings)}\\right\\}")
  }
  let left_open = if args.length() >= 3 {
    @symcore.bool_value(args[2]).unwrap_or(false)
  } else {
    false
  }
  let right_open = if args.length() >= 4 {
    @symcore.bool_value(args[3]).unwrap_or(false)
  } else {
    false
  }
  let left = if left_open { "(" } else { "[" }
  let right = if right_open { ")" } else { "]" }
  Some(
    "\\left\{left}\{latex_format_expr(start, 0, settings)}, \{latex_format_expr(end, 0, settings)}\\right\{right}",
  )
}

///|
fn latex_exact_int_value(expr : Expr) -> Int? {
  match @symcore.exact_number_num_den(expr) {
    Some((num, den)) if den.compare(1N) == 0 => Some(num.to_int())
    _ => None
  }
}

///|
fn latex_range_symbolic(
  start : Expr,
  stop : Expr,
  step : Expr,
  settings : LatexSettings,
) -> String {
  let cont = if @symcore.compare_expr(start, @symcore.int(0)) == 0 {
    if @symcore.compare_expr(step, @symcore.int(1)) == 0 {
      latex_format_expr(stop, 0, settings)
    } else {
      [
        latex_format_expr(start, 0, settings),
        latex_format_expr(stop, 0, settings),
        latex_format_expr(step, 0, settings),
      ].join(", ")
    }
  } else if @symcore.compare_expr(step, @symcore.int(1)) == 0 {
    [
      latex_format_expr(start, 0, settings),
      latex_format_expr(stop, 0, settings),
    ].join(", ")
  } else {
    [
      latex_format_expr(start, 0, settings),
      latex_format_expr(stop, 0, settings),
      latex_format_expr(step, 0, settings),
    ].join(", ")
  }
  "\\text{Range}\\left(\{cont}\\right)"
}

///|
fn latex_range_application(
  args : Array[Expr],
  settings : LatexSettings,
) -> String? {
  let (start, stop, step) = match args {
    [stop] => (@symcore.int(0), stop, @symcore.int(1))
    [start, stop] => (start, stop, @symcore.int(1))
    [start, stop, step] => (start, stop, step)
    _ => return None
  }
  match
    (
      latex_exact_int_value(start),
      latex_exact_int_value(stop),
      latex_exact_int_value(step),
    ) {
    (Some(start_i), Some(stop_i), Some(step_i)) if step_i != 0 => {
      let values : Array[Int] = []
      let mut current = start_i
      let mut steps_taken = 0
      while (
              (step_i > 0 && current < stop_i) ||
              (step_i < 0 && current > stop_i)
            ) &&
            steps_taken < 10000 {
        values.push(current)
        current += step_i
        steps_taken += 1
      }
      if steps_taken >= 10000 {
        return Some(latex_range_symbolic(start, stop, step, settings))
      }
      if values.is_empty() {
        return Some("\\left\\{\\right\\}")
      }
      let rendered = if values.length() < 4 {
        values.map(v => v.to_string()).join(", ")
      } else {
        [
          values[0].to_string(),
          values[1].to_string(),
          "\\ldots",
          values[values.length() - 1].to_string(),
        ].join(", ")
      }
      Some("\\left\\{\{rendered}\\right\\}")
    }
    _ => Some(latex_range_symbolic(start, stop, step, settings))
  }
}

///|
fn latex_set_operation_application(
  name : String,
  op_tex : String,
  args : Array[Expr],
  settings : LatexSettings,
  sort? : Bool = true,
) -> String? {
  if args.is_empty() {
    return None
  }
  let items = if sort { latex_sorted_exprs(args) } else { args.copy() }
  let rendered = items
    .map(item => latex_set_parenthesize(item, settings))
    .join(" \{op_tex} ")
  ignore(name)
  Some(rendered)
}

///|
fn latex_product_set_application(
  args : Array[Expr],
  settings : LatexSettings,
) -> String? {
  if args.is_empty() {
    return None
  }
  let mut same = true
  for i in 1..<args.length() {
    if @symcore.compare_expr(args[0], args[i]) != 0 {
      same = false
      break
    }
  }
  if same {
    return Some(
      "\{latex_set_parenthesize(args[0], settings)}^{\{args.length().to_string()}}",
    )
  }
  Some(
    args.map(item => latex_set_parenthesize(item, settings)).join(" \\times "),
  )
}

///|
fn latex_condition_set_application(
  args : Array[Expr],
  settings : LatexSettings,
) -> String? {
  if args.length() < 3 {
    return None
  }
  let vars_tex = latex_format_expr(args[0], 0, settings)
  let cond_tex = latex_format_expr(args[1], 0, settings)
  if latex_is_universal_set_expr(args[2]) {
    return Some("\\left\\{\{vars_tex}\\; \\middle|\\; \{cond_tex} \\right\\}")
  }
  let base_tex = latex_format_expr(args[2], 0, settings)
  Some(
    "\\left\\{\{vars_tex}\\; \\middle|\\; \{vars_tex} \\in \{base_tex} \\wedge \{cond_tex} \\right\\}",
  )
}

///|
fn latex_image_set_application(
  args : Array[Expr],
  settings : LatexSettings,
) -> String? {
  if args.length() < 2 {
    return None
  }
  let (vars, body) = match @symcore.expr_form(args[0]) {
    @symcore.ExprForm::Lambda(vars, body) => (vars, body)
    _ => return None
  }
  let vars_items = match @symcore.expr_form(vars) {
    @symcore.ExprForm::Tuple(items) => items
    _ => [vars]
  }
  if vars_items.length() != args.length() - 1 {
    return None
  }
  let clauses : Array[String] = []
  for i in 0..<vars_items.length() {
    clauses.push(
      "\{latex_format_expr(vars_items[i], 0, settings)} \\in \{latex_format_expr(args[i + 1], 0, settings)}",
    )
  }
  let clauses_tex = clauses.join(", ")
  Some(
    "\\left\\{\{latex_format_expr(body, 0, settings)}\\; \\middle|\\; \{clauses_tex}\\right\\}",
  )
}

///|
fn latex_power_set_application(
  args : Array[Expr],
  settings : LatexSettings,
) -> String? {
  if args.length() != 1 {
    return None
  }
  Some("\\mathcal{P}\\left(\{latex_format_expr(args[0], 0, settings)}\\right)")
}

///|
fn latex_contains_application(
  args : Array[Expr],
  settings : LatexSettings,
) -> String? {
  if args.length() != 2 {
    return None
  }
  Some(
    "\{latex_format_expr(args[0], 0, settings)} \\in \{latex_format_expr(args[1], 0, settings)}",
  )
}

///|
fn latex_order_application(
  args : Array[Expr],
  settings : LatexSettings,
) -> String? {
  if args.is_empty() {
    return None
  }
  let mut s = latex_format_expr(args[0], 0, settings)
  if args.length() > 1 {
    match latex_tuple_items(args[1]) {
      Some(items) if items.length() == 2 =>
        s += "; \{latex_format_expr(items[0], 0, settings)}\\rightarrow \{latex_format_expr(items[1], 0, settings)}"
      Some(items) if items.length() > 0 =>
        s += "; " +
          latex_parens_lspace(
            items
            .map(child => latex_format_expr(child, 0, settings))
            .join(", \\  "),
          )
      _ => s += "; " + latex_format_expr(args[1], 0, settings)
    }
  }
  Some("O\\left(\{s}\\right)")
}

///|
fn latex_function_application(
  settings : LatexSettings,
  name : String,
  args : Array[Expr],
  exp? : String? = None,
) -> String {
  let do_exponent = fn(tex : String) -> String {
    match exp {
      Some(power) => "\\left(\{tex}\\right)^{\{power}}"
      None => tex
    }
  }
  if name == "sqrt" && args.length() == 1 && exp is None {
    return "\\sqrt{\{latex_format_expr(args[0], 0, settings)}}"
  }
  if name == "exp" && args.length() == 1 {
    let tex = "e^{\{latex_format_expr(args[0], 0, settings)}}"
    return match exp {
      Some(power) => "\\left(\{tex}\\right)^{\{power}}"
      None => tex
    }
  }
  if name == "Abs" && args.length() == 1 {
    let tex = "\\left|{\{latex_format_expr(args[0], 0, settings)}}\\right|"
    return match exp {
      Some(power) => "\{tex}^{\{power}}"
      None => tex
    }
  }
  if name == "conjugate" && args.length() == 1 {
    let tex = "\\overline{\{latex_format_expr(args[0], 0, settings)}}"
    return match exp {
      Some(power) => "\{tex}^{\{power}}"
      None => tex
    }
  }
  if name == "log" && args.length() == 2 {
    let argument = latex_format_expr(args[0], 0, settings)
    let base = latex_format_expr(args[1], 0, settings)
    let tex = if base.length() == 1 {
      "\\log_\{base}{\\left(\{argument} \\right)}"
    } else {
      "\\log_{\{base}}{\\left(\{argument} \\right)}"
    }
    return match exp {
      Some(power) => "\{tex}^{\{power}}"
      None => tex
    }
  }
  if name == "log" && args.length() == 1 {
    let func_tex = if settings.ln_notation { "\\ln" } else { "\\log" }
    let tex = "\{func_tex}{\\left(\{latex_format_expr(args[0], 0, settings)} \\right)}"
    return match exp {
      Some(power) => "\{tex}^{\{power}}"
      None => tex
    }
  }
  if name == "Integral" {
    match latex_integral_application(args, settings) {
      Some(tex) => return tex
      None => ()
    }
  }
  if name == "Sum" {
    match latex_bigop_application("\\sum", args, settings) {
      Some(tex) => return tex
      None => ()
    }
  }
  if name == "Product" {
    match latex_bigop_application("\\prod", args, settings) {
      Some(tex) => return tex
      None => ()
    }
  }
  if name == "Limit" {
    match latex_limit_application(args, settings) {
      Some(tex) => return tex
      None => ()
    }
  }
  if name == "Piecewise" {
    match latex_piecewise_application(args, settings) {
      Some(tex) => return tex
      None => ()
    }
  }
  if name == "Not" && args.length() == 1 {
    match ordinary_application_name_args(args[0]) {
      Some(("Equivalent", inner_args)) =>
        return latex_logical_operation(
          inner_args,
          settings,
          "\\not\\Leftrightarrow",
          sort=true,
        )
      Some(("Implies", inner_args)) =>
        return latex_logical_operation(
          inner_args,
          settings,
          "\\not\\Rightarrow",
          sort=false,
        )
      _ => ()
    }
    let inner = latex_logic_arg(args[0], settings)
    return "\\neg \{inner}"
  }
  if name == "And" {
    return latex_logical_operation(args, settings, "\\wedge", sort=true)
  }
  if name == "Or" {
    return latex_logical_operation(args, settings, "\\vee", sort=true)
  }
  if name == "Xor" {
    return latex_logical_operation(args, settings, "\\veebar", sort=true)
  }
  if name == "Implies" {
    return latex_logical_operation(args, settings, "\\Rightarrow")
  }
  if name == "Equivalent" {
    return latex_logical_operation(
      args,
      settings,
      "\\Leftrightarrow",
      sort=true,
    )
  }
  if name == "Min" {
    return latex_variadic_named_application("min", args, settings, exp~)
  }
  if name == "Max" {
    return latex_variadic_named_application("max", args, settings, exp~)
  }
  if name == "floor" && args.length() == 1 {
    let tex = "\\left\\lfloor{\{latex_format_expr(args[0], 0, settings)}}\\right\\rfloor"
    return match exp {
      Some(power) => "\{tex}^{\{power}}"
      None => tex
    }
  }
  if name == "ceiling" && args.length() == 1 {
    let tex = "\\left\\lceil{\{latex_format_expr(args[0], 0, settings)}}\\right\\rceil"
    return match exp {
      Some(power) => "\{tex}^{\{power}}"
      None => tex
    }
  }
  if name == "re" && args.length() == 1 {
    return do_exponent(
      "\\operatorname{re}{\{latex_atomish_parenthesize(args[0], settings)}}",
    )
  }
  if name == "im" && args.length() == 1 {
    return do_exponent(
      "\\operatorname{im}{\{latex_atomish_parenthesize(args[0], settings)}}",
    )
  }
  if name == "O" {
    match latex_order_application(args, settings) {
      Some(tex) => return tex
      None => ()
    }
  }
  if name == "DiracDelta" && !args.is_empty() {
    let tex = if args.length() == 1 ||
      @symcore.compare_expr(args[1], @symcore.int(0)) == 0 {
      "\\delta\\left(\{latex_format_expr(args[0], 0, settings)}\\right)"
    } else {
      "\\delta^{\\left( \{latex_format_expr(args[1], 0, settings)} \\right)}\\left( \{latex_format_expr(args[0], 0, settings)} \\right)"
    }
    return match exp {
      Some(power) => "\\left(\{tex}\\right)^{\{power}}"
      None => tex
    }
  }
  if name == "Heaviside" && !args.is_empty() {
    let rendered_args = if args.length() == 2 {
      match @symcore.exact_number_num_den(args[1]) {
        Some((num, den)) if num.compare(1N) == 0 && den.compare(2N) == 0 =>
          [latex_format_expr(args[0], 0, settings)]
        _ => args.map(arg => latex_format_expr(arg, 0, settings))
      }
    } else {
      args.map(arg => latex_format_expr(arg, 0, settings))
    }
    let rendered_args_tex = rendered_args.join(", ")
    let tex = "\\theta\\left(\{rendered_args_tex}\\right)"
    return match exp {
      Some(power) => "\\left(\{tex}\\right)^{\{power}}"
      None => tex
    }
  }
  if name == "KroneckerDelta" && args.length() == 2 {
    let lhs = latex_format_expr(args[0], 0, settings)
    let rhs = latex_format_expr(args[1], 0, settings)
    let tex = if latex_is_atomic_index(args[0]) &&
      latex_is_atomic_index(args[1]) {
      "\\delta_{\{lhs} \{rhs}}"
    } else {
      "\\delta_{\{lhs}, \{rhs}}"
    }
    return match exp {
      Some(power) => "\\left(\{tex}\\right)^{\{power}}"
      None => tex
    }
  }
  if name == "LeviCivita" && !args.is_empty() {
    let rendered = args.map(arg => latex_format_expr(arg, 0, settings))
    let rendered_tex = if args.all(latex_is_atomic_index) {
      rendered.join(" ")
    } else {
      rendered.join(", ")
    }
    let tex = "\\varepsilon_{\{rendered_tex}}"
    return match exp {
      Some(power) => "\\left(\{tex}\\right)^{\{power}}"
      None => tex
    }
  }
  if name == "FiniteSet" {
    return latex_finite_set_application(args, settings)
  }
  if name == "Interval" {
    match latex_interval_application(args, settings) {
      Some(tex) => return tex
      None => ()
    }
  }
  if name == "Range" {
    match latex_range_application(args, settings) {
      Some(tex) => return tex
      None => ()
    }
  }
  if name == "Union" {
    match
      latex_set_operation_application(name, "\\cup", args, settings, sort=true) {
      Some(tex) => return tex
      None => ()
    }
  }
  if name == "Intersection" {
    match
      latex_set_operation_application(name, "\\cap", args, settings, sort=true) {
      Some(tex) => return tex
      None => ()
    }
  }
  if name == "Complement" {
    match
      latex_set_operation_application(
        name,
        "\\setminus",
        args,
        settings,
        sort=false,
      ) {
      Some(tex) => return tex
      None => ()
    }
  }
  if name == "ProductSet" {
    match latex_product_set_application(args, settings) {
      Some(tex) => return tex
      None => ()
    }
  }
  if name == "ConditionSet" {
    match latex_condition_set_application(args, settings) {
      Some(tex) => return tex
      None => ()
    }
  }
  if name == "ImageSet" {
    match latex_image_set_application(args, settings) {
      Some(tex) => return tex
      None => ()
    }
  }
  if name == "PowerSet" {
    match latex_power_set_application(args, settings) {
      Some(tex) => return tex
      None => ()
    }
  }
  if name == "Contains" {
    match latex_contains_application(args, settings) {
      Some(tex) => return tex
      None => ()
    }
  }
  if name == "MellinTransform" {
    match latex_unified_transform("M", args, settings) {
      Some(tex) => return tex
      None => ()
    }
  }
  if name == "InverseMellinTransform" {
    match latex_unified_transform("M", args, settings, inverse=true) {
      Some(tex) => return tex
      None => ()
    }
  }
  if name == "LaplaceTransform" {
    match latex_unified_transform("L", args, settings) {
      Some(tex) => return tex
      None => ()
    }
  }
  if name == "InverseLaplaceTransform" {
    match latex_unified_transform("L", args, settings, inverse=true) {
      Some(tex) => return tex
      None => ()
    }
  }
  if name == "FourierTransform" {
    match latex_unified_transform("F", args, settings) {
      Some(tex) => return tex
      None => ()
    }
  }
  if name == "InverseFourierTransform" {
    match latex_unified_transform("F", args, settings, inverse=true) {
      Some(tex) => return tex
      None => ()
    }
  }
  if name == "SineTransform" {
    match latex_unified_transform("SIN", args, settings) {
      Some(tex) => return tex
      None => ()
    }
  }
  if name == "InverseSineTransform" {
    match latex_unified_transform("SIN", args, settings, inverse=true) {
      Some(tex) => return tex
      None => ()
    }
  }
  if name == "CosineTransform" {
    match latex_unified_transform("COS", args, settings) {
      Some(tex) => return tex
      None => ()
    }
  }
  if name == "InverseCosineTransform" {
    match latex_unified_transform("COS", args, settings, inverse=true) {
      Some(tex) => return tex
      None => ()
    }
  }
  let mut func = if settings.ln_notation && name == "log" { "ln" } else { name }
  let inv_trig_table = [
    "asin", "acos", "atan", "acsc", "asec", "acot", "asinh", "acosh", "atanh", "acsch",
    "asech", "acoth",
  ]
  let mut inv_trig_power_case = false
  let mut can_fold_brackets = settings.fold_func_brackets &&
    args.length() == 1 &&
    !latex_needs_function_brackets(args[0])
  if inv_trig_table.contains(func) {
    match settings.inv_trig_style {
      "full" =>
        func = (if func.has_suffix("h") { "ar" } else { "arc" }) +
          func[1:func.length()].to_string()
      "power" => {
        func = func[1:func.length()].to_string()
        inv_trig_power_case = true
        if exp is Some(_) {
          can_fold_brackets = false
        }
      }
      _ => ()
    }
  }
  let mut head = if inv_trig_power_case {
    if is_accepted_latex_function(func) {
      "\\\{func}^{-1}"
    } else {
      "\\operatorname{\{func}}^{-1}"
    }
  } else {
    latex_hprint_function(func)
  }
  match exp {
    Some(power) =>
      head = "\{latex_parenthesize_super(head, settings)}^{\{power}}"
    None => ()
  }
  if args.is_empty() {
    return head
  }
  let rendered = args
    .map(child => latex_format_expr(child, 0, settings))
    .join(",")
  let arg_body = if can_fold_brackets {
    if is_accepted_latex_function(func) {
      " {\{rendered}}"
    } else {
      rendered
    }
  } else {
    "{\\left(\{rendered} \\right)}"
  }
  let suffix = if inv_trig_power_case {
    match exp {
      Some(power) => "^{\{power}}"
      None => ""
    }
  } else {
    ""
  }
  "\{head}\{arg_body}\{suffix}"
}

///|
fn expr_is_numericish(expr : Expr) -> Bool {
  match @symcore.expr_form(expr) {
    @symcore.ExprForm::Number(_)
    | @symcore.ExprForm::Float(_)
    | @symcore.ExprForm::ComplexFloat(_)
    | @symcore.ExprForm::NumberSymbol(_) => true
    _ => false
  }
}

///|
fn latex_mul(
  expr : Expr,
  args : Array[Expr],
  parent_prec : Int,
  settings : LatexSettings,
) -> String {
  let numerators : Array[Expr] = []
  let denominators : Array[Expr] = []
  let mut sign = ""
  for arg in args {
    match @symcore.expr_form(arg) {
      @symcore.ExprForm::Pow(base, exp) =>
        match exact_positive_denominator_pow(base, exp) {
          Some(den) => denominators.push(den)
          None => numerators.push(arg)
        }
      _ =>
        match @symcore.exact_number_num_den(arg) {
          Some((num, den)) => {
            let abs_num = if num.compare(0N) < 0 { -num } else { num }
            if num.compare(0N) < 0 {
              sign = if sign == "" { "-" } else { "" }
            }
            if den.compare(1N) != 0 {
              numerators.push(
                @symcore.Expr::Number(@symnum.BigRational::from_bigint(abs_num)),
              )
              denominators.push(
                @symcore.Expr::Number(@symnum.BigRational::from_bigint(den)),
              )
            } else {
              numerators.push(exact_abs_expr(arg))
            }
          }
          None => numerators.push(arg)
        }
    }
  }
  if numerators.is_empty() {
    numerators.push(@symcore.int(1))
  }
  if numerators.length() > 1 {
    let filtered : Array[Expr] = []
    for child in numerators {
      if !exact_one_expr(child) {
        filtered.push(child)
      }
    }
    if !filtered.is_empty() {
      numerators.clear()
      for child in filtered {
        numerators.push(child)
      }
    }
  }

  let join_product = fn(items : Array[Expr], wrap_single_add : Bool) -> String {
    let rendered : Array[String] = []
    let numeric_flags : Array[Bool] = []
    for child in items {
      numeric_flags.push(expr_is_numericish(child))
      let child_tex = latex_format_expr(child, 0, settings)
      let single_add = if items.length() == 1 {
        match @symcore.expr_form(child) {
          @symcore.ExprForm::Add(_) => true
          _ => false
        }
      } else {
        false
      }
      let wrap_child = latex_needs_mul_brackets(child) &&
        !(single_add && !wrap_single_add)
      if wrap_child {
        rendered.push(latex_parens(child_tex))
      } else {
        rendered.push(child_tex)
      }
    }
    if rendered.is_empty() {
      return ""
    }
    let mut out = rendered[0]
    for i in 1..<rendered.length() {
      let separator = if numeric_flags[i - 1] && numeric_flags[i] {
        settings.mul_symbol_latex_numbers
      } else {
        settings.mul_symbol_latex
      }
      out += separator + rendered[i]
    }
    out
  }

  let body = if denominators.is_empty() {
    sign + join_product(numerators, false)
  } else {
    let numerator_tex = join_product(numerators, false)
    let denominator_tex = join_product(denominators, false)
    if settings.fold_short_frac &&
      denominators.length() == 1 &&
      !contains_caret(denominator_tex) {
      let numerator_short = join_product(numerators, true)
      let denominator_short = join_product(denominators, true)
      sign + numerator_short + " / " + denominator_short
    } else {
      sign + "\\frac{\{numerator_tex}}{\{denominator_tex}}"
    }
  }
  if precedence(expr) < parent_prec {
    latex_parens(body)
  } else {
    body
  }
}

///|
fn latex_pow(base : Expr, exp : Expr, settings : LatexSettings) -> String {
  match ordinary_application_name_args(base) {
    Some((name, args)) if name != "exp" =>
      return latex_function_application(
        settings,
        name,
        args,
        exp=Some(latex_format_expr(exp, 0, settings)),
      )
    _ => ()
  }
  match @symcore.exact_number_num_den(exp) {
    Some((num, den)) if den.compare(1N) != 0 => {
      let abs_num = if num.compare(0N) < 0 { -num } else { num }
      if abs_num.compare(1N) == 0 && settings.root_notation {
        let base_tex = latex_format_expr(base, 0, settings)
        let root = if den.compare(2N) == 0 {
          "\\sqrt{\{base_tex}}"
        } else if settings.itex {
          "\\root{\{den.to_string()}}{\{base_tex}}"
        } else {
          "\\sqrt[\{den.to_string()}]{\{base_tex}}"
        }
        if num.compare(0N) < 0 {
          "\\frac{1}{\{root}}"
        } else {
          root
        }
      } else if settings.fold_frac_powers {
        match ordinary_application_name_args(base) {
          Some((name, args)) =>
            latex_function_application(
              settings,
              name,
              args,
              exp=Some("\{num.to_string()}/\{den.to_string()}"),
            )
          None => {
            let base_tex = latex_wrap_power_base(
              base,
              latex_format_expr(base, 0, settings),
              settings,
            )
            "\{base_tex}^{\{num.to_string()}/\{den.to_string()}}"
          }
        }
      } else if num.compare(0N) < 0 {
        let pos_exp = latex_exact_number(abs_num, den, latex_settings())
        let base_tex = latex_wrap_power_base(
          base,
          latex_format_expr(base, 0, settings),
          settings,
        )
        "\\frac{1}{\{base_tex}^{\{pos_exp}}}"
      } else {
        let exp_tex = latex_exact_number(num, den, latex_settings())
        let base_tex = latex_wrap_power_base(
          base,
          latex_format_expr(base, 0, settings),
          settings,
        )
        "\{base_tex}^{\{exp_tex}}"
      }
    }
    Some((num, den)) if den.compare(1N) == 0 && num.compare(-1N) == 0 =>
      if settings.fold_short_frac {
        "1 / " +
        latex_wrap_power_base(
          base,
          latex_format_expr(base, 0, settings),
          settings,
        )
      } else {
        "\\frac{1}{\{latex_format_expr(base, 0, settings)}}"
      }
    _ => {
      let base_tex = latex_wrap_power_base(
        base,
        latex_format_expr(base, 0, settings),
        settings,
      )
      "\{base_tex}^{\{latex_format_expr(exp, 0, settings)}}"
    }
  }
}

///|
fn latex_format_expr(
  expr : Expr,
  parent_prec : Int,
  settings : LatexSettings,
) -> String {
  match ordinary_application_name_args(expr) {
    Some((name, args)) =>
      return latex_function_application(settings, name, args)
    None => ()
  }
  let prec = precedence(expr)
  let body = match @symcore.expr_form(expr) {
    @symcore.ExprForm::Number(_) => latex_number(expr, settings)
    @symcore.ExprForm::Float(value) => latex_float(value, settings)
    @symcore.ExprForm::ComplexFloat(value) =>
      latex_complex_float(value, settings)
    @symcore.ExprForm::NumberSymbol(kind) => latex_number_symbol(kind, settings)
    @symcore.ExprForm::Symbol(name) =>
      match settings.symbol_names.get(name) {
        Some(rendered) => rendered
        None =>
          match latex_singleton_set_constant(name) {
            Some(tex) => tex
            None => deal_with_super_sub(name)
          }
      }
    @symcore.ExprForm::Dummy(name, _) => deal_with_super_sub(name)
    @symcore.ExprForm::Wild(name, _, _) => deal_with_super_sub(name)
    @symcore.ExprForm::WildFunction(name, _) => latex_hprint_function(name)
    @symcore.ExprForm::IdentityFunction => "\\left( x \\mapsto x \\right)"
    @symcore.ExprForm::FunctionHead(name) =>
      match latex_singleton_set_constant(name) {
        Some(tex) => tex
        None => latex_hprint_function(name)
      }
    @symcore.ExprForm::UndefinedFunction(name) =>
      match latex_singleton_set_constant(name) {
        Some(tex) => tex
        None => latex_hprint_function(name)
      }
    @symcore.ExprForm::Boolean(true) => "\\text{True}"
    @symcore.ExprForm::Boolean(false) => "\\text{False}"
    @symcore.ExprForm::Add(args) =>
      if args.is_empty() {
        "0"
      } else if args.length() == 2 {
        match split_negative_addend(args[0]) {
          Some(positive0) if exact_positive_expr(args[1]) =>
            latex_format_expr(args[1], prec, settings) +
            " - " +
            latex_format_expr(positive0, prec, settings)
          _ => {
            let rendered : Array[String] = []
            rendered.push(latex_format_expr(args[0], prec, settings))
            for i in 1..<args.length() {
              match split_negative_addend(args[i]) {
                Some(positive) =>
                  rendered.push(
                    "- " + latex_format_expr(positive, prec, settings),
                  )
                None =>
                  rendered.push(
                    "+ " + latex_format_expr(args[i], prec, settings),
                  )
              }
            }
            rendered.join(" ")
          }
        }
      } else {
        let rendered : Array[String] = []
        rendered.push(latex_format_expr(args[0], prec, settings))
        for i in 1..<args.length() {
          match split_negative_addend(args[i]) {
            Some(positive) =>
              rendered.push("- " + latex_format_expr(positive, prec, settings))
            None =>
              rendered.push("+ " + latex_format_expr(args[i], prec, settings))
          }
        }
        rendered.join(" ")
      }
    @symcore.ExprForm::Mul(args) =>
      return latex_mul(expr, args, parent_prec, settings)
    @symcore.ExprForm::Pow(base, exp) => latex_pow(base, exp, settings)
    @symcore.ExprForm::Mod(lhs, rhs) => {
      let lhs_tex_raw = latex_format_expr(lhs, 0, settings)
      let rhs_tex_raw = latex_format_expr(rhs, 0, settings)
      let lhs_tex = if latex_needs_mul_brackets(lhs) {
        latex_parens(lhs_tex_raw)
      } else {
        lhs_tex_raw
      }
      let rhs_tex = if latex_needs_mul_brackets(rhs) {
        latex_parens(rhs_tex_raw)
      } else {
        rhs_tex_raw
      }
      "\{lhs_tex} \\bmod \{rhs_tex}"
    }
    @symcore.ExprForm::Tuple(args) =>
      if args.length() == 1 {
        latex_parens_lspace(latex_format_expr(args[0], 0, settings) + ",")
      } else {
        latex_parens_lspace(
          args
          .map(child => latex_format_expr(child, 0, settings))
          .join(", \\  "),
        )
      }
    @symcore.ExprForm::Dict(items) => {
      let rendered : Array[String] = []
      for item in @symcore.sorted_dict_entries(items) {
        let (key, value) = item
        rendered.push(
          "\{latex_format_expr(key, 0, settings)} : \{latex_format_expr(value, 0, settings)}",
        )
      }
      let dict_tex = rendered.join(", \\  ")
      "\\left\\{ \{dict_tex}\\right\\}"
    }
    @symcore.ExprForm::Relational(op, lhs, rhs) => {
      let rel = match op {
        @symcore.RelOp::Eq => "="
        @symcore.RelOp::Ne => "\\neq"
        @symcore.RelOp::Lt => "<"
        @symcore.RelOp::Le => "\\leq"
        @symcore.RelOp::Gt => ">"
        @symcore.RelOp::Ge => "\\geq"
      }
      "\{latex_format_expr(lhs, 0, settings)} \{rel} \{latex_format_expr(rhs, 0, settings)}"
    }
    @symcore.ExprForm::Derivative(inner, deriv_args) => {
      let pair_count = deriv_args.length() / 2
      let wrts : Array[(Expr, Expr)] = []
      for i in 0..<pair_count {
        wrts.push((deriv_args[i * 2], deriv_args[i * 2 + 1]))
      }
      let mut total_order = 0
      let parts : Array[String] = []
      if !wrts.is_empty() {
        let mut i = wrts.length() - 1
        while true {
          let (wrt, order) = wrts[i]
          match @symcore.exact_number_num_den(order) {
            Some((num, den)) if den.compare(1N) == 0 => {
              total_order += num.to_int()
              if num.compare(1N) == 0 {
                parts.push(
                  "\{settings.diff_operator_latex} " +
                  latex_parenthesize_super(
                    latex_format_expr(wrt, 0, settings),
                    settings,
                  ),
                )
              } else {
                parts.push(
                  "\{settings.diff_operator_latex} " +
                  latex_parenthesize_super(
                    latex_format_expr(wrt, 0, settings),
                    settings,
                  ) +
                  "^{\{num.to_string()}}",
                )
              }
            }
            _ => {
              total_order += 1
              parts.push(
                "\{settings.diff_operator_latex} " +
                latex_parenthesize_super(
                  latex_format_expr(wrt, 0, settings),
                  settings,
                ),
              )
            }
          }
          if i == 0 {
            break
          }
          i -= 1
        }
      }
      let use_partial = @symcore.free_symbols(inner).length() > 1 ||
        wrts.length() > 1
      let diff_symbol = if use_partial {
        "\\partial"
      } else {
        settings.diff_operator_latex
      }
      let numerator = if total_order <= 1 {
        diff_symbol
      } else {
        "\{diff_symbol}^{\{total_order.to_string()}}"
      }
      let denominator = if use_partial {
        parts
        .join("")
        .replace_all(
          old=settings.diff_operator_latex + " ",
          new=diff_symbol + " ",
        )
      } else {
        parts.join("")
      }
      let inner_tex_raw = latex_format_expr(inner, 0, settings)
      let inner_tex = if latex_needs_mul_brackets(inner) {
        latex_parens(inner_tex_raw)
      } else {
        inner_tex_raw
      }
      "\\frac{\{numerator}}{\{denominator}} \{inner_tex}"
    }
    @symcore.ExprForm::Subs(inner, variable, value) =>
      "\\left. \{latex_format_expr(inner, 0, settings)} \\right|_{\\substack{ \{latex_format_expr(variable, 0, settings)}=\{latex_format_expr(value, 0, settings)} }}"
    @symcore.ExprForm::Lambda(vars, body) => {
      let vars_tex = match @symcore.expr_form(vars) {
        @symcore.ExprForm::Tuple(items) if items.length() == 1 =>
          latex_format_expr(items[0], 0, settings)
        _ => latex_format_expr(vars, 0, settings)
      }
      "\\left( \{vars_tex} \\mapsto \{latex_format_expr(body, 0, settings)} \\right)"
    }
    @symcore.ExprForm::Apply(head, args) => {
      let head_tex = latex_wrap_power_base(
        head,
        latex_format_expr(head, 0, settings),
        settings,
      )
      let rendered = args
        .map(child => latex_format_expr(child, 0, settings))
        .join(",")
      "\{head_tex}{\\left(\{rendered} \\right)}"
    }
  }
  if prec < parent_prec {
    latex_parens(body)
  } else {
    body
  }
}
