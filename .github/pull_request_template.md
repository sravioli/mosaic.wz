## Summary

<!-- What changed in mosaic.wz and why. Link related issues: Fixes #123 -->

## Type

- [ ] Bug fix
- [ ] Feature
- [ ] Documentation
- [ ] Other (refactor, CI, chore)

## Details

<!--
Fill in what applies, delete the rest.
- Bug fix: smallest setup that reproduces it, and the root cause. Common areas:
  module resolution, width budgeting, fitting strategies, separators and styles, tab titles, refresh caching, integration loading.
- Feature: API sketch and behavior, including defaults and failure cases.
- Documentation: files and examples changed.
-->

## Compatibility

- [ ] Non-breaking
- [ ] Breaking (describe the migration path)

## Checklist

- [ ] Tests added or updated (bug fixes include a regression test), or not
      applicable.
- [ ] `.github/readme.md` and annotations updated for public API or default
      changes.
- [ ] Renderer changes were benchmarked with `chrono` before and after.
- [ ] Existing presets and module names still work.
- [ ] Checks pass: `busted`, `luacheck plugin spec`,
      `selene --display-style=quiet plugin`, `stylua --check plugin spec`.
