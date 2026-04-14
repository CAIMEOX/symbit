# Symbit Documentation Style

This repository treats documentation as part of the public API. The default format is the MoonBit block comment style built on `///|`.

## Source of Truth

- Public source docstrings are the canonical description of runtime behavior.
- `README.mbt.md` files are package guides only.
- The test-only oracle layer under `src/sympy` is excluded from user-facing documentation.

## Comment Kinds

### 1. File header comments

Use a short `///|` block at the top of a file when the file owns one clear topic.

Template:

```mbt
///|
/// <What this file is for.>
///
/// Current Limits:
/// - <important current limit>
/// - <important current limit>
```

### 2. Public API docstrings

Use this format for important `pub fn`, `pub struct`, `pub enum`, and public methods:

```mbt
///|
/// <One-line summary.>
///
/// - Does: <what it does>
/// - Input: <what callers pass in>
/// - Returns: <what comes back>
/// - Limits: <front-door limits or error behavior>
///
/// ```mbt check
/// ///|
/// test "<example name>" {
///   ...
/// }
/// ```
```

Rules:

- Keep the summary short.
- Answer only `Does`, `Input`, `Returns`, and `Limits`.
- Add an executable `mbt check` example only for high-traffic entry points.
- Do not restate the type signature in prose.

### 3. Internal helper docstrings

Only document internal helpers when the behavior is non-obvious.

Template:

```mbt
///|
/// <Local responsibility of the helper.>
/// Preconditions:
/// - <required assumption>
/// Postconditions:
/// - <guarantee>
```

### 4. Inline `//` comments

Use inline comments only for:

- algorithmic rationale
- invariants or preconditions
- compatibility/parity constraints

Avoid comments like:

- `// sort`
- `// fast path`
- `// handle x`

If a comment does not explain *why*, delete it or rewrite it as a full sentence.

## User-facing writing rules

- Examples must be executable `mbt check` blocks.
- User docs must not tell the reader to consult upstream code.
- User docs should explain behavior in Symbit terms only.
- For incomplete public APIs, add `Current Limits` in the surrounding file or type docstring.
- Do not write implementation details unless the file is a contributor-facing guide.

## Validation

Run the normal doc validation loop:

```sh
python3 tools/package_docs.py check
moon check src/<package>
moon info src/<package>
```

If a source docstring contains an executable `test` block, also run:

```sh
moon test src/<package> -v
```

The strict-package list lives in `docs/docstring-strict-packages.txt`.
