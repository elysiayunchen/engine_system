# Progress — T-039
> Active task compression recovery anchor. See contract/src/20-file-templates.md FILE 13.

## §1 Goal
Fix checkpoint.md append-without-dedup bug in engine-verify.{sh,ps1}. Change from "append, don't overwrite" to "dedup: replace same AC-N line, append new AC-N". Clean up existing bloated files. v6.11.2 patch.

## §2 Current Step
AC-1: contract source change "追加写" → "dedup 写" in FILE 15.

## §3 Done
- [x] Task card T-039.md created (7 ACs, WRITE-SET defined)

## §4 Next AC
AC-1 contract source + compile.
