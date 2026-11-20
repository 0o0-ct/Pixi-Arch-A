use gtk4::gdk;
use gtk4::gio;
use gtk4::glib;
use gtk4::gdk_pixbuf::Pixbuf;
use gtk4::Image;

pub mod svgs {
    pub const WIFI: &str = include_str!("icons/wifi.svg");
    pub const WIFI_OFF: &str = include_str!("icons/wifi-off.svg");
    pub const LOCK: &str = include_str!("icons/lock.svg");
    pub const ETHERNET: &str = include_str!("icons/ethernet.svg");
    pub const SERVER: &str = include_str!("icons/server.svg");
    pub const REFRESH_CW: &str = include_str!("icons/refresh-cw.svg");
    pub const X: &str = include_str!("icons/x.svg");
    pub const SEARCH: &str = include_str!("icons/search.svg");
    pub const TRASH: &str = include_str!("icons/trash.svg");
    pub const EYE: &str = include_str!("icons/eye.svg");
    pub const EYE_OFF: &str = include_str!("icons/eye-off.svg");
    pub const LOADER_CIRCLE: &str = include_str!("icons/loader-circle.svg");
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
