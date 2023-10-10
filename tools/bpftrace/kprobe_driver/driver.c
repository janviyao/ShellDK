#include <linux/module.h>
#include <linux/ptrace.h>
#include <linux/uprobes.h>
#include <linux/namei.h>
#include <linux/moduleparam.h>

MODULE_AUTHOR("john doe");
MODULE_LICENSE("GPL v2");

static char *filename;
module_param(filename, charp, S_IRUGO);

static long offset;
module_param(offset, long, S_IRUGO);

static int handler_pre(struct uprobe_consumer *self, struct pt_regs *regs){
        pr_info("handler: arg0 = %d arg1 =%d \n", (int)regs->di, (int)regs->si);
        return 0;
}

static int handler_ret(struct uprobe_consumer *self,
                                unsigned long func,
                                struct pt_regs *regs){
        pr_info("ret_handler ret = %d \n", (int)regs->ax);
        return 0;
}

static struct uprobe_consumer uc = {
        .handler = handler_pre,
        .ret_handler = handler_ret,
};


static struct inode *inode;

static int __init uprobe_init(void) {
        struct path path;
        int ret;

        ret = kern_path(filename, LOOKUP_FOLLOW, &path);
        if (ret < 0) {
                pr_err("kern_path failed, returned %d\n", ret);
                return ret;
        }

        inode = igrab(path.dentry->d_inode);
        path_put(&path);

        ret = uprobe_register(inode, offset, &uc);
        if (ret < 0) {
                pr_err("register_uprobe failed, returned %d\n", ret);
                return ret;
        }

        return 0;
}

static void __exit uprobe_exit(void) {
        uprobe_unregister(inode, offset, &uc);
}

module_init(uprobe_init);
module_exit(uprobe_exit);
