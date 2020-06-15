# Release notes

## Unreleased – Version 1.4

### Added

- Support for unloading of `ipy_scd.py` within IPython session.
- Exclusion of paths according to patterns in `~/.scdignore`.
- Implicit path matching also for all parents of indexed paths.
- Conversion to canonical case when indexing paths on Mac OS X.
- Option `-p,--push` to invoke `pushd` instead of `cd`.
- Command-line completion for `scd` in zsh.
- Special pattern `./` to match only under the current directory.
- Start-of-path matching with `^`, for example, `^/tmp`.
- Cleanup of obsolete aliases using `scd --unalias OLD`.
- Special pattern `:PAT` to match PAT over the tail component.

### Changed

- Make IPython extension compatible with Python 3.
- Upgrade to extensions API in IPython 5.
- Enable scd options that follow positional arguments.
- Always use smart case matching (with zsh `(#l)` globbing flag).
- Support multiple targets for `scd --unalias`.
- Prefer scd alias expansion when it also exists as a directory.
- Make `zshrc_scd` load functions from relative repository paths.
- Rename hook function to `chpwd_scd`.

### Removed

- Support for IPython 0.12 and older.
- Support for zsh 4.2 and older.

### Fixed

- Slow scd response when index is compressed and trimmed.
  Rewrite the index in background instead.
- Spurious undefinition of `scd` after repeated loading of `zshrc_scd`.
- Undesired extra output when `CDPATH` is set in the invoking shell.
- Recursive unindexing from the root directory to produce empty index.
- Slow response due to path-check latency on some network file systems.
  Remove deleted paths from the index.


## Version 1.3 – 2015-04-13

### Changed

- Support unaliasing of non-existing directories.
- Make `scd --unalias` work with target paths as well as aliases.
- Remove noglob modifier for the scd function.
- Ignore non-directory entries in `scd --add`.
- Remove non-existent paths when trimming the index.


## Version 1.2 – 2014-09-01

### Added

- Support end-of-path matching with `$`.
- Add option `-A,--all` to consider paths with low likelihood.

### Changed

- Compress index duplicates to an equivalent timestamp.
- Directory matching algorithm.  Require all patterns to match
  the full path and at least one pattern to match the tail component.
- Undefine private sub-functions when `scd` returns.
- Create `SCD_SCRIPT` under `/tmp/` when `~/bin` does not exist.
