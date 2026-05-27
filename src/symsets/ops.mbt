///|
/// Core set operations and membership tests.
///
/// Current Limits:
/// - Coverage is strongest for finite sets, numeric intervals, standard numeric domains, and direct symbolic compositions.
/// - Harder symbolic reasoning still returns unevaluated set expressions or `Unknown`.

///|
fn setbool_or(a : SetBool, b : SetBool) -> SetBool {
  match (a, b) {
    (SetBool::True, _) | (_, SetBool::True) => SetBool::True
    (SetBool::Unknown, _) | (_, SetBool::Unknown) => SetBool::Unknown
    _ => SetBool::False
  }
}

///|
fn setbool_and(a : SetBool, b : SetBool) -> SetBool {
  match (a, b) {
    (SetBool::False, _) | (_, SetBool::False) => SetBool::False
    (SetBool::Unknown, _) | (_, SetBool::Unknown) => SetBool::Unknown
    _ => SetBool::True
  }
}

///|
fn setbool_not(a : SetBool) -> SetBool {
  match a {
    SetBool::True => SetBool::False
    SetBool::False => SetBool::True
    SetBool::Unknown => SetBool::Unknown
  }
}

///|
fn expr_depends_on(expr : Expr, name : String) -> Bool {
  match expr {
    Expr::Symbol(s) => s == name
    Expr::Add(args) | Expr::Mul(args) =>
      args.any(child => expr_depends_on(child, name))
    Expr::Pow(base, exp) =>
      expr_depends_on(base, name) || expr_depends_on(exp, name)
    _ => @symcore.args(expr).any(child => expr_depends_on(child, name))
  }
}

///|
fn set_is_empty(set : Set) -> SetBool {
  match set {
    Set::EmptySet => SetBool::True
    Set::UniversalSet => SetBool::False
    Set::FiniteSet(items) =>
      if items.is_empty() {
        SetBool::True
      } else {
        SetBool::False
      }
    Set::Interval(..) => SetBool::False
    Set::Naturals
    | Set::Naturals0
    | Set::Integers
    | Set::Rationals
    | Set::Reals
    | Set::Complexes => SetBool::False
    Set::ProductSet(items) => {
      for item in items {
        match set_is_empty(item) {
          SetBool::True => return SetBool::True
          SetBool::Unknown => return SetBool::Unknown
          _ => ()
        }
      }
      SetBool::False
    }
    Set::ConditionSet(symbol=_, condition=_, base~) => set_is_empty(base)
    Set::ImageSet(symbol=_, expr=_, base~) => set_is_empty(base)
    _ => SetBool::Unknown
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
      @symlogic.RelOp::Le =>
        if cmp <= 0 {
          SetBool::True
        } else {
          SetBool::False
        }
      @symlogic.RelOp::Ge =>
        if cmp >= 0 {
          SetBool::True
        } else {
          SetBool::False
        }
      @symlogic.RelOp::Lt =>
        if cmp < 0 {
          SetBool::True
        } else {
          SetBool::False
        }
      @symlogic.RelOp::Gt =>
        if cmp > 0 {
          SetBool::True
        } else {
          SetBool::False
        }
      @symlogic.RelOp::Eq =>
        if cmp == 0 {
          SetBool::True
        } else {
          SetBool::False
        }
    }
  }
  if coeffs.length() != 1 {
    return SetBool::Unknown
  }
  match coeffs.get(var_name) {
    None => SetBool::Unknown
    Some(coeff) => {
      let lhs = coeff.mul_r(value)
      let cmp = lhs.compare(constraint.rhs)
      match constraint.op {
        @symlogic.RelOp::Le =>
          if cmp <= 0 {
            SetBool::True
          } else {
            SetBool::False
          }
        @symlogic.RelOp::Ge =>
          if cmp >= 0 {
            SetBool::True
          } else {
            SetBool::False
          }
        @symlogic.RelOp::Lt =>
          if cmp < 0 {
            SetBool::True
          } else {
            SetBool::False
          }
        @symlogic.RelOp::Gt =>
          if cmp > 0 {
            SetBool::True
          } else {
            SetBool::False
          }
        @symlogic.RelOp::Eq =>
          if cmp == 0 {
            SetBool::True
          } else {
            SetBool::False
          }
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
    @symlogic.BoolExpr::True => SetBool::True
    @symlogic.BoolExpr::False => SetBool::False
    @symlogic.BoolExpr::Not(inner) =>
      setbool_not(eval_bool_expr(inner, var_name, value))
    @symlogic.BoolExpr::And(args) => {
      let mut acc = SetBool::True
      for arg in args {
        acc = setbool_and(acc, eval_bool_expr(arg, var_name, value))
        if acc == SetBool::False {
          return acc
        }
      }
      acc
    }
    @symlogic.BoolExpr::Or(args) => {
      let mut acc = SetBool::False
      for arg in args {
        acc = setbool_or(acc, eval_bool_expr(arg, var_name, value))
        if acc == SetBool::True {
          return acc
        }
      }
      acc
    }
    @symlogic.BoolExpr::Implies(a, b) => {
      let not_a = setbool_not(eval_bool_expr(a, var_name, value))
      setbool_or(not_a, eval_bool_expr(b, var_name, value))
    }
    @symlogic.BoolExpr::Equivalent(args) => {
      if args.is_empty() {
        return SetBool::True
      }
      let first = eval_bool_expr(args[0], var_name, value)
      for i in 1..<args.length() {
        let current = eval_bool_expr(args[i], var_name, value)
        if first == SetBool::Unknown || current == SetBool::Unknown {
          return SetBool::Unknown
        }
        if first != current {
          return SetBool::False
        }
      }
      first
    }
    @symlogic.BoolExpr::ITE(c, t, e) =>
      match eval_bool_expr(c, var_name, value) {
        SetBool::True => eval_bool_expr(t, var_name, value)
        SetBool::False => eval_bool_expr(e, var_name, value)
        SetBool::Unknown => SetBool::Unknown
      }
    @symlogic.BoolExpr::LRA(constraint) =>
      match value {
        Some(v) => eval_lra_constraint(constraint, var_name, v)
        None => SetBool::Unknown
      }
    _ => SetBool::Unknown
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
    Some(value) => Some(IntervalBound::Finite(value))
    None =>
      match @symcore.number_symbol_kind(expr) {
        Some(@symcore.NumberSymbolKind::NegativeInfinity) =>
          Some(IntervalBound::NegativeInfinity)
        Some(@symcore.NumberSymbolKind::Infinity) =>
          Some(IntervalBound::Infinity)
        _ => None
      }
  }
}

///|
fn compare_interval_bound(a : IntervalBound, b : IntervalBound) -> Int {
  match (a, b) {
    (IntervalBound::NegativeInfinity, IntervalBound::NegativeInfinity)
    | (IntervalBound::Infinity, IntervalBound::Infinity) => 0
    (IntervalBound::NegativeInfinity, _) => -1
    (_, IntervalBound::NegativeInfinity) => 1
    (IntervalBound::Infinity, _) => 1
    (_, IntervalBound::Infinity) => -1
    (IntervalBound::Finite(left), IntervalBound::Finite(right)) =>
      left.compare(right)
  }
}

///|
fn interval_spans_reals(set : Set) -> Bool {
  match set {
    Set::Interval(left~, right~, left_open=_, right_open=_) =>
      match (interval_bound(left), interval_bound(right)) {
        (Some(IntervalBound::NegativeInfinity), Some(IntervalBound::Infinity)) =>
          true
        _ => false
      }
    Set::Reals => true
    _ => false
  }
}

///|
fn interval_numeric(
  set : Set,
) -> (IntervalBound, IntervalBound, Bool, Bool, Expr, Expr)? {
  match set {
    Set::Interval(left~, right~, left_open~, right_open~) =>
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
    return Set::EmptySet
  }
  let flat : Array[Set] = Array::new()
  let mut has_universal = false
  let finite_items : Array[Expr] = Array::new()
  let intervals : Array[Set] = Array::new()
  for set in args {
    match set {
      Set::Union(inner) =>
        for item in inner {
          flat.push(item)
        }
      Set::EmptySet => ()
      Set::UniversalSet => has_universal = true
      Set::FiniteSet(items) =>
        for item in items {
          finite_items.push(item)
        }
      Set::Interval(..) => intervals.push(set)
      _ => flat.push(set)
    }
  }
  if has_universal {
    return Set::UniversalSet
  }
  let merged_intervals = merge_intervals(intervals)
  for item in merged_intervals {
    flat.push(item)
  }
  if !finite_items.is_empty() {
    let fset = combine_finite_sets(finite_items)
    match fset {
      Set::EmptySet => ()
      _ => flat.push(fset)
    }
  }
  let uniq = dedup_sets(flat)
  if uniq.is_empty() {
    Set::EmptySet
  } else if uniq.length() == 1 && interval_spans_reals(uniq[0]) {
    Set::Reals
  } else if uniq.length() == 1 {
    uniq[0]
  } else {
    Set::Union(uniq)
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
        Some(Set::EmptySet)
      } else if cmp == 0 {
        if left_open || right_open {
          Some(Set::EmptySet)
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
      SetBool::True => out.push(item)
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
    return Set::UniversalSet
  }
  let flat : Array[Set] = Array::new()
  for set in args {
    match set {
      Set::Intersection(inner) =>
        for item in inner {
          flat.push(item)
        }
      _ => flat.push(set)
    }
  }
  let trimmed : Array[Set] = Array::new()
  for set in flat {
    match set {
      Set::EmptySet => return Set::EmptySet
      Set::UniversalSet => ()
      _ => trimmed.push(set)
    }
  }
  if trimmed.is_empty() {
    return Set::UniversalSet
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
      Set::FiniteSet(items) =>
        match finite_items {
          None => finite_items = Some(items)
          Some(prev) => finite_items = Some(intersect_finite_sets(prev, items))
        }
      Set::Interval(..) =>
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
    Some(Set::EmptySet) => return Set::EmptySet
    _ => ()
  }
  if finite_items is Some(items) {
    let filtered = match interval_acc {
      Some(interval_set) =>
        match interval_set {
          Set::Interval(..) => filter_finite_by_interval(items, interval_set)
          Set::FiniteSet(other_items) =>
            intersect_finite_sets(items, other_items)
          Set::EmptySet => []
          _ => items
        }
      None => items
    }
    let fset = finite_set(filtered)
    match fset {
      Set::EmptySet => return Set::EmptySet
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
    Set::UniversalSet
  } else if uniq.length() == 1 {
    uniq[0]
  } else {
    Set::Intersection(uniq)
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
        return Some(Set::EmptySet)
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
        Some(Set::EmptySet)
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
    (Set::EmptySet, _) => Set::EmptySet
    (_, Set::EmptySet) => a
    (Set::UniversalSet, Set::UniversalSet) => Set::EmptySet
    (x, y) if compare_set(x, y) == 0 => Set::EmptySet
    (Set::FiniteSet(items), Set::FiniteSet(remove)) => {
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
    (Set::FiniteSet(items), interval_set) =>
      match interval_set {
        Set::Interval(..) => {
          // filter_finite_by_interval keeps contained items; we need complement
          let out : Array[Expr] = Array::new()
          for item in items {
            let res = contains(interval_set, item)
            match res {
              SetBool::True => ()
              _ => out.push(item)
            }
          }
          finite_set(out)
        }
        _ => Set::Complement(a, interval_set)
      }
    (Set::Interval(..), Set::Interval(..)) =>
      match interval_difference(a, b) {
        Some(res) => res
        None => Set::Complement(a, b)
      }
    (Set::Union(items), other) => {
      let parts : Array[Set] = Array::new()
      for item in items {
        parts.push(complement(item, other))
      }
      union(parts)
    }
    _ => Set::Complement(a, b)
  }
}

///|
fn interval_contains(set : Set, elem : Expr) -> SetBool {
  match (set, expr_number_value(elem)) {
    (Set::Interval(left~, right~, left_open~, right_open~), Some(value)) => {
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
            Some(@symcore.NumberSymbolKind::NegativeInfinity) => Some(true)
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
            Some(@symcore.NumberSymbolKind::Infinity) => Some(true)
            _ => None
          }
      }
      match (lower_ok, upper_ok) {
        (Some(true), Some(true)) => SetBool::True
        (Some(false), _) | (_, Some(false)) => SetBool::False
        _ => SetBool::Unknown
      }
    }
    _ => SetBool::Unknown
  }
}

///|
fn finite_contains(items : Array[Expr], elem : Expr) -> SetBool {
  for item in items {
    if @symcore.compare_expr(item, elem) == 0 {
      return SetBool::True
    }
  }
  SetBool::False
}

///|
fn contains_numerical_set(kind : Set, elem : Expr) -> SetBool {
  let is_noncomplex_infinite = fn(expr : Expr) {
    match @symcore.number_symbol_kind(expr) {
      Some(@symcore.NumberSymbolKind::ComplexInfinity) => true
      _ => false
    }
  }
  if kind == Set::Complexes {
    return match
      @symassume.tri_to_bool_option(
        @symassume.ask_predicate(elem, @symassume.Predicate::IsReal),
      ) {
      Some(true) => SetBool::True
      Some(false) =>
        match elem {
          Expr::ComplexFloat(_) => SetBool::True
          _ =>
            if @symcore.is_complex_number_atom(elem) &&
              !is_noncomplex_infinite(elem) {
              SetBool::True
            } else {
              SetBool::Unknown
            }
        }
      None =>
        match elem {
          Expr::Number(_) | Expr::Float(_) | Expr::ComplexFloat(_) =>
            SetBool::True
          _ =>
            if @symcore.is_number_symbol(elem) && !is_noncomplex_infinite(elem) {
              SetBool::True
            } else {
              SetBool::Unknown
            }
        }
    }
  }
  match expr_number_value(elem) {
    Some(value) => {
      let is_int = value.is_integral()
      match kind {
        Set::Naturals =>
          if is_int && value.compare(@symnum.BigRational::zero()) > 0 {
            SetBool::True
          } else {
            SetBool::False
          }
        Set::Naturals0 =>
          if is_int && value.compare(@symnum.BigRational::zero()) >= 0 {
            SetBool::True
          } else {
            SetBool::False
          }
        Set::Integers => if is_int { SetBool::True } else { SetBool::False }
        Set::Rationals => SetBool::True
        Set::Reals => SetBool::True
        _ => SetBool::Unknown
      }
    }
    None => SetBool::Unknown
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
    Set::EmptySet => SetBool::False
    Set::UniversalSet => SetBool::True
    Set::FiniteSet(items) => finite_contains(items, elem)
    Set::Interval(..) => interval_contains(set, elem)
    Set::ConditionSet(symbol~, condition~, base~) => {
      let base_res = contains(base, elem)
      match base_res {
        SetBool::False => SetBool::False
        SetBool::Unknown => SetBool::Unknown
        SetBool::True => {
          let var_name = match symbol {
            Expr::Symbol(name) => name
            _ => ""
          }
          if var_name == "" {
            SetBool::Unknown
          } else {
            let value = expr_number_value(elem)
            eval_bool_expr(condition, var_name, value)
          }
        }
      }
    }
    Set::ImageSet(symbol~, expr~, base~) => {
      let var_name = match symbol {
        Expr::Symbol(name) => name
        _ => ""
      }
      if var_name != "" && !expr_depends_on(expr, var_name) {
        let eq = @symcore.compare_expr(expr, elem) == 0
        match set_is_empty(base) {
          SetBool::True => return SetBool::False
          SetBool::False =>
            return if eq { SetBool::True } else { SetBool::False }
          SetBool::Unknown => return SetBool::Unknown
        }
      }
      match base {
        Set::FiniteSet(items) => {
          if var_name == "" {
            return SetBool::Unknown
          }
          let env : Map[String, Expr] = Map([])
          for item in items {
            env[var_name] = item
            let mapped = @symcore.subst(expr, env)
            if @symcore.compare_expr(mapped, elem) == 0 {
              return SetBool::True
            }
          }
          SetBool::False
        }
        _ => SetBool::Unknown
      }
    }
    Set::ProductSet(items) =>
      match @symcore.tuple_items(elem) {
        Some(args) => {
          if args.length() != items.length() {
            return SetBool::False
          }
          let mut acc = SetBool::True
          for i in 0..<items.length() {
            acc = setbool_and(acc, contains(items[i], args[i]))
            if acc == SetBool::False {
              return acc
            }
          }
          acc
        }
        None => SetBool::False
      }
    Set::Naturals
    | Set::Naturals0
    | Set::Integers
    | Set::Rationals
    | Set::Reals
    | Set::Complexes => contains_numerical_set(set, elem)
    Set::Union(items) => {
      let mut acc = SetBool::False
      for item in items {
        acc = setbool_or(acc, contains(item, elem))
        if acc == SetBool::True {
          return acc
        }
      }
      acc
    }
    Set::Intersection(items) => {
      let mut acc = SetBool::True
      for item in items {
        acc = setbool_and(acc, contains(item, elem))
        if acc == SetBool::False {
          return acc
        }
      }
      acc
    }
    Set::Complement(a, b) =>
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
    (Set::EmptySet, _) => SetBool::True
    (_, Set::UniversalSet) => SetBool::True
    (x, y) if compare_set(x, y) == 0 => SetBool::True
    (Set::FiniteSet(items), other) => {
      let mut acc = SetBool::True
      for item in items {
        acc = setbool_and(acc, contains(other, item))
        if acc == SetBool::False {
          return acc
        }
      }
      acc
    }
    (Set::Interval(..), Set::Interval(..)) =>
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
            SetBool::True
          } else {
            SetBool::False
          }
        }
        _ => SetBool::Unknown
      }
    (Set::ProductSet(xs), Set::ProductSet(ys)) => {
      if xs.length() != ys.length() {
        return SetBool::False
      }
      let mut acc = SetBool::True
      for i in 0..<xs.length() {
        acc = setbool_and(acc, is_subset(xs[i], ys[i]))
        if acc == SetBool::False {
          return acc
        }
      }
      acc
    }
    (
      Set::Naturals
      | Set::Naturals0
      | Set::Integers
      | Set::Rationals
      | Set::Reals,
      Set::Complexes,
    ) => SetBool::True
    _ => SetBool::Unknown
  }
}
