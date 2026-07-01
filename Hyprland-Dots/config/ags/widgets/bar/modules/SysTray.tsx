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
    <menubutton
      cssClasses={["tray-item"]}
      tooltipMarkup={createBinding(item, "tooltipMarkup")}
      $={(self) => {
        self.menuModel = item.menuModel;
        self.insert_action_group("dbusmenu", item.actionGroup);
        item.connect("notify::action-group", () => {
          self.insert_action_group("dbusmenu", item.actionGroup);
        });
      }}
    >
      <image gicon={createBinding(item, "gicon")} />
    </menubutton>
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

