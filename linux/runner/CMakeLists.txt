cmake_minimum_required(VERSION 3.13)
project(runner LANGUAGES CXX)

# Define the application target. To change its name, change BINARY_NAME in the
# top-level CMakeLists.txt, not the value here, or `flutter run` will no longer
# work.
#
# Any new source files that you add to the application should be added here.
add_executable(${BINARY_NAME}
  "main.cc"
  "my_application.cc"
  "../godot_embed/godot_embed_channel.cc"
  "${FLUTTER_MANAGED_DIR}/generated_plugin_registrant.cc"
)

# Apply the standard set of build settings. This can be removed for applications
# that need different build settings.
apply_standard_settings(${BINARY_NAME})

# Add preprocessor definitions for the application ID.
add_definitions(-DAPPLICATION_ID="${APPLICATION_ID}")

# Add dependency libraries. Add any application-specific dependencies here.
target_link_libraries(${BINARY_NAME} PRIVATE flutter)
target_link_libraries(${BINARY_NAME} PRIVATE PkgConfig::GTK)

# Xlib, for godot_embed/godot_embed_channel.cc's direct XQueryTree/
# XReparentWindow calls used to reparent the spawned Godot process's window
# into a GtkSocket. X11-only: see godot_embed_channel.h for the Wayland
# caveat.
find_package(X11 REQUIRED)
target_link_libraries(${BINARY_NAME} PRIVATE ${X11_LIBRARIES})
target_include_directories(${BINARY_NAME} PRIVATE ${X11_INCLUDE_DIR})

target_include_directories(${BINARY_NAME} PRIVATE "${CMAKE_SOURCE_DIR}")
