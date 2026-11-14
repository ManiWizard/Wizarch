#include <stdio.h>
#include <stdint.h>
#include <string.h>
#include <wayland-client.h>
#include "protocol.h"
static struct zwlr_virtual_pointer_manager_v1 *manager;
static void global(void *data,struct wl_registry *registry,uint32_t name,const char *interface,uint32_t version) {
 if(!strcmp(interface,"zwlr_virtual_pointer_manager_v1"))manager=wl_registry_bind(registry,name,&zwlr_virtual_pointer_manager_v1_interface,1);
}
static void remove_global(void *data,struct wl_registry *r,uint32_t n) {}
int main(){
 struct wl_display *display=wl_display_connect(NULL);if(!display)return 1;
 struct wl_registry *registry=wl_display_get_registry(display);
 struct wl_registry_listener listener={global,remove_global};wl_registry_add_listener(registry,&listener,NULL);wl_display_roundtrip(display);if(!manager)return 2;
 struct zwlr_virtual_pointer_v1 *pointer=zwlr_virtual_pointer_manager_v1_create_virtual_pointer(manager,NULL);
 char line[128];unsigned int x,y,clock=1;
 while(fgets(line,sizeof(line),stdin)){
  if(sscanf(line,"move %u %u",&x,&y)==2)zwlr_virtual_pointer_v1_motion_absolute(pointer,clock++,x,y,1920,1080);
  else if(!strncmp(line,"press",5))zwlr_virtual_pointer_v1_button(pointer,clock++,272,1);
  else if(!strncmp(line,"release",7))zwlr_virtual_pointer_v1_button(pointer,clock++,272,0);
  zwlr_virtual_pointer_v1_frame(pointer);wl_display_roundtrip(display);puts("ok");fflush(stdout);
 }
 zwlr_virtual_pointer_v1_destroy(pointer);wl_display_roundtrip(display);wl_display_disconnect(display);return 0;
}
