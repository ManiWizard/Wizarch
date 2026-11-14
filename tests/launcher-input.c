// Isolated Wayland keyboard/pointer driver. The runner checks its runtime before use.
#define _GNU_SOURCE
#include <stdio.h>
#include <stdint.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <sys/mman.h>
#include <wayland-client.h>
#include <xkbcommon/xkbcommon.h>
#include "keyboard.h"
#include "protocol.h"
static struct wl_seat *seat;
static struct zwp_virtual_keyboard_manager_v1 *keys;
static struct zwlr_virtual_pointer_manager_v1 *points;
static void global(void *data,struct wl_registry *registry,uint32_t name,const char *interface,uint32_t version) {
 if(!strcmp(interface,"wl_seat"))seat=wl_registry_bind(registry,name,&wl_seat_interface,1);
 if(!strcmp(interface,"zwp_virtual_keyboard_manager_v1"))keys=wl_registry_bind(registry,name,&zwp_virtual_keyboard_manager_v1_interface,1);
 if(!strcmp(interface,"zwlr_virtual_pointer_manager_v1"))points=wl_registry_bind(registry,name,&zwlr_virtual_pointer_manager_v1_interface,1);
}
static void removed(void *data,struct wl_registry *registry,uint32_t name) {}
int main(void) {
 struct wl_display *display=wl_display_connect(NULL);if(!display)return 1;
 struct wl_registry *registry=wl_display_get_registry(display);struct wl_registry_listener listener={global,removed};
 wl_registry_add_listener(registry,&listener,NULL);wl_display_roundtrip(display);if(!keys||!points||!seat)return 2;
 struct zwp_virtual_keyboard_v1 *keyboard=zwp_virtual_keyboard_manager_v1_create_virtual_keyboard(keys,seat);
 struct zwlr_virtual_pointer_v1 *pointer=zwlr_virtual_pointer_manager_v1_create_virtual_pointer(points,NULL);
 struct xkb_context *context=xkb_context_new(XKB_CONTEXT_NO_FLAGS);struct xkb_rule_names names={.layout="us"};
 struct xkb_keymap *map=xkb_keymap_new_from_names(context,&names,XKB_KEYMAP_COMPILE_NO_FLAGS);
 char *keymap=xkb_keymap_get_as_string(map,XKB_KEYMAP_FORMAT_TEXT_V1);size_t size=strlen(keymap)+1;
 int fd=memfd_create("launcher-keymap",0);ftruncate(fd,size);write(fd,keymap,size);
 zwp_virtual_keyboard_v1_keymap(keyboard,WL_KEYBOARD_KEYMAP_FORMAT_XKB_V1,fd,size);close(fd);free(keymap);wl_display_roundtrip(display);
 char line[128];unsigned int x,y,code,button,state,mods,clock=1,extentX=1920,extentY=1080;
 while(fgets(line,sizeof(line),stdin)) {
  if(sscanf(line,"extent %u %u",&x,&y)==2){extentX=x;extentY=y;}
  else if(sscanf(line,"move %u %u",&x,&y)==2)zwlr_virtual_pointer_v1_motion_absolute(pointer,clock++,x,y,extentX,extentY);
  else if(sscanf(line,"button %u %u",&button,&state)==2)zwlr_virtual_pointer_v1_button(pointer,clock++,button,state);
  else if(sscanf(line,"key %u",&code)==1){zwp_virtual_keyboard_v1_key(keyboard,clock++,code,1);zwp_virtual_keyboard_v1_key(keyboard,clock++,code,0);}
  else if(sscanf(line,"mods %u",&mods)==1)zwp_virtual_keyboard_v1_modifiers(keyboard,mods,0,0,0);
  zwlr_virtual_pointer_v1_frame(pointer);wl_display_roundtrip(display);puts("ok");fflush(stdout);
 }
 zwp_virtual_keyboard_v1_destroy(keyboard);zwlr_virtual_pointer_v1_destroy(pointer);wl_display_roundtrip(display);
 xkb_keymap_unref(map);xkb_context_unref(context);wl_display_disconnect(display);return 0;
}
