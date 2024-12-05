NetApp TCP vs. RDMA Performance test
=======================================

TCP vs. RDMA Transport Layer Performance Test
-----------------------------------------------

RDMA is the networking offload technology and makes data transfer more
efficiently than TCP.
RDMA is widely used for efficient data transfer between clients and storages.

We set up RoCE (RDMA over Converged Ethernet) and enabled NFS over RDMA.
We ran `fio Flexible I/O tester <https://github.com/axboe/fio>`_ and 
measured the throughput for sequential read/write and 
the IOPS for the random read/write.

The tests were performed on a linux client against a linux NFS server
using ramdisk so that the disk latency does not affect to the result and
measure the performance of the transport layer in TCP and RDMA.

* Client

    - Model: HPE ProLiant DL360 Gen10
    - OS: Rocky Linux 8.10
    - CPU: Intel Xeon Silver 4110 CPU @ 2.10GHz * 2 Sockets (32 cores)
    - RAM: 32GB DDR4 2666 MHz * 8 ea (256GB)
    - Network: Nvidia Mellanox ConnectX-6 Dx 100GbE (Jumbo frame enabled)

* Server

    - Model: HPE ProLiant DL360 Gen10
    - OS: Rocky Linux 8.10
    - CPU: Intel Xeon Gold 6142 CPU @ 2.60GHz * 2 Sockets (64 cores)
    - RAM: 32GB DDR4 2666 MHz * 8 ea (256 GB)
    - Network: Nvidia Mellanox ConnectX-6 Dx 100GbE (Jumbo frame enabled)

NFSv3 TCP mount options::

    10.1.1.13:/export on /srv type nfs (rw,relatime,vers=3,
    rsize=1048576,wsize=1048576,namlen=255,hard,proto=tcp,timeo=600,
    retrans=2,sec=sys,mountaddr=10.1.1.13,mountvers=3,mountport=20048,
    mountproto=udp,local_lock=none,addr=10.1.1.13)

NFSv3 RDMA mount options::

    10.1.1.13:/export on /srv type nfs (rw,relatime,vers=3,
    rsize=1048576,wsize=1048576,namlen=255,hard,proto=rdma,port=20049,
    timeo=600,retrans=2,sec=sys,mountaddr=10.1.1.13,mountvers=3,
    mountproto=tcp,local_lock=none,addr=10.1.1.13)

NFSv4 TCP mount options::

    10.1.1.13:/ on /srv type nfs4 (rw,relatime,vers=4.2,
    rsize=1048576,wsize=1048576,namlen=255,hard,proto=tcp,timeo=600,
    retrans=2,sec=sys,clientaddr=10.1.1.11,local_lock=none,addr=10.1.1.13)

NFSv4 RDMA mount options::

    10.1.1.13:/ on /srv type nfs4 (rw,relatime,vers=4.2,
    rsize=1048576,wsize=1048576,namlen=255,hard,proto=rdma,port=20049,
    timeo=600,retrans=2,sec=sys,clientaddr=10.1.1.11,local_lock=none,
    addr=10.1.1.13)

This is TCP vs. RoCE Sequential Read/Write IO TEST result.

.. image:: ../_static/images/netapp/tcp_rdma_sequential_read_write_64k_iodepth_128.svg
   :width: 600
   :alt: TCP vs. RDMA Sequential IO TEST

In NFSv3, RoCE is 2.39 times better than TCP in sequential read and 
1.39 times better in sequential write.

In NFSv4, RoCE is 2.23 times better than TCP in sequential read and
1.41 times better in sequential write.

This is TCP vs. RDMA Random Read/Write IO TEST result.

.. image:: ../_static/images/netapp/tcp_rdma_random_read_write_4k_iodepth_128.svg
   :width: 600
   :alt: TCP vs. RDMA Random IO TEST

In NFSv3, RoCE is 1.84 times better than TCP in random read and
1.35 times better in random write.

In NFSv4, RoCE is 2.30 times better than TCP in random read and
1.80 times better in random write.

You can see NFS over RDMA (RoCE) gives a lot of performance boost 
against NFS over TCP at the transport layer.


NetApp NFS RDMA Performance Test
---------------------------------

We set up the burrito system with one control plane node and one compute node
that are connected to NetApp AFF A400 with NFS over RDMA (RoCE).

* Control plane node

    - Model: HPE ProLiant DL360 Gen10
    - OS: Rocky Linux 8.10
    - CPU: Intel Xeon Silver 4110 CPU @ 2.10GHz * 2 Sockets (32 cores)
    - RAM: 32GB DDR4 2666 MHz * 8 ea
    - Network: Nvidia Mellanox ConnectX-6 Dx 100GbE (Jumbo frame enabled)

* Compute node

    - Model: HPE ProLiant DL360 Gen10
    - OS: Rocky Linux 8.10
    - CPU: Intel Xeon Gold 6142 CPU @ 2.60GHz * 2 Sockets (64 cores)
    - RAM: 32GB DDR4 2666 MHz * 8 ea
    - Network: Nvidia Mellanox ConnectX-6 Dx 100GbE (Jumbo frame enabled)

We implemented NFS over RDMA IO test at the host and the virtual machines
with NFSv3 and NFSv4.

We could use `nconnect` mount option with NFSv3 RDMA but we could not use
it with NFSv4 RDMA.
The `remoteports` option from `VAST NFS <https://vastnfs.vastdata.com>`_ 
can be used both NFSv3 and NFSv4.

The `nconnect` option creates the multiple NFS connections to the NFS server 
so that the data can be transferred concurrently.
The `remoteports` option creates the NFS connections to the multiple NFS 
server IP addresses.

Here is the NFSv3 mount options.::

    10.1.1.21:/n1data on /var/lib/nova/mnt/7470d2bb4c8c9bfec359ae9781a492ef 
    type nfs (rw,relatime,vers=3,rsize=65536,wsize=65536,namlen=255,hard,
    forcerdirplus,proto=rdma,nconnect=32,port=20049,timeo=600,retrans=2,
    sec=sys,mountaddr=10.1.1.21,mountvers=3,mountproto=tcp,lookupcache=pos,
    local_lock=none,remoteports=10.1.1.21-10.1.1.22,addr=10.1.1.22)

Two remote ports specify NetApp NFS server's IP addresses and 
16 NFS connections to each remote port. So there are 32 connections in total.

Here is the NFSv4 mount options.::

    10.1.1.21:/n1data on /var/lib/nova/mnt/7470d2bb4c8c9bfec359ae9781a492ef
    type nfs4 (rw,relatime,vers=4.2,rsize=65536,wsize=65536,namlen=255,
    hard,forcerdirplus,proto=rdma,max_connect=2,port=20049,timeo=600,
    retrans=2,sec=sys,clientaddr=10.1.1.13,lookupcache=pos,local_lock=none,
    remoteports=10.1.1.21-10.1.1.22,addr=10.1.1.22)

Two remote ports specify NetApp NFS server's IP addresses but nconnect is not
supported NFSv4 RDMA. So there are only 2 connections in total.

How to run the fio processes on the multiple virtual machines
+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

We created 6 debian virtual machines on the compute node.
Let's say debvm1, debvm2, ..., debvm6.
The debvm1 acts as both the fio client and the server and
other virtual machines act as the fio server.::

        debvm1
        fio client -> fio server on debvm1 -> run fio processes -|
        ^   |-------> fio server on debvm2 -> run fio processes -|
        |   |-------> fio server on debvm3 -> run fio processes -|
        |   |-------> fio server on debvm4 -> run fio processes -|
        |   |-------> fio server on debvm5 -> run fio processes -|
        |   |-------> fio server on debvm6 -> run fio processes -|
        |                                                        |
        |--------------------------------------------------------|
                 aggregate the io result from the fio servers

When we run the fio client with the server list file and job-spec file.
Then, the fio client sends the job-spec file to each server and run fio
processes concurrently.
Here is the example.::

    ## Run fio server on each virtual machine
    # fio --server --daemonize=/run/fio.pid
    ## Create host.list file
    192.168.21.28
    192.168.21.74
    192.168.21.79
    192.168.21.59
    192.168.21.38
    192.168.21.92
    # Run fio client on debvm1 virtual machine
    # fio --client=host.list randread.fio
    ...
    All clients: (groupid=0, jobs=6): err= 0: pid=0: Tue Dec  3 05:33:42 2024
      read: IOPS=433k, BW=1692Mi (1774M)(198GiB/120095msec)
        slat (usec): min=2, max=109182, avg= 8.98, stdev=59.20
        clat (usec): min=199, max=308437, avg=7077.64, stdev=4297.93
         lat (usec): min=215, max=308443, avg=7086.62, stdev=4301.60
       bw (  MiB/s): min=  527, max= 2754, per=100.00%, avg=1694.19, stdev=12.85, samples=5736
       iops        : min=134926, max=705068, avg=433712.13, stdev=3290.74, samples=5736
      lat (usec)   : 250=0.01%, 500=0.01%, 750=0.08%, 1000=0.32%
      lat (msec)   : 2=3.11%, 4=16.38%, 10=62.26%, 20=16.75%, 50=1.06%
      lat (msec)   : 100=0.03%, 250=0.01%, 500=0.01%
      cpu          : usr=4.58%, sys=11.67%, ctx=29724303, majf=0, minf=3334
      IO depths    : 1=0.1%, 2=0.1%, 4=0.1%, 8=0.1%, 16=0.1%, 32=0.1%, >=64=100.0%
         submit    : 0=0.0%, 4=100.0%, 8=0.0%, 16=0.0%, 32=0.0%, 64=0.0%, >=64=0.0%
         complete  : 0=0.0%, 4=100.0%, 8=0.0%, 16=0.0%, 32=0.0%, 64=0.0%, >=64=0.1%
         issued rwts: total=52005355,0,0,0 short=0,0,0,0 dropped=0,0,0,0


IO test result
++++++++++++++++

This is NetApp NFSv3 RDMA Sequential IO TEST result.

.. image:: ../_static/images/netapp/netapp_nfsv3_rdma_seq_iotest.svg
   :width: 600
   :alt: NetApp NFSv3 RDMA Sequential IO TEST

The IO Performance at the host is better than that of one virtual machine.
As we increase the number of virtual machines, the sum of throughput is
higher than the throughput of the host since more IO jobs are running
and distributed over the virtual machines.
We could almost saturate RoCE network with 4 virtual machines in 
sequential read IO test.

The maximum throughput in NFSv3 at the virtual machines was 
**11342 MB/s in read** and **3628 MB/s in write**.

This is NetApp NFSv4 RDMA Sequential IO TEST result.

.. image:: ../_static/images/netapp/netapp_nfsv4_rdma_seq_iotest.svg
   :width: 600
   :alt: NetApp NFSv4 RDMA Sequential IO TEST

The IO performance at the host is better than that of one virtual machine.
As we increase the number of virtual machines, the sum of throughput is
higher than the throughput of the host since more jobs are running
and distributed over the virtual machines.
We did not test more jobs at the host but it would be better if we tested it.
We could not saturate RoCE network in NFSv4 since we could not use nconnect
with NFSv4 RDMA.

The maximum throughput in NFSv4 at the virtual machines was 
**5752 MB/s in read** and **2385 MB/s in write**.


This is NetApp NFSv3 RDMA Random IO TEST result.

.. image:: ../_static/images/netapp/netapp_nfsv3_rdma_random_iotest.svg
   :width: 600
   :alt: NetApp NFSv3 RDMA Random IO TEST

The IO performance at the host is a lot better than that of one virtual machine.
As we increase the number of virtual machines, the sum of IOPS is increased
since more jobs are running and distributed over the virtual machines.

The maximum IOPS in NFSv3 at the virtual machines was 
**433k IOPS in random read** and **174k random write IOPS**.

This is NetApp NFSv4 RDMA Random IO TEST result.

.. image:: ../_static/images/netapp/netapp_nfsv4_rdma_random_iotest.svg
   :width: 600
   :alt: NetApp NFSv4 RDMA Random IO TEST

The IO performance at the host is a lot better than that of one virtual machine.
As we increase the number of virtual machines, the sum of IOPS is increased
since more jobs are running and distributed over the virtual machines.

The maximum IOPS in NFSv4 at the virtual machines was 
**136k IOPS in random read** and **75.6k random write IOPS**.
This is much worse than NFSv3.
It is the same reason as sequential IO test.
We could not use nconnect with NFSv4 RDMA.

For performance, we recommend using NFSv3 over RDMA.

