#include "flutter_window.h"

#include <flutter/standard_method_codec.h>
#include <optional>
#include <string>
#include <vector>

#include "flutter/generated_plugin_registrant.h"
#include "resource.h"

namespace {
constexpr UINT kTrayIconCallbackMessage = WM_APP + 101;
constexpr UINT kTrayIconId = 1001;
constexpr UINT_PTR kTrayMenuOpen = 2001;
constexpr UINT_PTR kTrayMenuQuickSend = 2002;
constexpr UINT_PTR kTrayMenuExit = 2003;

std::string WideToUtf8(const std::wstring& wide) {
  if (wide.empty()) return {};
  int size_needed = WideCharToMultiByte(
      CP_UTF8, 0, wide.c_str(), static_cast<int>(wide.size()), nullptr, 0,
      nullptr, nullptr);
  if (size_needed <= 0) return {};
  std::string result(size_needed, '\0');
  WideCharToMultiByte(CP_UTF8, 0, wide.c_str(), static_cast<int>(wide.size()),
                      result.data(), size_needed, nullptr, nullptr);
  return result;
}
}  // namespace

FlutterWindow::FlutterWindow(const flutter::DartProject& project)
    : project_(project) {}

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
  SetChildContent(flutter_controller_->view()->GetNativeWindow());

  // Set up MethodChannel for native Explorer drag-and-drop & System Tray Quick-Send
  desktop_channel_ =
      std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
          flutter_controller_->engine()->messenger(),
          "org.peerlink/desktop_shell",
          &flutter::StandardMethodCodec::GetInstance());

  // Enable Windows Explorer drag-and-drop directly onto the PeerLink window
  DragAcceptFiles(GetHandle(), TRUE);

  // Register minimalist Windows System Tray icon for Quick-Send
  SetupTrayIcon(GetHandle());

  flutter_controller_->engine()->SetNextFrameCallback([&]() {
    this->Show();
  });

  // Flutter can complete the first frame before the "show window" callback is
  // registered. The following call ensures a frame is pending to ensure the
  // window is shown. It is a no-op if the first frame hasn't completed yet.
  flutter_controller_->ForceRedraw();

  return true;
}

void FlutterWindow::OnDestroy() {
  RemoveTrayIcon();
  desktop_channel_ = nullptr;
  if (flutter_controller_) {
    flutter_controller_ = nullptr;
  }

  Win32Window::OnDestroy();
}

void FlutterWindow::SetupTrayIcon(HWND hwnd) {
  ZeroMemory(&tray_icon_data_, sizeof(tray_icon_data_));
  tray_icon_data_.cbSize = sizeof(NOTIFYICONDATAW);
  tray_icon_data_.hWnd = hwnd;
  tray_icon_data_.uID = kTrayIconId;
  tray_icon_data_.uFlags = NIF_ICON | NIF_MESSAGE | NIF_TIP;
  tray_icon_data_.uCallbackMessage = kTrayIconCallbackMessage;
  tray_icon_data_.hIcon = LoadIcon(GetModuleHandle(nullptr), MAKEINTRESOURCE(IDI_APP_ICON));
  if (!tray_icon_data_.hIcon) {
    tray_icon_data_.hIcon = LoadIcon(nullptr, IDI_APPLICATION);
  }
  wcsncpy_s(tray_icon_data_.szTip, L"PeerLink — Drop files or right-click to Quick-Send", _TRUNCATE);
  tray_icon_added_ = Shell_NotifyIconW(NIM_ADD, &tray_icon_data_) == TRUE;
}

void FlutterWindow::RemoveTrayIcon() {
  if (tray_icon_added_) {
    Shell_NotifyIconW(NIM_DELETE, &tray_icon_data_);
    tray_icon_added_ = false;
  }
}

void FlutterWindow::RestoreAndFocusWindow(HWND hwnd) {
  if (IsIconic(hwnd)) {
    ShowWindow(hwnd, SW_RESTORE);
  } else {
    ShowWindow(hwnd, SW_SHOW);
  }
  SetForegroundWindow(hwnd);
}

void FlutterWindow::ShowTrayContextMenu(HWND hwnd) {
  POINT pt;
  GetCursorPos(&pt);
  HMENU menu = CreatePopupMenu();
  if (!menu) return;

  AppendMenuW(menu, MF_STRING, kTrayMenuOpen, L"Open PeerLink");
  AppendMenuW(menu, MF_STRING, kTrayMenuQuickSend, L"Quick-Send Files...");
  AppendMenuW(menu, MF_SEPARATOR, 0, nullptr);
  AppendMenuW(menu, MF_STRING, kTrayMenuExit, L"Exit PeerLink");

  SetForegroundWindow(hwnd);
  UINT cmd = TrackPopupMenu(menu, TPM_RETURNCMD | TPM_NONOTIFY | TPM_RIGHTBUTTON,
                            pt.x, pt.y, 0, hwnd, nullptr);
  DestroyMenu(menu);

  if (cmd == kTrayMenuOpen) {
    RestoreAndFocusWindow(hwnd);
  } else if (cmd == kTrayMenuQuickSend) {
    RestoreAndFocusWindow(hwnd);
    if (desktop_channel_) {
      desktop_channel_->InvokeMethod("onTrayQuickSend", nullptr);
    }
  } else if (cmd == kTrayMenuExit) {
    RemoveTrayIcon();
    PostQuitMessage(0);
  }
}

void FlutterWindow::HandleDroppedFiles(HWND hwnd, HDROP hdrop) {
  UINT count = DragQueryFileW(hdrop, 0xFFFFFFFF, nullptr, 0);
  flutter::EncodableList dropped_paths;
  for (UINT i = 0; i < count; ++i) {
    UINT len = DragQueryFileW(hdrop, i, nullptr, 0);
    if (len == 0) continue;
    std::wstring path_buf(len + 1, L'\0');
    DragQueryFileW(hdrop, i, path_buf.data(), len + 1);
    path_buf.resize(len);
    std::string utf8 = WideToUtf8(path_buf);
    if (!utf8.empty()) {
      dropped_paths.push_back(flutter::EncodableValue(utf8));
    }
  }
  DragFinish(hdrop);

  if (!dropped_paths.empty()) {
    RestoreAndFocusWindow(hwnd);
    if (desktop_channel_) {
      desktop_channel_->InvokeMethod(
          "onFilesDropped",
          std::make_unique<flutter::EncodableValue>(dropped_paths));
    }
  }
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
    case WM_DROPFILES:
      HandleDroppedFiles(hwnd, reinterpret_cast<HDROP>(wparam));
      return 0;
    case kTrayIconCallbackMessage:
      if (lparam == WM_LBUTTONUP || lparam == WM_LBUTTONDBLCLK) {
        RestoreAndFocusWindow(hwnd);
      } else if (lparam == WM_RBUTTONUP || lparam == WM_CONTEXTMENU) {
        ShowTrayContextMenu(hwnd);
      }
      return 0;
  }

  return Win32Window::MessageHandler(hwnd, message, wparam, lparam);
}
