#ifndef GODOT_EMBED_CHANNEL_H_
#define GODOT_EMBED_CHANNEL_H_

#include <flutter_linux/flutter_linux.h>
#include <gtk/gtk.h>

G_BEGIN_DECLS

// Registers the 'game_hub/linux_godot_embed' MethodChannel on `messenger`
// and creates a GtkSocket, inserted as a child of `parent_container` at a
// fixed GTK-side position, that Dart can position via launch/updateGeometry
// method calls. `parent_container` must be a GtkFixed (or another container
// that supports absolute child positioning) so the socket can be moved to
// match the Flutter-side widget's on-screen bounds.
//
// This whole mechanism is X11-only: GtkSocket / the XEmbed protocol it
// implements have no Wayland equivalent, and GTK4 removed GtkSocket
// entirely. This app's Linux runner template (linux/CMakeLists.txt) links
// against gtk+-3.0, which still has GtkSocket, so this works as long as the
// session Flutter is running under is X11 or XWayland. Under a pure Wayland
// GDK backend this will fail at runtime; godot_embed_channel_setup() checks
// for this and reports it back over the channel instead of crashing.
void godot_embed_channel_setup(FlBinaryMessenger* messenger,
                                GtkFixed* parent_container);

G_END_DECLS

#endif  // GODOT_EMBED_CHANNEL_H_
