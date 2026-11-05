-- /* ---- 💫 https://github.com/0o0-ct/Pixi-Arch-A 💫 ---- */
-- Variables de entorno globales y GPU (Hyprland 0.57+ Lua)
-- Referencia: https://wiki.hypr.land/configuring/environment-variables/

local home = os.getenv("HOME") or ""
local configDir = home .. "/.config/hypr"
local scriptsDir = configDir .. "/scripts"
local userScripts = configDir .. "/UserScripts"

-- Paths y configuración
hl.env("XDG_CONFIG_HOME", home .. "/.config")
hl.env("HYPR_CONFIG_DIR", configDir)
hl.env("HYPR_SCRIPTS_DIR", scriptsDir)
hl.env("HYPR_USER_SCRIPTS_DIR", userScripts)

-- Compatibilidad Universal de Aplicaciones (Wayland / X11)
hl.env("ELECTRON_OZONE_PLATFORM_HINT", "auto")
hl.env("GDK_BACKEND", "wayland,x11,*")
hl.env("QT_QPA_PLATFORM", "wayland;xcb")
hl.env("QT_AUTO_SCREEN_SCALE_FACTOR", "1")
hl.env("QT_WAYLAND_DISABLE_WINDOWDECORATION", "1")
hl.env("QT_QPA_PLATFORMTHEME", "qt6ct")
hl.env("SDL_VIDEODRIVER", "wayland,x11")
hl.env("CLUTTER_BACKEND", "wayland")

-- Corrección para aplicaciones Java / Swing (Minecraft, JetBrains, NetBeans)
hl.env("_JAVA_AWT_WM_NONREPARENTING", "1")

-- Enrutamiento Aquamarine y Multi-GPU (NVIDIA + Intel iGPU)
hl.env("AQ_DRM_DEVICES", "/dev/dri/card2:/dev/dri/card1")
hl.env("WLR_DRM_DEVICES", "/dev/dri/card2:/dev/dri/card1")
hl.env("LIBVA_DRIVER_NAME", "iHD")
hl.env("__GLX_VENDOR_LIBRARY_NAME", "mesa")
hl.env("__GL_THREADED_OPTIMIZATIONS", "1")
hl.env("__GL_MaxFramesAllowed", "1")
hl.env("__NV_PRIME_RENDER_OFFLOAD", "1")
hl.env("AQ_NO_MODIFIERS", "1")
hl.env("AQ_MGPU_NO_DIRECT", "1")

-- Detección de contenedores
local isContainer = os.getenv("container") ~= nil or
    os.getenv("container_name") ~= nil or
    os.getenv("container_id") ~= nil

if isContainer then
    hl.env("HYPRLAND_INSTANCE_SIGNATURE", "pixi-arch-a-container")
end
