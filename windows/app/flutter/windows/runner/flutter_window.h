#ifndef RUNNER_FLUTTER_WINDOW_H_
#define RUNNER_FLUTTER_WINDOW_H_

#include <flutter/dart_project.h>
#include <flutter/encodable_value.h>
#include <flutter/flutter_view_controller.h>
#include <flutter/method_channel.h>
#include <shellapi.h>

#include <memory>

#include "win32_window.h"

// A window that hosts the Flutter view with native Windows Explorer drag-and-drop
// (WM_DROPFILES) and System Tray Quick-Send support.
class FlutterWindow : public Win32Window {
 public:
  // Creates a new FlutterWindow hosting a Flutter view running |project|.
  explicit FlutterWindow(const flutter::DartProject& project);
  virtual ~FlutterWindow();

 protected:
  // Win32Window:
  bool OnCreate() override;
  void OnDestroy() override;
  LRESULT MessageHandler(HWND window, UINT const message, WPARAM const wparam,
                         LPARAM const lparam) noexcept override;

 private:
  void SetupTrayIcon(HWND hwnd);
  void RemoveTrayIcon();
  void ShowTrayContextMenu(HWND hwnd);
  void RestoreAndFocusWindow(HWND hwnd);
  void HandleDroppedFiles(HWND hwnd, HDROP hdrop);

  // The project to run.
  flutter::DartProject project_;

  // The Flutter instance hosted by this window.
  std::unique_ptr<flutter::FlutterViewController> flutter_controller_;

  // MethodChannel for native desktop drag-and-drop and system tray Quick-Send.
  std::unique_ptr<flutter::MethodChannel<flutter::EncodableValue>> desktop_channel_;

  // Windows system tray icon metadata.
  NOTIFYICONDATAW tray_icon_data_{};
  bool tray_icon_added_ = false;
};

#endif  // RUNNER_FLUTTER_WINDOW_H_
