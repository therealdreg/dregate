#include <linux/module.h>
#define INCLUDE_VERMAGIC
#include <linux/build-salt.h>
#include <linux/vermagic.h>
#include <linux/compiler.h>

BUILD_SALT;

MODULE_INFO(vermagic, VERMAGIC_STRING);
MODULE_INFO(name, KBUILD_MODNAME);

__visible struct module __this_module
__section(".gnu.linkonce.this_module") = {
	.name = KBUILD_MODNAME,
	.init = init_module,
#ifdef CONFIG_MODULE_UNLOAD
	.exit = cleanup_module,
#endif
	.arch = MODULE_ARCH_INIT,
};

#ifdef CONFIG_RETPOLINE
MODULE_INFO(retpoline, "Y");
#endif

static const struct modversion_info ____versions[]
__used __section("__versions") = {
	{ 0x60789245, "module_layout" },
	{ 0xb6211199, "param_ops_int" },
	{ 0x68672d4a, "kthread_stop" },
	{ 0xca8ee4cb, "class_unregister" },
	{ 0x9f84b615, "device_destroy" },
	{ 0x76eb0c3, "wake_up_process" },
	{ 0x1f011161, "kthread_bind" },
	{ 0xd179bbf4, "kthread_create_on_node" },
	{ 0x952664c5, "do_exit" },
	{ 0xb3f7646e, "kthread_should_stop" },
	{ 0x1000e51, "schedule" },
	{ 0xf9a482f9, "msleep" },
	{ 0xc959d152, "__stack_chk_fail" },
	{ 0xc8fa02e9, "class_destroy" },
	{ 0xa245f0a2, "device_create" },
	{ 0x6bc3fbc0, "__unregister_chrdev" },
	{ 0x9214df3a, "__class_create" },
	{ 0xf1c5eb3d, "__register_chrdev" },
	{ 0x423ac41c, "try_module_get" },
	{ 0xba4236f5, "module_put" },
	{ 0xc5850110, "printk" },
	{ 0xbdfb6dbb, "__fentry__" },
	{ 0x5b8239ca, "__x86_return_thunk" },
	{ 0x1df2ddaa, "pv_ops" },
};

MODULE_INFO(depends, "");


MODULE_INFO(srcversion, "DE42C5D1BD58EEB55CBB3CB");
