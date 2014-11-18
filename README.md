rust-cross-openbsd
====================

Cross-compiling Rust to OpenBSD (currently only i386/amd64).

Getting Rust to work on OpenBSD is currently a work in progress and is not easy
to do.  Currently, it requires that you track OpenBSD -current and to patch and
build your own OpenBSD kernel and userland.  If you don't know what that is,
this is either a great opportunity for you to learn, or maybe you should wait
until this process gets easier (i.e. the OpenBSD rthread patch lands).

OpenBSD Prerequisites
---------------------

To start, you need to download and install an 
[OpenBSD snapshot](ftp://ftp.openbsd.org/pub/OpenBSD/snapshots/).  Then you
need to follow [the instructions](http://www.openbsd.org/faq/faq5.html#Bld) on 
how to check out -current and build it. After you have rebooted into -current, 
the next step is to patch librthreads and then rebuild your kernel and userland.

```sh
cd /usr/src
patch -p1 < patch-librthread
```

After patching, you need to rebuild your kernel and userland and reboot.  After
that, your OpenBSD -current system will have support for LLVM's segmented stacks.
The next section will walk you through building stage1 on OpenBSD.

Stage 1 Prerequisites OpenBSD
-----------------------------

Before you can build stage 1 on OpenBSD, you must compile and install a bunch of
ports from source.  Here is the list of ports:

* gcc-4.8.3
* python-2.7.8
* automake-1.14
* audoconf-2.69
* libtool
* gmake
* cmake
* perl
* git

When building gcc-4.8.3, make sure you do it like this:

```sh
cd /usr/ports/lang/gcc/4.8/
env FLAVOR="full" make
env FLAVOR="full" make install
env SUBPACKAGE="-c++" make install
```

This is necessary to make sure that both the C and C++ compilers are built and
installed.  Now you're ready to clone this repo and build stage 1.

Stage 1 OpenBSD
---------------

The build process requires full clones of the Rust and LLVM code trees so make
sure you do this on a partition with enough room.  I think 3 GByte is probably
sufficient.  Now clone this repo locally:

```sh
cd /tmp
git clone https://github.com/dhuseby/rust-cross-openbsd
```

The `stage1-openbsd.sh` script will install some of the intermediate binaries 
in your `/usr/local` so you need to run this with enough privileges to install 
there.  Also make sure that your `PATH` environment variable lists 
`/usr/local/bin` *before* anything else.  Now, let's build stage 1:

```sh
cd rust-cross-openbsd
sudo ./stage1-openbsd.sh
```

The build script will take care of cloning all of the required code and patching
things properly.  The first thing it does is pull down a newer version of GNU
binutils and build it.  If you watch the output carefully, you'll notice that the
binutils fails during the install pass.  It's because I think newer versions of
binutils use GPLv3 and is incompatible with the licensing requirements for
OpenBSD and is therefor not maintained to support OpenBSD.  The `ld` binary
doesn't support OpenBSD, but that's OK, because all we need from binutils is a
newer assember (e.g. `as`) that understands all of the pseudo-ops in the 
assembly files found in the Rust tree.

When the script is done, there will be a stage1-openbsd.tgz file that you need
to copy to your Linux box and unpack it in the root folder of this repo there.

Stage 1 Linux
-------------

Start off by cloning this repo somewhere with a few gigabytes of disk space:

```sh
cd /tmp
git clone https://github.com/dhuseby/rust-cross-openbsd
cd rust-cross-openbsd
```

Now kick off the `stage1-linux.sh` script:

```sh
./stage1-linux.sh
```

When that is done, everything should be ready to go to move to the second stage.

*NOTE*: This is as far as I've been able to get so far.  I'm debugging Stage 2
on Linux right now.

Stage 2 Linux
-------------

Stage 2 on Linux requires the output of Stage 1 on OpenBSD.  You should have copied
the `stage1-openbsd.tgz` file to the root folder of the clone of this repo on your
Linux machine.  Unpack it now:

```sh
tar -zxvf stage1-openbsd.tgz
```

Then kick off the `stage2-linux.sh` script.

