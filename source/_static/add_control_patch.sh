#!/bin/bash

# Copy localrepo haproxy files
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
# patch burrito.system role
cat <<EOF | patch -p0
--- roles/burrito.system/tasks/main.yml.bak
+++ roles/burrito.system/tasks/main.yml
@@ -91,7 +91,6 @@
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
@@ -19,6 +19,7 @@
 - name: Update etcd-servers for apiserver
   lineinfile:
     dest: "{{ kube_config_dir }}/manifests/kube-apiserver.yaml"
-    regexp: '^    - --etcd-servers='
-    line: '    - --etcd-servers={{ etcd_access_addresses }}'
+    regexp: '^(\s+- --etcd-servers=).*$'
+    line: '\1{{ etcd_access_addresses }}'
+    backrefs: true
   when: etcd_deployment_type != "kubeadm"
EOF
# patch run.sh
cat <<'EOF' | patch -p0
--- run.sh.bak
+++ run.sh
@@ -67,7 +67,7 @@
 [[ "${PLAYBOOK}" = "k8s" ]] && PLAYBOOK="kubespray/cluster" || :

 if [[ "${PLAYBOOK}" = "burrito" && -n ${OFFLINE_VARS} ]]; then
-  if ! (helm plugin list | grep -q ^diff); then
+  if ! (sudo helm plugin list | grep -q ^diff); then
     # install helm diff plugin
     HELM_DIFF_TARBALL="/mnt/files/github.com/databus23/helm-diff/releases/download/*/helm-diff-linux-amd64.tgz"
     HELM_PLUGINS=$(sudo helm env | grep HELM_PLUGINS |cut -d'"' -f2)
EOF

