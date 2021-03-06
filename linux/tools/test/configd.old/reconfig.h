#ifndef RECONFIG_H
#define RECONFIG_H

extern void init_reconfig(char *upper_name, char *upper_type,
			  char *lower_name, char *lower_type);

extern void cleanup_pipeline(void);

extern void setup_initial_stack(void);
extern void cleanup_stack(void);

extern void insert_and_bind_elem_to_stack(char *type, char *name, size_t len);
extern void remove_and_unbind_elem_from_stack(char *name, size_t len);
extern void copy_pipeline_to_vpipeline(void);
extern void insert_elem_to_stack(char *type, char *name, size_t len);
extern void insert_and_bind_elem_to_vstack(char *type, char *name, size_t len);
extern void commit_vstack(char *appname);
extern void remove_and_unbind_elem_from_vstack(char *type);
extern void remove_elem_from_stack(char *name);
extern void bind_elems_in_stack(char *name1, char *name2);
extern void unbind_elems_in_stack(char *name1, char *name2);
extern void setopt_of_elem_in_stack(char *name, char *opt, size_t len);

extern void reconfig_notify_reliability(int type);
extern void reconfig_reliability(void);
extern void reconfig_notify_privacy(int type);
extern void reconfig_privacy(void);

extern void get_dependencies(char *from_upper, char *to_lower, char ***stack,
			     size_t *len);

extern int init_negotiation(char *fbpfname, char *appname);
extern void reconfig_tell_app(char *appname);

#define MAXS 10
extern void start_negotiation_server(char *fbpfname);
extern void stop_negotiation_server(void);
/* returns index of picked config */
extern int negotiation_client(char sugg[MAXS][256], size_t used, char *fbname);

extern void build_stack_and_hash(char *cfg[MAXS], size_t max);

#endif /* RECONFIG_H */
