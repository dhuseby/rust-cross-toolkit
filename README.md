rust-cross-bitrig
====================

Cross-compiling Rust to Bitrig (currently only amd64).

Getting Rust to work on Bitrig is currently a work in progress and is not easy
to do.  It requires that you track Bitrig -current and to patch and
build your own Bitrig kernel and userland.  If you don't know what that is,
this is either a great opportunity for you to learn, or maybe you should wait
until this process gets easier (i.e. the Bitrig rthread patch lands).

Bitrig Prerequisites
---------------------

To start, you need to download and install a
[Bitrig snapshot](http://mirror2.us.bitrig.org/pub/bitrig/snapshots/amd64/current/).
Then you need to use git to clone the bitrig source tree and bitrig ports tree
locally before patching rthreads.

```sh
$ cd /usr/src
$ patch -p1 < patch-bitrig-rthread
```

After patching, you need to rebuild your kernel and userland and reboot.  After
that, your Bitrig system will have support for LLVM's segmented stacks. The 
next section will walk you through building stage1 on Bitrig

Stage 1 Prerequisites Bitrig
-----------------------------

Bitrig comes with most of the prerequisites already installed.  If you didn't
install the toolchain during installation you need to do that now.

```sh
$ pkg_add bitrig-syscomp
```

Stage 1 Bitrig
---------------

The build process requires full clones of the Rust and LLVM code trees so make
sure you do this on a partition with enough room.  I think 3 GByte is probably
sufficient.  Now clone this repo locally:

```sh
$ cd /tmp
$ git clone https://github.com/dhuseby/rust-cross-bitrig
```

The `stage1-bitrig.sh` script will install some of the intermediate binaries 
in your `/usr/local` so you need to run this with enough privileges to install 
there.  Now, let's build stage 1:

```sh
$ cd rust-cross-bitrig
$ sudo ./stage1-bitrig.sh
```

The build script will take care of cloning all of the required code and
building it. When the script is done, there will be a stage1-openbsd.tgz file 
that you need to copy to your Linux box and unpack it in the root folder of 
this repo there.

Stage 1 Linux
-------------

Start off by cloning this repo somewhere with a few gigabytes of disk space:

```sh
$ cd /tmp
$ git clone https://github.com/dhuseby/rust-cross-bitrig
$ cd rust-cross-bitrig
```

Now kick off the `stage1-linux.sh` script:

```sh
$ ./stage1-linux.sh
```

When that is done, everything should be ready to go to move to the second stage.

Stage 2 Linux
-------------

Stage 2 on Linux requires the output of Stage 1 on Bitrig and Stage 1 on Linux.  
You should have copied the `stage1-bitrig.tgz` file to the root folder of the 
clone of this repo on your Linux machine.  Unpack it now:

```sh
$ tar -zxvf stage1-bitrig.tgz
```

Then kick off the `stage2-linux.sh` script.  The second stage takes the parts
from Stage 1 on both machines and uses it to build the rust libraries and all
of the `.o` files needed to link a `rustc` executable on Bitrig.

When the script is done, it will have created a tarball named `stage2-linux.tgz`.
Copy this tarball over to your Bitrig machine and then continue on to Stage 3.

Stage 3 Bitrig
---------------

Before you start Stage 3 you must unpack the `stage2-linux.tgz` tarball from
earlier:

```sh
$ tar -zxvf stage2-linux.tgz
```

Now kick off Stage 3 on Bitrig:

```sh
$ ./stage3-bitrig.sh
```


