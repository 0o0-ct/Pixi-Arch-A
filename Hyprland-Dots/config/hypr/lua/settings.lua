-- /* ---- 💫 https://github.com/0o0-ct/Pixi-Arch-A 💫 ---- */
-- Opciones de sistema: input, general, misc, gestures, layout (Hyprland 0.57+)

hl.config({
    input = {
        kb_layout = "es,us",
        kb_variant = "",
        kb_model = "",
        kb_options = "grp:alt_shift_toggle",
        kb_rules = "",
        repeat_rate = 50,
        repeat_delay = 300,
        numlock_by_default = true,
        left_handed = false,
        follow_mouse = 1,
        float_switch_override_focus = 1,
        touchpad = {
            disable_while_typing = true,
            natural_scroll = true,
            clickfinger_behavior = false,
            middle_button_emulation = true,
            tap_to_click = true,
            drag_lock = 0,
        },
    },

    general = {
        gaps_in = 4,
        gaps_out = 8,
        border_size = 2,
        layout = "dwindle",
        resize_on_border = true,
        allow_tearing = false,
    },

    dwindle = {
        preserve_split = true,
        smart_split = false,
        smart_resizing = false,
    },

    master = {
        new_status = "master",
        new_on_top = true,
        mfact = 0.5,
    },

    gestures = {
        workspace_swipe_distance = 500,
        workspace_swipe_invert = true,
        workspace_swipe_min_speed_to_force = 30,
        workspace_swipe_cancel_ratio = 0.5,
        workspace_swipe_create_new = true,
        workspace_swipe_forever = true,
    },

    misc = {
        disable_hyprland_logo = true,
        disable_splash_rendering = true,
        vrr = 0,
        mouse_move_enables_dpms = true,
        enable_swallow = true,
        swallow_regex = "^(kitty)$",
        focus_on_activate = false,
        initial_workspace_tracking = 0,
        middle_click_paste = false,
        animate_manual_resizes = true,
        animate_mouse_windowdragging = true,
    },

    debug = {
        vfr = true,
    },

    xwayland = {
        enabled = true,
        force_zero_scaling = true,
    },
})
