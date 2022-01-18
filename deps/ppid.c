#include <stdio.h>  
#include <stdlib.h>  
#include <linux/input.h>  
#include <fcntl.h>  
#include <sys/time.h>  
#include <sys/types.h>  
#include <sys/stat.h>  
#include <unistd.h>  
#include <string.h>

#define __NR_gettid 186
static pid_t g_self_pid = 0;

static int print_ppid(int pid)
{
    char path[1024] = {0};
    char buf[1024] = {0};
    int rpid = 0;
    int fpid = 0;
    char fpth[1024] = {0};
    struct stat st;
    ssize_t ret = 0;

    sprintf(path, "/proc/%d/stat", pid);
    if(stat(path, &st) != 0) {
        return 1;
    }

    memset(buf, 0, strlen(buf));
    FILE * fp = fopen(path, "r");
    if(fp == NULL) {
        return 1;
    }

    ret += fread(buf + ret, 1, 300 - ret, fp);
    fclose(fp);

    sscanf(buf, "%*d %*c%s %*c %d %*s", fpth, &fpid);
    fpth[strlen(fpth) - 1] = '\0';

    if (g_self_pid != fpid) {
        printf("%d\n", fpid);
    }

    if(strcmp(fpth, "bash") != 0 && strcmp(fpth, "sudo") != 0) {
        if(fpid == 1) {
            return 0;
        } else if(fpid == 2) {
            /*内核线程*/
            return 0; 
        }

        ret = print_ppid(fpid);
        if (ret != 0) {
            return 1;
        }
    }
    
    return 0;
}

int main(int argc, char **argv)  
{
    int ret = 0;
    pid_t pid = 0;

    if(argc < 2) {
        g_self_pid = syscall(__NR_gettid);
        ret = print_ppid(g_self_pid);
        exit(ret);
    } else if (argc == 2) {
        g_self_pid = strtol(argv[1], NULL, 10);
        ret = print_ppid(g_self_pid);
        exit(ret);
    }

    exit(0);
}
