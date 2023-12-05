#define _GNU_SOURCE

#include <stdio.h>
#include <stdlib.h>
#include <pwd.h>
#include <shadow.h>
#include <sys/types.h>
#include <unistd.h>
#include <string.h>

#define DBG()                                   \
    do {                                        \
        char buf[100];                          \
        sprintf (buf, "error: %d\n", __LINE__); \
        perror (buf);                           \
    } while (0)

void help(void) 
{
    printf("chk_passwd [usr-name] [usr-password]\n");
}

int main(int argc, char *argv[])
{
    char *usrname, *password;
    struct spwd *shadow_entry;
    char *salt;

    if(argc != 3) {
        help();
        return 2;
    }

    usrname = argv[1];
    password = argv[2];

    /* Read the correct hash from the shadow entry */
    shadow_entry = getspnam(usrname);
    if(shadow_entry == NULL) {
        DBG();
        return 1;
    }
    
    salt = crypt(password, shadow_entry->sp_pwdp);
    if(salt == NULL) {
        DBG();
        return 2;
    }

    if(strcmp(salt, shadow_entry->sp_pwdp) == 0) {
        return 0;
    } else {
        return 1;
    }
}
