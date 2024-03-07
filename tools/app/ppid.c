#include <stdio.h>  
#include <stdlib.h>  
#include <stdint.h>
#include <stdbool.h>
#include <unistd.h>  
#include <ctype.h>
#include <string.h>
#include <limits.h>
#include <getopt.h>

#if defined(__linux__)
#include <fcntl.h>  
#include <sys/time.h>  
#include <sys/types.h>  
#include <sys/stat.h>  
#elif defined(_WIN32) || defined(__CYGWIN__)
#include <windows.h>
#include <tlhelp32.h>
#endif

#if defined(__linux__)
#define PID_T pid_t
#elif defined(_WIN32) || defined(__CYGWIN__)
#define PID_T DWORD
#endif

#define VERSION         "1.2"
#define PTREE_MAX_DEPTH 30
#define __NR_gettid     186

#define DEBUG(str)                                             \
    do {                                                       \
        int err = errno;                                       \
        char buf[BUFSIZ];                                      \
        sprintf (buf, "[%s:%d] %s ", __func__, __LINE__, str); \
        errno = err;                                           \
        perror (buf);                                          \
    } while (0)

typedef struct pid_info
{
    PID_T pid;
    char  name[NAME_MAX];
} pid_info_t;

static bool  g_print_name = false;
static PID_T g_stop_pid = 0;
static int g_tree_index = 0;
static pid_info_t g_ptree[PTREE_MAX_DEPTH];

static void help_usage(void)
{
    printf("ppid [options] [pid [,...]]\n");
    printf("DESCRIPTION\n");
    printf("    show parent pids up to root pid. when no parameter is specified, printout start from ppid-cmd's pid\n");
    printf("    pid: one special pid, when not specified, ppid-cmd's pid is default\n");
    printf("OPTIONS\n");
    printf("    -h|--help             : show this message\n");
    printf("    -v|--version          : show this message\n");
    printf("    -n|--name             : whether to show process-name\n");
    printf("    -s|--self             : whether to show process-self\n");
    printf("    -u <pid>|--until=<pid>: stop to show until this pid\n");
    printf("EXAMPLES\n");
    printf("    ppid $$ -u 1 -n -s\n");
}

static bool is_alpha(char *str, int len)
{
    int idx;
    
    for(idx = 0; idx < len; idx++){
        if (isalpha(str[idx]) == 0) {
            return false;
        }
    }

    return true;
}

static bool is_digit(char *str, int len)
{
    int idx;
    
    for(idx = 0; idx < len; idx++){
        if (isdigit(str[idx]) == 0) {
            return false;
        }
    }

    return true;
}

static PID_T get_main_pid()
{
    PID_T pid = 0;

#if defined(__linux__)
    pid = syscall(__NR_gettid);
#elif defined(_WIN32) || defined(__CYGWIN__)
    pid = GetCurrentProcessId();
#endif

    return pid;
}

static PID_T get_ppid(PID_T pid, char *name, int length)
{
    PID_T ppid = 0;
    char pname[NAME_MAX] = {0};
 
#if defined(__linux__)
    char buf[BUFSIZ] = {0};
    struct stat st;
    char path[PATH_MAX] = {0};

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

    if (name) {
        if (strlen(pname) >= length) {
            exit(EXIT_FAILURE);
        }
        memcpy(name, pname, length);
    }
#elif defined(_WIN32) || defined(__CYGWIN__)
    HANDLE hSnapshot = CreateToolhelp32Snapshot(TH32CS_SNAPPROCESS, 0);
    if (hSnapshot != INVALID_HANDLE_VALUE) {
        PROCESSENTRY32 processEntry;
        processEntry.dwSize = sizeof(PROCESSENTRY32);
        if (Process32First(hSnapshot, &processEntry)) {
            do {
                if (processEntry.th32ProcessID == pid) {
                    ppid = processEntry.th32ParentProcessID;
                    if (name) {
                        memcpy(name, processEntry.szExeFile, length);
                    }
                    break;
                }
            } while (Process32Next(hSnapshot, &processEntry));
        }
        CloseHandle(hSnapshot);
    }
#endif

    if(pid == g_stop_pid) {
        return 0;
    }

    return ppid;
}

static void print_ptree(PID_T pid)
{
    int index, fail_cnt;
    PID_T next = pid;

    fail_cnt = 0;
failed:
    while (next > 0) {
        g_ptree[g_tree_index].pid = next;
        next = get_ppid(next, g_ptree[g_tree_index].name, NAME_MAX);
        g_tree_index++;
        if (g_tree_index >= PTREE_MAX_DEPTH) {
            printf("failed: process depth over max(%d)\n", PTREE_MAX_DEPTH);
            exit(EXIT_FAILURE);
        }
    }
    
#if 0//defined(_WIN32) || defined(__CYGWIN__)
    if (g_tree_index <= 1) {
        fail_cnt++;
        if (fail_cnt < 3) {
            g_tree_index = 0;
            next = pid;
            goto failed;
        }
    }
#endif

    index = 0;
    while (index < g_tree_index) {
        if (g_print_name == true) {
            printf("%s[%d]\n", g_ptree[index].name, g_ptree[index].pid);
        } else {
            printf("%d\n", g_ptree[index].pid);
        }
        index++;
    }
}

int main(int argc, char **argv)  
{
    int idx, ret = 0;
    PID_T cpid, ppid;
    bool show_self;
    int opt, option_index;

    char *string = "hvnsu:";
    static struct option long_options[] =
    {
        {"help",    no_argument,       NULL, 'h'},
        {"version", no_argument,       NULL, 'v'},
        {"name",    no_argument,       NULL, 'n'},
        {"self",    no_argument,       NULL, 's'},
        {"until",   required_argument, NULL, 'u'},
    };
    
    cpid = 0;
    show_self = false;
    while((opt = getopt_long(argc, argv, string, long_options, &option_index)) != -1) {
        switch(opt) {
            case 'h':
                help_usage();
                exit(EXIT_SUCCESS);
            case 'v':
                printf("ppid version: %s\n", VERSION);
                exit(EXIT_SUCCESS);
            case 'n':
                g_print_name = true;
                break;
            case 's':
                show_self = true;
                break;
            case 'u':
                if (!optarg) {
                    help_usage();
                    goto error;
                }

                if (is_digit(optarg, strlen(optarg))) {
                    g_stop_pid = strtol(optarg, NULL, 10);
                } else {
                    help_usage();
                    goto error;
                }
                break;
            default:
                help_usage();
                goto error;
        }
    }
    
    memset(g_ptree, 0, PTREE_MAX_DEPTH * sizeof(pid_info_t));

    if (optind < argc) {
        for (idx = optind; idx < argc; idx++) {
            if (is_digit(argv[idx], strlen(argv[idx]))) {
                cpid = strtol(argv[idx], NULL, 10);
                if (show_self) {
                    ppid = cpid;
                } else {
                    ppid = get_ppid(cpid, NULL, 0);
                    if(ppid == 0) {
                        goto error;
                    }
                }

                print_ptree(ppid);
            } else {
                goto error;
            }
        }
    } else {
        if (!cpid) {
            cpid = get_main_pid();
        }

        if (cpid) {
            if (show_self) {
                ppid = cpid;
            } else {
                ppid = get_ppid(cpid, NULL, 0);
                if(ppid == 0) {
                    goto error;
                }
            }

            print_ptree(ppid);
        }
    }

    return 0;
error:
    exit(EXIT_FAILURE);
}
