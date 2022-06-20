[1mdiff --git a/tools/fio/conf/fio.r.r b/tools/fio/conf/fio.r.r[m
[1mindex 12c850c5..654fdc93 100755[m
[1m--- a/tools/fio/conf/fio.r.r[m
[1m+++ b/tools/fio/conf/fio.r.r[m
[36m@@ -22,6 +22,6 @@[m
     cpus_allowed_policy=shared[m
     ;>>>>>>>>>>>>[m
 [m
[31m-[group-disk-sdb][m
[31m-    name=group-disk-sdb[m
[32m+[m[32m[disk-sdb][m
[32m+[m[32m    name=disk-sdb[m
     filename=/dev/sdb[m
[1mdiff --git a/tools/fio/conf/fio.r.rw70 b/tools/fio/conf/fio.r.rw70[m
[1mindex 3da94897..9910a975 100755[m
[1m--- a/tools/fio/conf/fio.r.rw70[m
[1m+++ b/tools/fio/conf/fio.r.rw70[m
[36m@@ -23,8 +23,8 @@[m
     cpus_allowed_policy=shared[m
     ;>>>>>>>>>>>>[m
     [m
[31m-[group-disk-sdb][m
[31m-    name=group-disk-sdb[m
[32m+[m[32m[disk-sdb][m
[32m+[m[32m    name=disk-sdb[m
     filename=/dev/sdb[m
     [m
     [m
[1mdiff --git a/tools/fio/conf/fio.r.w b/tools/fio/conf/fio.r.w[m
[1mindex 52708a2d..b39bf3ae 100755[m
[1m--- a/tools/fio/conf/fio.r.w[m
[1m+++ b/tools/fio/conf/fio.r.w[m
[36m@@ -22,6 +22,6 @@[m
     cpus_allowed_policy=shared[m
     ;>>>>>>>>>>>>[m
 [m
[31m-[group-disk-sdb][m
[31m-    name=group-disk-sdb[m
[32m+[m[32m[disk-sdb][m
[32m+[m[32m    name=disk-sdb[m
     filename=/dev/sdb[m
[1mdiff --git a/tools/fio/conf/fio.s.r b/tools/fio/conf/fio.s.r[m
[1mindex bcdf2c49..d1839726 100755[m
[1m--- a/tools/fio/conf/fio.s.r[m
[1m+++ b/tools/fio/conf/fio.s.r[m
[36m@@ -20,6 +20,6 @@[m
     cpus_allowed_policy=shared[m
     ;>>>>>>>>>>>>[m
 [m
[31m-[group-disk-sdb][m
[31m-    name=group-disk-sdb[m
[32m+[m[32m[disk-sdb][m
[32m+[m[32m    name=disk-sdb[m
     filename=/dev/sdb[m
[1mdiff --git a/tools/fio/conf/fio.s.rw70 b/tools/fio/conf/fio.s.rw70[m
[1mindex f06cc0c6..52428b00 100755[m
[1m--- a/tools/fio/conf/fio.s.rw70[m
[1m+++ b/tools/fio/conf/fio.s.rw70[m
[36m@@ -21,8 +21,8 @@[m
     cpus_allowed_policy=shared[m
     ;>>>>>>>>>>>>[m
     [m
[31m-[group-disk-sdb][m
[31m-    name=group-disk-sdb[m
[32m+[m[32m[disk-sdb][m
[32m+[m[32m    name=disk-sdb[m
     filename=/dev/sdb[m
     [m
     [m
[1mdiff --git a/tools/fio/conf/fio.s.w b/tools/fio/conf/fio.s.w[m
[1mindex 6dbb23ed..44f6fa43 100755[m
[1m--- a/tools/fio/conf/fio.s.w[m
[1m+++ b/tools/fio/conf/fio.s.w[m
[36m@@ -20,6 +20,6 @@[m
     cpus_allowed_policy=shared[m
     ;>>>>>>>>>>>>[m
 [m
[31m-[group-disk-sdb][m
[31m-    name=group-disk-sdb[m
[32m+[m[32m[disk-sdb][m
[32m+[m[32m    name=disk-sdb[m
     filename=/dev/sdb[m
[1mdiff --git a/tools/test/setup.sh b/tools/test/setup.sh[m
[1mindex 1094ef3a..0f51cf18 100755[m
[1m--- a/tools/test/setup.sh[m
[1m+++ b/tools/test/setup.sh[m
[36m@@ -17,7 +17,7 @@[m [mAPPLY_SYSCTRL=true[m
 [m
 # TEST_TARGET=spdk[m
 if [[ "${LOCAL_IP}" == "172.24.15.170" ]];then[m
[31m-    TEST_TARGET=istgt[m
[32m+[m[32m    TEST_TARGET=spdk[m
     declare -xa SERVER_IP_ARRAY=(172.24.15.170)[m
     declare -xa CLIENT_IP_ARRAY=(172.24.15.172 172.24.15.171)[m
 elif [[ "${LOCAL_IP}" == "100.69.248.137" ]];then[m
