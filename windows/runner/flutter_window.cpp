#include "flutter_window.h"

#include <optional>
#include <utility>

#include "classic_spp_channel.h"
#include "desktop_multi_window/desktop_multi_window_plugin.h"
#include "file_open_channel.h"
#include "flutter/generated_plugin_registrant.h"
#include "mi_account_2fa_channel.h"
#include "zeppos_app_settings_channel.h"

FlutterWindow::FlutterWindow(const flutter::DartProject& project,
                             std::string initial_open_path,
                             bool show_on_first_frame)
    : project_(project),
      show_on_first_frame_(show_on_first_frame),
      initial_open_path_(std::move(initial_open_path)) {}

FlutterWindow::~FlutterWindow() {}

bool FlutterWindow::OnCreate() {
  if (!Win32Window::OnCreate()) {
    return false;
  }

  RECT frame = GetClientArea();

  // The size here must match the window dimensions to avoid unnecessary surface
  // creation / destruction in the startup path.
  flutter_controller_ = std::make_unique<flutter::FlutterViewController>(
      frame.right - frame.left, frame.bottom - frame.top, project_);
  // Ensure that basic setup of the controller was successful.
  if (!flutter_controller_->engine() || !flutter_controller_->view()) {
    return false;
  }
  RegisterPlugins(flutter_controller_->engine());
  DesktopMultiWindowSetWindowCreatedCallback([](void *controller) {
    auto *flutter_view_controller =
        reinterpret_cast<flutter::FlutterViewController *>(controller);
    auto *registry = flutter_view_controller->engine();
    RegisterPlugins(registry);
  });
  RegisterRfcommChannel(flutter_controller_->engine()->messenger());
  RegisterFileOpenChannel(flutter_controller_->engine()->messenger(),
                          initial_open_path_);
  RegisterMiAccountTwoFactorChannel(flutter_controller_->engine()->messenger(),
                                    GetHandle());
  RegisterZeppOsAppSettingsChannel(flutter_controller_->engine()->messenger(),
                                   GetHandle());
  SetChildContent(flutter_controller_->view()->GetNativeWindow());

  if (show_on_first_frame_) {
    flutter_controller_->engine()->SetNextFrameCallback([&]() {
      this->Show();
    });
  }

  // Flutter can complete the first frame before the "show window" callback is
  // registered. The following call ensures a frame is pending to ensure the
  // window is shown. It is a no-op if the first frame hasn't completed yet.
  if (show_on_first_frame_) {
    flutter_controller_->ForceRedraw();
  }

  return true;
}

void FlutterWindow::OnDestroy() {
  CloseZeppOsAppSettings();
  if (flutter_controller_) {
    flutter_controller_ = nullptr;
  }

  Win32Window::OnDestroy();
}

LRESULT
FlutterWindow::MessageHandler(HWND hwnd, UINT const message,
                              WPARAM const wparam,
                              LPARAM const lparam) noexcept {
  // Give Flutter, including plugins, an opportunity to handle window messages.
  if (flutter_controller_) {
    std::optional<LRESULT> result =
        flutter_controller_->HandleTopLevelWindowProc(hwnd, message, wparam,
                                                      lparam);
    if (result) {
      return *result;
    }
  }

  switch (message) {
    case WM_FONTCHANGE:
      flutter_controller_->engine()->ReloadSystemFonts();
      break;
  }

  return Win32Window::MessageHandler(hwnd, message, wparam, lparam);
}
