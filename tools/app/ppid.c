#include <stdio.h>  
#include <getopt.h>
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

#define VERSION     "1.1"
#define MAX_TMPBUF  128
#define __NR_gettid 186

static bool  g_print_name = false;
static pid_t g_stop_pid = 0;

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

static pid_t get_ppid(pid_t pid, bool show)
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
 
    if (show) {
        if (g_print_name == true) {
            printf("%s[%d]\n", pname, pid);
        } else {
            printf("%d\n", pid);
        }
    }

    if(pid == g_stop_pid) {
        return 0;
    }

    return ppid;
}

static void print_info(int pid)
{
    int ret;

    pid_t next = get_ppid(pid, true);
    if(!next) {
        return;
    }

#if 0
    if(next == 1) {
        /* systemd */
        return;
    } else if(next == 2) {
        /* kthreadd */
        return; 
    }
#endif

    print_info(next);
}

int main(int argc, char **argv)  
{
    int idx, ret = 0;
    pid_t cpid, ppid;
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
 
    if (optind < argc) {
        for (idx = optind; idx < argc; idx++) {
            if (is_digit(argv[idx], strlen(argv[idx]))) {
                cpid = strtol(argv[idx], NULL, 10);
                if (show_self) {
                    ppid = cpid;
                } else {
                    ppid = get_ppid(cpid, false);
                    if(ppid == 0) {
                        goto error;
                    }
                }

                print_info(ppid);
            } else {
                goto error;
            }
        }
    } else {
        if (!cpid) {
            cpid = syscall(__NR_gettid);
        }

        if (cpid) {
            if (show_self) {
                ppid = cpid;
            } else {
                ppid = get_ppid(cpid, false);
                if(ppid == 0) {
                    goto error;
                }
            }

            print_info(ppid);
        }
    }

    return 0;
error:
    exit(EXIT_FAILURE);
}
