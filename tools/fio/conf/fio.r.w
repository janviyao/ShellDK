[global]
    direct=1
    invalidate=1
    group_reporting

    time_based=1
    runtime=300s
    ramp_time=30s

    ioengine=psync
    iodepth=1
    thread=0
    numjobs=1

    blocksize=4k
    rw=randwrite
    norandommap
    randrepeat=0

    ;<<<<<<<<<<<<
    cpus_allowed=0
    cpus_allowed_policy=shared
    ;>>>>>>>>>>>>

[group-disk-sdb]
    name=group-disk-sdb
    filename=/dev/sdb
