# Running a command (Dockerfile RUN equivalent)

Shows how to update a base Ubuntu image using `container_run_and_save` rule.


## Before command (packages available)
```
$ bazel run //examples/run_commands:example_ubuntu_base_tarball
INFO: Analyzed target //examples/run_commands:example_ubuntu_base_tarball (0 packages loaded, 0 targets configured).
INFO: Found 1 target...
Target //examples/run_commands:example_ubuntu_base_tarball up-to-date:
  bazel-bin/examples/run_commands/example_ubuntu_base_tarball/tarball.tar
INFO: Elapsed time: 0.211s, Critical Path: 0.02s
INFO: 4 processes: 4 internal.
INFO: Build completed successfully, 4 total actions
INFO: Running command line: bazel-bin/examples/run_commands/example_ubuntu_base_tarball.sh
Loaded image: example-ubuntu-base:latest
```

```
ubuntu@ip-10-4-33-28:/grail/src/teams/beng/docker-images/allimages$ docker run --rm -it example-ubuntu-base:latest bash
root@0b0c7d39bed5:/# apt update; apt upgrade
Get:1 http://archive.ubuntu.com/ubuntu jammy InRelease [270 kB]
[...]
Get:18 http://security.ubuntu.com/ubuntu jammy-security/multiverse amd64 Packages [44.7 kB]
Fetched 31.4 MB in 4s (6970 kB/s)
Reading package lists... Done
Building dependency tree... Done
Reading state information... Done
42 packages can be upgraded. Run 'apt list --upgradable' to see them.
Reading package lists... Done
Building dependency tree... Done
Reading state information... Done
Calculating upgrade... Done
The following packages will be upgraded:
  apt base-files bash bsdutils coreutils dpkg gcc-12-base libapt-pkg6.0 libblkid1 libc-bin libc6 libcap2 libgcc-s1 libgnutls30 libgssapi-krb5-2 libk5crypto3 libkrb5-3
  libkrb5support0 libmount1 libncurses6 libncursesw6 libpam-modules libpam-modules-bin libpam-runtime libpam0g libprocps8 libsmartcols1 libssl3 libstdc++6 libsystemd0 libtinfo6
  libudev1 libuuid1 login mount ncurses-base ncurses-bin passwd perl-base procps tar util-linux
42 upgraded, 0 newly installed, 0 to remove and 0 not upgraded.
Need to get 20.4 MB of archives.
After this operation, 33.8 kB of additional disk space will be used.
Do you want to continue? [Y/n] 
```

## After command (no packages available)
```
$ bazel run //examples/run_commands:tarball
INFO: Analyzed target //examples/run_commands:tarball (0 packages loaded, 0 targets configured).
INFO: Found 1 target...
Target //examples/run_commands:tarball up-to-date:
  bazel-bin/examples/run_commands/tarball/tarball.tar
INFO: Elapsed time: 0.210s, Critical Path: 0.01s
INFO: 1 process: 1 internal.
INFO: Build completed successfully, 1 total action
INFO: Running command line: bazel-bin/examples/run_commands/tarball.sh
Loaded image: updated-ubuntu-base:latest
```

```
$ docker run --rm -it  updated-debian-base:latest bash 
root@196d67f6c4f4:/# apt update; apt upgrade
Hit:1 http://security.ubuntu.com/ubuntu jammy-security InRelease
Hit:2 http://archive.ubuntu.com/ubuntu jammy InRelease
Hit:3 http://archive.ubuntu.com/ubuntu jammy-updates InRelease
Hit:4 http://archive.ubuntu.com/ubuntu jammy-backports InRelease
Reading package lists... Done
Building dependency tree... Done
Reading state information... Done
All packages are up to date.
Reading package lists... Done
Building dependency tree... Done
Reading state information... Done
Calculating upgrade... Done
0 upgraded, 0 newly installed, 0 to remove and 0 not upgraded.
```