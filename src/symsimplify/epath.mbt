///|
pub(all) enum ESpan {
  All
  Index(Int)
  Slice(Int?, Int?, Int?)
} derive(Eq, Show)

///|
pub(all) struct ESelector {
  attrs : Array[String]
  types : Array[String]
  span : ESpan
}

///|
pub(all) struct EPath {
  raw : String
  selectors : Array[ESelector]
}

///|
/// Parse a path string and build an `EPath` selector sequence.
pub fn EPath::new(path : String) -> EPath {
  EPath::{ raw: path, selectors: parse_path(path) }
}

///|
/// Select all subexpressions matched by this path.
pub fn EPath::select(self : EPath, expr : Expr) -> Array[Expr] {
  let out : Array[Expr] = Array::new()
  select_at(self.selectors, 0, expr, out)
  out
}

///|
/// Apply `f` to every subexpression matched by this path.
pub fn EPath::apply(self : EPath, expr : Expr, f : (Expr) -> Expr) -> Expr {
  apply_at(self.selectors, 0, expr, f)
}

///|
/// Convenience wrapper for `EPath::select`.
pub fn epath(path : String, expr : Expr) -> Array[Expr] {
  EPath::new(path).select(expr)
}

///|
/// Convenience wrapper for `EPath::apply`.
pub fn epath_apply(path : String, expr : Expr, f : (Expr) -> Expr) -> Expr {
  EPath::new(path).apply(expr, f)
}

///|
fn parse_path(path : String) -> Array[ESelector] {
  match path.strip_prefix("/") {
    Some(rest) => {
      let selectors : Array[ESelector] = Array::new()
      for raw_sel in rest.split("/") {
        let sel = raw_sel.trim().to_string()
        if sel != "" {
          selectors.push(parse_selector(sel))
        }
      }
      selectors
    }
    None => []
  }
}

///|
fn is_selector_head_char(c : Char) -> Bool {
  c.is_ascii_alphabetic() ||
  c.is_ascii_digit() ||
  c == '_' ||
  c == '|' ||
  c == '?'
}

///|
fn split_selector(raw : String) -> (String, String) {
  let head = StringBuilder::new()
  let tail = StringBuilder::new()
  let mut in_tail = false
  for c in raw {
    if !in_tail && is_selector_head_char(c) {
      head.write_char(c)
    } else {
      in_tail = true
      tail.write_char(c)
    }
  }
  (head.to_string(), tail.to_string())
}

///|
fn parse_selector(raw : String) -> ESelector {
  let (head, tail) = split_selector(raw)
  let attrs : Array[String] = Array::new()
  let types : Array[String] = Array::new()
  if head != "" {
    for part_view in head.split("|") {
      let part = part_view.trim().to_string()
      if part != "" {
        match part.strip_suffix("?") {
          Some(attr) => attrs.push(attr.to_string())
          None => types.push(part)
        }
      }
    }
  }
  let span = parse_selector_span(tail)
  ESelector::{ attrs, types, span }
}

///|
fn parse_selector_span(tail : String) -> ESpan {
  if tail == "" || tail == "*" {
    ESpan::All
  } else if tail.has_prefix("[") && tail.has_suffix("]") {
    match tail.strip_prefix("[") {
      Some(without_prefix) =>
        match without_prefix.strip_suffix("]") {
          Some(content) => parse_span(content.to_string())
          None => ESpan::All
        }
      None => ESpan::All
    }
  } else {
    ESpan::All
  }
}

///|
fn parse_int_opt(text : String) -> Int? {
  let parsed : Result[Int, @strconv.StrConvError] = try? @strconv.parse_int(
    text,
  )
  match parsed {
    Ok(value) => Some(value)
    Err(_) => None
  }
}

///|
fn parse_span_part(parts : Array[StringView], idx : Int) -> Int? {
  if idx >= parts.length() {
    return None
  }
  let token = parts[idx].trim().to_string()
  if token == "" {
    None
  } else {
    parse_int_opt(token)
  }
}

///|
fn parse_span(content : String) -> ESpan {
  let trimmed = content.trim().to_string()
  if trimmed == "" {
    return ESpan::All
  }
  if !trimmed.contains(":") {
    match parse_int_opt(trimmed) {
      Some(idx) => ESpan::Index(idx)
      None => ESpan::All
    }
  } else {
    let parts = trimmed.split(":").to_array()
    let start = parse_span_part(parts, 0)
    let stop = parse_span_part(parts, 1)
    let step = parse_span_part(parts, 2)
    ESpan::Slice(start, stop, step)
  }
}

///|
fn select_at(
  selectors : Array[ESelector],
  idx : Int,
  expr : Expr,
  out : Array[Expr],
) -> Unit {
  if idx >= selectors.length() {
    out.push(expr)
    return
  }
  let sel = selectors[idx]
  let children = ordered_children(expr)
  let indices = span_indices(sel.span, children.length())
  for i in indices {
    if i < 0 || i >= children.length() {
      continue
    }
    let child = children[i]
    if selector_matches(sel, child) {
      select_at(selectors, idx + 1, child, out)
    }
  }
}

///|
fn apply_at(
  selectors : Array[ESelector],
  idx : Int,
  expr : Expr,
  f : (Expr) -> Expr,
) -> Expr {
  if idx >= selectors.length() {
    return f(expr)
  }
  let sel = selectors[idx]
  let children = ordered_children(expr)
  if children.is_empty() {
    return expr
  }
  let updated = children.map(c => c)
  let indices = span_indices(sel.span, children.length())
  for i in indices {
    if i < 0 || i >= children.length() {
      continue
    }
    let child = children[i]
    if selector_matches(sel, child) {
      updated[i] = apply_at(selectors, idx + 1, child, f)
    }
  }
  rebuild_expr(expr, updated)
}

///|
fn selector_matches(sel : ESelector, expr : Expr) -> Bool {
  if sel.attrs.is_empty() && sel.types.is_empty() {
    return true
  }
  for a in sel.attrs {
    if has_attr(expr, a) {
      return true
    }
  }
  for t in sel.types {
    if has_type(expr, t) {
      return true
    }
  }
  false
}

///|
fn has_type(expr : Expr, t : String) -> Bool {
  match expr {
    Expr::Number(_) => t == "Number" || t == "Expr"
    Expr::Float(_) => t == "Float" || t == "Number" || t == "Expr"
    Expr::ComplexFloat(_) =>
      t == "ComplexFloat" || t == "Float" || t == "Number" || t == "Expr"
    Expr::NumberSymbol(_) => t == "NumberSymbol" || t == "Number" || t == "Expr"
    Expr::Boolean(_) => t == "Boolean" || t == "Expr"
    Expr::Dummy(_, _) => t == "Dummy" || t == "Symbol" || t == "Expr"
    Expr::Wild(_) => t == "Wild" || t == "Symbol" || t == "Expr"
    Expr::FunctionHead(_) =>
      t == "FunctionHead" || t == "UndefinedFunction" || t == "Function" ||
      t == "Expr"
    Expr::UndefinedFunction(_) =>
      t == "UndefinedFunction" || t == "Function" || t == "Expr"
    Expr::AppliedUndef(_, _) =>
      t == "AppliedUndef" || t == "Function" || t == "Expr"
    Expr::Symbol(_) => t == "Symbol" || t == "Expr"
    Expr::Add(_) => t == "Add" || t == "Expr"
    Expr::Mul(_) => t == "Mul" || t == "Expr"
    Expr::Pow(_, _) => t == "Pow" || t == "Expr"
    Expr::Mod(_, _) => t == "Mod" || t == "Expr"
    Expr::Tuple(_) => t == "Tuple" || t == "Expr"
    Expr::Dict(_) => t == "Dict" || t == "Expr"
    Expr::Relational(_, _, _) => t == "Relational" || t == "Expr"
    Expr::Derivative(_, _) => t == "Derivative" || t == "Expr"
    Expr::Subs(_, _, _) => t == "Subs" || t == "Expr"
    Expr::Lambda(_, _) => t == "Lambda" || t == "Expr"
    Expr::Function(_, _) => t == "Function" || t == "Expr"
  }
}

///|
fn has_attr(expr : Expr, a : String) -> Bool {
  match a {
    "is_Atom" => epath_is_atom(expr)
    "__iter__" => !ordered_children(expr).is_empty()
    "is_Add" =>
      match expr {
        Expr::Add(_) => true
        _ => false
      }
    "is_Mul" =>
      match expr {
        Expr::Mul(_) => true
        _ => false
      }
    "is_Pow" =>
      match expr {
        Expr::Pow(_, _) => true
        _ => false
      }
    "is_Function" =>
      match expr {
        Expr::Function(_, _) => true
        _ => false
      }
    _ => false
  }
}

///|
fn epath_is_atom(expr : Expr) -> Bool {
  match expr {
    Expr::Number(_)
    | Expr::Float(_)
    | Expr::ComplexFloat(_)
    | Expr::Boolean(_)
    | Expr::Symbol(_) => true
    _ => false
  }
}

///|
fn ordered_children(expr : Expr) -> Array[Expr] {
  match expr {
    Expr::Add(args)
    | Expr::Mul(args)
    | Expr::Tuple(args)
    | Expr::Function(_, args) => args.map(x => x)
    Expr::Pow(a, b) => [a, b]
    Expr::Relational(_, lhs, rhs) => [lhs, rhs]
    Expr::Derivative(inner, deriv_args) => {
      let out : Array[Expr] = [inner]
      for arg in deriv_args {
        out.push(arg)
      }
      out
    }
    Expr::Subs(inner, variable, value) => [inner, variable, value]
    Expr::Lambda(vars, body) => [vars, body]
    _ => []
  }
}

///|
fn rebuild_expr(expr : Expr, args : Array[Expr]) -> Expr {
  match expr {
    Expr::Add(_) => @symcore.raw_add(args)
    Expr::Mul(_) => @symcore.raw_mul(args)
    Expr::Tuple(_) => @symcore.Expr::Tuple(args)
    Expr::Relational(op, _, _) =>
      if args.length() == 2 {
        match op {
          @symcore.RelOp::Eq => @symcore.Expr::Relational(@symcore.RelOp::Eq, args[0], args[1])
          @symcore.RelOp::Ne => @symcore.Expr::Relational(@symcore.RelOp::Ne, args[0], args[1])
          @symcore.RelOp::Lt => @symcore.Expr::Relational(@symcore.RelOp::Lt, args[0], args[1])
          @symcore.RelOp::Le => @symcore.Expr::Relational(@symcore.RelOp::Le, args[0], args[1])
          @symcore.RelOp::Gt => @symcore.Expr::Relational(@symcore.RelOp::Gt, args[0], args[1])
          @symcore.RelOp::Ge => @symcore.Expr::Relational(@symcore.RelOp::Ge, args[0], args[1])
        }
      } else {
        expr
      }
    Expr::Derivative(_, _) =>
      if args.length() >= 2 {
        @symcore.raw_function("Derivative", args)
      } else {
        expr
      }
    Expr::Subs(_, _, _) =>
      if args.length() == 3 {
        @symcore.subs_expr(args[0], args[1], args[2])
      } else {
        expr
      }
    Expr::Lambda(_, _) =>
      if args.length() == 2 {
        @symcore.lambda_expr(args[0], args[1])
      } else {
        expr
      }
    Expr::Function(name, _) => @symcore.raw_function(name, args)
    Expr::Pow(_, _) =>
      if args.length() == 2 {
        @symcore.raw_pow(args[0], args[1])
      } else {
        expr
      }
    _ => expr
  }
}

///|
fn span_indices(span : ESpan, n : Int) -> Array[Int] {
  match span {
    ESpan::All => {
      let out : Array[Int] = Array::new()
      for i in 0..<n {
        out.push(i)
      }
      out
    }
    ESpan::Index(i) => [i]
    ESpan::Slice(start, stop, step) => {
      let s = match step {
        Some(v) if v != 0 => v
        _ => 1
      }
      let mut i = match start {
        Some(v) => if v < 0 { n + v } else { v }
        None => if s > 0 { 0 } else { n - 1 }
      }
      let end = match stop {
        Some(v) => if v < 0 { n + v } else { v }
        None => if s > 0 { n } else { -1 }
      }
      let out : Array[Int] = Array::new()
      if s > 0 {
        while i < end {
          out.push(i)
          i = i + s
        }
      } else {
        while i > end {
          out.push(i)
          i = i + s
        }
      }
      out
    }
  }
}
