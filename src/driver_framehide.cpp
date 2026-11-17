// driver_framehide: a device-less SteamVR driver that hides the controller models by pointing each
// controller's render model at an invisible copy, and puts the original back on request.
//
// By default the models are hidden only while SteamVR's passthrough (room view) is on.
// ~/.local/state/framehide/mode can say "always" or "off" instead (set by the framehide command).
// Only Prop_RenderModelName_String is touched; tracking and input are left alone.
#include <stdarg.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/stat.h>
#include <time.h>

#include <chrono>
#include <string>

#include "openvr_driver.h"

namespace {

std::string StateDir() {
  const char *home = getenv("HOME");
  return std::string(home ? home : "/home/steamos") + "/.local/state/framehide";
}

void Log(const char *fmt, ...) {
  char line[600];
  va_list ap;
  va_start(ap, fmt);
  vsnprintf(line, sizeof line, fmt, ap);
  va_end(ap);
  if (vr::VRDriverLog()) vr::VRDriverLog()->Log(line);
  if (FILE *f = fopen((StateDir() + "/driver.log").c_str(), "a")) {
    time_t t = time(nullptr);
    char ts[32];
    strftime(ts, sizeof ts, "%F %T", localtime(&t));
    fprintf(f, "%s %s\n", ts, line);
    fclose(f);
  }
}

// Mode, from ~/.local/state/framehide/mode: "passthrough" (default), "always" or "off".
std::string Mode() {
  std::string mode = "passthrough";
  if (FILE *f = fopen((StateDir() + "/mode").c_str(), "r")) {
    char buf[32] = "";
    if (fgets(buf, sizeof buf, f)) {
      mode = buf;
      while (!mode.empty() && (mode.back() == '\n' || mode.back() == ' ')) mode.pop_back();
    }
    fclose(f);
  }
  return mode;
}

// SteamVR's own room view (passthrough) switch: it sets camera/enableConstructRoomView to true when
// passthrough is turned on and removes it (default false) when it is turned off.
bool PassthroughOn() {
  vr::EVRSettingsError err = vr::VRSettingsError_None;
  const bool on = vr::VRSettings()->GetBool(vr::k_pch_Camera_Section, "enableConstructRoomView", &err);
  return err == vr::VRSettingsError_None && on;
}

bool WantHidden(const std::string &mode, bool passthrough) {
  if (mode == "always") return true;
  if (mode == "off") return false;
  return passthrough;
}

const char kOurPrefix[] = "{framehide}";

// What we know about one tracked device slot.
struct Slot {
  std::string original;  // the controller's own render model name, once seen
};

class Provider : public vr::IServerTrackedDeviceProvider {
 public:
  vr::EVRInitError Init(vr::IVRDriverContext *ctx) override {
    VR_INIT_SERVER_DRIVER_CONTEXT(ctx);
    mkdir((StateDir()).c_str(), 0755);
    Log("framehide: loaded (test build)");
    return vr::VRInitError_None;
  }

  void Cleanup() override {
    // Leave every controller with its own model when SteamVR shuts down.
    for (uint32_t i = 0; i < vr::k_unMaxTrackedDeviceCount; i++) Apply(i, false);
    Log("framehide: cleanup, originals restored");
    VR_CLEANUP_SERVER_DRIVER_CONTEXT();
  }

  const char *const *GetInterfaceVersions() override { return vr::k_InterfaceVersions; }

  void RunFrame() override {
    auto now = std::chrono::steady_clock::now();
    if (now - last_ < std::chrono::milliseconds(250)) return;
    last_ = now;
    const std::string mode = Mode();
    const bool passthrough = PassthroughOn();
    const bool hide = WantHidden(mode, passthrough);
    if (hide != lastWant_ || mode != lastMode_)
      Log("framehide: mode %s, passthrough %s -> %s", mode.c_str(), passthrough ? "on" : "off", hide ? "HIDE" : "SHOW");
    lastWant_ = hide;
    lastMode_ = mode;
    for (uint32_t i = 1; i < vr::k_unMaxTrackedDeviceCount; i++) Apply(i, hide);
  }

  bool ShouldBlockStandbyMode() override { return false; }
  void EnterStandby() override {}
  void LeaveStandby() override {}

 private:
  // Sets device i to the hidden or original model, if it is a Frame controller.
  void Apply(uint32_t i, bool hide) {
    vr::PropertyContainerHandle_t c = vr::VRProperties()->TrackedDeviceToPropertyContainer(i);
    if (c == vr::k_ulInvalidPropertyContainer) return;
    vr::ETrackedPropertyError err = vr::TrackedProp_Success;
    std::string cur = vr::VRProperties()->GetStringProperty(c, vr::Prop_RenderModelName_String, &err);
    if (err != vr::TrackedProp_Success || cur.empty()) return;

    Slot &s = slots_[i];
    const bool ours = cur.rfind(kOurPrefix, 0) == 0;
    if (!ours) {
      // Only Frame controllers; anything else (HMD, trackers) is left alone.
      if (cur.find("frame_controller_left") == std::string::npos &&
          cur.find("frame_controller_right") == std::string::npos)
        return;
      if (s.original != cur) {
        if (!s.original.empty()) Log("framehide: device %u model changed by its driver to %s", i, cur.c_str());
        s.original = cur;
      }
    }
    if (s.original.empty()) return;

    const bool left = s.original.find("_left") != std::string::npos;
    const std::string target = hide ? std::string(kOurPrefix) + (left ? "framehide_left" : "framehide_right") : s.original;
    if (cur == target) return;

    vr::ETrackedPropertyError setErr = vr::VRProperties()->SetStringProperty(c, vr::Prop_RenderModelName_String, target.c_str());
    std::string back = vr::VRProperties()->GetStringProperty(c, vr::Prop_RenderModelName_String, &err);
    Log("framehide: device %u %s -> %s (set result %d, reads back %s)", i, cur.c_str(), target.c_str(), (int)setErr,
        back.c_str());
  }

  Slot slots_[vr::k_unMaxTrackedDeviceCount];
  std::chrono::steady_clock::time_point last_{};
  bool lastWant_ = false;
  std::string lastMode_;
};

Provider g_provider;

}  // namespace

extern "C" __attribute__((visibility("default"))) void *HmdDriverFactory(const char *name, int *ret) {
  if (strcmp(name, vr::IServerTrackedDeviceProvider_Version) == 0) return &g_provider;
  if (ret) *ret = vr::VRInitError_Init_InterfaceNotFound;
  return nullptr;
}
