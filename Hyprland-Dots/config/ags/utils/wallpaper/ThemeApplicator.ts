import GLib from "gi://GLib";
import { execAsync } from "ags/process";
import type { ThemeProperties } from "./types";

/**
 * Applies a wallpaper theme through the single colour engine.
 *
 * pixi_colors.py owns every generated palette (Waybar, Rofi, Hyprland, AGS,
 * QuickShell, SwayNC, Kitty, Ghostty and GTK).  AGS must not call Matugen or
 * write _theme_variables_matugen.scss itself: doing so races the engine and
 * leaves different consumers on different generations.
 */
export class ThemeApplicator {
  async applyTheme(
    imagePath: string,
    analysis: ThemeProperties,
    requestedMode: ThemeProperties["mode"] = analysis.mode,
    requestedScheme: ThemeProperties["scheme"] = analysis.scheme,
  ): Promise<void> {
    await this.applyEngine(imagePath, requestedMode, requestedScheme);

    this.sendNotification(imagePath, analysis).catch((error) => {
      console.warn("Failed to send theme notification:", error);
    });
  }

  private async applyEngine(
    imagePath: string,
    mode: ThemeProperties["mode"],
    scheme: ThemeProperties["scheme"],
  ): Promise<void> {
    const engine = `${GLib.get_user_config_dir()}/hypr/scripts/WallustSwww.sh`;

    if (!GLib.file_test(engine, GLib.FileTest.EXISTS)) {
      throw new Error(`colour engine not found: ${engine}`);
    }

    try {
      await execAsync([
        engine,
        imagePath,
        "--mode",
        mode,
        "--scheme",
        scheme,
        "--persist",
      ]);
    } catch (error) {
      console.error("Failed to run colour engine:", error);
      throw error;
    }
  }

  private async sendNotification(
    imagePath: string,
    analysis: ThemeProperties,
  ): Promise<void> {
    const notifySend = GLib.find_program_in_path("notify-send");
    if (!notifySend) return;

    const basename = GLib.path_get_basename(imagePath);
    const message = `Theme: ${analysis.mode} ${analysis.scheme}`;

    execAsync(
      `${notifySend} "Colors and Wallpaper updated" "Image: ${basename}\n${message}"`,
    );
  }
}
