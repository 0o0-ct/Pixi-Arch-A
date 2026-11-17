use gtk4::gdk;
use gtk4::gio;
use gtk4::glib;
use gtk4::gdk_pixbuf::Pixbuf;
use gtk4::Image;
use crate::events::DeviceType;

pub mod svgs {
    pub const BLUETOOTH: &str = include_str!("icons/bluetooth.svg");
    pub const BLUETOOTH_CONNECTED: &str = include_str!("icons/bluetooth-connected.svg");
    pub const BLUETOOTH_OFF: &str = include_str!("icons/bluetooth-off.svg");
    pub const BLUETOOTH_SEARCHING: &str = include_str!("icons/bluetooth-searching.svg");
    pub const REFRESH_CW: &str = include_str!("icons/refresh-cw.svg");
    pub const X: &str = include_str!("icons/x.svg");
    pub const SEARCH: &str = include_str!("icons/search.svg");
    pub const HEADPHONES: &str = include_str!("icons/headphones.svg");
    pub const SPEAKER: &str = include_str!("icons/speaker.svg");
    pub const MOUSE: &str = include_str!("icons/mouse.svg");
    pub const KEYBOARD: &str = include_str!("icons/keyboard.svg");
    pub const SMARTPHONE: &str = include_str!("icons/smartphone.svg");
    pub const WATCH: &str = include_str!("icons/watch.svg");
    pub const LAPTOP: &str = include_str!("icons/laptop.svg");
    pub const TV: &str = include_str!("icons/tv.svg");
    pub const GAMEPAD_2: &str = include_str!("icons/gamepad-2.svg");
    pub const TRASH: &str = include_str!("icons/trash.svg");
    pub const CHECK: &str = include_str!("icons/check.svg");
    pub const LOADER_CIRCLE: &str = include_str!("icons/loader-circle.svg");
    pub const SIGNAL_HIGH: &str = include_str!("icons/signal-high.svg");
    pub const BATTERY: &str = include_str!("icons/battery.svg");
    pub const BATTERY_CHARGING: &str = include_str!("icons/battery-charging.svg");
}

/// Genera un `gdk::Texture` a partir del SVG de Lucide, coloreando el trazo y escalándolo
pub fn create_texture(svg_content: &str, stroke_color: &str, size: i32) -> Option<gdk::Texture> {
    let colored_svg = svg_content
        .replace("stroke=\"currentColor\"", &format!("stroke=\"{}\"", stroke_color))
        .replace("width=\"24\"", &format!("width=\"{}\"", size))
        .replace("height=\"24\"", &format!("height=\"{}\"", size));

    let bytes = glib::Bytes::from(colored_svg.as_bytes());
    let stream = gio::MemoryInputStream::from_bytes(&bytes);
    let pixbuf = Pixbuf::from_stream_at_scale(&stream, size, size, true, gio::Cancellable::NONE).ok()?;
    Some(gdk::Texture::for_pixbuf(&pixbuf))
}

/// Crea un widget `gtk4::Image` con el icono de Lucide renderizado como textura nítida
pub fn create_icon_image(svg_content: &str, stroke_color: &str, size: i32) -> Image {
    if let Some(texture) = create_texture(svg_content, stroke_color, size) {
        let image = Image::from_paintable(Some(&texture));
        image.set_pixel_size(size);
        image
    } else {
        Image::from_icon_name("image-missing")
    }
}

/// Devuelve el contenido SVG de Lucide correspondiente a cada tipo de dispositivo
pub fn device_type_svg(device_type: DeviceType) -> &'static str {
    match device_type {
        DeviceType::Mouse => svgs::MOUSE,
        DeviceType::Keyboard => svgs::KEYBOARD,
        DeviceType::Headset => svgs::HEADPHONES,
        DeviceType::Speaker => svgs::SPEAKER,
        DeviceType::Phone => svgs::SMARTPHONE,
        DeviceType::Watch => svgs::WATCH,
        DeviceType::Computer => svgs::LAPTOP,
        DeviceType::Tv => svgs::TV,
        DeviceType::Gamepad => svgs::GAMEPAD_2,
        DeviceType::Generic => svgs::BLUETOOTH,
    }
}
