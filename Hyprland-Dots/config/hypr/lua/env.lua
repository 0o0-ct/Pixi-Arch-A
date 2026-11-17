-- /* ---- 💫 https://github.com/0o0-ct/Pixi-Arch-A 💫 ---- */
-- Variables de entorno globales y GPU autónomas (Hyprland 0.57+ Lua)
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

-- =========================================================================
-- DETECCIÓN AUTÓNOMA DE HARDWARE Y GPU (Aquamarine / Hyprland 0.57+)
-- =========================================================================

local function read_line(path)
    local f = io.open(path, "r")
    if not f then return nil end
    local line = f:read("*l")
    f:close()
    return line and line:match("^%s*(.-)%s*$")
end

local function file_exists(path)
    local f = io.open(path, "r")
    if f then
        f:close()
        return true
    end
    return false
end

-- Detección de Laptop vs Desktop
local function detect_is_laptop()
    if file_exists("/sys/class/power_supply/BAT0") or
       file_exists("/sys/class/power_supply/BAT1") or
       file_exists("/sys/class/power_supply/BAT2") then
        return true
    end
    local chassis = read_line("/sys/class/dmi/id/chassis_type")
    if chassis then
        local t = tonumber(chassis)
        if t and (t == 8 or t == 9 or t == 10 or t == 11 or t == 12 or t == 14 or t == 31 or t == 32) then
            return true
        end
    end
    return false
end

-- Detección de Máquina Virtual (VM)
local function detect_is_vm()
    local product = read_line("/sys/class/dmi/id/product_name") or ""
    local sys_vendor = read_line("/sys/class/dmi/id/sys_vendor") or ""
    local bios_vendor = read_line("/sys/class/dmi/id/bios_vendor") or ""
    local vm_signatures = { "qemu", "kvm", "virtualbox", "vmware", "hyper-v", "xen", "bochs", "parallels" }
    local combined = (product .. " " .. sys_vendor .. " " .. bios_vendor):lower()
    for _, sig in ipairs(vm_signatures) do
        if combined:find(sig, 1, true) then
            return true
        end
    end
    return false
end

-- Escaneo dinámico de tarjetas DRM en /sys/class/drm/card*
local intel_card = nil
local nvidia_card = nil
local amd_card = nil

for i = 0, 9 do
    local vendor = read_line("/sys/class/drm/card" .. i .. "/device/vendor")
    if vendor then
        local dev = "/dev/dri/card" .. i
        if vendor == "0x8086" and not intel_card then
            intel_card = dev
        elseif vendor == "0x10de" and not nvidia_card then
            nvidia_card = dev
        elseif vendor == "0x1002" and not amd_card then
            amd_card = dev
        end
    end
end

local is_laptop = detect_is_laptop()
local is_vm = detect_is_vm()

-- Configuración autónoma según topología de GPU detectada
if is_vm then
    -- Entorno Virtual: renderizado por software seguro
    hl.env("WLR_RENDERER_ALLOW_SOFTWARE", "1")
    hl.env("WLR_NO_HARDWARE_CURSORS", "1")
elseif is_laptop and nvidia_card and intel_card then
    -- LAPTOP HÍBRIDO Intel + NVIDIA:
    -- Pantalla interna cableada a iGPU (Intel), NVIDIA para render offload
    hl.env("AQ_DRM_DEVICES", intel_card .. ":" .. nvidia_card)
    hl.env("LIBVA_DRIVER_NAME", "iHD")
    hl.env("__GLX_VENDOR_LIBRARY_NAME", "mesa")
    hl.env("__NV_PRIME_RENDER_OFFLOAD", "1")
    hl.env("__GL_THREADED_OPTIMIZATIONS", "1")
    hl.env("__GL_MaxFramesAllowed", "1")
elseif is_laptop and nvidia_card and amd_card then
    -- LAPTOP HÍBRIDO AMD + NVIDIA:
    -- Pantalla interna cableada a iGPU (AMD), NVIDIA para render offload
    hl.env("AQ_DRM_DEVICES", amd_card .. ":" .. nvidia_card)
    hl.env("LIBVA_DRIVER_NAME", "radeonsi")
    hl.env("VDPAU_DRIVER", "radeonsi")
    hl.env("__GLX_VENDOR_LIBRARY_NAME", "mesa")
    hl.env("__NV_PRIME_RENDER_OFFLOAD", "1")
    hl.env("__GL_THREADED_OPTIMIZATIONS", "1")
    hl.env("__GL_MaxFramesAllowed", "1")
elseif nvidia_card then
    -- PC DE ESCRITORIO CON NVIDIA (o Laptop en modo dGPU puro / MUX switch):
    -- Las salidas de video están conectadas directamente a la tarjeta NVIDIA
    hl.env("AQ_DRM_DEVICES", nvidia_card)
    hl.env("LIBVA_DRIVER_NAME", "nvidia")
    hl.env("GBM_BACKEND", "nvidia-drm")
    hl.env("__GLX_VENDOR_LIBRARY_NAME", "nvidia")
    hl.env("NVD_BACKEND", "direct")
    hl.env("__GL_THREADED_OPTIMIZATIONS", "1")
    hl.env("__GL_MaxFramesAllowed", "1")
elseif amd_card then
    -- PC DE ESCRITORIO O LAPTOP SOLO AMD
    hl.env("AQ_DRM_DEVICES", amd_card)
    hl.env("LIBVA_DRIVER_NAME", "radeonsi")
    hl.env("VDPAU_DRIVER", "radeonsi")
    hl.env("__GLX_VENDOR_LIBRARY_NAME", "mesa")
elseif intel_card then
    -- PC DE ESCRITORIO O LAPTOP SOLO INTEL
    hl.env("AQ_DRM_DEVICES", intel_card)
    hl.env("LIBVA_DRIVER_NAME", "iHD")
    hl.env("__GLX_VENDOR_LIBRARY_NAME", "mesa")
end

-- Detección de contenedores
local isContainer = os.getenv("container") ~= nil or
    os.getenv("container_name") ~= nil or
    os.getenv("container_id") ~= nil

if isContainer then
    hl.env("HYPRLAND_INSTANCE_SIGNATURE", "pixi-arch-a-container")
end
