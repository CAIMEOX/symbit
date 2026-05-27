# Symbit

Symbit is a MoonBit symbolic mathematics library with a broad symbolic algebra surface. The project is not a thin wrapper over Python: the runtime implementation lives in MoonBit packages under `src/sym*`, while a separate oracle-test tree is reserved for behavior checks and never participates in runtime semantics. In practice this means Symbit is meant to be linked into MoonBit programs as a native symbolic engine: expressions, simplifiers, polynomial domains, statistics, physics, geometry, logic, combinatorics, and related algebraic subsystems are all represented as MoonBit values and manipulated locally.

The module-level root package, `CAIMEOX/symbit`, is intentionally small and stable. It exposes the core expression type together with a practical facade for expression construction, printing, simplification, rational-function utilities, common-subexpression elimination, and the full Fu trigonometric rewrite family. The deeper mathematical subsystems live in dedicated packages such as `sympolys`, `symstats`, `symphysics`, `symgeometry`, `symlogic`, and `symtensor`. A useful way to read the project is: the root package is the ergonomic entry point for general symbolic rewriting, and the specialized packages are where domain-heavy algorithms and larger APIs live.

The examples in this README are executable `mbt check` blocks. They are kept intentionally concrete: if the public facade changes, the README should fail under `moon test` rather than silently drifting out of sync with the code. From another MoonBit package you would import `CAIMEOX/symbit` in `moon.pkg` and call the same exported functions shown below.

## QuickStart

The fastest way to start is to build expressions with `symbol`, `integer`, `rational`, `add`, `mul`, and `pow`, then render them with `pretty_string` or `debug_inspect`. This keeps the entry path explicit and avoids hiding tree structure behind parser magic. In real use you usually construct a symbolic expression, inspect it in debug or readable form, then apply one of the simplifiers depending on whether you want a general rewrite, a rational-function normalization, or a more specialized transformation.

```mbt check
///|
test "quickstart expression construction and simplification" {
  let x = Expr::Symbol("x")
  let y = Expr::Symbol("y")

  let expr = add([integer(1), mul([x, pow(y, integer(2))])])
  debug_inspect(expr, content="(+ (* sym:x (^ sym:y 2)) 1)")
  inspect(pretty_string(expr), content="x*y**2 + 1")

  let cancelled = simplify(
    mul([add([x, integer(1)]), pow(add([x, integer(1)]), integer(-1))]),
  )
  inspect(pretty_string(cancelled), content="1")
}
```

Exact rationals are first-class. The root package deliberately exposes `rational(num, den)` rather than forcing every caller to construct rationals through lower-level numeric packages. This makes it straightforward to write exact algebraic examples without losing track of the fact that the result is symbolic rather than floating-point.

```mbt check
///|
test "quickstart exact rationals remain symbolic" {
  let third = try! rational(1, 3)
  let expr = add([third, third, third])
  inspect(pretty_string(expr), content="1")
}
```

## Simplification Workflow

Symbit separates general simplification from targeted simplification. `simplify` runs the broad rewrite pipeline. `trigsimp`, `ratsimp`, `radsimp`, `sqrtdenest`, `powdenest`, and related helpers each target one mathematical regime and are often a better engineering choice when you know the shape of the input in advance. This mirrors how symbolic code tends to be maintained in larger systems: broad passes are convenient for interactive work, while explicit targeted passes are easier to reason about in library code and tests.

```mbt check
///|
test "targeted simplification keeps intent explicit" {
  let x = Expr::Symbol("x")
  let sin_x = @symcore.function("sin", [x])
  let cos_x = @symcore.function("cos", [x])
  let trig = add([pow(sin_x, integer(2)), pow(cos_x, integer(2))])
  inspect(pretty_string(trigsimp(trig)), content="1")

  let frac_expr = mul([
    add([x, integer(1)]),
    pow(Expr::Symbol("y"), integer(-1)),
  ])
  let (num, den) = fraction(frac_expr)
  inspect(pretty_string(num), content="x + 1")
  inspect(pretty_string(den), content="y")
}
```

The project also exposes the lower-level pieces that are useful when you need to preserve or inspect structure instead of asking for a full simplification pass. `fraction`, `numer`, `denom`, `collect`, `collect_const`, `collect_sqrt`, `collect_abs`, `epath`, and `epath_apply` all exist for that reason. They let downstream packages and end-user code write deterministic transformations without depending on the entire global simplifier.

## Common-Subexpression Elimination

`cse` is the root-package entry point for common-subexpression elimination. The returned `CseResult` keeps both the extracted substitutions and the reduced expressions, and `cse_reconstruct` lets you rebuild the originals. This matters when you want optimization without losing a simple verification path: tests can assert on the extracted substitution count while still proving that reconstruction recovers the initial expressions exactly.

```mbt check
///|
test "cse extracts and reconstructs shared structure" {
  let x = Expr::Symbol("x")
  let shared = @symcore.function("sin", [x])
  let exprs = [mul([shared, shared]), add([shared, shared])]

  let result = cse(exprs)
  inspect(result.replacement_count(), content="1")

  let replacements = result.replacements_copy()
  let (tmp, rhs) = replacements[0]
  inspect(tmp, content="x0")
  inspect(pretty_string(rhs), content="sin(x)")

  let rebuilt = cse_reconstruct(result)
  assert_true(pretty_string(rebuilt[0]) == pretty_string(exprs[0]))
  assert_true(pretty_string(rebuilt[1]) == pretty_string(exprs[1]))
}
```

## Trigonometric Rewrites and Fu Rules

For code that wants precise control over trigonometric normalization, the root package exposes the Fu rewrite family directly. This is useful when a full `trigsimp` pass is too aggressive or when a test wants to pin one named rewrite rule. The public surface includes `fu`, `futrig`, and the individual `TR0`-style helpers such as `tr0`, `tr2`, `tr10`, `tr111`, `tr22`, `trpower`, and `trmorrie`. In other words, the root package is not only a convenience layer; it also exposes the rewrite toolkit needed to script deterministic transformations.

```mbt check
///|
test "fu-style helpers are available from the root package" {
  let x = Expr::Symbol("x")
  let sin_x = @symcore.function("sin", [x])
  let cos_x = @symcore.function("cos", [x])
  let tan_x = @symcore.function("tan", [x])

  inspect(
    to_repr(tr2(tan_x)).to_string(),
    content="(* (^ (call cos sym:x) -1) (call sin sym:x))",
  )
  inspect(
    pretty_string(tr2i(mul([sin_x, pow(cos_x, integer(-1))]))),
    content="tan(x)",
  )
}
```

## Package Guide

The project is organized as a set of focused packages rather than a single monolith. `symcore` provides the fundamental expression representation and low-level symbolic constructors. `symsimplify` provides the rewrite engine, algebraic simplifiers, rational simplifiers, denesting, common-subexpression elimination, and the Fu trigonometric rule family; the root package is primarily a curated facade over this layer. `symnum` provides exact rational arithmetic and related numeric helpers used throughout the rest of the module.

`sympolys` contains the polynomial stack: dense and sparse polynomial operations, domains, domain matrices, number-field compatibility layers, and AGCA- or series-adjacent helpers. `symstats` covers random variables, distributions, stochastic processes, matrix ensembles, and symbolic probability queries. `symphysics` is a large family of packages including quantum mechanics, vector calculus, mechanics, control, optics, and continuum mechanics. `symgeometry` covers points, linear entities, conics, polygons, curves, convex hulls, and related geometry algorithms. `symlogic`, `symsets`, `symtensor`, `symseries`, `symcombinatorics`, `symntheory`, `symcalculus`, `symconcrete`, `symliealgebras`, `symfunctions`, `symassume`, `symholonomic`, `symalgebras`, `symdiscrete`, and `symstrategies` fill out the rest of the symbolic stack.

The project also ships a test-only oracle layer under `src/`. Those packages call Python to compare behavior, normalize output, or validate algorithms during regression testing. They are intentionally isolated from runtime implementation code. If you are extending Symbit itself, that separation is not optional: new functionality belongs in `src/sym*`, and oracle calls belong only in the test-only oracle layer.

## Package Manuals

The root package is intentionally small. The deeper runtime manuals now live with the packages themselves as `README.mbt.md`, so you do not need to reverse-engineer behavior from the source tree. The most important entry points are:

- [`src/symcore/README.mbt.md`](src/symcore/README.mbt.md) for expression construction and low-level symbolic structure
- [`src/symsimplify/README.mbt.md`](src/symsimplify/README.mbt.md) for simplification workflows and targeted rewrites
- [`src/symsolvers/README.mbt.md`](src/symsolvers/README.mbt.md) for equation solving, `solveset`, ODE/PDE front doors, and LP helpers
- [`src/sympolys/README.mbt.md`](src/sympolys/README.mbt.md) for domains, polynomial representations, and polynomial algorithms
- [`src/symmatrices/README.mbt.md`](src/symmatrices/README.mbt.md) for dense/sparse matrices and symbolic linear algebra
- [`src/symsets/README.mbt.md`](src/symsets/README.mbt.md) for symbolic sets and set operations
- [`src/symprint/README.mbt.md`](src/symprint/README.mbt.md) for plain-text and LaTeX output
- [`src/symvector/README.mbt.md`](src/symvector/README.mbt.md) and [`src/symphysics/README.mbt.md`](src/symphysics/README.mbt.md) for geometry-adjacent and physics-heavy workflows

For contributors, package manuals are synchronized and checked by `tools/package_docs.py`. That tool enforces package-guide presence, checks for banned placeholder phrasing, and can be used to keep generated package READMEs aligned with the current public package layout.

## Choosing the Right Entry Point

Use the root package when you need a stable, compact API for building expressions and applying simplification passes. Import a specialized package directly when your code depends on deeper semantics such as polynomial domains, statistics, geometry, or physics subsystems. This split is deliberate. It keeps the default API small enough to be teachable while still allowing the module as a whole to grow into a broad symbolic mathematics toolkit.

That distinction matters for maintenance as well. The root package should stay easy to read and hard to misuse. Specialized packages can be larger and more domain-specific. The README is therefore written around the root package first, then points outward to the rest of the module. If you are evaluating the project as a library consumer, start here. If you are looking for a specific mathematical subsystem, read the corresponding package directly under `src/`.
