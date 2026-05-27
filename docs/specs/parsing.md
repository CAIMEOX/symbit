# Symbit Parsing — Current Design

This file describes the parser implemented in `src/symparse`. `symparse` is a
top-level runtime package with an oracle/parity package under
`src/sympy/parsing`.

## Current Scope

The implemented front door covers the Python-like expression syntax needed by
the current Symbit browser, tests, and package front doors:

- integer and decimal literals;
- identifiers and automatic symbol insertion;
- parentheses and tuples;
- unary `+` / `-`;
- binary `+`, `-`, `*`, `/`, `**`;
- optional `^` to power conversion;
- function calls and callable-name contexts;
- lambda notation;
- chained comparisons and optional single-`=` conversion;
- factorial and double-factorial notation;
- repeated-decimal and rationalization transformations;
- implicit multiplication / implicit application / function exponentiation,
  when explicitly enabled.

External formats such as LaTeX, Mathematica, Maxima, C, and Fortran are not part
of this front door.

## Package Layout

Runtime package: `src/symparse`

- `errors.mbt` — spans and `ParseError`.
- `token.mbt` — token kinds and token records.
- `lexer.mbt` — source text to token stream.
- `ast.mbt` — typed syntax tree, `ParseOptions`, `ParseContext`, and
  transformation descriptors.
- `parser_expr.mbt` — Pratt / precedence expression parser.
- `ast_parser.mbt` — AST front doors.
- `lower_expr.mbt` — AST to `symcore.Expr` lowering.
- `api.mbt` — public parse front doors.
- `builtin_callable_names.mbt` — built-in callable-name registry used by
  parsing and lowering.

Oracle package: `src/sympy/parsing`

- parity tests against `sympy.parsing.sympy_parser.parse_expr`;
- support helpers for normalizing SymPy and Symbit output.

## Public API

- `lex(src) -> Array[Token] raise ParseError`
- `parse_ast*` front doors for callers that need syntax before lowering
- `parse_expr(src) -> Expr raise ParseError`
- `parse_expr_with(src, options) -> Expr raise ParseError`
- `parse_expr_in(src, options, context) -> Expr raise ParseError`
- `parse_expr_with_transformations(...)`
- `parse_expr_in_with_transformations(...)`

`ParseOptions` controls evaluation and syntax transformations. `ParseContext`
controls local/global bindings and callable-name declarations.

## Architecture

The parser intentionally does not mimic SymPy's Python `eval`-style pipeline.
It uses:

- an explicit token ADT;
- a typed AST with source spans;
- transformation switches represented as `Transformation` variants;
- a typed lowering pass into `symcore.Expr`;
- explicit name-resolution context instead of dynamic Python locals.

This keeps parser behavior testable and makes unsupported syntax fail through
structured `ParseError` values with source spans.

## Current Limits

- The parser is an expression parser, not a full Python parser.
- External parser families are not implemented here.
- Some transformation switches are conservative and cover only the syntax that
  the current parser/lowerer can represent.
- `evaluate=false` preserves raw tree shape where possible, but it is not a
  complete clone of every SymPy construction edge case.

## Testing And Parity

Runtime tests cover lexer, AST parser, lowering, parse options, implicit syntax,
and regression cases. Oracle tests in `src/sympy/parsing` compare supported
front-door behavior with SymPy.
