#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <unistd.h>
#include <errno.h>
#include <fcntl.h>
#include <string.h>
#include <dirent.h>
#include <sys/stat.h>
#include <sys/types.h>

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
    printf("fstat [file-name [,...]]\n");
}

static void get_dir_size(char *dirname, uint32_t *file_cnt, uint64_t *dir_size)
{
    DIR *dir;
    struct dirent *entry;
    struct stat dstate;
    char path[PATH_MAX];

    dir = opendir(dirname);
    if(dir == NULL) {
        printf("open dir: %s failed\n", path);
        exit(-1);
    }

    while((entry = readdir(dir)) != NULL) {
        snprintf(path, (size_t)PATH_MAX, "%s/%s", dirname, entry->d_name);
        if(lstat(path, &dstate) < 0) {
            printf("lstat %s error\n", path);
            exit(-1);
        }

        if(strcmp(entry->d_name, ".") == 0) {
            *dir_size += dstate.st_size;
            continue;
        }

        if(strcmp(entry->d_name, "..") == 0) {
            continue;
        }

        if(entry->d_type == DT_DIR) {
            get_dir_size(path, file_cnt, dir_size);
        } else {
            *file_cnt += 1;
            *dir_size += dstate.st_size;
        }
    }

    closedir(dir);
    return;
}

int main(int argc, char *argv[])
{
    int idx, fd;
    uint32_t count = 0;
    uint64_t size = 0;
    struct stat fstat;

    if(argc < 2) {
        help_usage();
        return -1;
    }

    for(idx = 1; idx < argc; idx ++) {
        if(stat(argv[idx], &fstat) != 0) {
            perror(argv[idx]);
            return -1;
        }

        if(S_ISDIR(fstat.st_mode)) {
            get_dir_size(argv[idx], &count, &size);
        } else {
            fd = open(argv[idx], O_RDONLY);
            if (fd == -1) {
                printf("open %s failed\n", argv[idx]);
                return -1;
            }

            count += 1;
            size += lseek(fd, 0, SEEK_END);
            close(fd);
        }
    }

    printf("%lu %lu\n", count, size);
    return 0;
}
