///|
pub type Expr = @symcore.Expr

///|
pub type BigRational = @symnum.BigRational

///|
pub type SimplifyPattern = @symsimplify.SimplifyPattern

///|
pub type SimplifyPlan = @symsimplify.SimplifyPlan

///|
pub type CseResult = @symsimplify.CseResult

///|
pub type EPath = @symsimplify.EPath

///|
pub fn symbol(name : String) -> Expr {
  @symcore.symbol(name)
}

///|
pub fn integer(value : Int) -> Expr {
  @symcore.int(value)
}

///|
pub fn rational(num : Int, den : Int) -> Expr raise @symnum.RationalError {
  @symcore.rational_from_ints(num, den)
}

///|
pub fn add(args : Array[Expr]) -> Expr {
  if args.is_empty() {
    @symcore.int(0)
  } else {
    let mut acc = args[0]
    for i in 1..<args.length() {
      acc = acc + args[i]
    }
    acc
  }
}

///|
pub fn mul(args : Array[Expr]) -> Expr {
  if args.is_empty() {
    @symcore.int(1)
  } else {
    let mut acc = args[0]
    for i in 1..<args.length() {
      acc = acc * args[i]
    }
    acc
  }
}

///|
pub fn pow(base : Expr, exp : Expr) -> Expr {
  base ^ exp
}

///|
pub fn debug_repr(expr : Expr) -> String {
  @symprint.debug_repr(expr)
}

///|
pub fn to_string(expr : Expr) -> String {
  @symprint.to_string(expr)
}

///|
pub fn simplify(expr : Expr) -> Expr {
  @symsimplify.simplify(expr)
}

///|
pub fn powsimp(expr : Expr) -> Expr {
  @symsimplify.powsimp(expr)
}

///|
pub fn trigsimp(expr : Expr) -> Expr {
  @symsimplify.trigsimp(expr)
}

///|
pub fn signsimp(expr : Expr) -> Expr {
  @symsimplify.signsimp(expr)
}

///|
pub fn simplify_with_patterns(
  expr : Expr,
  patterns : Array[SimplifyPattern],
  max_passes? : Int = 8,
) -> Expr {
  @symsimplify.simplify_with_patterns(expr, patterns, max_passes~)
}

///|
pub fn radsimp(expr : Expr) -> Expr {
  @symsimplify.radsimp(expr)
}

///|
pub fn ratsimp(expr : Expr) -> Expr {
  @symsimplify.ratsimp(expr)
}

///|
pub fn ratsimpmodprime(
  expr : Expr,
  basis? : Array[Expr] = [],
  gens? : Array[Expr] = [],
  quick? : Bool = true,
  polynomial? : Bool = false,
) -> Expr {
  @symsimplify.ratsimpmodprime(expr, basis~, gens~, quick~, polynomial~)
}

///|
pub fn sqrtdenest(expr : Expr) -> Expr {
  @symsimplify.sqrtdenest(expr)
}

///|
pub fn combsimp(expr : Expr) -> Expr {
  @symsimplify.combsimp(expr)
}

///|
pub fn hyperexpand(expr : Expr) -> Expr {
  @symsimplify.hyperexpand(expr)
}

///|
pub fn cse(exprs : Array[Expr]) -> CseResult {
  @symsimplify.cse(exprs)
}

///|
pub fn cse_reconstruct(result : CseResult) -> Array[Expr] {
  @symsimplify.cse_reconstruct(result)
}

///|
pub fn sub_pre(expr : Expr) -> Expr {
  @symsimplify.sub_pre(expr)
}

///|
pub fn sub_post(expr : Expr) -> Expr {
  @symsimplify.sub_post(expr)
}

///|
pub fn fraction(expr : Expr) -> (Expr, Expr) {
  @symsimplify.fraction(expr)
}

///|
pub fn numer(expr : Expr) -> Expr {
  @symsimplify.numer(expr)
}

///|
pub fn denom(expr : Expr) -> Expr {
  @symsimplify.denom(expr)
}

///|
pub fn fraction_expand(expr : Expr) -> Expr {
  @symsimplify.fraction_expand(expr)
}

///|
pub fn numer_expand(expr : Expr) -> Expr {
  @symsimplify.numer_expand(expr)
}

///|
pub fn denom_expand(expr : Expr) -> Expr {
  @symsimplify.denom_expand(expr)
}

///|
pub fn rad_rationalize(num : Expr, den : Expr) -> (Expr, Expr) {
  @symsimplify.rad_rationalize(num, den)
}

///|
pub fn split_surds(expr : Expr) -> (Expr, Expr, Expr) {
  @symsimplify.split_surds(expr)
}

///|
pub fn collect(expr : Expr, sym : Expr) -> Expr {
  @symsimplify.collect(expr, sym)
}

///|
pub fn rcollect(expr : Expr, sym : Expr) -> Expr {
  @symsimplify.rcollect(expr, sym)
}

///|
pub fn collect_const(expr : Expr) -> Expr {
  @symsimplify.collect_const(expr)
}

///|
pub fn collect_sqrt(expr : Expr) -> Expr {
  @symsimplify.collect_sqrt(expr)
}

///|
pub fn collect_abs(expr : Expr) -> Expr {
  @symsimplify.collect_abs(expr)
}

///|
pub fn powdenest(expr : Expr) -> Expr {
  @symsimplify.powdenest(expr)
}

///|
pub fn exptrigsimp(expr : Expr) -> Expr {
  @symsimplify.exptrigsimp(expr)
}

///|
pub fn gammasimp(expr : Expr) -> Expr {
  @symsimplify.gammasimp(expr)
}

///|
pub fn logcombine(expr : Expr) -> Expr {
  @symsimplify.logcombine(expr)
}

///|
pub fn besselsimp(expr : Expr) -> Expr {
  @symsimplify.besselsimp(expr)
}

///|
pub fn kroneckersimp(expr : Expr) -> Expr {
  @symsimplify.kroneckersimp(expr)
}

///|
pub fn nsimplify(
  expr : Expr,
  constants? : Array[Expr] = [],
  full? : Bool = false,
  rational? : Bool = true,
) -> Expr {
  @symsimplify.nsimplify(expr, constants~, full~, rational~)
}

///|
pub fn separatevars(expr : Expr, force? : Bool = false) -> Expr {
  @symsimplify.separatevars(expr, force~)
}

///|
pub fn posify(expr : Expr) -> (Expr, Map[String, Expr]) {
  @symsimplify.posify(expr)
}

///|
pub fn hypersimp(f : Expr, k : Expr) -> Expr {
  @symsimplify.hypersimp(f, k)
}

///|
pub fn hypersimilar(f : Expr, g : Expr, k : Expr) -> Bool {
  @symsimplify.hypersimilar(f, g, k)
}

///|
pub fn epath(path : String, expr : Expr) -> Array[Expr] {
  @symsimplify.epath(path, expr)
}

///|
pub fn epath_apply(
  path : String,
  expr : Expr,
  f : (Expr) -> Expr,
) -> Expr {
  @symsimplify.epath_apply(path, expr, f)
}

///|
pub fn use(
  expr : Expr,
  f : (Expr) -> Expr,
  level? : Int = 0,
) -> Expr {
  @symsimplify.use(expr, f, level~)
}

///|
pub fn fu(expr : Expr) -> Expr {
  @symsimplify.fu(expr)
}

///|
pub fn futrig(expr : Expr) -> Expr {
  @symsimplify.futrig(expr)
}

///|
pub fn tr0(expr : Expr) -> Expr {
  @symsimplify.tr0(expr)
}

///|
pub fn tr1(expr : Expr) -> Expr {
  @symsimplify.tr1(expr)
}

///|
pub fn tr2(expr : Expr) -> Expr {
  @symsimplify.tr2(expr)
}

///|
pub fn tr2i(expr : Expr, half? : Bool = false) -> Expr {
  @symsimplify.tr2i(expr, half~)
}

///|
pub fn tr3(expr : Expr) -> Expr {
  @symsimplify.tr3(expr)
}

///|
pub fn tr4(expr : Expr) -> Expr {
  @symsimplify.tr4(expr)
}

///|
pub fn tr5(expr : Expr, max? : Int = 4, pow? : Bool = false) -> Expr {
  @symsimplify.tr5(expr, max~, pow~)
}

///|
pub fn tr6(expr : Expr, max? : Int = 4, pow? : Bool = false) -> Expr {
  @symsimplify.tr6(expr, max~, pow~)
}

///|
pub fn tr7(expr : Expr) -> Expr {
  @symsimplify.tr7(expr)
}

///|
pub fn tr8(expr : Expr) -> Expr {
  @symsimplify.tr8(expr)
}

///|
pub fn tr9(expr : Expr) -> Expr {
  @symsimplify.tr9(expr)
}

///|
pub fn tr10(expr : Expr) -> Expr {
  @symsimplify.tr10(expr)
}

///|
pub fn tr10i(expr : Expr) -> Expr {
  @symsimplify.tr10i(expr)
}

///|
pub fn tr11(expr : Expr) -> Expr {
  @symsimplify.tr11(expr)
}

///|
pub fn tr12(expr : Expr) -> Expr {
  @symsimplify.tr12(expr)
}

///|
pub fn tr12i(expr : Expr) -> Expr {
  @symsimplify.tr12i(expr)
}

///|
pub fn tr13(expr : Expr) -> Expr {
  @symsimplify.tr13(expr)
}

///|
pub fn tr14(expr : Expr) -> Expr {
  @symsimplify.tr14(expr)
}

///|
pub fn tr15(expr : Expr, max? : Int = 4, pow? : Bool = false) -> Expr {
  @symsimplify.tr15(expr, max~, pow~)
}

///|
pub fn tr16(expr : Expr, max? : Int = 4, pow? : Bool = false) -> Expr {
  @symsimplify.tr16(expr, max~, pow~)
}

///|
pub fn tr111(expr : Expr) -> Expr {
  @symsimplify.tr111(expr)
}

///|
pub fn tr22(expr : Expr, max? : Int = 4, pow? : Bool = false) -> Expr {
  @symsimplify.tr22(expr, max~, pow~)
}

///|
pub fn trpower(expr : Expr) -> Expr {
  @symsimplify.trpower(expr)
}

///|
pub fn trmorrie(expr : Expr) -> Expr {
  @symsimplify.trmorrie(expr)
}
