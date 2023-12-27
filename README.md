# Zero
Zero is a static site generator written in Zig. It is nowhere near completion yet :D

## Why
not.

## Build
- Clone this repo with `--recurse-submodules` to get the cmark dependency
- Run `make -C deps/cmark` to build libcmark.a, which Zero depends on
- Run `zig build` to build, or `zig build run` to build and run Zero

## TODO
- [x] Markdown rendering
- [ ] Figure out how to build cmark using build.zig (instead of building it manually)
- [ ] Populate TODO with actually important things
