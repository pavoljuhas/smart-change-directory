# Release notes

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
