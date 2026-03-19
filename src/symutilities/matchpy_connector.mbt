///|
/// Structural pattern-matching helpers inspired by
/// `sympy.utilities.matchpy_connector`.
///
/// This is a MoonBit-native matcher for Symbit's minimal `Expr` tree.  It does
/// not depend on external MatchPy, but it supports the high-value wildcard and
/// replacer workflow: fixed-size wildcards, sequence wildcards inside
/// associative nodes, and repeated replacement with preorder traversal.

///|
pub enum WildcardKind {
  Dot
  Plus
  Star
} derive(Eq, Show)

///|
pub struct ReplacementInfo[T] {
  replacement : T
  info : String
} derive(Eq)

///|
pub fn[T] replacement_info(
  replacement : T,
  info : String,
) -> ReplacementInfo[T] {
  { replacement, info }
}

///|
enum WildBinding {
  Single(Expr)
  Sequence(Array[Expr])
} derive(Eq)

///|
struct ReplacementRule {
  pattern : Expr
  replacement : Expr
  info : String?
} derive(Eq)

///|
pub struct Replacer {
  rules : Ref[Array[ReplacementRule]]
}

///|
fn wildcard_tag(kind : WildcardKind) -> String {
  match kind {
    WildcardKind::Dot => "__symutil_wild_dot"
    WildcardKind::Plus => "__symutil_wild_plus"
    WildcardKind::Star => "__symutil_wild_star"
  }
}

///|
fn encode_wildcard(
  kind : WildcardKind,
  variable_name : String,
  optional : Expr?,
) -> Expr {
  let args : Array[Expr] = [symbol(variable_name)]
  match optional {
    Some(value) => args.push(value)
    None => ()
  }
  @symcore.raw_function(wildcard_tag(kind), args)
}

///|
fn decode_wildcard(
  expr : Expr,
) -> (WildcardKind, String, Expr?)? {
  match expr {
    Expr::Function(name, args) => {
      let kind = match name {
        "__symutil_wild_dot" => Some(WildcardKind::Dot)
        "__symutil_wild_plus" => Some(WildcardKind::Plus)
        "__symutil_wild_star" => Some(WildcardKind::Star)
        _ => None
      }
      match (kind, args) {
        (Some(kind), [Expr::Symbol(variable_name)]) =>
          Some((kind, variable_name, None))
        (Some(kind), [Expr::Symbol(variable_name), optional]) =>
          Some((kind, variable_name, Some(optional)))
        _ => None
      }
    }
    _ => None
  }
}

///|
pub fn wild_dot(
  variable_name : String,
  optional? : Expr? = None,
) -> Expr {
  encode_wildcard(WildcardKind::Dot, variable_name, optional)
}

///|
pub fn wild_plus(
  variable_name : String,
  optional? : Expr? = None,
) -> Expr {
  encode_wildcard(WildcardKind::Plus, variable_name, optional)
}

///|
pub fn wild_star(
  variable_name : String,
  optional? : Expr? = None,
) -> Expr {
  encode_wildcard(WildcardKind::Star, variable_name, optional)
}

///|
pub fn get_srepr(expr : Expr) -> String {
  match decode_wildcard(expr) {
    Some((kind, variable_name, _)) =>
      match kind {
        WildcardKind::Dot => variable_name
        WildcardKind::Plus | WildcardKind::Star => "*" + variable_name
      }
    None =>
      match expr {
        Expr::Number(_) | Expr::Symbol(_) =>
          @symprint.to_string(expr)
        Expr::Add(args) =>
          "Add(" + args.map(get_srepr).join(", ") + ")"
        Expr::Mul(args) =>
          "Mul(" + args.map(get_srepr).join(", ") + ")"
        Expr::Pow(base, exp) =>
          "Pow(" + get_srepr(base) + ", " + get_srepr(exp) + ")"
        Expr::Function(name, args) =>
          name + "(" + args.map(get_srepr).join(", ") + ")"
      }
  }
}

///|
pub fn replacer() -> Replacer {
  { rules: { val: [] } }
}

///|
fn[K : Eq + Hash, V] map_copy(source : Map[K, V]) -> Map[K, V] {
  let out : Map[K, V] = {}
  for entry in source {
    out[entry.0] = entry.1
  }
  out
}

///|
fn bind_single(
  bindings : Map[String, WildBinding],
  name : String,
  value : Expr,
) -> Map[String, WildBinding]? {
  match bindings.get(name) {
    Some(WildBinding::Single(existing)) =>
      if existing == value {
        Some(bindings)
      } else {
        None
      }
    Some(_) => None
    None => {
      let out = map_copy(bindings)
      out[name] = WildBinding::Single(value)
      Some(out)
    }
  }
}

///|
fn bind_sequence(
  bindings : Map[String, WildBinding],
  name : String,
  values : Array[Expr],
) -> Map[String, WildBinding]? {
  match bindings.get(name) {
    Some(WildBinding::Sequence(existing)) =>
      if existing == values {
        Some(bindings)
      } else {
        None
      }
    Some(_) => None
    None => {
      let out = map_copy(bindings)
      let seq : Array[Expr] = []
      for value in values {
        seq.push(value)
      }
      out[name] = WildBinding::Sequence(seq)
      Some(out)
    }
  }
}

///|
fn min_required_exprs(patterns : Array[Expr], start : Int) -> Int {
  let mut need = 0
  for i in start..<patterns.length() {
    match decode_wildcard(patterns[i]) {
      Some((WildcardKind::Star, _, _)) => ()
      Some((WildcardKind::Plus, _, _)) => need += 1
      _ => need += 1
    }
  }
  need
}

///|
fn match_expr(
  pattern : Expr,
  expr : Expr,
  bindings : Map[String, WildBinding],
) -> Map[String, WildBinding]? {
  match decode_wildcard(pattern) {
    Some((WildcardKind::Dot, variable_name, _))
    | Some((WildcardKind::Plus, variable_name, _))
    | Some((WildcardKind::Star, variable_name, _)) =>
      bind_single(bindings, variable_name, expr)
    None =>
      match (pattern, expr) {
        (Expr::Number(a), Expr::Number(b)) =>
          if a == b {
            Some(bindings)
          } else {
            None
          }
        (Expr::Symbol(a), Expr::Symbol(b)) =>
          if a == b {
            Some(bindings)
          } else {
            None
          }
        (Expr::Add(pa), Expr::Add(ea))
        | (Expr::Mul(pa), Expr::Mul(ea)) =>
          match_expr_list(pa, ea, 0, 0, bindings)
        (Expr::Pow(pb, pe), Expr::Pow(eb, ee)) =>
          match match_expr(pb, eb, bindings) {
            Some(next) => match_expr(pe, ee, next)
            None => None
          }
        (
          Expr::Function(pname, pargs),
          Expr::Function(ename, eargs),
        ) =>
          if pname == ename {
            match_expr_list(pargs, eargs, 0, 0, bindings)
          } else {
            None
          }
        _ => None
      }
  }
}

///|
fn match_expr_list(
  patterns : Array[Expr],
  exprs : Array[Expr],
  pidx : Int,
  eidx : Int,
  bindings : Map[String, WildBinding],
) -> Map[String, WildBinding]? {
  if pidx == patterns.length() {
    return if eidx == exprs.length() { Some(bindings) } else { None }
  }
  let pattern = patterns[pidx]
  match decode_wildcard(pattern) {
    Some((WildcardKind::Plus, variable_name, optional))
    | Some((WildcardKind::Star, variable_name, optional)) => {
      let min_len = match decode_wildcard(pattern) {
        Some((WildcardKind::Plus, _, _)) => 1
        _ => 0
      }
      let remaining_need = min_required_exprs(patterns, pidx + 1)
      if eidx + min_len > exprs.length() ||
        exprs.length() - eidx < min_len + remaining_need {
        return None
      }
      let max_len = exprs.length() - eidx - remaining_need
      for count in min_len..<=max_len {
        let seq : Array[Expr] = []
        for i in 0..<count {
          seq.push(exprs[eidx + i])
        }
        let seq_to_bind = if seq.length() == 0 {
          match optional {
            Some(value) => [value]
            None => []
          }
        } else {
          seq
        }
        match bind_sequence(bindings, variable_name, seq_to_bind) {
          Some(next) =>
            match
              match_expr_list(patterns, exprs, pidx + 1, eidx + count, next) {
              Some(done) => return Some(done)
              None => ()
            }
          None => ()
        }
      }
      None
    }
    _ =>
      if eidx >= exprs.length() {
        None
      } else {
        match match_expr(pattern, exprs[eidx], bindings) {
          Some(next) =>
            match_expr_list(patterns, exprs, pidx + 1, eidx + 1, next)
          None => None
        }
      }
  }
}

///|
fn resolve_binding(
  pattern : Expr,
  bindings : Map[String, WildBinding],
) -> WildBinding? {
  match decode_wildcard(pattern) {
    Some((_, variable_name, optional)) =>
      match bindings.get(variable_name) {
        Some(value) => Some(value)
        None =>
          match optional {
            Some(value) => Some(WildBinding::Single(value))
            None => None
          }
      }
    None => None
  }
}

///|
fn substitute_expr_list(
  exprs : Array[Expr],
  bindings : Map[String, WildBinding],
) -> Array[Expr] {
  let out : Array[Expr] = []
  for expr in exprs {
    match resolve_binding(expr, bindings) {
      Some(WildBinding::Single(value)) => out.push(value)
      Some(WildBinding::Sequence(values)) =>
        for value in values {
          out.push(value)
        }
      None => out.push(substitute_expr(expr, bindings))
    }
  }
  out
}

///|
fn substitute_expr(
  expr : Expr,
  bindings : Map[String, WildBinding],
) -> Expr {
  match resolve_binding(expr, bindings) {
    Some(WildBinding::Single(value)) => value
    Some(WildBinding::Sequence(values)) =>
      match values.length() {
        0 => int(0)
        1 => values[0]
        _ => @symcore.add(values)
      }
    None =>
      match expr {
        Expr::Add(args) =>
          @symcore.raw_add(substitute_expr_list(args, bindings))
        Expr::Mul(args) =>
          @symcore.raw_mul(substitute_expr_list(args, bindings))
        Expr::Pow(base, exp) =>
          @symcore.pow(
            substitute_expr(base, bindings),
            substitute_expr(exp, bindings),
          )
        Expr::Function(name, args) =>
          @symcore.function(name, substitute_expr_list(args, bindings))
        _ => expr
      }
  }
}

///|
fn apply_rules_at_root(
  expr : Expr,
  rules : Array[ReplacementRule],
) -> (Expr, String?)? {
  for rule in rules {
    let bindings : Map[String, WildBinding] = {}
    match match_expr(rule.pattern, expr, bindings) {
      Some(found) =>
        return Some((substitute_expr(rule.replacement, found), rule.info))
      None => ()
    }
  }
  None
}

///|
fn replace_once(
  expr : Expr,
  rules : Array[ReplacementRule],
) -> (Expr, Bool, String?) {
  match apply_rules_at_root(expr, rules) {
    Some((replaced, info)) => (replaced, true, info)
    None =>
      match expr {
        Expr::Add(args) => {
          let rebuilt : Array[Expr] = []
          for arg in args {
            let (next, changed, info) = replace_once(arg, rules)
            rebuilt.push(next)
            if changed {
              for i in rebuilt.length()..<args.length() {
                rebuilt.push(args[i])
              }
              return (@symcore.raw_add(rebuilt), true, info)
            }
          }
          (expr, false, None)
        }
        Expr::Mul(args) => {
          let rebuilt : Array[Expr] = []
          for arg in args {
            let (next, changed, info) = replace_once(arg, rules)
            rebuilt.push(next)
            if changed {
              for i in rebuilt.length()..<args.length() {
                rebuilt.push(args[i])
              }
              return (@symcore.raw_mul(rebuilt), true, info)
            }
          }
          (expr, false, None)
        }
        Expr::Pow(base, exp) => {
          let (base_next, base_changed, base_info) = replace_once(base, rules)
          if base_changed {
            (@symcore.pow(base_next, exp), true, base_info)
          } else {
            let (exp_next, exp_changed, exp_info) = replace_once(exp, rules)
            if exp_changed {
              (@symcore.pow(base, exp_next), true, exp_info)
            } else {
              (expr, false, None)
            }
          }
        }
        Expr::Function(name, args) => {
          let rebuilt : Array[Expr] = []
          for arg in args {
            let (next, changed, info) = replace_once(arg, rules)
            rebuilt.push(next)
            if changed {
              for i in rebuilt.length()..<args.length() {
                rebuilt.push(args[i])
              }
              return (@symcore.function(name, rebuilt), true, info)
            }
          }
          (expr, false, None)
        }
        _ => (expr, false, None)
      }
  }
}

///|
pub fn Replacer::clear(self : Replacer) -> Unit {
  self.rules.val = []
}

///|
pub fn Replacer::add(
  self : Replacer,
  expr : Expr,
  replacement : Expr,
  info? : String? = None,
) -> Unit {
  self.rules.val.push({ pattern: expr, replacement, info })
}

///|
pub fn Replacer::replace(
  self : Replacer,
  expression : Expr,
  max_count? : Int = -1,
) -> Expr {
  self.replace_with_info(expression, max_count~).0
}

///|
pub fn Replacer::replace_with_info(
  self : Replacer,
  expression : Expr,
  max_count? : Int = -1,
) -> (Expr, Array[String]) {
  let rules = self.rules.val
  let infos : Array[String] = []
  let mut current = expression
  let mut replaced = true
  let mut replace_count = 0
  while replaced && (max_count < 0 || replace_count < max_count) {
    let (next, changed, info) = replace_once(current, rules)
    current = next
    replaced = changed
    match info {
      Some(value) => infos.push(value)
      None => ()
    }
    replace_count += 1
  }
  (current, infos)
}
