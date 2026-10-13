# libelfin: abort on a zero-length DWARF string attribute

`libelfin`'s `value::as_string` copies a DWARF string without checking its length:

```cpp
// dwarf/value.cc
void value::as_string(string &buf) const
{
        size_t size;
        const char *p = as_cstr(&size);
        buf.resize(size);
        memmove(&buf.front(), p, size);      // front() on an empty string
}
```

`std::string::front()` on an empty string is undefined behaviour. With
`_GLIBCXX_ASSERTIONS` — the default in some distributions, opt-in elsewhere — it
aborts the process:

```
basic_string.h:1452: ... front() ... Assertion '!empty()' failed.
```

Its sibling `cursor::string` in `dwarf/cursor.cc` guards the identical call; that
guard arrived with
[PR #2](https://github.com/plasma-umass/libelfin/pull/2), and `value::as_string`
was missed.

## Reproduce

Needs only `git` and a C++ compiler — no distribution packages, no Arch, no pacman,
no `/usr/lib/coz-profiler`.

```shell
git clone https://github.com/iacore/libelfin-empty-string-repro
cd libelfin-empty-string-repro
./run.sh
```

`run.sh` clones libelfin, checks out the revision named by `LIBELFIN_REV`
(default `8d6cfef453613423a12a5f6d7b0d868bfb8763d6`, the unfixed `master`),
compiles `repro.cc` against libelfin's sources and runs it on the fixture.

Expected with the unfixed revision:

```
== ./repro fixture/empty-attr.o ==
.../bits/basic_string.h:1452: ... front() ... Assertion '!empty()' failed.
```

Exit status 134 (`SIGABRT`).

Then point it at the fix:

```shell
LIBELFIN_REV=34c0e390472850b1624ac7e58559c6346508f45d ./run.sh
```

Expected:

```
zero-length string attribute (tag DW_TAG_compile_unit)
walked 1 string attributes, 1 of them zero-length
```

Exit status 0.

## The input

`fixture/empty-attr.o` — assembled from `fixture/empty-attr.s`, both committed — is a
minimal ELF object holding one DWARF compilation unit with a single
`DW_TAG_compile_unit` DIE whose `DW_AT_name` is a `DW_FORM_string` of length 0. That
empty string is the entire input needed to reach the unguarded `memmove`.

`repro.cc` opens the object, walks every DIE of every compilation unit and calls
`value::as_string` on each attribute that is string-valued, skipping the ones that
throw `value_type_mismatch`.

## Notes

- `_GLIBCXX_ASSERTIONS` is what turns the undefined behaviour into a hard abort, so
  the build sets it explicitly rather than relying on the toolchain's default.
- No compiler to hand was found to emit a zero-length string attribute by itself
  (checked: gcc, g++, clang, rustc, zig), so the input is crafted. The bug is
  therefore latent, not observed in the wild.
- libelfin has no working build system in this tree — its root `CMakeLists.txt` is a
  stray `ExternalProject_Add` populate script pointing at `/Users/emery/...` — so
  `run.sh` compiles the needed sources directly.