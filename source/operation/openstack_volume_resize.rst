OpenStack Volume Resize
========================

This is a document about resizing openstack volumes.

1. Resize the attached-but-not-mounted disk
--------------------------------------------

The first test is resizing the attched-but-not-mounted disk.

Here is a volume `test_vol` attached to the VM.::

    root@btx-0:/# o volume list
    +--------------------------------------+----------+--------+------+-------------------------------+
    | ID                                   | Name     | Status | Size | Attached to                   |
    +--------------------------------------+----------+--------+------+-------------------------------+
    | afecb155-dd07-45f4-abca-d6c654b73b29 | test_vol | in-use |    5 | Attached to test on /dev/vdb  |
    +--------------------------------------+----------+--------+------+-------------------------------+

List the block devices in the VM.::

    $ lsblk
    NAME    MAJ:MIN RM  SIZE RO TYPE MOUNTPOINT
    vda     252:0    0    1G  0 disk
    |-vda1  252:1    0 1015M  0 part /
    `-vda15 252:15   0    8M  0 part
    vdb     252:16   0    5G  0 disk
    |-vdb1  252:17   0  103M  0 part
    `-vdb15 252:31   0    8M  0 part

The `test_vol` is mapped to `vdb` and is not mounted.

Resize the volume to 10GiB.::

    root@btx-0:/# o volume set --size 10 test_vol

Check the volume size in openstack.::

    root@btx-0:/# o volume list
    +--------------------------------------+----------+--------+------+-------------------------------+
    | ID                                   | Name     | Status | Size | Attached to                   |
    +--------------------------------------+----------+--------+------+-------------------------------+
    | afecb155-dd07-45f4-abca-d6c654b73b29 | test_vol | in-use |   10 | Attached to test on /dev/vdb  |
    +--------------------------------------+----------+--------+------+-------------------------------+

Check the volume inside the VM.::

    $ lsblk
    NAME    MAJ:MIN RM  SIZE RO TYPE MOUNTPOINT
    vda     252:0    0    1G  0 disk
    |-vda1  252:1    0 1015M  0 part /
    `-vda15 252:15   0    8M  0 part
    vdb     252:16   0   10G  0 disk
    |-vdb1  252:17   0  103M  0 part
    `-vdb15 252:31   0    8M  0 part

Yes, `vdb` is resized to 10GiB.

The dmesg log also shows it is resized.::

    [1215561.272261] virtio_blk virtio5: [vdb] new size: 20971520 512-byte logical blocks (10.7 GB/10.0 GiB)
    [1215561.289134] vdb: detected capacity change from 0 to 10737418240

* Conclusion: Attached-but-not-mounted volume can be resized!

2. Resize the attached-and-mounted disk
----------------------------------------

The second test is resizing the attched-and-mounted disk.

Delete /dev/vdb1 and /dev/vdb15 partitions and format /dev/vdb.::

    # mkfs.ext4 /dev/vdb
    mke2fs 1.44.5 (15-Dec-2018)
    Found a gpt partition table in /dev/vdb
    Proceed anyway? (y,N) y
    Discarding device blocks: done
    Creating filesystem with 2621440 4k blocks and 655360 inodes
    Filesystem UUID: 08eccbb5-bc20-4483-af44-2c42462c792c
    Superblock backups stored on blocks:
        32768, 98304, 163840, 229376, 294912, 819200, 884736, 1605632

    Allocating group tables: done
    Writing inode tables: done
    Creating journal (16384 blocks): done
    Writing superblocks and filesystem accounting information: done

Mount it to /srv.::

    # mkdir /srv
    # mount /dev/vdb /srv
    # df -hT /srv
    Filesystem       Type            Size      Used Available Use% Mounted on
    /dev/vdb         ext4            9.8G     36.0M      9.2G   0% /srv

Resize the volume to 15GiB.::

    root@btx-0:/# o volume set --size 15 test_vol

Check the volume size in openstack.::

    root@btx-0:/# o volume list
    +--------------------------------------+----------+--------+------+-------------------------------+
    | ID                                   | Name     | Status | Size | Attached to                   |
    +--------------------------------------+----------+--------+------+-------------------------------+
    | afecb155-dd07-45f4-abca-d6c654b73b29 | test_vol | in-use |   15 | Attached to test on /dev/vdb  |
    +--------------------------------------+----------+--------+------+-------------------------------+

Check the volume size inside the VM.::

    # lsblk
    NAME    MAJ:MIN RM  SIZE RO TYPE MOUNTPOINT
    vda     252:0    0    1G  0 disk
    |-vda1  252:1    0 1015M  0 part /
    `-vda15 252:15   0    8M  0 part
    vdb     252:16   0   15G  0 disk /srv
    # df -hT /srv
    Filesystem       Type            Size      Used Available Use% Mounted on
    /dev/vdb         ext4            9.8G     36.0M      9.2G   0% /srv

The volume is resized to 15G but the mounted size is still 10GiB.

Extend it with resize2fs command.::

    # resize2fs /dev/vdb
    resize2fs 1.44.5 (15-Dec-2018)
    Filesystem at /dev/vdb is mounted on /srv; on-line resizing required
    old_desc_blocks = 2, new_desc_blocks = 2
    The filesystem on /dev/vdb is now 3932160 (4k) blocks long.
    # df -hT /srv
    Filesystem       Type            Size      Used Available Use% Mounted on
    /dev/vdb         ext4           14.7G     40.0M     13.9G   0% /srv

Yes, it is resized to 15G.

* Conclusion: Attached-and-mounted disk can be resized and the mounted
  filesystem can be extended using the appropriate resize tool
  (resize2fs for ext4, xfs_growfs for xfs).


3. Resize the OS disk
----------------------

The final test is resizing the OS disk.

I create a debian 12 VM with 2 GiB OS disk volume.

Here is the block list inside the VM.::

    debian@debian12-vm:~$ lsblk
    NAME    MAJ:MIN RM  SIZE RO TYPE MOUNTPOINTS
    sda       8:0    0    2G  0 disk
    ├─sda1    8:1    0  1.9G  0 part /
    ├─sda14   8:14   0    3M  0 part
    └─sda15   8:15   0  124M  0 part /boot/efi
    debian@debian12-vm:~$ df -hT /
    Filesystem     Type  Size  Used Avail Use% Mounted on
    /dev/sda1      ext4  1.9G 1006M  734M  58% /

Resize the OS disk.::

    root@btx-0:~# o volume set --size 5 debian12-vol

Check the volume size in openstack.::

    root@btx-0:~# o volume list
    +--------------------------------------+--------------+--------+------+--------------------------------------+
    | ID                                   | Name         | Status | Size | Attached to                          |
    +--------------------------------------+--------------+--------+------+--------------------------------------+
    | f54996b8-a1b9-4543-942e-c3af3e4a9610 | debian12-vol | in-use |    5 | Attached to debian12-vm on /dev/sda  |
    | afecb155-dd07-45f4-abca-d6c654b73b29 | test_vol     | in-use |   15 | Attached to test on /dev/vdb         |
    +--------------------------------------+--------------+--------+------+--------------------------------------+

Check the volume inside the VM.::

    debian@debian12-vm:~$ lsblk
    NAME    MAJ:MIN RM  SIZE RO TYPE MOUNTPOINTS
    sda       8:0    0    5G  0 disk
    ├─sda1    8:1    0  1.9G  0 part /
    ├─sda14   8:14   0    3M  0 part
    └─sda15   8:15   0  124M  0 part /boot/efi

Yes, it is resized to 5GiB.

I need to extend the root partition (sda1).::

    root@debian12-vm:~# growpart /dev/sda 1
    CHANGED: partition=1 start=262144 old: size=3930112 end=4192255 new: size=10223583 end=10485726
    root@debian12-vm:~# lsblk
    NAME    MAJ:MIN RM  SIZE RO TYPE MOUNTPOINTS
    sda       8:0    0    5G  0 disk
    ├─sda1    8:1    0  4.9G  0 part /
    ├─sda14   8:14   0    3M  0 part
    └─sda15   8:15   0  124M  0 part /boot/efi
    root@debian12-vm:~# df -hT /
    Filesystem     Type  Size  Used Avail Use% Mounted on
    /dev/sda1      ext4  1.9G  1.2G  522M  71% /

Yes, the root partition is extended but the filesystem is still not.

Extend the filesystem.::

    root@debian12-vm:~# resize2fs /dev/sda1
    resize2fs 1.47.0 (5-Feb-2023)
    Filesystem at /dev/sda1 is mounted on /; on-line resizing required
    old_desc_blocks = 1, new_desc_blocks = 1
    The filesystem on /dev/sda1 is now 1277947 (4k) blocks long.
    root@debian12-vm:~# df -hT /
    Filesystem     Type  Size  Used Avail Use% Mounted on
    /dev/sda1      ext4  4.8G  1.2G  3.4G  27% /

* Conclusion: OS disk can be resized with appropriate tools
  (growpart, resize2fs).




