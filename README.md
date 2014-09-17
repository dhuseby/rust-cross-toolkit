rust-cross-openbsd
====================

Cross-compiling Rust to OpenBSD.

This is a work in progress and is aimed at creating a rustc binary to run
natively on OpenBSD. The current status is that it can cross-compile rustc to
OpenBSD.

Read [this document][rust-cross] on how to cross-compile Rust to OpenBSD.

## Dependencies on Linux

Basic dependencies needed to build rust.

## Dependencies on OpenBSD

We need to build the following libraries on a OpenBSD system, as we can't
easily cross-compile them on a Linux system:

* libuv
* llvm (our patched version)
* rustllvm (easy to compile as we already build llvm on OpenBSD)

To build, we need:

* gmake
* cmake
* git
* perl
* libtool
* automake
* python
