#ifndef PROPS_H
#define PROPS_H

#define MAX_PROPS	32

extern void start_property_fetcher(void);
extern void stop_property_fetcher(void);
extern int find_type_by_properties(char name[FBNAMSIZ],
				   enum fblock_props needed[MAX_PROPS],
				   size_t *num);
extern int fbtype_is_available(char name[FBNAMSIZ]);

#endif /* PROPS_H */
