#!/bin/bash

# copy localrepo haproxy files
cat > roles/burrito.localrepo/tasks/haproxy_setup.yml <<EOF
---
- name: Local Repo | template local repo
  ansible.builtin.template:
    dest: "{{ item.dest }}"
    src: "{{ ansible_os_family | lower }}{{ item.dest + '.j2' }}"
    owner: "root"
    group: "root"
    mode: "0644"
  loop:
    - {dest: "/etc/yum.repos.d/burrito.repo"}
  become: true

- name: Local Repo | add localrepo haproxy config
  ansible.builtin.template:
    dest: "{{ item.dest }}"
    src: "{{ ansible_os_family | lower }}{{ item.dest + '.j2' }}"
    owner: "{{ item.owner }}"
    group: "{{ item.group }}"
    mode: "{{ item.mode }}"
  loop: "{{ service_conf }}"
  become: true
  when: inventory_hostname in groups['kube_control_plane']
  notify:
    - haproxy reload service
...
EOF
cat > localrepo_haproxy_setup.yml <<EOF
---
- name: Set up local repo haproxy
  hosts: kube_control_plane
  any_errors_fatal: true
  tasks:
    - name: Set up local repo haproxy
      include_role:
        name: burrito.localrepo
        tasks_from: haproxy_setup
...
EOF

# patch burrito.ceph role
cat <<EOF | patch -p0
--- roles/burrito.ceph/tasks/main.yml.bak	2024-10-22 16:24:02.398389101 +0900
+++ roles/burrito.ceph/tasks/main.yml	2024-10-22 16:24:06.156389990 +0900
@@ -1,9 +1,14 @@
 ---
 - name: Main | import common tasks
   ansible.builtin.import_tasks: "common.yml"
+  tags: ['always']
 
 - name: Main | include os specific tasks
   ansible.builtin.include_tasks: "{{ lookup('first_found', _params) }}"
+  args:
+    apply:
+      tags: always
+  tags: always
   vars:
     _params:
       files:
@@ -18,22 +23,29 @@
 
 - name: Main | import ceph bootstrap tasks
   ansible.builtin.import_tasks: "bootstrap.yml"
+  tags: ['bootstrap', 'ceph_servers']
 
 - name: Main | import ceph public ssh key tasks
   ansible.builtin.import_tasks: "sshkey.yml"
+  tags: ['sshkey', 'ceph_servers']
 
 - name: Main | import ceph cluster setup tasks
   ansible.builtin.import_tasks: "setup.yml"
+  tags: ['setup', 'ceph_servers']
 
 - name: Main | import ceph init tasks
   ansible.builtin.import_tasks: "init.yml"
+  tags: ['init', 'ceph_servers']
 
 - name: Main | import ceph client tasks
   ansible.builtin.import_tasks: "client.yml"
+  tags: ['ceph_client']
 
 - name: Main | import ceph status check tasks
   ansible.builtin.import_tasks: "status.yml"
+  tags: ['status']
 
 - name: Main | import radosgw haproxy setup tasks
   ansible.builtin.import_tasks: "haproxy.yml"
+  tags: ['haproxy']
 ...
EOF

# patch burrito.system role
cat <<EOF | patch -p0
--- roles/burrito.system/tasks/main.yml.bak
+++ roles/burrito.system/tasks/main.yml
@@ -84,7 +84,6 @@
     mode: "0644"
   when: 
     - inventory_hostname in groups['kube_control_plane']
-    - client_cert is changed
 
 - name: Kubeconfig | copy client key file on server
   ansible.builtin.copy:
EOF

# patch kubespray
cat <<EOF | patch -p0
--- kubespray/roles/kubernetes/control-plane/tasks/kubeadm-fix-apiserver.yml.bak
+++ kubespray/roles/kubernetes/control-plane/tasks/kubeadm-fix-apiserver.yml
@@ -1,5 +1,4 @@
 ---
-
 - name: Update server field in component kubeconfigs
   lineinfile:
     dest: "{{ kube_config_dir }}/{{ item }}"
@@ -15,3 +14,10 @@
     - "Master | Restart kube-controller-manager"
     - "Master | Restart kube-scheduler"
     - "Master | reload kubelet"
+
+- name: Update etcd-servers for apiserver
+  ansible.builtin.replace:
+    path: "{{ kube_config_dir }}/manifests/kube-apiserver.yaml"
+    regexp: '(etcd-servers=).*'
+    replace: '\1{{ etcd_access_addresses }}'
+  when: etcd_deployment_type != "kubeadm"
EOF
