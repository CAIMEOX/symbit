# Symbit Documentation Style

This repository treats documentation as part of the public API, not as a trailing comment after implementation work. The rules in this file are the baseline for package guides, public docstrings, and executable examples.

## Source of Truth

- Public API docstrings are the canonical source of truth for behavior.
- `README.mbt.md` files are package guides and navigation hubs.
- The test-only oracle layer under `src/` is excluded from user-facing documentation. It exists for regression checking only.

## Public API Docstrings

Every public export that is documented in-source should aim to answer the following questions:

1. What does this symbol do in Symbit?
2. When should a caller use it instead of a neighboring API?
3. What are the important inputs, return shapes, and failure modes?
4. What semantic limits or current constraints matter to a MoonBit user?

Use this structure whenever the symbol is important enough to justify more than a one-line note:

- One-line summary
- Behavior paragraph
- Input notes for non-obvious parameters
- Output shape or return semantics
- Error behavior when relevant
- At least one runnable `mbt check` example for high-traffic entry points

Do not write docstrings that only restate the type signature. Do not send users
back to upstream source code or treat the upstream project as the primary
documentation surface.

## Package README Expectations

Each public runtime package should have a `README.mbt.md` with:

- A short explanation of the package's role in the Symbit stack
- Guidance on when to import it directly
- A short list of representative public entry points
- At least one example block
- Links to adjacent packages or deeper specs when they exist

For package-level guides, prefer concrete Symbit terms and MoonBit calling
style. Explain behavior directly in terms of inputs, outputs, and effects.

## Executable Docs

When an example is meant to be part of the tested documentation surface, write it as `mbt check`.

When an example is illustrative but not stable enough to run, use `mbt nocheck` explicitly and explain why.

The goal is to make documentation drift visible under normal development tooling:

```sh
python3 tools/package_docs.py sync-readmes
python3 tools/package_docs.py check
moon test src
```

## Validation Policy

The checker in `tools/package_docs.py` validates:

- package README presence
- placeholder-free docs
- strict-package public docstring coverage

The strict-package list lives in `docs/docstring-strict-packages.txt`. Expand that list as package docstrings are upgraded.
