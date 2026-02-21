# UmVirt LFSAutoBuilder

LFS Version: 12.4

Supported editions:  SysV, Systemd

License: GPL

## About

Automated Linux From Scratch (LFS) base bootable image builder.

Live video demo: [https://www.youtube.com/watch?v=ZqP_4o_DjEA](https://www.youtube.com/watch?v=ZqP\_4o\_DjEA)

TMUX version video demo: [https://www.youtube.com/watch?v=XAwWgJEt_8A](https://www.youtube.com/watch?v=XAwWgJEt\_8A)

Source code: [https://gitlab.com/Umvirt/lfsautobuilder](https://gitlab.com/Umvirt/lfsautobuilder)

## Disclaimer

Data backup is needed before using this software.

This software is aimed to experienced Linux From Scratch maintainers.

**Runing this software by unexperienced users can lead to data loss & hardware damage!**

## Building environment

This software intended to run inside Virtual Machine (VM).

Virtual Machine acts as Build Environment (BE).

### Software

####  Operating system

Almost any modern x86_64 (amd64) GNU/Linux distribution is suitable. We prefere ULFS 0.2.3 (Linux From Scratch 12.3-systemd).

To check build system run:

    bash version-check.sh

You have to get:

        OK:    Coreutils 9.6    >= 8.1
        OK:    Bash      5.2.37 >= 3.2
        OK:    Binutils  2.44   >= 2.13.1
        OK:    Bison     3.8.2  >= 2.7
        OK:    Diffutils 3.11   >= 2.8.1
        OK:    Findutils 4.10.0 >= 4.2.31
        OK:    Gawk      5.3.1  >= 4.0.1
        OK:    GCC       14.2.0 >= 5.4
        OK:    GCC (C++) 14.2.0 >= 5.4
        OK:    Grep      3.11   >= 2.5.1a
        OK:    Gzip      1.13   >= 1.3.12
        OK:    M4        1.4.19 >= 1.4.10
        OK:    Make      4.4.1  >= 4.0
        OK:    Patch     2.7.6  >= 2.5.4
        OK:    Perl      5.40.1 >= 5.8.8
        OK:    Python    3.13.2 >= 3.4
        OK:    Sed       4.9    >= 4.1.5
        OK:    Tar       1.35   >= 1.22
        OK:    Texinfo   7.2    >= 5.0
        OK:    Xz        5.6.4  >= 5.0.0
        OK:    Linux Kernel 6.13.4 >= 5.4
        OK:    Linux Kernel supports UNIX 98 PTY
        Aliases:
        OK:    awk  is GNU
        OK:    yacc is Bison
        OK:    sh   is Bash
        Compiler check:
        OK:    g++ works
        OK: nproc reports 8 logical cores are available

#### Aditional software

In addition you also need followed software packages:

- **qemu** - to run virtual machine and to create disk images (block devices).
- **mutipath-tools** - to mount partitions on block devices.
- **tmux** - to run TMUX version of vmautobuild.
- **git** - to get Builder source code.
- **markdown** - to convert Builder documentation in HTML format.
- **neofetch** - to save Builder system information in logs.

### Hardware

**CPU:** x86_64 (amd64)

**SWAP:** none

**RAM:** 2GB per CPU's core 

**Warning:**  Use hypervisor to set CPU model. Model "qemu64" is most safe and allows to move disk between machines with different CPU models.

####Disks

VM should have two disks:

- System disk
- Target disk

##### System disk

System disk is disk which used to boot and run a build system.

LiveCD/DVD (/dev/sr0) or VirtIO(/dev/vda) drives can be used.

##### Target disk

Target disk is disk which used to build a LFS system. disk should be used.

20GB or more IDE or SATA drive (/dev/sdb) should be used.

Durinig a build proccess MBR partition table will be created.

Also one partition ext4 will be created and formated.

Later after build LFS system can be moved to 

- Live media (LiveCD/DVD/USB)
- Other disk and other partition
- Other machine to perform network boot

#### Resource allocation for VM

Because host consumes memory, Virtual Machine memory & CPUs are need to be reduced. 

For example, if you have 16GB of RAM, VM can have 12GB. 4GB should be reserved to host. 
Because one core consumes 2GB of RAM, maximum amount of cores is 6.

Lack of free host memory can cause Virtual Machine sudden poweroff. 
You can check kernel error messages with *dmesg* command 

#### Estemated time amount (ETA)

Automatic building LFS without tests on virtual machine (7 CPUs, 20GB RAM) on AMD FX8350 is takes about 180 minutes.

To speed up building you can use

- more powerful CPU
- more faster storage: SSD, RAM-disk

## Final result

After building you will get:

- LFS book based instructions
- Kernel with default configuration
- HDD support: SATA
- Timezone: UTC
- Root password: none

This is not the final product. It's a base for further configuration and customization.

## Preparation

### Downloading Builder

Use *Git* to download Builder:

    git clone https://gitlab.com/Umvirt/lfsautobuilder

After downloading via *Git* you have to make somedirectories:

    make dirs

### Downloading source code packages

Download *wget-list* & *md5sums* files from LFS site and put in "src/books" directory.

File *wget-list* is common for both editions (SysV and Systemd).

File *md5sums* is edition specific.

If you wish to build disk images for both editions merge md5sums for both editions:

    cat systemd.md5sums sysv.md5sums | uniq > md5sums

You can download sorce code packages manually or by runing downloader script *downloadsrc*:

    ./downoadsrc

In some cases problems with packages availability can take place.

In such case edit "config/downloaderconfig.sh" file.

### Placing already downloaded source code packages

It's possible to download packages on other place and put them to build environment.

Source code packages should be placed in "src/packages" directory.

### Source code packages integrity check

Run *checksrc* script to perform integrity check

    ./checksrc

You will get:

    ------------------------------------
     Linux From Scratch Integrity Check 
    ------------------------------------

    Downloading check

    Files wanted: 94 
    Files found: 94 
    Files not found: 0 
    
    Checksum check
    
    Files with checksums: 89 
    Files with wrong checksums: 0 

If some files not found then run downloader script again.

If some files have wrong checksums then delete this files and run downloader script again.

### Configuration

You can use "config/config.sh" file to set build options.

If file is not available copy config file template.

    cd config
    cp config.sh.sample config.sh

### Build environment init

Build directory should be created according to config file before runing build.

To init environment run:

    ./invinit

### Build

**Warning: Running autmatic build on physical computer cause data loss!**

In order of automatic build you have to run just one command:

    ./vmautobuild

You can place this command in time program to count build time:

    time ./vmautobuild

It's possible to use tmux version:

    ./vmautobuild-tmux

## Additional information

### Build Directory structure

- **books/** - files provided with LFS book.
    - wget-list - source packages & patches files list.
    - md5sums - md5-checksums for downloaded files integrity check.
- **builddir/** - LFS root partition mount point.
- **samples/** - configuration file samples.
- **cscripts/** - scripts to run by **root** user in chroot mode (Stage 2).
- **cscripts.config/** - config files for cscripts.
- **log/** - log files will be placed there.
- **scripts** - scripts to run by **lfs** user (Stage 1).
- **src/** - downloaded source code packages.
- **tmp/** - temporary directory.
    - dlist.txt - wanted source code & patches files. This file generated by *dlist.php* from URLs which stored in *books/wget-list* file. If you don't have php to generate this file, simply generate it on another machine and place it there.
- adduser - add *lfs* user to host.
- checksrc - check source code files and print report.
- chrootcmd - run command in target's chroot environment.
- chrootinit - init target's chroot environment.
- chrootmount - mount system filesystems on target's chroot environment.
- chrootshell - run shell in target's chroot environment.
- chrootumount - unmount system filesystems from target's chroot environment.
- copysrc - copy source code files to target.
- deletesrc - delete source code files from target.
- dlist.php - wget-list parser. needed to get wanted files by checksrc.
- downloadsrc - downloads source code files and put them in src folder. Log is stored in tmp/wget.log.
- env.sh - config file for some scripts.
- finish - finish operations. */tmp* cleanup & free space zeroing.
- initdirs - create dirs in target.
- logenv - script for saving in logs information about system, Builder configuration and files integrity.
- runchrootscripts - run all chroot scripts one by one (Stage 2).
- runscripts - run lfs scripts one by one (Stage 1).
- runscriptsbyroot - run *runscripts* script as root.
- showconfig - show contets of all config files.
- tmux-cscripts - run cscripts with tmux (experimental).
- userenv.sh - config file for lfs user.
- version-check.sh - check package versions.
- vmautobuild - one click target building **(DANGEROUS*)**
- vmautobuild-tmux - TMUX version of *vmautobuild*
- vmautoinfo - this script prints useful information about auto building.
- vmautomonitor - script that call *vmautoinfo* script in loop after delay.
- vmcmds.txt - one click target building scenario.
- vmfinish - like finish but with root password deletion and grub bootloader installation.
- vmstart - formats /dev/sdb1 partition WITHOUT PROMPT and mout it on mount point **(DANGEROUS*)** 

**(DANGEROUS)** - running this script cause /dev/sdb1 formatting therefore don't run this script on physical computer.

Scripts with "vm" prefix is intended to run only in virtual machine. Be careful!

## Log files

Log files are placed in log directory in building time.

If you have an error, you can inspect log files for details or compare them with same files on succesful builds logs.

Lists of installed files are also stored there you can find which script is install a specific file.

In log directory you can found followed files:

- aa.bb-cc.* - log files from script placed on "aa.bb" chapter of LFS book with name "cc"
    - aa.bb-cc.start - Unix-timestamp of moment before running a script.
    - aa.bb-cc.end - Unix-timestamp of moment after running a script.
    - aa.bb-cc.files - List of files installed by a script.
    - aa.bb-cc.log - Stdout dump of a script. In most cases this file contain are build messages.
- \_%scriptname%.* - log files for scripts runned in automatic mode.
    - \_%scriptname%.start - Unix-timestamp of moment before running a script.
    - \_%scriptname%.end - Unix-timestamp of moment after running a script.
- current_autoscript - current top-level script runned in automatic mode.
- current_script - current script called on both stages.
- last_script.files - count of files installed by previous script. If this file is contain "0", this means that error has occurred and further installation should be interrupted.
- autobuild.start - Unix-timestamp of moment before running an automatic build script.
- autobuild.end - Unix-timestamp of moment after running an automatic build script.

## Documentation

Builder documentation is stored in Markdown format.

To convert documentation from Markdown to HTML format type:

    make doc

After conversion HTML files should appear in root directory of Builder.
