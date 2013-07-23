/*
 * TODO Copyright 2012 Stefan Kronig <>
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

// include all content analysers
#include "ca_utf8_nonshortest_form.h"


struct fb_ips_priv {
	// private daten von jeder "instanz" des moduls.
	// beim AES Block wäre das z. B. der key.
	idp_t port[2];
	seqlock_t lock;
	// TODO take this value from procfs
	int	header_length; // TODO: = 1;	// in bytes
} ____cacheline_aligned_in_smp;

static ssize_t fb_ips_linearize(struct fblock *fb, uint8_t *binary, size_t len)
// um irgendwas zur hw zu senden muss man dies typischerweise zuerste "linearisieren"
// also aus structs o.ä. Datenstrukturen einen "bit vektor" machen den man in die HW Register / Speicher schreiben kann.
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
// umkehrung von linearize
{
	struct fb_ips_priv *fb_priv;
	/* mem is already flat */
	fb_priv = rcu_dereference_raw(fb->private_data);
	memcpy(fb_priv, binary, sizeof(struct fb_ips_priv));
}

static int fb_ips_netrx(	const struct fblock * const	fb,
                        	struct sk_buff * const     	skb,
                        	enum path_type * const     	dir)
{
  	int drop                    	= 0;	// set this to 1 to drop the packet. Else it will be forwarded. 
//	u8 mask                     	= 1;	
  	unsigned int seq;           	    		
  	struct fb_ips_priv *fb_priv;	    	
//	int i                       	= 0;	
  	unsigned char * ca_start;   	    	// pointer to the start of the payload; Where to start the content analysis.
  	unsigned int ca_length;     	    	// # data payload bytes to be analysed.
  	int ret;                    	    	// return value of functions called by this function.

//	printk(KERN_INFO "[fb_ips] netrx 1\n");





	//	 ____	                                      	_____
	//	/    	hard-coded for debugging. Remove this.	     \
	//	     	moved.                                	
	//	\____	end hardcoded debug stuff.            	_____/
	//
 


	//	 ____	                                                                   	_____
	//	/    	non-shortest form specific stuff. move to separate file / function.	     \
	//	     	moved.                                                             	
	//	\____	non-shortest form specific stuff continues below.                  	_____/
	//	     	                                                                   	





	fb_priv = rcu_dereference_raw(fb->private_data);
	do {
		seq = read_seqbegin(&fb_priv->lock);
		*dir = TYPE_INGRESS; // debug: provides loopback functionality.
		write_next_idp_to_skb(skb, fb->idp, fb_priv->port[*dir]);
		if (fb_priv->port[*dir] == IDP_UNKNOWN)
			drop = 1;
		// printk("IDP to push: %u, path: %u\n", fb_priv->port[*dir], *dir);
		// From FB_Dummy:
		// loop through payload (skb->data, skb->len) and set last bit of every byte to 1
		//printk(KERN_INFO "[fb_ips] received packet!\n");
		//for (i = 0; i < skb->len; i++){
		//	skb->data[i] = skb->data[i] | mask;
		//}
	} while (read_seqretry(&fb_priv->lock, seq));
	printk(KERN_INFO "[fb_ips] received packet!\n");
	printk(KERN_INFO "[fb_ips] perform IPS check here\n");





	// TODO determine memory area where the payload is located (skip header und so)
	ca_start 	= skb->data	+ fb_priv->header_length;
	ca_length	= skb->len 	- fb_priv->header_length;


	// for each test
	// TODO:  irgendwie automatisieren.
	// Momentane Idee:	Der Präprozessor generiert untenstehenden String mit all den &&.
	//                	Jedes includete File fügt seine "main"-Funktion selbst der Liste hinzu.
	//                	
	// Weitere Iden:  	Eine Liste von Funktionen und Header Files (String-Array das dann ausgeführt wird). kA ob das in C geht, bisher nichts gefunden.

	ret = ca_utf8_nonshortest_form(ca_start, ca_length);
	//	|| second_contentanalysis()
	//	|| third_contentanalysis()
	//	etc.


	//	 ____	                                                 	_____
	//	/    	continuation of non-shortest form specific stuff.	     \
	//	     	moved.                                           	
	//	\____	end non-shortest form specific stuff.            	_____/
	//	     	                                                 	


	if (ret==1)
		drop = 1;

  	
  	if (drop) {
  		printk(KERN_INFO "[fb_ips] drop packet1\n");
  		kfree_skb(skb);
  		return PPE_DROPPED;
  	}
//		printk(KERN_INFO "[fb_ips] netrx 2\n");

	return PPE_SUCCESS;
}

static int fb_ips_event(	struct notifier_block *self, 
                        	unsigned long cmd,
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
	fb_priv->header_length = 1; // Added by Stefan
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
	.properties = { // TODO!
		[0] = "reliable", 
		[1] = "privacy" 
	},
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
