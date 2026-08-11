///|
/// Core set operations and membership tests.
///
/// Current Limits:
/// - Coverage is strongest for finite sets, numeric intervals, standard numeric domains, and direct symbolic compositions.
/// - Harder symbolic reasoning still returns unevaluated set expressions or `Unknown`.

///|
fn setbool_or(a : SetBool, b : SetBool) -> SetBool {
  match (a, b) {
    (True, _) | (_, True) => True
    (Unknown, _) | (_, Unknown) => Unknown
    _ => False
  }
}

///|
fn setbool_and(a : SetBool, b : SetBool) -> SetBool {
  match (a, b) {
    (False, _) | (_, False) => False
    (Unknown, _) | (_, Unknown) => Unknown
    _ => True
  }
}

///|
fn setbool_not(a : SetBool) -> SetBool {
  match a {
    True => False
    False => True
    Unknown => Unknown
  }
}

///|
fn expr_depends_on(expr : Expr, name : String) -> Bool {
  match expr {
    Symbol(s) => s == name
    Add(args) | Mul(args) => args.any(child => expr_depends_on(child, name))
    Pow(base, exp) => expr_depends_on(base, name) || expr_depends_on(exp, name)
    _ => @symcore.args(expr).any(child => expr_depends_on(child, name))
  }
}

///|
fn set_is_empty(set : Set) -> SetBool {
  match set {
    EmptySet => True
    UniversalSet => False
    FiniteSet(items) => if items.is_empty() { True } else { False }
    Interval(..) => False
    Naturals | Naturals0 | Integers | Rationals | Reals | Complexes => False
    ProductSet(items) => {
      for item in items {
        match set_is_empty(item) {
          True => return True
          Unknown => return Unknown
          _ => ()
        }
      }
      False
    }
    ConditionSet(symbol=_, condition=_, base~) => set_is_empty(base)
    ImageSet(symbol=_, expr=_, base~) => set_is_empty(base)
    _ => Unknown
  }
}

///|

///|
fn eval_lra_constraint(
  constraint : @symlogic.LinearConstraint,
  var_name : String,
  value : @symnum.BigRational,
) -> SetBool {
  let coeffs = constraint.coeffs
  if coeffs.is_empty() {
    let cmp = @symnum.BigRational::zero().compare(constraint.rhs)
    return match constraint.op {
      Le => if cmp <= 0 { True } else { False }
      Ge => if cmp >= 0 { True } else { False }
      Lt => if cmp < 0 { True } else { False }
      Gt => if cmp > 0 { True } else { False }
      Eq => if cmp == 0 { True } else { False }
    }
  }
  if coeffs.length() != 1 {
    return Unknown
  }
  match coeffs.get(var_name) {
    None => Unknown
    Some(coeff) => {
      let lhs = coeff.mul_r(value)
      let cmp = lhs.compare(constraint.rhs)
      match constraint.op {
        Le => if cmp <= 0 { True } else { False }
        Ge => if cmp >= 0 { True } else { False }
        Lt => if cmp < 0 { True } else { False }
        Gt => if cmp > 0 { True } else { False }
        Eq => if cmp == 0 { True } else { False }
      }
    }
  }
}

///|
fn eval_bool_expr(
  expr : @symlogic.BoolExpr,
  var_name : String,
  value : @symnum.BigRational?,
) -> SetBool {
  match expr {
    True => True
    False => False
    Not(inner) => setbool_not(eval_bool_expr(inner, var_name, value))
    And(args) => {
      let mut acc = SetBool::True
      for arg in args {
        acc = setbool_and(acc, eval_bool_expr(arg, var_name, value))
        if acc == False {
          return acc
        }
      }
      acc
    }
    Or(args) => {
      let mut acc = SetBool::False
      for arg in args {
        acc = setbool_or(acc, eval_bool_expr(arg, var_name, value))
        if acc == True {
          return acc
        }
      }
      acc
    }
    Implies(a, b) => {
      let not_a = setbool_not(eval_bool_expr(a, var_name, value))
      setbool_or(not_a, eval_bool_expr(b, var_name, value))
    }
    Equivalent(args) => {
      if args.is_empty() {
        return True
      }
      let first = eval_bool_expr(args[0], var_name, value)
      for i in 1..<args.length() {
        let current = eval_bool_expr(args[i], var_name, value)
        if first == Unknown || current == Unknown {
          return Unknown
        }
        if first != current {
          return False
        }
      }
      first
    }
    ITE(c, t, e) =>
      match eval_bool_expr(c, var_name, value) {
        True => eval_bool_expr(t, var_name, value)
        False => eval_bool_expr(e, var_name, value)
        Unknown => Unknown
      }
    LRA(constraint) =>
      match value {
        Some(v) => eval_lra_constraint(constraint, var_name, v)
        None => Unknown
      }
    _ => Unknown
  }
}

///|
fn dedup_sets(items : Array[Set]) -> Array[Set] {
  let out : Array[Set] = Array::new()
  if items.is_empty() {
    return out
  }
  let tmp : Array[Set] = Array::new()
  for item in items {
    tmp.push(item)
  }
  sort_sets_in_place(tmp)
  for item in tmp {
    if out.is_empty() {
      out.push(item)
    } else {
      let last = out[out.length() - 1]
      if compare_set(item, last) != 0 {
        out.push(item)
      }
    }
  }
  out
}

///|
priv enum IntervalBound {
  NegativeInfinity
  Finite(@symnum.BigRational)
  Infinity
}

///|
fn interval_bound(expr : Expr) -> IntervalBound? {
  match expr_number_value(expr) {
    Some(value) => Some(Finite(value))
    None =>
      match @symcore.number_symbol_kind(expr) {
        Some(NegativeInfinity) => Some(NegativeInfinity)
        Some(Infinity) => Some(Infinity)
        _ => None
      }
  }
}

///|
fn compare_interval_bound(a : IntervalBound, b : IntervalBound) -> Int {
  match (a, b) {
    (NegativeInfinity, NegativeInfinity) | (Infinity, Infinity) => 0
    (NegativeInfinity, _) => -1
    (_, NegativeInfinity) => 1
    (Infinity, _) => 1
    (_, Infinity) => -1
    (Finite(left), Finite(right)) => left.compare(right)
  }
}

///|
fn interval_spans_reals(set : Set) -> Bool {
  match set {
    Interval(left~, right~, left_open=_, right_open=_) =>
      match (interval_bound(left), interval_bound(right)) {
        (Some(NegativeInfinity), Some(Infinity)) => true
        _ => false
      }
    Reals => true
    _ => false
  }
}

///|
fn interval_numeric(
  set : Set,
) -> (IntervalBound, IntervalBound, Bool, Bool, Expr, Expr)? {
  match set {
    Interval(left~, right~, left_open~, right_open~) =>
      match (interval_bound(left), interval_bound(right)) {
        (Some(lv), Some(rv)) =>
          Some((lv, rv, left_open, right_open, left, right))
        _ => None
      }
    _ => None
  }
}

///|
fn interval_overlap_or_touch(
  a : (IntervalBound, IntervalBound, Bool, Bool),
  b : (IntervalBound, IntervalBound, Bool, Bool),
) -> Bool {
  let (_al, ar, _alo, aro) = a
  let (bl, _br, blo, _bro) = b
  let cmp = compare_interval_bound(bl, ar)
  if cmp < 0 {
    true
  } else if cmp > 0 {
    false
  } else {
    !(aro && blo)
  }
}

///|
fn merge_interval_pair(
  a : (IntervalBound, IntervalBound, Bool, Bool, Expr, Expr),
  b : (IntervalBound, IntervalBound, Bool, Bool, Expr, Expr),
) -> (IntervalBound, IntervalBound, Bool, Bool, Expr, Expr) {
  let (al, ar, alo, aro, aleft, aright) = a
  let (bl, br, _blo, bro, _bleft, bright) = b
  let left_val = al
  let left_open = if compare_interval_bound(al, bl) == 0 {
    if alo {
      true
    } else {
      false
    }
  } else {
    alo
  }
  let right_cmp = compare_interval_bound(ar, br)
  let (right_val, right_open, right_expr) = if right_cmp > 0 {
    (ar, aro, aright)
  } else if right_cmp < 0 {
    (br, bro, bright)
  } else {
    (ar, aro && bro, aright)
  }
  (left_val, right_val, left_open, right_open, aleft, right_expr)
}

///|
fn merge_intervals(intervals : Array[Set]) -> Array[Set] {
  let numeric : Array[(IntervalBound, IntervalBound, Bool, Bool, Expr, Expr)] = Array::new()
  let others : Array[Set] = Array::new()
  for item in intervals {
    match interval_numeric(item) {
      Some(info) => numeric.push(info)
      None => others.push(item)
    }
  }
  if numeric.is_empty() {
    return others
  }
  numeric.sort_by((a, b) => {
    let (al, _ar, alo, _aro, _ae, _ae2) = a
    let (bl, _br, blo, _bro, _be, _be2) = b
    let cmp = compare_interval_bound(al, bl)
    if cmp != 0 {
      cmp
    } else if alo != blo {
      if alo {
        1
      } else {
        -1
      }
    } else {
      0
    }
  })
  let out : Array[Set] = Array::new()
  let mut current = numeric[0]
  for i in 1..<numeric.length() {
    let next = numeric[i]
    let (al, ar, alo, aro, _alexpr, _arexpr) = current
    let (bl, br, blo, bro, _blexpr, _brexpr) = next
    let overlap = interval_overlap_or_touch(
      (al, ar, alo, aro),
      (bl, br, blo, bro),
    )
    if overlap {
      current = merge_interval_pair(current, next)
    } else {
      let (_cl, _cr, clo, cro, cleft, cright) = current
      out.push(interval(cleft, cright, left_open=clo, right_open=cro))
      current = next
    }
  }
  let (_cl, _cr, clo, cro, cleft, cright) = current
  out.push(interval(cleft, cright, left_open=clo, right_open=cro))
  for item in others {
    out.push(item)
  }
  out
}

///|
fn combine_finite_sets(items : Array[Expr]) -> Set {
  finite_set(items)
}

///|
/// Build the union of several sets.
///
/// - Does: Flattens nested unions, removes empty members, merges finite elements, and combines overlapping intervals when possible.
/// - Input: An `Array[Set]` of set operands.
/// - Returns: A simplified `Set`, often `EmptySet`, one member, `Reals`, or `Union`.
/// - Limits: Interval coalescing is strongest for numeric interval data.
pub fn union(args : Array[Set]) -> Set {
  if args.is_empty() {
    return EmptySet
  }
  let flat : Array[Set] = Array::new()
  let mut has_universal = false
  let finite_items : Array[Expr] = Array::new()
  let intervals : Array[Set] = Array::new()
  for set in args {
    match set {
      Union(inner) =>
        for item in inner {
          flat.push(item)
        }
      EmptySet => ()
      UniversalSet => has_universal = true
      FiniteSet(items) =>
        for item in items {
          finite_items.push(item)
        }
      Interval(..) => intervals.push(set)
      _ => flat.push(set)
    }
  }
  if has_universal {
    return UniversalSet
  }
  let merged_intervals = merge_intervals(intervals)
  for item in merged_intervals {
    flat.push(item)
  }
  if !finite_items.is_empty() {
    let fset = combine_finite_sets(finite_items)
    match fset {
      EmptySet => ()
      _ => flat.push(fset)
    }
  }
  let uniq = dedup_sets(flat)
  if uniq.is_empty() {
    EmptySet
  } else if uniq.length() == 1 && interval_spans_reals(uniq[0]) {
    Reals
  } else if uniq.length() == 1 {
    uniq[0]
  } else {
    Union(uniq)
  }
}

///|
fn interval_intersection(a : Set, b : Set) -> Set? {
  match (interval_numeric(a), interval_numeric(b)) {
    (
      Some((al, ar, alo, aro, aleft, aright)),
      Some((bl, br, blo, bro, bleft, bright)),
    ) => {
      let left_cmp = compare_interval_bound(al, bl)
      let (left_val, left_open, left_expr) = if left_cmp > 0 {
        (al, alo, aleft)
      } else if left_cmp < 0 {
        (bl, blo, bleft)
      } else {
        (al, alo || blo, aleft)
      }
      let right_cmp = compare_interval_bound(ar, br)
      let (right_val, right_open, right_expr) = if right_cmp < 0 {
        (ar, aro, aright)
      } else if right_cmp > 0 {
        (br, bro, bright)
      } else {
        (ar, aro || bro, aright)
      }
      let cmp = compare_interval_bound(left_val, right_val)
      if cmp > 0 {
        Some(EmptySet)
      } else if cmp == 0 {
        if left_open || right_open {
          Some(EmptySet)
        } else {
          Some(finite_set([left_expr]))
        }
      } else {
        Some(interval(left_expr, right_expr, left_open~, right_open~))
      }
    }
    _ => None
  }
}

///|
fn intersect_finite_sets(a : Array[Expr], b : Array[Expr]) -> Array[Expr] {
  let out : Array[Expr] = Array::new()
  for item in a {
    let mut found = false
    for other in b {
      if @symcore.compare_expr(item, other) == 0 {
        found = true
        break
      }
    }
    if found {
      out.push(item)
    }
  }
  out
}

///|
fn filter_finite_by_interval(
  items : Array[Expr],
  interval_set : Set,
) -> Array[Expr] {
  let out : Array[Expr] = Array::new()
  for item in items {
    let res = contains(interval_set, item)
    match res {
      True => out.push(item)
      _ => ()
    }
  }
  out
}

///|
/// Build the intersection of several sets.
///
/// - Does: Flattens nested intersections, removes universal members, and simplifies common finite-set and interval cases.
/// - Input: An `Array[Set]` of set operands.
/// - Returns: A simplified `Set`, often `EmptySet`, one member, `UniversalSet`, or `Intersection`.
/// - Limits: Deep symbolic intersections outside the implemented special cases stay symbolic.
pub fn intersection(args : Array[Set]) -> Set {
  if args.is_empty() {
    return UniversalSet
  }
  let flat : Array[Set] = Array::new()
  for set in args {
    match set {
      Intersection(inner) =>
        for item in inner {
          flat.push(item)
        }
      _ => flat.push(set)
    }
  }
  let trimmed : Array[Set] = Array::new()
  for set in flat {
    match set {
      EmptySet => return EmptySet
      UniversalSet => ()
      _ => trimmed.push(set)
    }
  }
  if trimmed.is_empty() {
    return UniversalSet
  }
  if trimmed.length() == 1 {
    return trimmed[0]
  }
  // Handle finite sets
  let mut finite_items : Array[Expr]? = None
  let mut interval_acc : Set? = None
  let rest : Array[Set] = Array::new()
  for set in trimmed {
    match set {
      FiniteSet(items) =>
        match finite_items {
          None => finite_items = Some(items)
          Some(prev) => finite_items = Some(intersect_finite_sets(prev, items))
        }
      Interval(..) =>
        match interval_acc {
          None => interval_acc = Some(set)
          Some(prev) =>
            match interval_intersection(prev, set) {
              Some(res) => interval_acc = Some(res)
              None => rest.push(set)
            }
        }
      _ => rest.push(set)
    }
  }
  match interval_acc {
    Some(EmptySet) => return EmptySet
    _ => ()
  }
  if finite_items is Some(items) {
    let filtered = match interval_acc {
      Some(interval_set) =>
        match interval_set {
          Interval(..) => filter_finite_by_interval(items, interval_set)
          FiniteSet(other_items) => intersect_finite_sets(items, other_items)
          EmptySet => []
          _ => items
        }
      None => items
    }
    let fset = finite_set(filtered)
    match fset {
      EmptySet => return EmptySet
      _ => rest.push(fset)
    }
  } else {
    match interval_acc {
      Some(interval_set) => rest.push(interval_set)
      None => ()
    }
  }
  let uniq = dedup_sets(rest)
  if uniq.is_empty() {
    UniversalSet
  } else if uniq.length() == 1 {
    uniq[0]
  } else {
    Intersection(uniq)
  }
}

///|
fn interval_difference(a : Set, b : Set) -> Set? {
  match (interval_numeric(a), interval_numeric(b)) {
    (
      Some((al, ar, alo, aro, aleft, aright)),
      Some((bl, br, blo, bro, bleft, bright)),
    ) => {
      // Disjoint
      if compare_interval_bound(br, al) < 0 ||
        compare_interval_bound(bl, ar) > 0 {
        return Some(a)
      }
      // B covers A
      let left_cmp = compare_interval_bound(bl, al)
      let right_cmp = compare_interval_bound(br, ar)
      if (left_cmp < 0 || (left_cmp == 0 && (!alo || !blo))) &&
        (right_cmp > 0 || (right_cmp == 0 && (!aro || !bro))) {
        return Some(EmptySet)
      }
      let parts : Array[Set] = Array::new()
      if left_cmp > 0 || (left_cmp == 0 && !alo && blo) {
        let right_open = if blo { false } else { true }
        parts.push(interval(aleft, bleft, left_open=alo, right_open~))
      }
      if right_cmp < 0 || (right_cmp == 0 && !aro && bro) {
        let left_open = if bro { false } else { true }
        parts.push(interval(bright, aright, left_open~, right_open=aro))
      }
      if parts.is_empty() {
        Some(EmptySet)
      } else if parts.length() == 1 {
        Some(parts[0])
      } else {
        Some(union(parts))
      }
    }
    _ => None
  }
}

///|
/// Remove the elements of one set from another.
///
/// - Does: Computes `a \\ b` with simplifications for common finite-set, interval, and union cases.
/// - Input: Two `Set` values.
/// - Returns: A simplified `Set`, often `EmptySet`, a reduced concrete set, or `Complement(a, b)`.
/// - Limits: Cases outside the implemented simplifiers remain symbolic.
pub fn complement(a : Set, b : Set) -> Set {
  match (a, b) {
    (EmptySet, _) => EmptySet
    (_, EmptySet) => a
    (UniversalSet, UniversalSet) => EmptySet
    (x, y) if compare_set(x, y) == 0 => EmptySet
    (FiniteSet(items), FiniteSet(remove)) => {
      let remaining : Array[Expr] = Array::new()
      for item in items {
        let mut found = false
        for r in remove {
          if @symcore.compare_expr(item, r) == 0 {
            found = true
            break
          }
        }
        if !found {
          remaining.push(item)
        }
      }
      finite_set(remaining)
    }
    (FiniteSet(items), interval_set) =>
      match interval_set {
        Interval(..) => {
          // filter_finite_by_interval keeps contained items; we need complement
          let out : Array[Expr] = Array::new()
          for item in items {
            let res = contains(interval_set, item)
            match res {
              True => ()
              _ => out.push(item)
            }
          }
          finite_set(out)
        }
        _ => Complement(a, interval_set)
      }
    (Interval(..), Interval(..)) =>
      match interval_difference(a, b) {
        Some(res) => res
        None => Complement(a, b)
      }
    (Union(items), other) => {
      let parts : Array[Set] = Array::new()
      for item in items {
        parts.push(complement(item, other))
      }
      union(parts)
    }
    _ => Complement(a, b)
  }
}

///|
fn interval_contains(set : Set, elem : Expr) -> SetBool {
  match (set, expr_number_value(elem)) {
    (Interval(left~, right~, left_open~, right_open~), Some(value)) => {
      let left_kind = @symcore.number_symbol_kind(left)
      let right_kind = @symcore.number_symbol_kind(right)
      let lower_ok = match expr_number_value(left) {
        Some(lv) => {
          let cmp_l = value.compare(lv)
          if cmp_l < 0 {
            Some(false)
          } else if cmp_l == 0 {
            Some(!left_open)
          } else {
            Some(true)
          }
        }
        None =>
          match left_kind {
            Some(NegativeInfinity) => Some(true)
            _ => None
          }
      }
      let upper_ok = match expr_number_value(right) {
        Some(rv) => {
          let cmp_r = value.compare(rv)
          if cmp_r > 0 {
            Some(false)
          } else if cmp_r == 0 {
            Some(!right_open)
          } else {
            Some(true)
          }
        }
        None =>
          match right_kind {
            Some(Infinity) => Some(true)
            _ => None
          }
      }
      match (lower_ok, upper_ok) {
        (Some(true), Some(true)) => True
        (Some(false), _) | (_, Some(false)) => False
        _ => Unknown
      }
    }
    _ => Unknown
  }
}

///|
fn finite_contains(items : Array[Expr], elem : Expr) -> SetBool {
  for item in items {
    if @symcore.compare_expr(item, elem) == 0 {
      return True
    }
  }
  False
}

///|
fn contains_numerical_set(kind : Set, elem : Expr) -> SetBool {
  let is_noncomplex_infinite = fn(expr : Expr) {
    match @symcore.number_symbol_kind(expr) {
      Some(ComplexInfinity) => true
      _ => false
    }
  }
  if kind == Complexes {
    return match
      @symassume.tri_to_bool_option(@symassume.ask_predicate(elem, IsReal)) {
      Some(true) => True
      Some(false) =>
        match elem {
          ComplexFloat(_) => True
          _ =>
            if @symcore.is_complex_number_atom(elem) &&
              !is_noncomplex_infinite(elem) {
              True
            } else {
              Unknown
            }
        }
      None =>
        match elem {
          Number(_) | Float(_) | ComplexFloat(_) => True
          _ =>
            if @symcore.is_number_symbol(elem) && !is_noncomplex_infinite(elem) {
              True
            } else {
              Unknown
            }
        }
    }
  }
  match expr_number_value(elem) {
    Some(value) => {
      let is_int = value.is_integral()
      match kind {
        Naturals =>
          if is_int && value.compare(@symnum.BigRational::zero()) > 0 {
            True
          } else {
            False
          }
        Naturals0 =>
          if is_int && value.compare(@symnum.BigRational::zero()) >= 0 {
            True
          } else {
            False
          }
        Integers => if is_int { True } else { False }
        Rationals => True
        Reals => True
        _ => Unknown
      }
    }
    None => Unknown
  }
}

///|
/// Test whether an element belongs to a set.
///
/// - Does: Evaluates membership with concrete special cases and symbolic fallbacks.
/// - Input: One `Set` value and one candidate `Expr`.
/// - Returns: A `SetBool` decision.
/// - Limits: Returns `Unknown` when the current implementation cannot decide the membership query exactly.
pub fn contains(set : Set, elem : Expr) -> SetBool {
  match set {
    EmptySet => False
    UniversalSet => True
    FiniteSet(items) => finite_contains(items, elem)
    Interval(..) => interval_contains(set, elem)
    ConditionSet(symbol~, condition~, base~) => {
      let base_res = contains(base, elem)
      match base_res {
        False => False
        Unknown => Unknown
        True => {
          let var_name = match symbol {
            Symbol(name) => name
            _ => ""
          }
          if var_name == "" {
            Unknown
          } else {
            let value = expr_number_value(elem)
            eval_bool_expr(condition, var_name, value)
          }
        }
      }
    }
    ImageSet(symbol~, expr~, base~) => {
      let var_name = match symbol {
        Symbol(name) => name
        _ => ""
      }
      if var_name != "" && !expr_depends_on(expr, var_name) {
        let eq = @symcore.compare_expr(expr, elem) == 0
        match set_is_empty(base) {
          True => return False
          False => return if eq { True } else { False }
          Unknown => return Unknown
        }
      }
      match base {
        FiniteSet(items) => {
          if var_name == "" {
            return Unknown
          }
          let env : Map[String, Expr] = Map([])
          for item in items {
            env[var_name] = item
            let mapped = @symcore.subst(expr, env)
            if @symcore.compare_expr(mapped, elem) == 0 {
              return True
            }
          }
          False
        }
        _ => Unknown
      }
    }
    ProductSet(items) =>
      match @symcore.tuple_items(elem) {
        Some(args) => {
          if args.length() != items.length() {
            return False
          }
          let mut acc = SetBool::True
          for i in 0..<items.length() {
            acc = setbool_and(acc, contains(items[i], args[i]))
            if acc == False {
              return acc
            }
          }
          acc
        }
        None => False
      }
    Naturals | Naturals0 | Integers | Rationals | Reals | Complexes =>
      contains_numerical_set(set, elem)
    Union(items) => {
      let mut acc = SetBool::False
      for item in items {
        acc = setbool_or(acc, contains(item, elem))
        if acc == True {
          return acc
        }
      }
      acc
    }
    Intersection(items) => {
      let mut acc = SetBool::True
      for item in items {
        acc = setbool_and(acc, contains(item, elem))
        if acc == False {
          return acc
        }
      }
      acc
    }
    Complement(a, b) =>
      setbool_and(contains(a, elem), setbool_not(contains(b, elem)))
  }
}

///|
/// Test whether one set is a subset of another.
///
/// - Does: Evaluates subset inclusion with concrete rules for finite sets, intervals, products, and a few symbolic shapes.
/// - Input: Two `Set` values.
/// - Returns: A `SetBool` decision.
/// - Limits: Returns `Unknown` when the package does not implement enough reasoning to prove or refute inclusion.
pub fn is_subset(a : Set, b : Set) -> SetBool {
  match (a, b) {
    (EmptySet, _) => True
    (_, UniversalSet) => True
    (x, y) if compare_set(x, y) == 0 => True
    (FiniteSet(items), other) => {
      let mut acc = SetBool::True
      for item in items {
        acc = setbool_and(acc, contains(other, item))
        if acc == False {
          return acc
        }
      }
      acc
    }
    (Interval(..), Interval(..)) =>
      match (interval_numeric(a), interval_numeric(b)) {
        (
          Some((al, ar, alo, aro, _alexpr, _arexpr)),
          Some((bl, br, blo, bro, _blexpr, _brexpr)),
        ) => {
          let left_cmp = compare_interval_bound(al, bl)
          let right_cmp = compare_interval_bound(ar, br)
          let left_ok = if left_cmp > 0 {
            true
          } else if left_cmp == 0 {
            !alo || blo
          } else {
            false
          }
          let right_ok = if right_cmp < 0 {
            true
          } else if right_cmp == 0 {
            !aro || bro
          } else {
            false
          }
          if left_ok && right_ok {
            True
          } else {
            False
          }
        }
        _ => Unknown
      }
    (ProductSet(xs), ProductSet(ys)) => {
      if xs.length() != ys.length() {
        return False
      }
      let mut acc = SetBool::True
      for i in 0..<xs.length() {
        acc = setbool_and(acc, is_subset(xs[i], ys[i]))
        if acc == False {
          return acc
        }
      }
      acc
    }
    (Naturals | Naturals0 | Integers | Rationals | Reals, Complexes) => True
    _ => Unknown
  }
}
