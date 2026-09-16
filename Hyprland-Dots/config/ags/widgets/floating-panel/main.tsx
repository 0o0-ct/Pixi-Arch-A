import app from "ags/gtk4/app";
import { execAsync } from "ags/process";
import { Astal, Gdk, Gtk } from "ags/gtk4";
import { createState, onCleanup } from "ags";
import { gdkmonitor } from "utils/monitors.ts";
import PanelButton from "./modules/PanelButton.tsx";

const PANEL_HIDE_DELAY = 350;

export default function FloatingPanel() {
  const [panelVisible, setPanelVisible] = createState(false);
  let hideTimeout: ReturnType<typeof setTimeout> | null = null;
  let motionCtrl: Gtk.EventControllerMotion | null = null;
  let keyCtrl: Gtk.EventControllerKey | null = null;

  function cleanupControllers() {
    if (motionCtrl) {
      // Remove from window if still attached
      // Note: We can't easily get a reference to the window here,
      // but we can null the controller so it's not used again
      motionCtrl = null;
    }
    if (keyCtrl) {
      keyCtrl = null;
    }
  }

  function scheduleHide() {
    cancelHide();
    hideTimeout = setTimeout(() => {
      setPanelVisible(false);
      // Cleanup controllers when panel is hidden
      cleanupControllers();
    }, PANEL_HIDE_DELAY);
  }

  function cancelHide() {
    if (hideTimeout) {
      clearTimeout(hideTimeout);
      hideTimeout = null;
    }
  }

  function showPanel() {
    cancelHide();
    setPanelVisible(true);
    // Ensure controllers are attached when panel is shown
    // (they're attached in the window $ callback)
  }

  function hidePanel() {
    setPanelVisible(false);
    cancelHide();
    cleanupControllers();
  }

  // Expose toggle for IPC - safe version
  togglePanel = () => {
    if (panelVisible) {
      hidePanel();
    } else {
      showPanel();
    }
  };

  onCleanup(() => {
    if (hideTimeout) clearTimeout(hideTimeout);
    cleanupControllers();
  });

  return (
    <window
      name="floating-panel"
      visible={true}
      gdkmonitor={gdkmonitor}
      anchor={Astal.WindowAnchor.TOP | Astal.WindowAnchor.RIGHT}
      exclusivity={Astal.Exclusivity.IGNORE}
      layer={Astal.Layer.OVERLAY}
      keymode={Astal.Keymode.NONE}
      application={app}
      $={(self) => {
        self.set_default_size(6, 80);
        self.set_margin_top(44);
        self.set_margin_end(0);

        // Create motion controller for hover detection
        const newMotion = new Gtk.EventControllerMotion();
        newMotion.connect("enter", showPanel);
        newMotion.connect("leave", scheduleHide);
        
        // Create key controller for ESC
        const newKeyCtrl = new Gtk.EventControllerKey();
        newKeyCtrl.connect("key-pressed", (_widget, keyval: number) => {
          if (keyval === Gdk.KEY_Escape) {
            hidePanel();
          }
        });

        // Replace old controllers if they exist
        if (motionCtrl) {
          // Controllers will be garbage collected
        }
        
        motionCtrl = newMotion;
        keyCtrl = newKeyCtrl;

        self.add_controller(newMotion);
        self.add_controller(newKeyCtrl);
      }}
    >
      <box
        orientation={Gtk.Orientation.HORIZONTAL}
        spacing={0}
        cssClasses={["floating-panel-container"]}
      >
        {/* Panel content - hidden by default, shown on hover */}
        <box
          visible={panelVisible}
          cssClasses={["floating-panel"]}
          orientation={Gtk.Orientation.HORIZONTAL}
          spacing={0}
        >
          <PanelButton
            icon="system-lock-screen-symbolic"
            tooltip="Bloquear pantalla"
            command="hyprlock"
          />
          <PanelButton
            icon="weather-clear-night-symbolic"
            tooltip="Modo oscuro"
            command="pkill -USR1 hyprpaper || true"
          />
          <PanelButton
            icon="system-log-out-symbolic"
            tooltip="Cerrar sesion"
            command="pkill Hyprland || loginctl terminate-user $USER"
          />
          <PanelButton
            icon="view-refresh-symbolic"
            tooltip="Recargar configuracion"
            onClick={() => execAsync(["sh", "-c", "ags -r 'reload-css'"])}
          />
          <PanelButton
            icon="system-shutdown-symbolic"
            tooltip="Apagar"
            command="systemctl poweroff || loginctl poweroff"
          />
<separator orientation={Gtk.Orientation.VERTICAL} />
          <PanelButton
            icon="system-shutdown-symbolic"
            tooltip="Apagar"
            command="systemctl poweroff || loginctl poweroff"
          />
        </box>

        {/* Trigger strip - always visible on the right edge */}
        <box
          cssClasses={["floating-panel-trigger"]}
          widthRequest={6}
          vertical={Gtk.Align.FILL}
        />
      </box>
    </window>
  );
}