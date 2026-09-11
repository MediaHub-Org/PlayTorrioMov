#include "my_application.h"

#include <flutter_linux/flutter_linux.h>

#include "flutter/generated_plugin_registrant.h"

// The Flatpak's own app-id (flatpak/io.github.MediaHubOrg.PlayTorrioMov.json,
// and every file it exports -- the .desktop entry, the icon). Used to set
// the window's icon directly (gtk_window_set_icon_name, an icon-theme lookup
// by this exact name), as the GApplication's "application-id", and as the
// prgname (see my_application_new) -- on GTK3/Wayland the compositor's
// xdg_toplevel app_id it uses to match a running window to an installed
// .desktop file (for the taskbar icon and "pin to task manager") actually
// comes from gdk_get_program_class(), which defaults to g_get_prgname(), NOT
// from the GApplication "application-id" property; confirmed live after an
// earlier attempt set only the latter and neither the icon nor pinning
// changed. Previously prgname stayed at APPLICATION_ID
// (com.mediahub.playtorriomov) because Flutter's path_provider_linux (and
// shared_preferences_linux) resolve the on-disk data directory from
// whichever of these two properties is authoritative, and changing it would
// have moved every existing install's saved library to an empty directory.
// That coupling is now broken deliberately: lib/main.dart pins both to
// "com.mediahub.playtorriomov" directly, independent of prgname or
// application-id, so both native identifiers are free to match the
// Flatpak's real app-id here.
#define GTK_APPLICATION_ID "io.github.MediaHubOrg.PlayTorrioMov"

struct _MyApplication {
  GtkApplication parent_instance;
  char** dart_entrypoint_arguments;
};

G_DEFINE_TYPE(MyApplication, my_application, GTK_TYPE_APPLICATION)

// Called when first Flutter frame received.
static void first_frame_cb(MyApplication* self, FlView* view) {
  gtk_widget_show(gtk_widget_get_toplevel(GTK_WIDGET(view)));
}

// Implements GApplication::activate.
static void my_application_activate(GApplication* application) {
  MyApplication* self = MY_APPLICATION(application);
  GtkWindow* window =
      GTK_WINDOW(gtk_application_window_new(GTK_APPLICATION(application)));

  // Belt-and-suspenders: set the icon explicitly via the same icon-theme
  // name the Flatpak installs it under, so it doesn't depend on the
  // app_id/.desktop-file matching below working in every compositor.
  gtk_window_set_icon_name(window, GTK_APPLICATION_ID);

  // The stock Flutter template's default here creates a client-side
  // GtkHeaderBar with a hardcoded title and close button -- its own
  // Adwaita-derived chrome, unrelated to and inconsistent with the app's
  // own dark UI, and taller than a plain title bar. It also renders with
  // whatever GTK theme is actually available, which inside a Flatpak
  // sandbox may not be the host's theme at all. The app has no custom
  // in-app window controls (no Flutter-drawn minimize/maximize/close), so
  // window decoration can't be removed outright -- this instead always
  // takes the plain-title-bar path, letting the window manager/compositor
  // draw its own (themed, slimmer) decoration instead of a bespoke CSD bar.
  gtk_window_set_title(window, "PlayTorrioMov");

  gtk_window_set_default_size(window, 1280, 720);

  g_autoptr(FlDartProject) project = fl_dart_project_new();
  fl_dart_project_set_dart_entrypoint_arguments(
      project, self->dart_entrypoint_arguments);

  FlView* view = fl_view_new(project);
  GdkRGBA background_color;
  // Background defaults to black, override it here if necessary, e.g. #00000000
  // for transparent.
  gdk_rgba_parse(&background_color, "#000000");
  fl_view_set_background_color(view, &background_color);
  gtk_widget_show(GTK_WIDGET(view));
  gtk_container_add(GTK_CONTAINER(window), GTK_WIDGET(view));

  // Show the window when Flutter renders.
  // Requires the view to be realized so we can start rendering.
  g_signal_connect_swapped(view, "first-frame", G_CALLBACK(first_frame_cb),
                           self);
  gtk_widget_realize(GTK_WIDGET(view));

  fl_register_plugins(FL_PLUGIN_REGISTRY(view));

  gtk_widget_grab_focus(GTK_WIDGET(view));
}

// Implements GApplication::local_command_line.
static gboolean my_application_local_command_line(GApplication* application,
                                                  gchar*** arguments,
                                                  int* exit_status) {
  MyApplication* self = MY_APPLICATION(application);
  // Strip out the first argument as it is the binary name.
  self->dart_entrypoint_arguments = g_strdupv(*arguments + 1);

  g_autoptr(GError) error = nullptr;
  if (!g_application_register(application, nullptr, &error)) {
    g_warning("Failed to register: %s", error->message);
    *exit_status = 1;
    return TRUE;
  }

  g_application_activate(application);
  *exit_status = 0;

  return TRUE;
}

// Implements GApplication::startup.
static void my_application_startup(GApplication* application) {
  // MyApplication* self = MY_APPLICATION(object);

  // Perform any actions required at application startup.

  G_APPLICATION_CLASS(my_application_parent_class)->startup(application);
}

// Implements GApplication::shutdown.
static void my_application_shutdown(GApplication* application) {
  // MyApplication* self = MY_APPLICATION(object);

  // Perform any actions required at application shutdown.

  G_APPLICATION_CLASS(my_application_parent_class)->shutdown(application);
}

// Implements GObject::dispose.
static void my_application_dispose(GObject* object) {
  MyApplication* self = MY_APPLICATION(object);
  g_clear_pointer(&self->dart_entrypoint_arguments, g_strfreev);
  G_OBJECT_CLASS(my_application_parent_class)->dispose(object);
}

static void my_application_class_init(MyApplicationClass* klass) {
  G_APPLICATION_CLASS(klass)->activate = my_application_activate;
  G_APPLICATION_CLASS(klass)->local_command_line =
      my_application_local_command_line;
  G_APPLICATION_CLASS(klass)->startup = my_application_startup;
  G_APPLICATION_CLASS(klass)->shutdown = my_application_shutdown;
  G_OBJECT_CLASS(klass)->dispose = my_application_dispose;
}

static void my_application_init(MyApplication* self) {}

MyApplication* my_application_new() {
  // Drives gdk_get_program_class(), which GTK3's Wayland backend uses as the
  // xdg_toplevel app_id -- this, not the GApplication "application-id" set
  // below, is what the compositor actually matches against the installed
  // .desktop file's basename for the taskbar icon and "pin to task manager".
  g_set_prgname(GTK_APPLICATION_ID);

  return MY_APPLICATION(g_object_new(my_application_get_type(),
                                     "application-id", GTK_APPLICATION_ID, "flags",
                                     G_APPLICATION_NON_UNIQUE, nullptr));
}
