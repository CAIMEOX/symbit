///|\
/// Rules for Expr trees (SymPy strategies rl port).

///|
fn expr_args(expr : @symcore.Expr) -> Array[@symcore.Expr] {
  let out : Array[@symcore.Expr] = Array::new()
  for child in @symcore.children(expr) {
    out.push(child)
  }
  out
}

///|
/// Create a rule to remove identities.
pub fn rm_id(
  isid : (@symcore.Expr) -> Bool,
  new? : (@strategies_util.ExprOp, Array[@symcore.Expr]) -> @symcore.Expr = @strategies_util.new,
) -> (@symcore.Expr) -> @symcore.Expr {
  (expr : @symcore.Expr) => {
    let args = expr_args(expr)
    let ids : Array[Bool] = args.map(isid)
    let mut count = 0
    for flag in ids {
      if flag { count += 1 }
    }
    if count == 0 {
      expr
    } else if count != ids.length() {
      let kept : Array[@symcore.Expr] = Array::new()
      for i in 0..<args.length() {
        if !ids[i] {
          kept.push(args[i])
        }
      }
      new(@strategies_util.expr_op(expr), kept)
    } else {
      new(@strategies_util.expr_op(expr), [args[0]])
    }
  }
}

///|
/// Create a rule to conglomerate identical args.
pub fn[K : Eq + Hash, C : Add] glom(
  key : (@symcore.Expr) -> K,
  count : (@symcore.Expr) -> C,
  combine : (C, K) -> @symcore.Expr,
) -> (@symcore.Expr) -> @symcore.Expr {
  (expr : @symcore.Expr) => {
    let args = expr_args(expr)
    let groups = sift(args, key)
    let newargs : Array[@symcore.Expr] = Array::new()
    for k, group in groups {
      if group.is_empty() {
        continue
      }
      let mut total = count(group[0])
      for i in 1..<group.length() {
        total = total + count(group[i])
      }
      newargs.push(combine(total, k))
    }
    if newargs.length() != args.length() {
      @strategies_util.expr_new_eval(@strategies_util.expr_op(expr), newargs)
    } else {
      expr
    }
  }
}

///|
/// Create a rule to sort by a key function.
pub fn[K : Compare] sort(
  key : (@symcore.Expr) -> K,
  new? : (@strategies_util.ExprOp, Array[@symcore.Expr]) -> @symcore.Expr = @strategies_util.new,
) -> (@symcore.Expr) -> @symcore.Expr {
  (expr : @symcore.Expr) => {
    let args = expr_args(expr)
    args.sort_by((a, b) => key(a).compare(key(b)))
    new(@strategies_util.expr_op(expr), args)
  }
}

///|
/// Turns an A containing Bs into a B of As.
pub fn distribute(
  opA : @strategies_util.ExprOp,
  opB : @strategies_util.ExprOp,
) -> (@symcore.Expr) -> @symcore.Expr {
  (expr : @symcore.Expr) => {
    let args = expr_args(expr)
    for i in 0..<args.length() {
      if @strategies_util.expr_op(args[i]) == opB {
        let first : Array[@symcore.Expr] = Array::new()
        let tail : Array[@symcore.Expr] = Array::new()
        for j in 0..<args.length() {
          if j < i {
            first.push(args[j])
          } else if j > i {
            tail.push(args[j])
          }
        }
        let b_args = expr_args(args[i])
        let out : Array[@symcore.Expr] = Array::new()
        for barg in b_args {
          let inner : Array[@symcore.Expr] = Array::new()
          for v in first { inner.push(v) }
          inner.push(barg)
          for v in tail { inner.push(v) }
          out.push(@strategies_util.expr_new_eval(opA, inner))
        }
        return @strategies_util.expr_new_eval(opB, out)
      }
    }
    expr
  }
}

///|
/// Replace expressions exactly.
pub fn subs(a : @symcore.Expr, b : @symcore.Expr) -> (@symcore.Expr) -> @symcore.Expr {
  (expr : @symcore.Expr) => if expr == a { b } else { expr }
}

///|
/// Rule to unpack singleton args.
pub fn unpack(expr : @symcore.Expr) -> @symcore.Expr {
  let args = expr_args(expr)
  if args.length() == 1 { args[0] } else { expr }
}

///|
/// Flatten T(a, b, T(c, d), T2(e)) to T(a, b, c, d, T2(e)).
pub fn flatten(
  expr : @symcore.Expr,
  new? : (@strategies_util.ExprOp, Array[@symcore.Expr]) -> @symcore.Expr = @strategies_util.new,
) -> @symcore.Expr {
  let target = @strategies_util.expr_op(expr)
  let args = expr_args(expr)
  let out : Array[@symcore.Expr] = Array::new()
  for arg in args {
    if @strategies_util.expr_op(arg) == target {
      for child in expr_args(arg) {
        out.push(child)
      }
    } else {
      out.push(arg)
    }
  }
  new(target, out)
}

///|
/// Rebuild an Expr tree with canonical constructors.
pub fn rebuild(expr : @symcore.Expr) -> @symcore.Expr {
  if @strategies_util.expr_leaf(expr) {
    expr
  } else {
    let op = @strategies_util.expr_op(expr)
    let args = expr_args(expr).map(rebuild)
    @strategies_util.expr_new_eval(op, args)
  }
}

///|
/// Group values by key.
fn[T, K : Eq + Hash] sift(values : Array[T], key : (T) -> K) -> Map[K, Array[T]] {
  let out : Map[K, Array[T]] = Map::new()
  for v in values {
    let k = key(v)
    match out.get(k) {
      Some(arr) => arr.push(v)
      None => out[k] = [v]
    }
  }
  out
}
