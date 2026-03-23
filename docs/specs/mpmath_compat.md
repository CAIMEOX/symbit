# `sympy.external.mpmath` Compatibility Surface

This file tracks the MoonBit-side compatibility layer built on top of
`CAIMEOX/moon_floating`, and how it maps to the subset of
`sympy.external.mpmath` that SymPy actually imports.

The implementation lives in `src/symnum/`. The goal is not to reproduce
Python's global-runtime behavior exactly; the goal is to provide an equivalent
numeric backend that Symbit can depend on while making MoonBit-specific API
choices explicit.

## Directly implemented

The following names now exist with close semantics:

- precision / formatting:
  - `dps_to_prec`, `prec_to_dps`, `repr_dps`
- low-level construction / conversion:
  - `from_int`, `from_man_exp`, `from_str`
  - `from_float`, `from_rational`
  - `to_float`, `to_int`, `to_rational`, `to_str`
  - `normalize` (`mpf_normalize` remains available too)
- raw constants:
  - `fzero`, `fone`, `fnone`, `fhalf`, `finf`, `fninf`, `fnan`
  - `inf`, `ninf`, `round_nearest`
- raw real ops:
  - `mpf_abs`, `mpf_add`, `mpf_sub`, `mpf_mul`, `mpf_div`, `mpf_mod`
  - `mpf_pow`, `mpf_pow_int`, `mpf_shift`
  - `mpf_floor`, `mpf_ceil`, `mpf_cmp`, `mpf_lt`, `mpf_le`, `mpf_gt`,
    `mpf_ge`, `mpf_neg`, `mpf_pi`, `mpf_e`, `mpf_exp`, `mpf_log`,
    `mpf_sin`, `mpf_cos`, `mpf_tan`, `mpf_sqrt`
  - `mpf_cosh_sinh`
- raw complex ops:
  - `make_mpc`, `mpc_abs`, `mpc_exp`, `mpc_pow`, `mpc_pow_int`,
    `mpc_pow_mpf`, `mpc_sqrt`
- context / interval:
  - `MPContext`, `mp`, `workprec`, `local_workprec`
  - `MPIntervalContext`, `mpi`, `mpi_from_str`
- integer helpers:
  - `MPZ`, `isqrt`, `sqrtrem`, `ifac`, `ifib`, `giant_steps`
- constants in fixed-point form:
  - `phi_fixed`, `catalan_fixed`, `euler_fixed`
- higher-level helpers used by SymPy-adjacent code:
  - `sqrt`, `fac`, `diff`, `findroot`, `quad`, `quadts`, `quadgl`,
    `summation`, `nsum`, `nprod`, `limit`, `polyroots`
- matrix constructor subset:
  - `_matrix`

## Implemented with MoonBit-specific adaptation

- `local_workprec`
  - SymPy/mpmath exposes a context manager.
  - Symbit exposes a higher-order function: `local_workprec(prec, f)`.
  - This keeps precision changes local without any global mutable runtime.

- `workprec`
  - In Python this temporarily mutates `mp`.
  - In Symbit it returns an explicit `MPContext`.

- `mpf`
  - Python exposes an overloaded numeric class/constructor.
  - Symbit exposes a minimal constructor subset: `mpf(string, prec?, rnd?)`.

- `mpc`
  - Python exposes a complex numeric class/constructor.
  - Symbit exposes `mpc(real, imag?)` from explicit `Mpf` parts.

- `ComplexResult`
  - Python exposes an exception class.
  - Symbit normalizes this to `MPError::ComplexResult(msg)`.
  - Convenience probe: `is_complex_result(err)`.

- `NoConvergence`
  - Python exposes an exception class hanging off `mp`.
  - Symbit normalizes this to `MPError::ConvergenceError(msg)`.
  - Convenience probe: `is_no_convergence(err)`.

- `MPZ_ONE`
  - Python exposes an uppercase constant.
  - MoonBit does not allow a `BigInt` uppercase constant binding in the same
    way, so Symbit exports `mpz_one`.

- `_matrix`
  - Python's `_matrix` is a class from `mpmath.matrices`.
  - Symbit currently provides the dense real constructor subset
    `_matrix(rows_data, prec?, rounding?) -> MpfMatrix`.

## Still missing

These names do not yet have a direct counterpart:

- `bernfrac`
  - Needs an exact Bernoulli-fraction algorithm, not just a floating
    approximation.

- `eulernum`
  - Needs exact Euler-number generation.

- `mpnumeric`
  - Python-specific numeric base class; no clean MoonBit analogue.

- `int_types`
  - Python tuple of runtime integer classes; not meaningful as-is in MoonBit.

## Practical guidance

- For new Symbit code, prefer the explicit MoonBit surface:
  - `MPContext` / `local_workprec`
  - `Mpf`, `Mpc`, `Mpi`
  - `from_*` / `to_*`
  - raw `mpf_*` / `mpc_*` helpers
- Use the compatibility names only where they help align future SymPy ports.
- `symcore.Float` is already wired to this layer, but `Expr::Float` is not
  introduced yet to avoid breaking exhaustive `Expr` matches across the repo.
