/*
 * Copyright 2012 Daniel Borkmann <dborkma@tik.ee.ethz.ch>
 */

#include <linux/kernel.h>
#include <linux/module.h>
#include <linux/spinlock.h>
#include <linux/notifier.h>
#include <linux/rcupdate.h>
#include <linux/seqlock.h>
#include <linux/prefetch.h>

#include "xt_fblock.h"
#include "xt_engine.h"

struct fb_ips_priv {
	idp_t port[2];
	seqlock_t lock;
} ____cacheline_aligned_in_smp;

static ssize_t fb_ips_linearize(struct fblock *fb, uint8_t *binary, size_t len)
{
	struct fb_ips_priv *fb_priv;

	if (len < sizeof(struct fb_ips_priv))
		return -ENOMEM;

	/* mem is already flat */
	fb_priv = rcu_dereference_raw(fb->private_data);
	memcpy(binary, fb_priv, sizeof(struct fb_ips_priv));

	return sizeof(struct fb_ips_priv);
}

static void fb_ips_delinearize(struct fblock *fb, uint8_t *binary, size_t len)
{
	struct fb_ips_priv *fb_priv;
	/* mem is already flat */
	fb_priv = rcu_dereference_raw(fb->private_data);
	memcpy(fb_priv, binary, sizeof(struct fb_ips_priv));
}

static int fb_ips_netrx(const struct fblock * const fb,
			  struct sk_buff * const skb,
			  enum path_type * const dir)
{
  	int drop = 0;
//	u8 mask = 1;
  	unsigned int seq;
  	struct fb_ips_priv *fb_priv;
//	int i = 0;
//	printk(KERN_INFO "[fb_ips] netrx 1\n");

  	fb_priv = rcu_dereference_raw(fb->private_data);
  	do {
  		seq = read_seqbegin(&fb_priv->lock);
  		*dir = TYPE_INGRESS; // debug: provides loopback functionality.
  		write_next_idp_to_skb(skb, fb->idp, fb_priv->port[*dir]);
  		if (fb_priv->port[*dir] == IDP_UNKNOWN)
  			drop = 1;
//		printk("IDP to push: %u, path: %u\n", fb_priv->port[*dir], *dir);
  		//TODO: loop through payload (skb->data, skb->len) and set last bit of every byte to 1
  	 //printk(KERN_INFO "[fb_ips] received packet!\n");
  	 //for (i = 0; i < skb->len; i++){
  	 //		skb->data[i] = skb->data[i] | mask;
  	// 	}
  	} while (read_seqretry(&fb_priv->lock, seq));
  	printk(KERN_INFO "[fb_ips] received packet!\n");
  	printk(KERN_INFO "[fb_ips] perform IPS check here\n");
  	
  	if (drop) {
  		printk(KERN_INFO "[fb_ips] drop packet1\n");
  		kfree_skb(skb);
  		return PPE_DROPPED;
  	}
//		printk(KERN_INFO "[fb_ips] netrx 2\n");

	return PPE_SUCCESS;
}

static int fb_ips_event(struct notifier_block *self, unsigned long cmd,
			  void *args)
{
	int ret = NOTIFY_OK;
	struct fblock *fb;
	struct fb_ips_priv *fb_priv;

	rcu_read_lock();
	fb = rcu_dereference_raw(container_of(self, struct fblock_notifier, nb)->self);
	fb_priv = rcu_dereference_raw(fb->private_data);
	rcu_read_unlock();

	switch (cmd) {
	case FBLOCK_BIND_IDP: {
		struct fblock_bind_msg *msg = args;
		if (fb_priv->port[msg->dir] == IDP_UNKNOWN) {
			write_seqlock(&fb_priv->lock);
			fb_priv->port[msg->dir] = msg->idp;
			write_sequnlock(&fb_priv->lock);
		} else {
			ret = NOTIFY_BAD;
		}
		break; }
	case FBLOCK_UNBIND_IDP: {
		struct fblock_bind_msg *msg = args;
		if (fb_priv->port[msg->dir] == msg->idp) {
			write_seqlock(&fb_priv->lock);
			fb_priv->port[msg->dir] = IDP_UNKNOWN;
			write_sequnlock(&fb_priv->lock);
		} else {
			ret = NOTIFY_BAD;
		}
		break; }
	default:
		break;
	}

	return ret;
}

static struct fblock *fb_ips_ctor(char *name)
{
	int ret = 0;
	struct fblock *fb;
	struct fb_ips_priv *fb_priv;

	fb = alloc_fblock(GFP_ATOMIC);
	if (!fb)
		return NULL;
	fb_priv = kzalloc(sizeof(*fb_priv), GFP_ATOMIC);
	if (!fb_priv)
		goto err;
	seqlock_init(&fb_priv->lock);
	fb_priv->port[0] = IDP_UNKNOWN;
	fb_priv->port[1] = IDP_UNKNOWN;
	ret = init_fblock(fb, name, fb_priv);
	if (ret)
		goto err2;
	fb->netfb_rx = fb_ips_netrx;
	fb->event_rx = fb_ips_event;
	fb->linearize = fb_ips_linearize;
	fb->delinearize = fb_ips_delinearize;
	ret = register_fblock_namespace(fb);
	if (ret)
		goto err3;
	__module_get(THIS_MODULE);

	return fb;
err3:
	cleanup_fblock_ctor(fb);
err2:
	kfree(fb_priv);
err:
	kfree_fblock(fb);
	return NULL;
}

static void fb_ips_dtor(struct fblock *fb)
{
	kfree(rcu_dereference_raw(fb->private_data));
	module_put(THIS_MODULE);
}

static struct fblock_factory fb_ips_factory = {
	.type = "ch.ethz.csg.ips",
	.mode = MODE_DUAL,
	.ctor = fb_ips_ctor,
	.dtor = fb_ips_dtor,
	.owner = THIS_MODULE,
	.properties = { [0] = "reliable", [1] = "privacy" },
};

static int __init init_fb_ips_module(void)
// __init: The kernel can [...] free up used memory resources after [initialisation].
{
	return register_fblock_type(&fb_ips_factory);
}

static void __exit cleanup_fb_ips_module(void)
// __exit: Will not even be loaded when the module is compiled into the kernel or the kernel disallows unloading of modules.
{
	synchronize_rcu();
	unregister_fblock_type(&fb_ips_factory);
}

module_init(init_fb_ips_module); // called on insmod
module_exit(cleanup_fb_ips_module); // called on rmmod

MODULE_LICENSE("GPL");
MODULE_AUTHOR("Stefan Kronig <kronigs@ee.ethz.ch>");
MODULE_DESCRIPTION("LANA ips/test module");
