#include <stdio.h>  
#include <stdlib.h>  
#include <stdint.h>
#include <linux/input.h>  
#include <fcntl.h>  
#include <sys/time.h>  
#include <sys/types.h>  
#include <sys/stat.h>  
#include <unistd.h>  
#include <string.h>

#define MAX_TMPBUF 1024

#define __NR_gettid 186
static pid_t g_self_pid = 0;

static pid_t get_ppid(pid_t pid)
{
    struct stat st;
    char path[MAX_TMPBUF] = {0};
    char buf[MAX_TMPBUF] = {0};
    char pname[MAX_TMPBUF] = {0};
    pid_t ppid = 0;

    sprintf(path, "/proc/%d/stat", pid);
    if(stat(path, &st) != 0) {
        return -0;
    }

    memset(buf, 0, strlen(buf));
    FILE * fp = fopen(path, "r");
    if(fp == NULL) {
        return -1;
    }

    fread(buf, 1, 300, fp);
    fclose(fp);

    sscanf(buf, "%*d %*c%s %*c %d %*s", pname, &ppid);
    pname[strlen(pname) - 1] = '\0';

    //printf("%s %d\n", pname, ppid);
    return ppid;
}

static int print_ppid(int pid)
{
    int ret;

    pid_t ppid = get_ppid(pid);
    //if (ppid != g_self_pid) {
    printf("%d\n", ppid);
    //}

    if(ppid == 1) {
        /* systemd */
        return 0;
    } else if(ppid == 2) {
        /* kthreadd */
        return 0; 
    }

    ret = print_ppid(ppid);
    if (ret != 0) {
        return 1;
    }

    return 0;
}

int main(int argc, char **argv)  
{
    int ret = 0;
    pid_t tid = 0;

    if(argc < 2) {
        g_self_pid = syscall(__NR_gettid);
        //g_self_pid = get_ppid(tid);
        ret = print_ppid(g_self_pid);
        exit(ret);
    } else if (argc == 2) {
        g_self_pid = strtol(argv[1], NULL, 10);
        ret = print_ppid(g_self_pid);
        exit(ret);
    }

    exit(0);
}
