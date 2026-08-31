#include <flutter/dart_project.h>
#include <flutter/flutter_view_controller.h>
#include <windows.h>

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

  FlutterWindow window(project);
  // Get screen dimensions
  int screen_width = GetSystemMetrics(SM_CXSCREEN);
  int screen_height = GetSystemMetrics(SM_CYSCREEN);

  // Set preferred size, but cap it to 90% of the screen size if the screen is smaller
  int window_width = 1440;
  int window_height = 900;

  if (window_width > screen_width * 0.9) {
    window_width = static_cast<int>(screen_width * 0.9);
  }
  if (window_height > screen_height * 0.9) {
    window_height = static_cast<int>(screen_height * 0.9);
  }

  // Center the window on screen
  int origin_x = (screen_width - window_width) / 2;
  int origin_y = (screen_height - window_height) / 2;

  Win32Window::Point origin(origin_x, origin_y);
  Win32Window::Size size(window_width, window_height);
  if (!window.Create(L"PlayTorrioMod", origin, size)) {
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
