#include <stdio.h>  
#include <stdlib.h>  
#include <stdint.h>
#include <stdbool.h>
#include <unistd.h>  
#include <ctype.h>
#include <string.h>

#include <fcntl.h>  
#include <sys/time.h>  
#include <sys/types.h>  
#include <sys/stat.h>  

#define MAX_TMPBUF 128

#define __NR_gettid 186
static bool  g_print_name = false;
static pid_t g_self_pid  = 0;

static pid_t get_ppid(pid_t pid)
{
    struct stat st;
    char path[MAX_TMPBUF] = {0};
    char buf[MAX_TMPBUF] = {0};
    char pname[MAX_TMPBUF] = {0};
    pid_t ppid = 0;

    sprintf(path, "/proc/%d/stat", pid);
    if(stat(path, &st) != 0) {
        return 0;
    }

    memset(buf, 0, strlen(buf));
    FILE * fp = fopen(path, "r");
    if(fp == NULL) {
        return 0;
    }

    fread(buf, 1, 300, fp);
    fclose(fp);

    sscanf(buf, "%*d %*c%s %*c %d %*s", pname, &ppid);
    pname[strlen(pname) - 1] = '\0';

    if(ppid == 0) {
        return 0;
    }

    if (g_print_name == true) {
        printf("%s[%d]\n", pname, pid);
    } else {
        printf("%d\n", pid);
    }

    return ppid;
}

static int print_ppid(int pid)
{
    int ret;

    pid_t ppid = get_ppid(pid);
    if(ppid == 0) {
        return 1;
    }

    if(ppid == 1) {
        /* systemd */
        return 0;
    } else if(ppid == 2) {
        /* kthreadd */
        return 0; 
    }

    return print_ppid(ppid);
}

int main(int argc, char **argv)  
{
    int idx, ret = 0;
    pid_t ppid = 0;
    bool isdigit = true;
    char buf[MAX_TMPBUF] = {0};

    if(argc < 2) {
        g_self_pid = syscall(__NR_gettid);

        ppid = get_ppid(g_self_pid);
        if(ppid == 0) {
            return 1;
        }

        ret = print_ppid(ppid);
    } else if (argc == 2) {
        isdigit = true;
        memcpy(buf, argv[1], MAX_TMPBUF);
        for(idx = 0; buf[idx]; idx++){
            if (!isdigit(buf[idx])) {
                isdigit = false;
                break;
            }
        }

        if (isdigit) {
            g_self_pid  = strtol(argv[1], NULL, 10);
        } else {
            g_self_pid = syscall(__NR_gettid);

            for(idx = 0; buf[idx]; idx++){
                if (isalpha(buf[idx]) == 1) {
                    buf[idx] = tolower(buf[idx]);
                }
            }

            if (strcmp(buf, "true") == 0) {
                g_print_name  = true;
            } else if (strcmp(buf, "false") == 0) {
                g_print_name  = false;
            } else {
                printf("invalid pid[%s]\n", argv[1]);
                return 1;
            }
        }

        ppid = get_ppid(g_self_pid);
        if(ppid == 0) {
            return 1;
        }

        ret = print_ppid(ppid);
    } else if (argc == 3) {
        isdigit = true;
        memcpy(buf, argv[1], MAX_TMPBUF);
        for(idx = 0; buf[idx]; idx++){
            if (!isdigit(buf[idx])) {
                isdigit = false;
                break;
            }
        }

        if (isdigit) {
            g_self_pid  = strtol(argv[1], NULL, 10);
        } else {
            printf("invalid pid[%s]\n", argv[1]);
            return 1;
        }

        isdigit = true;
        memcpy(buf, argv[2], MAX_TMPBUF);
        for(idx = 0; buf[idx]; idx++){
            if (!isdigit(buf[idx])) {
                isdigit = false;
                break;
            }
        }

        if (isdigit) {
            g_print_name = (bool)strtol(buf, NULL, 10);
        } else {
            for(idx = 0; buf[idx]; idx++){
                if (isalpha(buf[idx]) == 1) {
                    buf[idx] = tolower(buf[idx]);
                }
            }

            if (strcmp(buf, "true") == 0) {
                g_print_name  = true;
            } else if (strcmp(buf, "false") == 0) {
                g_print_name  = false;
            } else {
                printf("invalid bool[%s]\n", argv[2]);
                return 1;
            }
        }

        ppid = get_ppid(g_self_pid);
        if(ppid == 0) {
            return 1;
        }

        ret = print_ppid(ppid);
    }

    return ret;
}
