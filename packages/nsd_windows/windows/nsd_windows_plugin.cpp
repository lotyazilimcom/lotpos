#include "nsd_windows_plugin.h"

// This must be included before many other Windows headers.
#include <windows.h>

// For getPlatformVersion; remove unless needed for your plugin implementation.
#include <VersionHelpers.h>

#include <flutter/method_channel.h>
#include <flutter/plugin_registrar_windows.h>
#include <flutter/standard_method_codec.h>

#include <memory>
#include <sstream>

namespace nsd_windows {

	void NsdWindowsPlugin::RegisterWithRegistrar(flutter::PluginRegistrarWindows* registrar) {
		auto methodChannel = std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
			registrar->messenger(), "com.haberey/nsd", &flutter::StandardMethodCodec::GetInstance());

		HWND viewHwnd = nullptr;
		if (registrar->GetView() != nullptr) {
			viewHwnd = registrar->GetView()->GetNativeWindow();
		}

		// Top-level window handle is required for platform-thread dispatch via WindowProc delegate.
		HWND topLevelHwnd = viewHwnd != nullptr ? GetAncestor(viewHwnd, GA_ROOT) : nullptr;
		UINT dispatchMessage = RegisterWindowMessage(L"com.haberey.nsd_windows.dispatch");

		auto plugin = std::make_unique<NsdWindowsPlugin>(
			std::move(methodChannel),
			registrar,
			topLevelHwnd,
			dispatchMessage);
		registrar->AddPlugin(std::move(plugin));
	}

	NsdWindowsPlugin::NsdWindowsPlugin(
		std::unique_ptr<flutter::MethodChannel<flutter::EncodableValue>> methodChannel,
		flutter::PluginRegistrarWindows* registrar,
		HWND dispatchHwnd,
		UINT dispatchMessage)
		: nsdWindows(std::move(methodChannel), dispatchHwnd, dispatchMessage)
	{
		this->registrar = registrar;
		if (this->registrar != nullptr) {
			windowProcDelegateId = this->registrar->RegisterTopLevelWindowProcDelegate(
				[this](HWND hwnd, UINT message, WPARAM wparam, LPARAM lparam) -> std::optional<LRESULT> {
					return nsdWindows.HandleWindowProc(hwnd, message, wparam, lparam);
				});
		}
	}

	NsdWindowsPlugin::~NsdWindowsPlugin() {
		if (registrar != nullptr && windowProcDelegateId != -1) {
			registrar->UnregisterTopLevelWindowProcDelegate(windowProcDelegateId);
		}
	};

}  // namespace nsd_windows
