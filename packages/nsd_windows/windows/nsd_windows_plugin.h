#ifndef FLUTTER_PLUGIN_NSD_WINDOWS_PLUGIN_H_
#define FLUTTER_PLUGIN_NSD_WINDOWS_PLUGIN_H_

#include "nsd_windows.h"

#include <flutter/method_channel.h>
#include <flutter/plugin_registrar_windows.h>

#include <memory>

namespace nsd_windows {

	class NsdWindowsPlugin : public flutter::Plugin {
	public:
		static void RegisterWithRegistrar(flutter::PluginRegistrarWindows* registrar);

		NsdWindowsPlugin(
			std::unique_ptr<flutter::MethodChannel<flutter::EncodableValue>> methodChannel,
			flutter::PluginRegistrarWindows* registrar,
			HWND dispatchHwnd,
			UINT dispatchMessage);
		virtual ~NsdWindowsPlugin();

		// Disallow copy and assign.
		NsdWindowsPlugin(const NsdWindowsPlugin&) = delete;
		NsdWindowsPlugin& operator=(const NsdWindowsPlugin&) = delete;

	private:

		nsd_windows::NsdWindows nsdWindows;
		flutter::PluginRegistrarWindows* registrar = nullptr;
		int windowProcDelegateId = -1;
	};

}  // namespace nsd_windows

#endif  // FLUTTER_PLUGIN_NSD_WINDOWS_PLUGIN_H_
