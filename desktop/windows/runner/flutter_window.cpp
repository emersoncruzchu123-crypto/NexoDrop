#include "flutter_window.h"

#include <optional>
#include <cstdint>
#include <string>
#include <shellapi.h>
#include <flutter/standard_method_codec.h>

#include "flutter/generated_plugin_registrant.h"

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
  history_channel_ =
      std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
          flutter_controller_->engine()->messenger(), "app.nexodrop/history",
          &flutter::StandardMethodCodec::GetInstance());
  history_channel_->SetMethodCallHandler(
      [this](const flutter::MethodCall<flutter::EncodableValue>& call,
             std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
        if (call.method_name() != "open") {
          result->NotImplemented();
          return;
        }
        const auto* arguments = call.arguments()
            ? std::get_if<flutter::EncodableMap>(call.arguments()) : nullptr;
        const std::string* path = nullptr;
        if (arguments) {
          const auto entry = arguments->find(flutter::EncodableValue("id"));
          if (entry != arguments->end()) {
            path = std::get_if<std::string>(&entry->second);
          }
        }
        if (!path || path->empty() || path->size() > 32767 ||
            path->find('\0') != std::string::npos) {
          result->Error("invalid_path", "Archivo no disponible.");
          return;
        }
        const int size = MultiByteToWideChar(CP_UTF8, MB_ERR_INVALID_CHARS,
            path->data(), static_cast<int>(path->size()), nullptr, 0);
        if (size == 0) {
          result->Error("invalid_path", "Ruta no valida.");
          return;
        }
        std::wstring wide_path(static_cast<size_t>(size), L'\0');
        if (MultiByteToWideChar(CP_UTF8, MB_ERR_INVALID_CHARS, path->data(),
            static_cast<int>(path->size()), wide_path.data(), size) != size) {
          result->Error("invalid_path", "Ruta no valida.");
          return;
        }
        const DWORD attributes = GetFileAttributesW(wide_path.c_str());
        if (attributes == INVALID_FILE_ATTRIBUTES ||
            (attributes & FILE_ATTRIBUTE_DIRECTORY)) {
          result->Error("missing_file", "El archivo ya no esta disponible.");
          return;
        }
        // Pass the path as a file, never as a shell command or command arguments.
        SHELLEXECUTEINFOW info = {};
        info.cbSize = static_cast<DWORD>(sizeof(info));
        info.fMask = SEE_MASK_FLAG_NO_UI | SEE_MASK_NOASYNC;
        info.hwnd = GetHandle();
        info.lpVerb = L"open";
        info.lpFile = wide_path.c_str();
        info.nShow = SW_SHOWNORMAL;
        if (!ShellExecuteExW(&info)) {
          result->Error("open_file", "Windows no pudo abrir el archivo.",
              flutter::EncodableValue(static_cast<int64_t>(GetLastError())));
          return;
        }
        result->Success();
      });
  SetChildContent(flutter_controller_->view()->GetNativeWindow());

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
  history_channel_.reset();
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
