#include <stdio.h>  
#include <stdlib.h>  
#include <stdint.h>
#include <stdbool.h>
#include <errno.h>
#include <unistd.h>  
#include <ctype.h>
#include <string.h>

static void help_usage(void)
{
    printf("perror [errno [,...]]\n");
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

int main(int argc, char *argv[])
{
    int idx;
    long erro_num;
    char *erro_str;
    char buf[BUFSIZ];                          \

    if(argc < 2) {
        help_usage();
        return 2;
    }

    for(idx = 1; idx < argc; idx ++) {
        erro_str = argv[idx];
        if (is_digit(erro_str, strlen(erro_str))) {
            erro_num = strtol(erro_str, NULL, 10);
            if (strerror_r(erro_num, buf, BUFSIZ) == 0) {
                printf("%s\n", buf);
            }    
        }
    }

    return 0;
}
