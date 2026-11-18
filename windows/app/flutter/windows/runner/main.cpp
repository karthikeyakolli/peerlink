#include <flutter/dart_project.h>
#include <flutter/flutter_view_controller.h>
#include <windows.h>
#include <shobjidl.h>

#include "flutter_window.h"
#include "utils.h"

int APIENTRY wWinMain(_In_ HINSTANCE instance, _In_opt_ HINSTANCE prev,
                      _In_ wchar_t *command_line, _In_ int show_command) {
  // Attach to console when present (e.g., 'flutter run') or create a
  // new console when running with a debugger.
  if (!::AttachConsole(ATTACH_PARENT_PROCESS) && ::IsDebuggerPresent()) {
    CreateAndAttachConsole();
  }

  // Initialize COM, so that it is available for use in the library and/or
  // plugins.
  ::CoInitializeEx(nullptr, COINIT_APARTMENTTHREADED);

  flutter::DartProject project(L"data");

  std::vector<std::string> command_line_arguments =
      GetCommandLineArguments();

  project.set_dart_entrypoint_arguments(std::move(command_line_arguments));

  // Set explicit Win32 AppUserModelID for taskbar pinning and notification routing
  ::SetCurrentProcessExplicitAppUserModelID(L"PeerLink.Desktop.v1");

  FlutterWindow window(project);

  // Center window on primary monitor with responsive default dimensions
  const int screenWidth = ::GetSystemMetrics(SM_CXSCREEN);
  const int screenHeight = ::GetSystemMetrics(SM_CYSCREEN);
  const int windowWidth = 1280;
  const int windowHeight = 800;
  const int originX = (screenWidth > windowWidth) ? (screenWidth - windowWidth) / 2 : 40;
  const int originY = (screenHeight > windowHeight) ? (screenHeight - windowHeight) / 2 : 40;

  Win32Window::Point origin(originX, originY);
  Win32Window::Size size(windowWidth, windowHeight);
  if (!window.Create(L"PeerLink — Decentralized Personal Data Network", origin, size)) {
    return EXIT_FAILURE;
  }
  window.SetQuitOnClose(true);

  ::MSG msg;
  while (::GetMessage(&msg, nullptr, 0, 0)) {
    ::TranslateMessage(&msg);
    ::DispatchMessage(&msg);
  }

  ::CoUninitialize();
  return EXIT_SUCCESS;
}
