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
  let isHorizontal = false;

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
      isHorizontal = true;
    } else if (layout_name.includes("[RIGHT]")) {
      positionX = "right";
      positionY = "bottom";
      isHorizontal = true;
    } else if (layout_name.includes("[BOT]")) {
      positionX = "right";
      positionY = "bottom";
    } else if (layout_name.includes("[TOP]")) {
      positionX = "right";
      positionY = "top";
    }

    // Parse config content to dynamically locate the notify module placement
    const [, content] = GLib.file_get_contents(target);
    const text = new TextDecoder("utf-8").decode(content);
    const cleanText = text.replace(/\/\*[\s\S]*?\*\/|([^\\:]|^)\/\/.*$/gm, '$1');
    
    const leftIndex = cleanText.indexOf("modules-left");
    const rightIndex = cleanText.indexOf("modules-right");
    const notifyIndex = cleanText.indexOf("group/notify");
    const swayncIndex = cleanText.indexOf("custom/swaync");
    
    const indexToUse = notifyIndex !== -1 ? notifyIndex : swayncIndex;
    
    if (indexToUse !== -1) {
      if (leftIndex !== -1 && rightIndex !== -1) {
        if (leftIndex < rightIndex) {
          if (indexToUse > leftIndex && indexToUse < rightIndex) {
            positionX = "left";
          } else if (indexToUse > rightIndex) {
            positionX = "right";
          }
        } else {
          if (indexToUse > rightIndex && indexToUse < leftIndex) {
            positionX = "right";
          } else if (indexToUse > leftIndex) {
            positionX = "left";
          }
        }
      } else if (leftIndex !== -1) {
        positionX = "left";
      } else if (rightIndex !== -1) {
        positionX = "right";
      }
    }
  } catch (e) {
    console.error("Error reading waybar config link:", e);
  }

  if (isHorizontal) {
    width = 720;
    height = 450;
  } else {
    width = 450;
    height = 720;
  }

  return { positionX, positionY, width, height, isHorizontal };
}
