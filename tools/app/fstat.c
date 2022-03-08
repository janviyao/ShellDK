#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <unistd.h>
#include <fcntl.h>
#include <string.h>
#include <dirent.h>
#include <sys/stat.h>
#include <sys/types.h>

#define MAX_TMPBUF 1024

void get_dir_size(char *dirname, uint32_t *file_cnt, uint64_t *dir_size)
{
    DIR *dir_ptr;
    struct dirent *dirent_ptr;
    char path[PATH_MAX] = {0};

    dir_ptr = opendir(dirname);
    if(dir_ptr == NULL) {
        printf("open dir_ptr: %s failed\n", path);
        exit(-1);
    }

    while((dirent_ptr = readdir(dir_ptr)) != NULL) {
        struct stat dstate;

        snprintf(path, (size_t)PATH_MAX, "%s/%s", dirname, dirent_ptr->d_name);
        if(lstat(path, &dstate) < 0) {
            printf("lstat %s error\n", path);
            exit(-1);
        }

        if(strcmp(dirent_ptr->d_name, ".") == 0) {
            *dir_size += dstate.st_size;
            continue;
        }

        if(strcmp(dirent_ptr->d_name, "..") == 0) {
            continue;
        }

        if(dirent_ptr->d_type == DT_DIR) {
            get_dir_size(path, file_cnt, dir_size);
        } else {
            *file_cnt += 1;
            *dir_size += dstate.st_size;
        }
    }

    closedir(dir_ptr);
    return;
}

int main(int argc, char *argv[])
{
    int idx;
    int fd = -1;
    uint32_t total_count = 0;
    uint64_t total_size = 0;
    struct stat filestat;

    if(argc < 2) {
        printf("argv < 2\n");
        return -1;
    }
    
    for(idx = 1; idx < argc; idx ++) {
        if(stat(argv[idx], &filestat) != 0) {
            perror(argv[idx]);
            return -1;
        }

        if(S_ISDIR(filestat.st_mode)) {
            get_dir_size(argv[idx], &total_count, &total_size);
        } else {
            fd = open(argv[idx], O_RDONLY);
            if (fd == -1) {
                printf("open %s failed\n", argv[idx]);
                return -1;
            }

            total_count += 1;
            total_size += lseek(fd, 0, SEEK_END);
            close(fd);
        }
    }
     
    printf("%lu %lu\n", total_count, total_size);
    return 0;
}
