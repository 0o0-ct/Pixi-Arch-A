import GLib from "gi://GLib?version=2.0";

export interface WaybarLayout {
  positionX: "left" | "right";
  positionY: "top" | "bottom";
  width: number;
  height: number;
  isHorizontal: boolean;
}

export function getWaybarLayout(): WaybarLayout {
  let positionX: "left" | "right" = "right";
  let positionY: "top" | "bottom" = "top";
  let width = 450;
  let height = 720;

  try {
    const configPath = `${GLib.get_home_dir()}/.config/waybar/config`;
    // Read the symlink target
    const target = GLib.file_read_link(configPath);
    const layout_name = GLib.path_get_basename(target);
    
    if (layout_name.includes("[TOP & BOT]")) {
      positionX = "right";
      positionY = "bottom";
    } else if (layout_name.includes("[BOT & Left]") || layout_name.includes("[BOT & LEFT]")) {
      positionX = "left";
      positionY = "bottom";
    } else if (layout_name.includes("[BOT & Right]") || layout_name.includes("[BOT & RIGHT]")) {
      positionX = "right";
      positionY = "bottom";
    } else if (layout_name.includes("[TOP & Left]") || layout_name.includes("[TOP & LEFT]")) {
      positionX = "left";
      positionY = "top";
    } else if (layout_name.includes("[TOP & Right]") || layout_name.includes("[TOP & RIGHT]")) {
      positionX = "right";
      positionY = "top";
    } else if (layout_name.includes("[LEFT]")) {
      positionX = "left";
      positionY = "bottom";
    } else if (layout_name.includes("[RIGHT]")) {
      positionX = "right";
      positionY = "bottom";
    } else if (layout_name.includes("[BOT]")) {
      positionX = "right";
      positionY = "bottom";
    } else if (layout_name.includes("[TOP]")) {
      positionX = "right";
      positionY = "top";
    }
  } catch (e) {
    console.error("Error reading waybar config link:", e);
  }

  // Determine size (width/height) based on positionX and if the bar is a side bar
  // User: horizontal/wide (e.g. 720x450) when on the left/right, and vertical/tall (e.g. 450x720) when on top/bottom
  const isHorizontal = positionX === "left" || (positionX === "right" && GLib.file_read_link(`${GLib.get_home_dir()}/.config/waybar/config`).includes("[RIGHT]"));
  
  if (isHorizontal) {
    width = 720;
    height = 450;
  } else {
    width = 450;
    height = 720;
  }

  return { positionX, positionY, width, height, isHorizontal };
}
