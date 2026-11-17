import Tray from "gi://AstalTray";
import { For, createBinding, createState } from "ags";
import { Gtk } from "ags/gtk4";

const tray = Tray.get_default();

export const hasTrayItems = createBinding(
  tray,
  "items",
)((items) => items.length > 0);

function SysTrayItem({ item }) {
  return (
    <button
      cssClasses={["tray-item"]}
      tooltipMarkup={createBinding(item, "tooltipMarkup")}
      $={(self) => {
        // Create popover menu for right-click context menu
        const popover = new Gtk.PopoverMenu({
          menu_model: item.menuModel,
        });
        popover.set_parent(self);

        self.insert_action_group("dbusmenu", item.actionGroup);
        item.connect("notify::action-group", () => {
          self.insert_action_group("dbusmenu", item.actionGroup);
        });

        // Click gesture controller
        const gesture = new Gtk.GestureClick();
        gesture.connect("released", (g, n, x, y) => {
          const button = gesture.get_current_button();
          if (button === 1) {
            // Left click: activate the app
            item.activate(0, 0);
          } else if (button === 3) {
            // Right click: open context menu popover
            popover.popup();
          }
        });
        self.add_controller(gesture);
      }}
    >
      <image gicon={createBinding(item, "gicon")} />
    </button>
  );
}

export function SysTray() {
  const [revealed, setRevealed] = createState(false);

  return (
    <box
      cssClasses={["SysTray-container"]}
      visible={hasTrayItems}
      $={(self) => {
        const motionController = new Gtk.EventControllerMotion();

        motionController.connect("enter", () => {
          setRevealed(true);
        });

        motionController.connect("leave", () => {
          setRevealed(false);
        });

        self.add_controller(motionController);
      }}
    >
      <button cssClasses={["tray-arrow-btn", "module"]}>
        <label label={createBinding(revealed)((rev) => (rev ? "" : ""))} />
      </button>
      <revealer
        transitionType={Gtk.RevealerTransitionType.SLIDE_RIGHT}
        transitionDuration={300}
        revealChild={revealed}
      >
        <box cssClasses={["SysTray", "module"]}>
          <For each={createBinding(tray, "items")}>
            {(item) => <SysTrayItem item={item} />}
          </For>
        </box>
      </revealer>
    </box>
  );
}

