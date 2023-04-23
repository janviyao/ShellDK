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

void chomp(char *str)
{
    while(*str != '\0' && *str != '\n') {
        str++;
    }
    *str = '\0';
}

int main(int argc, char *argv[])
{
    char password[128];
    struct spwd *shadow_entry;
    char *pptr, *correct, *supplied, *salt;

    if(argc < 2) {
        DBG();
        return 2;
    }

    /* Read the password from stdin */
    pptr = fgets(password, sizeof(password), stdin);
    if(pptr == NULL) {
        DBG();
        return 2;
    }

    //*pptr = 0; - this was a pretty obvious error
    chomp(pptr);  // this is what was intended above
    //printf("password = %s\n", pptr);

    /* Read the correct hash from the shadow entry */
    shadow_entry = getspnam(argv[1]);
    if(shadow_entry == NULL) {
        DBG();
        return 1;
    }
    correct = shadow_entry->sp_pwdp;

    /* Extract the salt. Remember to free the memory. */
    salt = strdup(correct);
    if(salt == NULL) {
        DBG();
        return 2;
    }

    pptr = strchr(salt + 1, '$');
    if(pptr == NULL) {
        DBG();
        return 2;
    }

    pptr = strchr(pptr + 1, '$');
    if(pptr == NULL) {
        DBG();
        return 2;
    }
    pptr[1] = 0;

    /*Encrypt the supplied password with the salt and compare the results*/
    supplied = crypt(password, salt);
    if(supplied == NULL) {
        DBG();
        return 2;
    }

    if(strcmp(supplied, correct) == 0) {
        //printf("pass\n %s\n %s\n", supplied, correct);
        return (0);
    } else {
        //printf("fail\n %s\n %s\n", supplied, correct);
        return (1);
    }
}
