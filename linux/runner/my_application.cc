#include "my_application.h"

#include <flutter_linux/flutter_linux.h>
#ifdef GDK_WINDOWING_X11
#include <gdk/gdkx.h>
#endif

#include "classic_spp_channel.h"
#include "file_open_channel.h"
#include "flutter/generated_plugin_registrant.h"
#include "desktop_multi_window/desktop_multi_window_plugin.h"
#include "mi_account_2fa_channel.h"
#include "window_setup.h"
#include "zeppos_app_settings_channel.h"

struct _MyApplication {
  GtkApplication parent_instance;
  char** dart_entrypoint_arguments;
};

G_DEFINE_TYPE(MyApplication, my_application, GTK_TYPE_APPLICATION)

// Called when first Flutter frame received.
static void first_frame_cb(MyApplication* self, FlView* view) {
  gtk_widget_show(gtk_widget_get_toplevel(GTK_WIDGET(view)));
}

// Native overlays such as the account and ZeppOS settings WebViews can own
// GTK's keyboard focus. Once an overlay is closed (or the app regains focus
// after opening a browser), Flutter may still receive pointer events without
// its FlView receiving key events. Restore the native focus whenever the user
// clicks back into the Flutter surface. Returning FALSE keeps the event
// available to Flutter for its normal hit testing and text-field focus.
// Implements GApplication::activate.
static void my_application_activate(GApplication* application) {
  MyApplication* self = MY_APPLICATION(application);

  GtkWindow* active_window =
      gtk_application_get_active_window(GTK_APPLICATION(application));
  if (active_window != nullptr) {
    gtk_window_present(active_window);
    return;
  }

  GtkWindow* window =
      GTK_WINDOW(gtk_application_window_new(GTK_APPLICATION(application)));
  oronbox_set_window_icon(window);

  // Use a header bar when running in GNOME as this is the common style used
  // by applications and is the setup most users will be using (e.g. Ubuntu
  // desktop).
  // If running on X and not using GNOME then just use a traditional title bar
  // in case the window manager does more exotic layout, e.g. tiling.
  // If running on Wayland assume the header bar will work (may need changing
  // if future cases occur).
  gboolean use_header_bar = TRUE;
#ifdef GDK_WINDOWING_X11
  GdkScreen* screen = gtk_window_get_screen(window);
  if (GDK_IS_X11_SCREEN(screen)) {
    const gchar* wm_name = gdk_x11_screen_get_window_manager_name(screen);
    if (g_strcmp0(wm_name, "GNOME Shell") != 0) {
      use_header_bar = FALSE;
    }
  }
#endif
  if (use_header_bar) {
    GtkHeaderBar* header_bar = GTK_HEADER_BAR(gtk_header_bar_new());
    gtk_widget_show(GTK_WIDGET(header_bar));
    gtk_header_bar_set_title(header_bar, "oronbox");
    gtk_header_bar_set_show_close_button(header_bar, TRUE);
    gtk_window_set_titlebar(window, GTK_WIDGET(header_bar));
  } else {
    gtk_window_set_title(window, "oronbox");
  }

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
  gtk_widget_add_events(GTK_WIDGET(view), GDK_BUTTON_PRESS_MASK);
  g_signal_connect(view, "button-press-event",
                   G_CALLBACK(oronbox_restore_flutter_focus), nullptr);
  gtk_widget_show(GTK_WIDGET(view));
  GtkOverlay* overlay = GTK_OVERLAY(gtk_overlay_new());
  gtk_widget_show(GTK_WIDGET(overlay));
  gtk_container_add(GTK_CONTAINER(window), GTK_WIDGET(overlay));
  gtk_container_add(GTK_CONTAINER(overlay), GTK_WIDGET(view));

  // Show the window when Flutter renders.
  // Requires the view to be realized so we can start rendering.
  g_signal_connect_swapped(view, "first-frame", G_CALLBACK(first_frame_cb),
                           self);
  gtk_widget_realize(GTK_WIDGET(view));

  fl_register_plugins(FL_PLUGIN_REGISTRY(view));
  desktop_multi_window_plugin_set_window_created_callback([](FlPluginRegistry* registry) {
    fl_register_plugins(registry);
  });
  classic_spp_channel_register(fl_engine_get_binary_messenger(fl_view_get_engine(view)));
  file_open_channel_register(fl_engine_get_binary_messenger(fl_view_get_engine(view)));
  mi_account_2fa_channel_register(
      fl_engine_get_binary_messenger(fl_view_get_engine(view)), overlay);
  zeppos_app_settings_channel_register(
      fl_engine_get_binary_messenger(fl_view_get_engine(view)), overlay);

  gtk_widget_grab_focus(GTK_WIDGET(view));
}

// Implements GApplication::command_line.
static gint my_application_command_line(GApplication* application,
                                        GApplicationCommandLine* command_line) {
  MyApplication* self = MY_APPLICATION(application);

  if (gtk_application_get_active_window(GTK_APPLICATION(application)) ==
      nullptr) {
    gint argc = 0;
    gchar** arguments =
        g_application_command_line_get_arguments(command_line, &argc);
    g_clear_pointer(&self->dart_entrypoint_arguments, g_strfreev);
    self->dart_entrypoint_arguments = g_strdupv(arguments + 1);
    g_strfreev(arguments);
  }

  g_application_activate(application);
  return 0;
}

// Implements GApplication::open — invoked when the user opens a file (e.g.
// double-click in a file manager) with OronBox as the handler. GApplication
// hands over GFile handles; queue each resolved path for the Flutter side.
static void my_application_open(GApplication* application, GFile** files,
                                gint file_count, const gchar* hint) {
  MyApplication* self = MY_APPLICATION(application);
  (void)hint;

  // Make sure the main window exists before forwarding the files.
  GtkWindow* active_window =
      gtk_application_get_active_window(GTK_APPLICATION(application));
  if (active_window == nullptr) {
    g_application_activate(application);
  }

  for (gint i = 0; i < file_count; i++) {
    g_autofree gchar* path = g_file_get_path(files[i]);
    if (path != nullptr) {
      file_open_channel_queue(path);
    }
  }
  file_open_channel_flush();
  (void)self;
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
  G_APPLICATION_CLASS(klass)->command_line = my_application_command_line;
  G_APPLICATION_CLASS(klass)->open = my_application_open;
  G_APPLICATION_CLASS(klass)->startup = my_application_startup;
  G_APPLICATION_CLASS(klass)->shutdown = my_application_shutdown;
  G_OBJECT_CLASS(klass)->dispose = my_application_dispose;
}

static void my_application_init(MyApplication* self) {}

MyApplication* my_application_new(gboolean non_unique) {
  // Set the program name to the application ID, which helps various systems
  // like GTK and desktop environments map this running application to its
  // corresponding .desktop file. This ensures better integration by allowing
  // the application to be recognized beyond its binary name.
  g_set_prgname(APPLICATION_ID);

  GApplicationFlags flags = static_cast<GApplicationFlags>(
      G_APPLICATION_HANDLES_COMMAND_LINE | G_APPLICATION_HANDLES_OPEN);
  if (non_unique) {
    flags = static_cast<GApplicationFlags>(flags | G_APPLICATION_NON_UNIQUE);
  }
  return MY_APPLICATION(g_object_new(my_application_get_type(),
                                     "application-id", APPLICATION_ID, "flags",
                                     flags, nullptr));
}
