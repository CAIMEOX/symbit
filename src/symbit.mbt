///|
/// Root alias for Symbit's symbolic expression tree.
pub type Expr = @symcore.Expr

///|
/// Root alias for the dense symbolic matrix type.
pub type Matrix = @symmatrices.Matrix

///|
/// Root alias for the sparse symbolic matrix type.
pub type SparseMatrix = @symmatrices.SparseMatrix

///|
/// Root alias for matrix-construction and linear-algebra errors.
pub type MatrixError = @symmatrices.MatrixError

///|
/// Root alias for machine floating-point values carried by symbolic expressions.
pub type Float = @symcore.Float

///|
/// Root alias for complex floating-point leaves used in evaluated expressions.
pub type ComplexFloat = @symcore.ComplexFloat

///|
/// Root alias for exact rational arithmetic used throughout Symbit.
pub type BigRational = @symnum.BigRational

///|
/// Root alias for values accepted by the high-level `sympify` facade.
pub type SympifyInput = @symcore.SympifyInput

///|
/// Root alias for one targeted simplify rewrite pattern.
pub type SimplifyPattern = @symsimplify.SimplifyPattern

///|
/// Root alias for named simplify pipelines used by `simplify`.
pub type SimplifyPlan = @symsimplify.SimplifyPlan

///|
/// Root alias for the result returned by common-subexpression elimination.
pub type CseResult = @symsimplify.CseResult

///|
/// Root alias for expression-path selectors used by traversal helpers.
pub type EPath = @symsimplify.EPath

///|
/// Create a fresh dummy symbol with identity distinct from its printed name.
pub fn dummy(name? : String = "Dummy") -> Expr {
  @symcore.dummy(name~)
}

///|
/// Apply an undefined function head to arguments while preserving first-class head structure.
pub fn applied_undefined_function(name : String, args : Array[Expr]) -> Expr {
  @symcore.applied_undefined_function(name, args)
}

///|
/// Apply a first-class function head to arguments. Returns `None` when `head`
/// is not a callable core head.
pub fn apply(head : Expr, args : Array[Expr]) -> Expr? {
  @symcore.apply(head, args)
}

///|
/// Coerce a symbolic name through the core `sympify` pipeline.
pub fn sympify_name(name : String) -> Expr {
  @symcore.sympify_name(name)
}

///|
/// Coerce a typed MoonBit payload into a core symbolic expression.
pub fn sympify(value : SympifyInput) -> Expr {
  @symcore.sympify(value)
}

///|
/// Lift tuple-shaped inputs into a symbolic tuple.
pub fn sympify_tuple(items : Array[SympifyInput]) -> Expr {
  @symcore.sympify_tuple(items)
}

///|
/// Lift key/value pairs into a symbolic dict container.
pub fn sympify_dict(items : Array[(SympifyInput, SympifyInput)]) -> Expr {
  @symcore.sympify_dict(items)
}

///|
/// Create an exact integer expression.
pub fn integer(value : Int) -> Expr {
  @symcore.int(value)
}

///|
/// Create an exact rational expression `num/den`.
pub fn rational(num : Int, den : Int) -> Expr raise @symnum.RationalError {
  @symcore.rational_from_ints(num, den)
}

///|
/// Create a dense symbolic matrix.
pub fn matrix(rows : Array[Array[Expr]]) -> Matrix raise MatrixError {
  @symmatrices.matrix(rows)
}

///|
/// Create a sparse symbolic matrix from DOK-style entries.
pub fn sparse_matrix(
  rows : Int,
  cols : Int,
  entries : Map[(Int, Int), Expr],
) -> SparseMatrix raise MatrixError {
  @symmatrices.sparse_matrix(rows, cols, entries)
}

///|
/// Create an all-zero matrix.
pub fn zeros(rows : Int, cols? : Int? = None) -> Matrix raise MatrixError {
  @symmatrices.zeros(rows, cols~)
}

///|
/// Create an all-one matrix.
pub fn ones(rows : Int, cols? : Int? = None) -> Matrix raise MatrixError {
  @symmatrices.ones(rows, cols~)
}

///|
/// Create the identity matrix.
pub fn eye(n : Int) -> Matrix raise MatrixError {
  @symmatrices.eye(n)
}

///|
/// Create a diagonal matrix from the supplied diagonal entries.
pub fn diag(
  values : Array[Expr],
  rows? : Int? = None,
  cols? : Int? = None,
) -> Matrix raise MatrixError {
  @symmatrices.diag(values, rows~, cols~)
}

///|
/// Build an additive expression from `args` (empty -> `0`).
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
/// Build a multiplicative expression from `args` (empty -> `1`).
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
/// Construct a power expression `base**exp`.
pub fn pow(base : Expr, exp : Expr) -> Expr {
  base ^ exp
}

///|
/// Return the default pretty string form for an expression.
pub fn to_string(expr : Expr) -> String {
  @symprint.to_string(expr)
}

///|
/// Numerically evaluate exact numeric leaves and common constants/functions.
pub fn evalf(expr : Expr, prec? : Int = 53) -> Expr {
  @symcore.evalf(expr, prec~)
}

///|
/// Run the general simplification pipeline.
pub fn simplify(expr : Expr) -> Expr {
  @symsimplify.simplify(expr)
}

///|
/// Simplify powers and exponent combinations.
pub fn powsimp(expr : Expr) -> Expr {
  @symsimplify.powsimp(expr)
}

///|
/// Simplify trigonometric expressions.
pub fn trigsimp(expr : Expr) -> Expr {
  @symsimplify.trigsimp(expr)
}

///|
/// Normalize signs in additive and multiplicative expressions.
pub fn signsimp(expr : Expr) -> Expr {
  @symsimplify.signsimp(expr)
}

///|
/// Apply a custom simplify plan composed of rewrite patterns.
pub fn simplify_with_patterns(
  expr : Expr,
  patterns : Array[SimplifyPattern],
  max_passes? : Int = 8,
) -> Expr {
  @symsimplify.simplify_with_patterns(expr, patterns, max_passes~)
}

///|
/// Rationalize and simplify radicals in denominators.
pub fn radsimp(expr : Expr) -> Expr {
  @symsimplify.radsimp(expr)
}

///|
/// Perform rational function simplification.
pub fn ratsimp(expr : Expr) -> Expr {
  @symsimplify.ratsimp(expr)
}

///|
/// Run modular rational simplification over a temporary prime field.
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
/// Denest nested square roots when algebraically possible.
pub fn sqrtdenest(expr : Expr) -> Expr {
  @symsimplify.sqrtdenest(expr)
}

///|
/// Simplify combinatorial and factorial-style expressions.
pub fn combsimp(expr : Expr) -> Expr {
  @symsimplify.combsimp(expr)
}

///|
/// Expand hypergeometric functions into simpler closed forms when possible.
pub fn hyperexpand(expr : Expr) -> Expr {
  @symsimplify.hyperexpand(expr)
}

///|
/// Compute common-subexpression elimination replacements and reduced outputs.
pub fn cse(exprs : Array[Expr]) -> CseResult {
  @symsimplify.cse(exprs)
}

///|
/// Reconstruct original expressions from a `cse` result.
pub fn cse_reconstruct(result : CseResult) -> Array[Expr] {
  @symsimplify.cse_reconstruct(result)
}

///|
/// Apply `sub_pre` rewriting (parent before children).
pub fn sub_pre(expr : Expr) -> Expr {
  @symsimplify.sub_pre(expr)
}

///|
/// Apply `sub_post` rewriting (children before parent).
pub fn sub_post(expr : Expr) -> Expr {
  @symsimplify.sub_post(expr)
}

///|
/// Split an expression into numerator and denominator.
pub fn fraction(expr : Expr) -> (Expr, Expr) {
  @symsimplify.fraction(expr)
}

///|
/// Extract the numerator of a rational expression.
pub fn numer(expr : Expr) -> Expr {
  @symsimplify.numer(expr)
}

///|
/// Extract the denominator of a rational expression.
pub fn denom(expr : Expr) -> Expr {
  @symsimplify.denom(expr)
}

///|
/// Expand numerator and denominator components of a fraction.
pub fn fraction_expand(expr : Expr) -> Expr {
  @symsimplify.fraction_expand(expr)
}

///|
/// Expand only the numerator of a rational expression.
pub fn numer_expand(expr : Expr) -> Expr {
  @symsimplify.numer_expand(expr)
}

///|
/// Expand only the denominator of a rational expression.
pub fn denom_expand(expr : Expr) -> Expr {
  @symsimplify.denom_expand(expr)
}

///|
/// Rationalize a radical denominator and return transformed `(num, den)`.
pub fn rad_rationalize(num : Expr, den : Expr) -> (Expr, Expr) {
  @symsimplify.rad_rationalize(num, den)
}

///|
/// Split surd terms into `(g, a, b)` for denesting-style transformations.
pub fn split_surds(expr : Expr) -> (Expr, Expr, Expr) {
  @symsimplify.split_surds(expr)
}

///|
/// Collect additive terms by powers of `sym`.
pub fn collect(expr : Expr, sym : Expr) -> Expr {
  @symsimplify.collect(expr, sym)
}

///|
/// Recursively collect terms by `sym` in nested expressions.
pub fn rcollect(expr : Expr, sym : Expr) -> Expr {
  @symsimplify.rcollect(expr, sym)
}

///|
/// Collect numeric constants in additive expressions.
pub fn collect_const(expr : Expr) -> Expr {
  @symsimplify.collect_const(expr)
}

///|
/// Collect terms containing square roots.
pub fn collect_sqrt(expr : Expr) -> Expr {
  @symsimplify.collect_sqrt(expr)
}

///|
/// Collect terms containing absolute values.
pub fn collect_abs(expr : Expr) -> Expr {
  @symsimplify.collect_abs(expr)
}

///|
/// Denest powers such as `(x**a)**b` when safe.
pub fn powdenest(expr : Expr) -> Expr {
  @symsimplify.powdenest(expr)
}

///|
/// Rewrite between exponential and trigonometric forms for simplification.
pub fn exptrigsimp(expr : Expr) -> Expr {
  @symsimplify.exptrigsimp(expr)
}

///|
/// Simplify Gamma-family function expressions.
pub fn gammasimp(expr : Expr) -> Expr {
  @symsimplify.gammasimp(expr)
}

///|
/// Combine sums/products of logs into compact log forms.
pub fn logcombine(expr : Expr) -> Expr {
  @symsimplify.logcombine(expr)
}

///|
/// Simplify Bessel-function expressions.
pub fn besselsimp(expr : Expr) -> Expr {
  @symsimplify.besselsimp(expr)
}

///|
/// Simplify Kronecker-delta expressions.
pub fn kroneckersimp(expr : Expr) -> Expr {
  @symsimplify.kroneckersimp(expr)
}

///|
/// Try to recognize a numeric expression as an exact symbolic form.
pub fn nsimplify(
  expr : Expr,
  constants? : Array[Expr] = [],
  full? : Bool = false,
  rational? : Bool = true,
) -> Expr {
  @symsimplify.nsimplify(expr, constants~, full~, rational~)
}

///|
/// Separate multiplicative factors by symbolic variables.
pub fn separatevars(expr : Expr, force? : Bool = false) -> Expr {
  @symsimplify.separatevars(expr, force~)
}

///|
/// Replace symbols with positivity-assumed dummies and return reverse map.
pub fn posify(expr : Expr) -> (Expr, Map[String, Expr]) {
  @symsimplify.posify(expr)
}

///|
/// Return the hypergeometric term ratio `f(k+1)/f(k)` when possible.
pub fn hypersimp(f : Expr, k : Expr) -> Expr {
  @symsimplify.hypersimp(f, k)
}

///|
/// Check whether two terms are hyper-similar in index `k`.
pub fn hypersimilar(f : Expr, g : Expr, k : Expr) -> Bool {
  @symsimplify.hypersimilar(f, g, k)
}

///|
/// Traverse an expression by an explicit edit path.
pub fn epath(path : String, expr : Expr) -> Array[Expr] {
  @symsimplify.epath(path, expr)
}

///|
/// Apply a transformation function at a path-selected subexpression.
pub fn epath_apply(path : String, expr : Expr, f : (Expr) -> Expr) -> Expr {
  @symsimplify.epath_apply(path, expr, f)
}

///|
/// Apply a transformation to nodes at a specific tree depth.
pub fn apply_at_level(
  expr : Expr,
  f : (Expr) -> Expr,
  level? : Int = 0,
) -> Expr {
  @symsimplify.apply_at_level(expr, f, level~)
}

///|
/// Run the full Fu trigonometric rewrite strategy.
pub fn fu(expr : Expr) -> Expr {
  @symsimplify.fu(expr)
}

///|
/// Run Fu trigonometric simplification without the full simplify pipeline.
pub fn futrig(expr : Expr) -> Expr {
  @symsimplify.futrig(expr)
}

///|
/// Apply Fu rule TR0.
pub fn tr0(expr : Expr) -> Expr {
  @symsimplify.tr0(expr)
}

///|
/// Apply Fu rule TR1.
pub fn tr1(expr : Expr) -> Expr {
  @symsimplify.tr1(expr)
}

///|
/// Apply Fu rule TR2.
pub fn tr2(expr : Expr) -> Expr {
  @symsimplify.tr2(expr)
}

///|
/// Apply inverse Fu rule TR2i.
pub fn tr2i(expr : Expr, half? : Bool = false) -> Expr {
  @symsimplify.tr2i(expr, half~)
}

///|
/// Apply Fu rule TR3.
pub fn tr3(expr : Expr) -> Expr {
  @symsimplify.tr3(expr)
}

///|
/// Apply Fu rule TR4.
pub fn tr4(expr : Expr) -> Expr {
  @symsimplify.tr4(expr)
}

///|
/// Apply Fu rule TR5.
pub fn tr5(expr : Expr, max? : Int = 4, pow? : Bool = false) -> Expr {
  @symsimplify.tr5(expr, max~, pow~)
}

///|
/// Apply Fu rule TR6.
pub fn tr6(expr : Expr, max? : Int = 4, pow? : Bool = false) -> Expr {
  @symsimplify.tr6(expr, max~, pow~)
}

///|
/// Apply Fu rule TR7.
pub fn tr7(expr : Expr) -> Expr {
  @symsimplify.tr7(expr)
}

///|
/// Apply Fu rule TR8.
pub fn tr8(expr : Expr) -> Expr {
  @symsimplify.tr8(expr)
}

///|
/// Apply Fu rule TR9.
pub fn tr9(expr : Expr) -> Expr {
  @symsimplify.tr9(expr)
}

///|
/// Apply Fu rule TR10.
pub fn tr10(expr : Expr) -> Expr {
  @symsimplify.tr10(expr)
}

///|
/// Apply inverse Fu rule TR10i.
pub fn tr10i(expr : Expr) -> Expr {
  @symsimplify.tr10i(expr)
}

///|
/// Apply Fu rule TR11.
pub fn tr11(expr : Expr) -> Expr {
  @symsimplify.tr11(expr)
}

///|
/// Apply Fu rule TR12.
pub fn tr12(expr : Expr) -> Expr {
  @symsimplify.tr12(expr)
}

///|
/// Apply inverse Fu rule TR12i.
pub fn tr12i(expr : Expr) -> Expr {
  @symsimplify.tr12i(expr)
}

///|
/// Apply Fu rule TR13.
pub fn tr13(expr : Expr) -> Expr {
  @symsimplify.tr13(expr)
}

///|
/// Apply Fu rule TR14.
pub fn tr14(expr : Expr) -> Expr {
  @symsimplify.tr14(expr)
}

///|
/// Apply Fu rule TR15.
pub fn tr15(expr : Expr, max? : Int = 4, pow? : Bool = false) -> Expr {
  @symsimplify.tr15(expr, max~, pow~)
}

///|
/// Apply Fu rule TR16.
pub fn tr16(expr : Expr, max? : Int = 4, pow? : Bool = false) -> Expr {
  @symsimplify.tr16(expr, max~, pow~)
}

///|
/// Apply Fu rule TR111.
pub fn tr111(expr : Expr) -> Expr {
  @symsimplify.tr111(expr)
}

///|
/// Apply Fu rule TR22.
pub fn tr22(expr : Expr, max? : Int = 4, pow? : Bool = false) -> Expr {
  @symsimplify.tr22(expr, max~, pow~)
}

///|
/// Apply Fu power-focused trigonometric rewrites.
pub fn trpower(expr : Expr) -> Expr {
  @symsimplify.trpower(expr)
}

///|
/// Apply Morrie-style Fu product-to-sum rewrites.
pub fn trmorrie(expr : Expr) -> Expr {
  @symsimplify.trmorrie(expr)
}
