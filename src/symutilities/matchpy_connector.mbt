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
} derive(Eq, Debug)

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
    Dot => "__symutil_wild_dot"
    Plus => "__symutil_wild_plus"
    Star => "__symutil_wild_star"
  }
}

///|
fn encode_wildcard(
  kind : WildcardKind,
  variable_name : String,
  optional : Expr?,
) -> Expr {
  let args : Array[Expr] = [Symbol(variable_name)]
  match optional {
    Some(value) => args.push(value)
    None => ()
  }
  @symcore.raw_function(wildcard_tag(kind), args)
}

///|
fn decode_wildcard(expr : Expr) -> (WildcardKind, String, Expr?)? {
  match (@symcore.application_name(expr), @symcore.application_args(expr)) {
    (Some(name), Some(args)) => {
      let kind = match name {
        "__symutil_wild_dot" => Some(WildcardKind::Dot)
        "__symutil_wild_plus" => Some(Plus)
        "__symutil_wild_star" => Some(Star)
        _ => None
      }
      match (kind, args) {
        (Some(kind), [Symbol(variable_name)]) =>
          Some((kind, variable_name, None))
        (Some(kind), [Symbol(variable_name), optional]) =>
          Some((kind, variable_name, Some(optional)))
        _ => None
      }
    }
    _ => None
  }
}

///|
pub fn wild_dot(variable_name : String, optional? : Expr? = None) -> Expr {
  encode_wildcard(Dot, variable_name, optional)
}

///|
pub fn wild_plus(variable_name : String, optional? : Expr? = None) -> Expr {
  encode_wildcard(Plus, variable_name, optional)
}

///|
pub fn wild_star(variable_name : String, optional? : Expr? = None) -> Expr {
  encode_wildcard(Star, variable_name, optional)
}

///|
pub fn get_srepr(expr : Expr) -> String {
  match decode_wildcard(expr) {
    Some((kind, variable_name, _)) =>
      match kind {
        Dot => variable_name
        Plus | Star => "*" + variable_name
      }
    None =>
      match @symcore.application_parts(expr) {
        Some((head, args)) =>
          match @symcore.function_head_name(head) {
            Some(name) =>
              if args.is_empty() {
                name
              } else {
                let rendered = args.map(get_srepr).join(",")
                "\{name}(\{rendered})"
              }
            None =>
              "Apply(" +
              get_srepr(head) +
              (if args.is_empty() {
                ""
              } else {
                ", " + args.map(get_srepr).join(", ")
              }) +
              ")"
          }
        None =>
          match @symcore.expr_form(expr) {
            Number(_)
            | Float(_)
            | ComplexFloat(_)
            | NumberSymbol(_)
            | Symbol(_)
            | Dummy(_, _)
            | Wild(_, _, _)
            | FunctionHead(_)
            | UndefinedFunction(_)
            | Boolean(_) => @symprint.pretty_string(expr)
            Add(args) => "Add(" + args.map(get_srepr).join(", ") + ")"
            Mul(args) => "Mul(" + args.map(get_srepr).join(", ") + ")"
            Pow(base, exp) =>
              "Pow(" + get_srepr(base) + ", " + get_srepr(exp) + ")"
            Mod(lhs, rhs) =>
              "Mod(" + get_srepr(lhs) + ", " + get_srepr(rhs) + ")"
            Tuple(args) => "Tuple(" + args.map(get_srepr).join(", ") + ")"
            Dict(items) => {
              let rendered : Array[String] = []
              for item in items {
                let (key, value) = item
                rendered.push(
                  "Tuple(" + get_srepr(key) + ", " + get_srepr(value) + ")",
                )
              }
              "Dict(" + rendered.join(", ") + ")"
            }
            Relational(_, lhs, rhs) =>
              @symcore.head_name(expr) +
              "(" +
              get_srepr(lhs) +
              ", " +
              get_srepr(rhs) +
              ")"
            Derivative(inner, deriv_args) => {
              let rendered : Array[String] = [get_srepr(inner)]
              for arg in deriv_args {
                rendered.push(get_srepr(arg))
              }
              "Derivative(" + rendered.join(", ") + ")"
            }
            Subs(inner, variable, value) =>
              "Subs(" +
              get_srepr(inner) +
              ", " +
              get_srepr(variable) +
              ", " +
              get_srepr(value) +
              ")"
            Lambda(vars, body) =>
              "Lambda(" + get_srepr(vars) + ", " + get_srepr(body) + ")"
            _ => "<invalid>"
          }
      }
  }
}

///|
pub fn replacer() -> Replacer {
  { rules: { val: [] } }
}

///|
fn[K : Eq + Hash, V] map_copy(source : Map[K, V]) -> Map[K, V] {
  let out : Map[K, V] = Map([])
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
    Some(Single(existing)) =>
      if existing == value {
        Some(bindings)
      } else {
        None
      }
    Some(_) => None
    None => {
      let out = map_copy(bindings)
      out[name] = Single(value)
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
    Some(Sequence(existing)) =>
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
      out[name] = Sequence(seq)
      Some(out)
    }
  }
}

///|
fn min_required_exprs(patterns : Array[Expr], start : Int) -> Int {
  let mut need = 0
  for i in start..<patterns.length() {
    match decode_wildcard(patterns[i]) {
      Some((Star, _, _)) => ()
      Some((Plus, _, _)) => need += 1
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
    Some((Dot, variable_name, _))
    | Some((Plus, variable_name, _))
    | Some((Star, variable_name, _)) =>
      bind_single(bindings, variable_name, expr)
    None =>
      match (pattern, expr) {
        (Number(a), Number(b)) => if a == b { Some(bindings) } else { None }
        (Symbol(a), Symbol(b)) => if a == b { Some(bindings) } else { None }
        (Add(pa), Add(ea)) | (Mul(pa), Mul(ea)) =>
          match_expr_list(pa, ea, 0, 0, bindings)
        (Pow(pb, pe), Pow(eb, ee)) =>
          match match_expr(pb, eb, bindings) {
            Some(next) => match_expr(pe, ee, next)
            None => None
          }
        _ =>
          match
            (
              @symcore.application_parts(pattern),
              @symcore.application_parts(expr),
            ) {
            (Some((phead, pargs)), Some((ehead, eargs))) =>
              if phead == ehead {
                match_expr_list(pargs, eargs, 0, 0, bindings)
              } else {
                None
              }
            _ => None
          }
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
    Some((Plus, variable_name, optional))
    | Some((Star, variable_name, optional)) => {
      let min_len = match decode_wildcard(pattern) {
        Some((Plus, _, _)) => 1
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
            Some(value) => Some(Single(value))
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
      Some(Single(value)) => out.push(value)
      Some(Sequence(values)) =>
        for value in values {
          out.push(value)
        }
      None => out.push(substitute_expr(expr, bindings))
    }
  }
  out
}

///|
fn substitute_expr(expr : Expr, bindings : Map[String, WildBinding]) -> Expr {
  match resolve_binding(expr, bindings) {
    Some(Single(value)) => value
    Some(Sequence(values)) =>
      match values.length() {
        0 => int(0)
        1 => values[0]
        _ => @symcore.add(values)
      }
    None =>
      match expr {
        Add(args) => @symcore.raw_add(substitute_expr_list(args, bindings))
        Mul(args) => @symcore.raw_mul(substitute_expr_list(args, bindings))
        Pow(base, exp) =>
          @symcore.pow(
            substitute_expr(base, bindings),
            substitute_expr(exp, bindings),
          )
        _ =>
          match @symcore.application_parts(expr) {
            Some((head, args)) =>
              match
                @symcore.raw_apply(head, substitute_expr_list(args, bindings)) {
                Some(applied) => applied
                None => expr
              }
            None => expr
          }
      }
  }
}

///|
fn apply_rules_at_root(
  expr : Expr,
  rules : Array[ReplacementRule],
) -> (Expr, String?)? {
  for rule in rules {
    let bindings : Map[String, WildBinding] = Map([])
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
        Add(args) => {
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
        Mul(args) => {
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
        Pow(base, exp) => {
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
        _ =>
          match @symcore.application_parts(expr) {
            Some((head, args)) => {
              let rebuilt : Array[Expr] = []
              for arg in args {
                let (next, changed, info) = replace_once(arg, rules)
                rebuilt.push(next)
                if changed {
                  for i in rebuilt.length()..<args.length() {
                    rebuilt.push(args[i])
                  }
                  return (
                    match @symcore.raw_apply(head, rebuilt) {
                      Some(applied) => applied
                      None => expr
                    },
                    true,
                    info,
                  )
                }
              }
              (expr, false, None)
            }
            None => (expr, false, None)
          }
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
