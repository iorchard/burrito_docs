Errata
=======

Ceph crush map setting issue
-----------------------------

* Affected version: from 1.1.0 to 1.3.0
* Severity: Critical

There is an error in the ceph crush map settings that causes 
the failure domain to be set to OSD-level instead of host-level.

Issue
++++++

The single_osd_node variable in vars.yml.sample is as follows.::

    single_osd_node: "{{ ((groups['osds']|length) == 1)|ternary('true', 'false') }}"


Due to the single quotes around true and false,
single_osd_node's variable type is text.

This affects the value of osd_crush_chooseleaf_type that uses 
the single_osd_node variable.::

    osd_crush_chooseleaf_type: "{{ single_osd_node | ternary(0, 1) }}"

Since single_osd_node is a text,
the value of osd_crush_chooseleaf_type is always 0 so the failure domain
is set to osd-level.

Solution
+++++++++

If you have not installed Ceph yet, modify vars.yml file before running
./run.sh ceph.::

    single_osd_node: "{{ ((groups['osds']|length) == 1)|ternary(true, false) }}"


If you have already installed Ceph, 
Get and change the crush map as follows.

Get the crush map.::

    $ sudo ceph osd getcrushmap -o crushmap.bin

Decompile the crush map.::

    $ sudo crushtool -d crushmap.bin -o crushmap.txt

Open crushmap.txt and look for replicated_rule.::

    rule replicated_rule {
            id 0
            type replicated
            step take default
            step choose firstn 0 type osd
            step emit
    }

As you can see 'step choose firstn 0 type osd' means the failure domain is
osd-level.

Edit crushmap.txt to change the failure domain to host-level.::

    rule replicated_rule {
            id 0
            type replicated
            step take default
            step chooseleaf firstn 0 type host
            step emit
    }

Recompile the crush map.::

    $ sudo crushtool -c crushmap.txt -o newcrushmap.bin

Apply the new crush map to the cluster.::

    $ sudo ceph osd setcrushmap -i newcrushmap.bin

As soon as the new crush map is applied to the ceph cluster,
there will be a lot of placement group movement.
So it is recommended to do the above tasks during off-peak hours.

