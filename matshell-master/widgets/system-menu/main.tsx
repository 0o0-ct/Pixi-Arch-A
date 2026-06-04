import { Astal, Gtk } from "ags/gtk4";
import app from "ags/gtk4/app";
import PowerProfiles from "gi://AstalPowerProfiles";
import { createState, onCleanup } from "ags";
import { Sliders } from "./modules/Sliders.tsx";
import { Toggles } from "./modules/Toggles.tsx";
import { PowerProfileBox } from "./modules/PowerProfileBox.tsx";
import { BatteryBox } from "./modules/BatteryBox.tsx";
import options from "options.ts";
import { gdkmonitor } from "utils/monitors.ts";
import { getWaybarLayout } from "utils/waybar.ts";

export default function SystemMenu() {
  const powerprofiles = PowerProfiles.get_default();
  const hasProfiles = powerprofiles?.get_profiles()?.length > 0;
  const { TOP, BOTTOM, LEFT, RIGHT } = Astal.WindowAnchor;
  const [visible, _setVisible] = createState(false);

  const layout = getWaybarLayout();
  const anchorY = layout.positionY === "top" ? TOP : BOTTOM;
  const anchorX = layout.positionX === "left" ? LEFT : RIGHT;
  const finalAnchor = anchorY | anchorX;

  return (
    <window
      name="system-menu"
      application={app}
      layer={Astal.Layer.OVERLAY}
      anchor={finalAnchor}
      keymode={Astal.Keymode.ON_DEMAND}
      // Fixes gtk4-layer-shell bug
      // https://github.com/Aylur/astal/issues/258
      $={(self) => {
        self.set_default_size(1, 1);
      }}
      visible={visible}
      gdkmonitor={gdkmonitor}
    >
      {layout.isHorizontal ? (
        <box
          cssClasses={["system-menu", "system-menu-horizontal"]}
          widthRequest={720}
          heightRequest={450}
          orientation={Gtk.Orientation.HORIZONTAL}
          spacing={16}
        >
          {/* Column 1: Toggles and other controls */}
          <box
            orientation={Gtk.Orientation.VERTICAL}
            spacing={8}
            hexpand={true}
            valign={Gtk.Align.CENTER}
          >
            <Toggles showTogglesOnly={true} />
            {hasProfiles && <PowerProfileBox />}
            <Sliders />
            <BatteryBox />
          </box>
          
          {/* Vertical Separator */}
          <Gtk.Separator orientation={Gtk.Orientation.VERTICAL} />

          {/* Column 2: Notifications List */}
          <box
            orientation={Gtk.Orientation.VERTICAL}
            spacing={8}
            hexpand={true}
            cssClasses={["notification-column"]}
          >
            <Toggles showNotificationsOnly={true} />
          </box>
        </box>
      ) : (
        <box
          cssClasses={["system-menu"]}
          widthRequest={450}
          heightRequest={720}
          orientation={Gtk.Orientation.VERTICAL}
          spacing={8}
        >
          <Toggles />
          {hasProfiles && <PowerProfileBox />}
          <Sliders />
          <BatteryBox />
        </box>
      )}
    </window>
  );
}
