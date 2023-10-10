Preserve glance image persistent volume
========================================

Overview
--------

In burrito, if the default storage backend is netapp, 
the Persistent Volume (PV) is created and used to store glance images.

When the PV is dynamically created by netapp trident csi driver and the
reclaim policy is inherited from the storageclass setting which is Delete,
the PV is deleted when no pod uses it.
So if we uninstall glance, the PV is gone.

We want to preserve the PV even if glance is deleted.
Then we can reuse the already uploaded images 
when we install glance again.

Here is the howto.

How to preserve glance image persistent volume
------------------------------------------------

The reclaim policy of glance image PV is Delete.::

    root@btx-0:~# k get pv pvc-b0f01f0f-fab5-4c0f-b549-89f47d819cf1
    NAME                                       CAPACITY   ACCESS MODES   RECLAIM POLICY   STATUS   CLAIM                     STORAGECLASS   REASON   AGE
    pvc-b0f01f0f-fab5-4c0f-b549-89f47d819cf1   500Gi      RWX            Delete           Bound    openstack/glance-images   netapp                  25h

Patch the PV to set it to Retain.::

    root@btx-0:~# k patch pv pvc-b0f01f0f-fab5-4c0f-b549-89f47d819cf1 -p \
        '{"spec":{"persistentVolumeReclaimPolicy":"Retain"}}'
    persistentvolume/pvc-b0f01f0f-fab5-4c0f-b549-89f47d819cf1 patched

The reclaim policy of the PV is changed to Retain.::

    root@btx-0:~# k get pv pvc-b0f01f0f-fab5-4c0f-b549-89f47d819cf1
    NAME                                       CAPACITY   ACCESS MODES   RECLAIM POLICY   STATUS   CLAIM                     STORAGECLASS   REASON   AGE
    pvc-b0f01f0f-fab5-4c0f-b549-89f47d819cf1   500Gi      RWX            Retain           Bound    openstack/glance-images   netapp                  25h

Uninstall glance.::

    $ ./scripts/burrito.sh uninstall glance

The glance-images PVC is gone but the PV still exists.::

    root@btx-0:/# k get pv pvc-b0f01f0f-fab5-4c0f-b549-89f47d819cf1
    NAME                                       CAPACITY   ACCESS MODES   RECLAIM POLICY   STATUS     CLAIM                     STORAGECLASS   REASON   AGE
    pvc-b0f01f0f-fab5-4c0f-b549-89f47d819cf1   500Gi      RWX            Retain           Released   openstack/glance-images   netapp                  25h

Yes, it exists and the status is changed to Released.

Patch resourceVersion and uid of claimRef to null.::

    root@btx-0:~# k patch pv pvc-b0f01f0f-fab5-4c0f-b549-89f47d819cf1 -p \
        '{"spec":{"claimRef": {"resourceVersion": null, "uid": null}}}'
    persistentvolume/pvc-b0f01f0f-fab5-4c0f-b549-89f47d819cf1 patched

I want to reuse the PV when I install glance so I edit the appropriate yaml 
manifest file - pvc-images.yaml.::

    [clex@bbeta-controller burrito]$ git diff openstack-helm/glance/templates/pvc-images.yaml
    diff --git a/openstack-helm/glance/templates/pvc-images.yaml b/openstack-helm/glance/templates/pvc-images.yaml
    index 86a3b47..658c1ec 100644
    --- a/openstack-helm/glance/templates/pvc-images.yaml
    +++ b/openstack-helm/glance/templates/pvc-images.yaml
    @@ -26,5 +26,6 @@ spec:
         requests:
           storage: {{ .Values.volume.size }}
       storageClassName: {{ .Values.volume.class_name }}
    +  volumeName: pvc-b0f01f0f-fab5-4c0f-b549-89f47d819cf1
     {{- end }}
     {{- end }}

I added 'volumeName: <PV name>' to let the PVC use the PV.

Install glance.::

    $ ./scripts/burrito.sh install glance
    
And see the PV is reused.::

    root@btx-0:/# k get pvc glance-images
    NAME            STATUS   VOLUME                                     CAPACITY ACCESS MODES   STORAGECLASS   AGE
    glance-images   Bound    pvc-b0f01f0f-fab5-4c0f-b549-89f47d819cf1   500Gi   RWX            netapp         1m
    root@btx-0:/# k get pv |grep glance-images
    pvc-b0f01f0f-fab5-4c0f-b549-89f47d819cf1   500Gi      RWX     Retain Bound    openstack/glance-images                       netapp         26h

Yes, the glance-images PVC takes the preserved PV.

