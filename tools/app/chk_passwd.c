#define _GNU_SOURCE
#include <stdio.h>
#include <stdlib.h>
#include <errno.h>
#include <unistd.h>
#include <string.h>
#include <sys/types.h>
#include <pwd.h>
#include <shadow.h>

#define DEBUG(str)                                             \
    do {                                                       \
        int err = errno;                                       \
        char buf[BUFSIZ];                                      \
        sprintf (buf, "[%s:%d] %s ", __func__, __LINE__, str); \
        errno = err;                                           \
        perror (buf);                                          \
    } while (0)

static void help_usage(void)
{
    printf("chk_passwd [usr-name] [usr-password]\n");
}

int main(int argc, char *argv[])
{
    char *salt;
    char *usrname, *password;
    struct spwd *shadow_entry;

    if(argc != 3) {
        help_usage();
        return 2;
    }

    usrname = argv[1];
    password = argv[2];

    /* Read the correct hash from the shadow entry */
    shadow_entry = getspnam(usrname);
    if(shadow_entry == NULL) {
        DEBUG("user shadow null");
        return 1;
    }

    salt = crypt(password, shadow_entry->sp_pwdp);
    if(salt == NULL) {
        DEBUG("crypt fail");
        return 2;
    }

    if(strcmp(salt, shadow_entry->sp_pwdp) == 0) {
        return 0;
    } else {
        return 1;
    }
}
