rust-cross-toolkit
====================

Toolkit for cross-compiling Rust to new platforms.

Stage 1 Target Prerequisites
----------------------------

Compiling Rust from source requires only a few packages:

* CMake
* GNU make
* Bash
* Python
* Python PIP

Python PIP is required to install the git-cachecow python module which greatly
speeds up the bootstrapping process by maintaining a local cache of remote
repositories and only pulling from origin if necessary.

```sh
$ sudo pip install git-cachecow
```

Stage 1 Target
--------------

To build stage 1 on the target, first clone this repo somewhere:

```sh
$ cd /tmp
$ git clone https://github.com/dhuseby/rust-cross-toolkit
```

Then, just run the `stage1.sh` script, specifying the target OS, the target
arch, and the toolchain:

```sh
$ cd rust-cross-toolkit
$ ./stage1.sh netbsd x86_64 gcc
```

Specifying the toolchain is necessary because some of the compiler and linker
flags are different between GCC and Clang.  Both compilers are supported, but
it is a good idea to use the same on both.  For instance, Bitrig only uses the
Clang compiler, so the Linux portions of this process use Clang installed on
Linux.

If you are cross-compiling to a target machine that has a different arch (e.g.
armv7), you will have to have the Linux toolchain that can build for that arch.
It is easiest to use the same arch on both machines, but sometimes that isn't
possible.

The build script will take care of cloning all of the required code, applying
patches and building it. When the script is done, there will be a stage1.tgz
file that you need to copy to your Linux box.

TIP: I like to redirect all of the output from the stage scripts to a log file
so I can debug any issues more easily.  I do that by running the script like so:

```sh
$ ./stage1.sh netbsd x86_64 gcc > build.log 2>&1
```

That will redirect both stdout and stderr to the build.log for later analysis.

Stage 1 Linux
-------------

Start off by cloning this repo somewhere with a few gigabytes of disk space:

```sh
$ cd /tmp
$ git clone https://github.com/dhuseby/rust-cross-toolkit
```

Now kick off the `stage1.sh` script:

```sh
$ cd rust-cross-toolkit
$ ./stage1.sh linux x86_64 gcc > build.log 2>&1
```

When that is done, everything should be ready to go to move to the second stage.

Stage 2 Linux
-------------

Stage 2 on Linux requires the output of Stage 1 on the target and Stage 1 on
Linux.  You should have copied the `stage1.tgz` file to the root folder of the
this repo on your Linux machine.  Unpack it now:

```sh
$ tar -zxvf stage1.tgz
```

Then kick off the `stage2.sh` script.  The second stage takes the parts from
Stage 1 on both machines and uses it to build the rust libraries and all of the
`.o` files needed to link a `rustc` executable on the target.

```sh
$ ./stage2.sh
```

When the script is done, it will have created a tarball named `stage2.tgz`.
Copy this tarball over to your target machine and then continue on to Stage 3.

Stage 3 Target
--------------

Before you start Stage 3 you must unpack the `stage2.tgz` tarball from
earlier:

```sh
$ tar -zxvf stage2.tgz
```

Now kick off Stage 3 on the target:

```sh
$ ./stage3.sh
```

The stage 3 script uses the pieces from target stage 1 as well as Linux stages
1 and 2 to link a `rustc` executable on the target.  It then uses the `rustc` to
build a simple "Hello World!" application written in Rust.  If that works,
proceed to stage 4.

Stage 4 Target
--------------

Stage 4 is the last stage of bootstrapping.  It uses the `rustc` executable
built in stage 3 as the "local rust" for building the entire Rust toolchain
from source.  Just run the `stage4.sh` script:

```sh
$ ./stage4.sh
```

If everything worked, you should be able to run `gmake install` as super-user
and it will install Rust on your target system.

That's it! Have fun.
