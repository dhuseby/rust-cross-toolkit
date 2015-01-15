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

Before we can do anything else, you need to modify your user system and user
account to allow you to build rust from source.  First, you'll need to be added
to the `sudoers` file.  Log in as root and edit sudoers.

```sh
# visudo
```

I usually just duplicate the line for `root` and change the username to my
username.  After that is done, log out and log back in with your normal account.

If you didn't install the Bitrig toolchain when installing, do it now.

```sh
$ sudo pkg_add bitrig-syscomp
```

Next we will add you to the `wsrc` group so that you will have write access to
`/usr/src`, `/usr/ports`, and `/usr/xenocara` directories.

```sh
$ sudo usermod -G wsrc <username>
```

Now you can use git to clone the bitrig system, ports, and xenocara trees.

```sh
$ cd /usr
$ git clone https://github.com/bitrig/bitrig src
$ git clone https://github.com/bitrig/bitrig-ports ports
$ git clone https://github.com/bitrig/bitrig-xenocara xenocara
```

Now go ahead and clone this repo somewhere on your system.  I usually create
an `/opt` directory and give it full permissions for my user and group.

```sh
$ sudo mkdir /opt
$ sudo chown -R <username>.<username> /opt
$ cd /opt
$ git clone https://github.com/dhuseby/rust-cross-bitrig
```

Once you have the source repos cloned, you need to patch rthreads and ld.so.

```sh
$ cd /usr/src
$ patch -p1 < /opt/rust-cross-bitrig/patches/bitrig_usr_src.patch
```

After patching, you need to rebuild your kernel and reboot.

```sh
$ cd /usr/src/sys/arch/amd64/conf
$ config GENERIC
$ cd ../compile/GENERIC
$ make clean && make
$ sudo make install
$ sudo reboot
```

Now, rebuild the userland and reboot.

```sh
$ cd /usr/src
$ rm -f /usr/obj/*
$ make obj
$ cd /usr/src/etc
$ sudo env DESTDIR=/ make distrib-dirs
$ cd /usr/src
$ sudo make build
$ sudo make install
$ reboot
```

After rebooting, your Bitrig system will have support for LLVM's segmented
stacks. The next section will walk you through building stage1 on Bitrig

Stage 1 Prerequisites Bitrig
-----------------------------

Compiling rust from source requires only a few packages.

```sh
$ pkg_add cmake gmake bash python py-pip
```

Also set up the git-cachecow python module.

```sh
$ sudo pip install git-cachecow
```

The git cachecow python module adds some caching clone operations that the
scripts use to save on bandwidth and time.

Currently it is necessary to compile the bitrig-binutils-2.24 port.

```sh
$ cd /usr/ports/bitrig/bitrig-binutils-2.24
$ sudo make
$ sudo pkg_delete bitrig-binutils-0.9.2p2  # answer Y to deleting bitrig-syscomp package as well
$ sudo make install
```

Stage 1 Bitrig
---------------

To build stage 1 on bitrig, just run the `stage1.sh` script:

```sh
$ ./stage1.sh
```

The build script will take care of cloning all of the required code, applying
patches and building it. When the script is done, there will be a stage1.tgz
file that you need to copy to your Linux box.

TIP: I like to redirect all of the output from the stage scripts to a log file
so I can debug any issues more easily.  I do that by running the script like so:

```sh
$ ./stage1.sh > build.log 2>&1
```

That will redirect both stdout and stderr to the build.log for later analysis.

Stage 1 Linux
-------------

Start off by cloning this repo somewhere with a few gigabytes of disk space:

```sh
$ cd /tmp
$ git clone https://github.com/dhuseby/rust-cross-bitrig
```

Now kick off the `stage1.sh` script:

```sh
$ cd rust-cross-bitrig
$ ./stage1.sh
```

When that is done, everything should be ready to go to move to the second stage.

Stage 2 Linux
-------------

Stage 2 on Linux requires the output of Stage 1 on Bitrig and Stage 1 on Linux.
You should have copied the `stage1.tgz` file to the root folder of the this
repo on your Linux machine.  Unpack it now:

```sh
$ tar -zxvf stage1.tgz
```

Then kick off the `stage2.sh` script.  The second stage takes the parts from
Stage 1 on both machines and uses it to build the rust libraries and all of the
`.o` files needed to link a `rustc` executable on Bitrig.

When the script is done, it will have created a tarball named `stage2.tgz`.
Copy this tarball over to your Bitrig machine and then continue on to Stage 3.

Stage 3 Bitrig
---------------

Before you start Stage 3 you must unpack the `stage2.tgz` tarball from
earlier:

```sh
$ tar -zxvf stage2.tgz
```

Now kick off Stage 3 on Bitrig:

```sh
$ ./stage3.sh
```

The stage 3 script uses the pieces from Bitrig stage 1 as well as Linux stages
1 and 2 to link a `rustc` executable on Bitrig.  It then uses the `rustc` to
build a simple "Hello World!" application written in Rust.  If that works,
proceed to stage 4.

Stage 4 Bitrig
--------------

Stage 4 is the last stage of bootstrapping.  It uses the `rustc` executable
built in stage 3 as the "local rust" for building the entire Rust toolchain
from source.  Just run the `stage4.sh` script:

```sh
$ ./stage4.sh
```

If everything worked, you should be able to run `gmake install` as super-user
and it will install Rust on your Bitrig system.

That's it! Have fun.
