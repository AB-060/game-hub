#include "godot_embed_channel.h"

#include <gdk/gdk.h>
#ifdef GDK_WINDOWING_X11
#include <X11/Xlib.h>
#include <X11/Xatom.h>
#include <gdk/gdkx.h>
#include <gtk/gtkx.h>
#endif

#include <glib.h>
#include <spawn.h>
#include <sys/wait.h>
#include <unistd.h>

#include <cstdlib>
#include <cstring>
#include <string>

namespace {

constexpr char kChannelName[] = "game_hub/linux_godot_embed";

// State for the single embedded Godot child this app supports at a time
// (one football screen embedding one game). Kept as static/global because
// the FlMethodChannel callback API is a plain C function pointer with a
// user_data pointer, and there is only ever one football screen visible.
struct EmbedState {
  GtkFixed* parent_container = nullptr;
  GtkWidget* socket = nullptr;
  GPid child_pid = 0;
  guint poll_source_id = 0;
  gulong plug_added_handler = 0;
};

EmbedState g_state;

void destroy_socket() {
  if (g_state.socket != nullptr) {
    gtk_widget_destroy(g_state.socket);
    g_state.socket = nullptr;
  }
}

void stop_poll() {
  if (g_state.poll_source_id != 0) {
    g_source_remove(g_state.poll_source_id);
    g_state.poll_source_id = 0;
  }
}

#ifdef GDK_WINDOWING_X11
// Walks the X window tree looking for a top-level window whose _NET_WM_PID
// property matches `pid`. This is the reliable fallback for embedding a
// child process's window regardless of whether Godot 4.4 itself supports a
// "reparent into this XID" launch flag (it may not, or the exact flag name
// may differ by version — this polling approach works independent of that).
Window find_window_for_pid(Display* display, Window root, pid_t pid) {
  Atom net_wm_pid = XInternAtom(display, "_NET_WM_PID", True);
  if (net_wm_pid == None) return None;

  Window found = None;
  Window dummy_root, dummy_parent;
  Window* children = nullptr;
  unsigned int n_children = 0;

  if (!XQueryTree(display, root, &dummy_root, &dummy_parent, &children,
                   &n_children)) {
    return None;
  }

  for (unsigned int i = 0; i < n_children && found == None; i++) {
    Atom actual_type;
    int actual_format;
    unsigned long n_items, bytes_after;
    unsigned char* prop = nullptr;

    if (XGetWindowProperty(display, children[i], net_wm_pid, 0, 1, False,
                            XA_CARDINAL, &actual_type, &actual_format,
                            &n_items, &bytes_after, &prop) == Success &&
        prop != nullptr) {
      if (actual_type == XA_CARDINAL && n_items == 1) {
        pid_t window_pid = *reinterpret_cast<unsigned long*>(prop);
        if (window_pid == pid) {
          found = children[i];
        }
      }
      XFree(prop);
    }

    if (found == None) {
      // Recurse into descendants in case the window manager reparented
      // Godot's window under a decoration frame.
      found = find_window_for_pid(display, children[i], pid);
    }
  }

  if (children != nullptr) XFree(children);
  return found;
}

gboolean poll_for_child_window(gpointer user_data) {
  if (g_state.socket == nullptr || g_state.child_pid == 0) {
    g_state.poll_source_id = 0;
    return G_SOURCE_REMOVE;
  }

  GdkDisplay* gdk_display = gtk_widget_get_display(g_state.socket);
  if (!GDK_IS_X11_DISPLAY(gdk_display)) {
    g_warning(
        "linux_godot_embed: not running under X11/XWayland; GtkSocket "
        "embedding is unavailable on native Wayland.");
    g_state.poll_source_id = 0;
    return G_SOURCE_REMOVE;
  }

  Display* xdisplay = GDK_DISPLAY_XDISPLAY(gdk_display);
  Window root = DefaultRootWindow(xdisplay);

  Window child_window = find_window_for_pid(xdisplay, root, g_state.child_pid);
  if (child_window == None) {
    // Not mapped yet; keep polling (bounded by the caller stopping this
    // source on terminate()/dispose).
    return G_SOURCE_CONTINUE;
  }

  gulong socket_id = gtk_socket_get_id(GTK_SOCKET(g_state.socket));
  XReparentWindow(xdisplay, child_window, socket_id, 0, 0);
  XMapWindow(xdisplay, child_window);
  XFlush(xdisplay);

  g_state.poll_source_id = 0;
  return G_SOURCE_REMOVE;
}
#endif  // GDK_WINDOWING_X11

FlMethodResponse* handle_launch(FlValue* args) {
  if (args == nullptr || fl_value_get_type(args) != FL_VALUE_TYPE_MAP) {
    return FL_METHOD_RESPONSE(fl_method_error_response_new(
        "bad_args", "launch expects a map argument", nullptr));
  }

  FlValue* path_value = fl_value_lookup_string(args, "godotBinaryPath");
  FlValue* x_value = fl_value_lookup_string(args, "x");
  FlValue* y_value = fl_value_lookup_string(args, "y");
  FlValue* width_value = fl_value_lookup_string(args, "width");
  FlValue* height_value = fl_value_lookup_string(args, "height");
  if (path_value == nullptr ||
      fl_value_get_type(path_value) != FL_VALUE_TYPE_STRING) {
    return FL_METHOD_RESPONSE(fl_method_error_response_new(
        "bad_args", "launch requires a string godotBinaryPath", nullptr));
  }

  const char* binary_path = fl_value_get_string(path_value);
  if (!g_file_test(binary_path, G_FILE_TEST_IS_EXECUTABLE)) {
    return FL_METHOD_RESPONSE(fl_method_error_response_new(
        "not_found", "Godot Linux export binary not found or not executable",
        args));
  }

  // Tear down any previous embed before starting a new one.
  stop_poll();
  destroy_socket();

  g_state.socket = gtk_socket_new();
  gtk_widget_set_can_focus(g_state.socket, TRUE);
  gtk_fixed_put(g_state.parent_container, g_state.socket,
                x_value ? static_cast<int>(fl_value_get_int(x_value)) : 0,
                y_value ? static_cast<int>(fl_value_get_int(y_value)) : 0);
  int width = width_value ? static_cast<int>(fl_value_get_int(width_value)) : 1;
  int height =
      height_value ? static_cast<int>(fl_value_get_int(height_value)) : 1;
  gtk_widget_set_size_request(g_state.socket, width, height);
  gtk_widget_show(g_state.socket);

  GError* spawn_error = nullptr;
  gchar* argv[] = {const_cast<gchar*>(binary_path), nullptr};
  gboolean spawned = g_spawn_async(
      nullptr, argv, nullptr,
      static_cast<GSpawnFlags>(G_SPAWN_DO_NOT_REAP_CHILD), nullptr, nullptr,
      &g_state.child_pid, &spawn_error);

  if (!spawned) {
    std::string message =
        spawn_error != nullptr ? spawn_error->message : "unknown error";
    if (spawn_error != nullptr) g_error_free(spawn_error);
    destroy_socket();
    return FL_METHOD_RESPONSE(fl_method_error_response_new(
        "spawn_failed", message.c_str(), nullptr));
  }

#ifdef GDK_WINDOWING_X11
  // Poll for the child's top-level window and reparent it into the socket
  // once it appears (Godot needs a moment to create its window after the
  // process starts).
  g_state.poll_source_id =
      g_timeout_add(50, poll_for_child_window, nullptr);
#else
  g_warning(
      "linux_godot_embed: built without X11 support; cannot embed the "
      "Godot window.");
#endif

  return FL_METHOD_RESPONSE(fl_method_success_response_new(nullptr));
}

FlMethodResponse* handle_update_geometry(FlValue* args) {
  if (g_state.socket == nullptr) {
    return FL_METHOD_RESPONSE(fl_method_success_response_new(nullptr));
  }
  if (args == nullptr || fl_value_get_type(args) != FL_VALUE_TYPE_MAP) {
    return FL_METHOD_RESPONSE(fl_method_error_response_new(
        "bad_args", "updateGeometry expects a map argument", nullptr));
  }

  FlValue* x_value = fl_value_lookup_string(args, "x");
  FlValue* y_value = fl_value_lookup_string(args, "y");
  FlValue* width_value = fl_value_lookup_string(args, "width");
  FlValue* height_value = fl_value_lookup_string(args, "height");

  int x = x_value ? static_cast<int>(fl_value_get_int(x_value)) : 0;
  int y = y_value ? static_cast<int>(fl_value_get_int(y_value)) : 0;
  gtk_fixed_move(g_state.parent_container, g_state.socket, x, y);

  if (width_value != nullptr && height_value != nullptr) {
    gtk_widget_set_size_request(
        g_state.socket, static_cast<int>(fl_value_get_int(width_value)),
        static_cast<int>(fl_value_get_int(height_value)));
  }

  return FL_METHOD_RESPONSE(fl_method_success_response_new(nullptr));
}

FlMethodResponse* handle_terminate() {
  stop_poll();
  if (g_state.child_pid != 0) {
    kill(g_state.child_pid, SIGTERM);
    g_spawn_close_pid(g_state.child_pid);
    g_state.child_pid = 0;
  }
  destroy_socket();
  return FL_METHOD_RESPONSE(fl_method_success_response_new(nullptr));
}

void method_call_cb(FlMethodChannel* channel, FlMethodCall* method_call,
                     gpointer user_data) {
  const gchar* method = fl_method_call_get_name(method_call);
  FlValue* args = fl_method_call_get_args(method_call);

  g_autoptr(FlMethodResponse) response = nullptr;
  if (strcmp(method, "launch") == 0) {
    response = handle_launch(args);
  } else if (strcmp(method, "updateGeometry") == 0) {
    response = handle_update_geometry(args);
  } else if (strcmp(method, "terminate") == 0) {
    response = handle_terminate();
  } else {
    response = FL_METHOD_RESPONSE(fl_method_not_implemented_response_new());
  }

  g_autoptr(GError) error = nullptr;
  if (!fl_method_call_respond(method_call, response, &error)) {
    g_warning("linux_godot_embed: failed to send method response: %s",
              error->message);
  }
}

}  // namespace

void godot_embed_channel_setup(FlBinaryMessenger* messenger,
                                GtkFixed* parent_container) {
  g_state.parent_container = parent_container;

  g_autoptr(FlStandardMethodCodec) codec = fl_standard_method_codec_new();
  FlMethodChannel* channel = fl_method_channel_new(
      messenger, kChannelName, FL_METHOD_CODEC(codec));
  fl_method_channel_set_method_call_handler(channel, method_call_cb, nullptr,
                                             nullptr);
}
