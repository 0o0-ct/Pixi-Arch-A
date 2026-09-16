import { Gtk } from "ags/gtk4";
import { execAsync } from "ags/process";

type PanelButtonProps = {
  icon: string;
  tooltip: string;
  command?: string;
  onClick?: () => void;
  cssClasses?: string[];
};

export default function PanelButton({
  icon,
  tooltip,
  command,
  onClick,
  cssClasses = [],
}: PanelButtonProps) {
  return (
    <button
      cssClasses={["floating-panel-btn", ...cssClasses]}
      tooltipText={tooltip}
      onClicked={() => {
        if (onClick) onClick();
        else if (command) execAsync(["sh", "-c", command]);
      }}
    >
      <icon icon={icon} />
    </button>
  );
}
