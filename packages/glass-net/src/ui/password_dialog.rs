use gtk4::prelude::*;
use gtk4::{Box, Button, Entry, Label, Orientation, Window};
use crate::events::NetCommand;
use crate::ui::icons::{create_texture, svgs};

pub struct PasswordDialog;

impl PasswordDialog {
    pub fn show(
        req_id: u64,
        ssid: &str,
        security: &str,
        parent: &impl IsA<Window>,
        cmd_tx: async_channel::Sender<NetCommand>,
    ) {
        let dialog = Window::builder()
            .transient_for(parent)
            .modal(true)
            .title("Contraseña Wi-Fi")
            .default_width(360)
            .build();

        dialog.add_css_class("dialog-box");

        let container = Box::new(Orientation::Vertical, 12);
        container.set_margin_top(16);
        container.set_margin_bottom(16);
        container.set_margin_start(16);
        container.set_margin_end(16);

        let title = Label::new(Some("Conectarse a la red"));
        title.add_css_class("panel-title");
        container.append(&title);

        let network_info = Label::new(Some(&format!("{ssid} • {security}")));
        network_info.add_css_class("device-sub");
        network_info.set_wrap(true);
        container.append(&network_info);

        // Entrada de contraseña con toggle de visibilidad (ojo Lucide)
        let entry = Entry::new();
        entry.set_placeholder_text(Some("Introduce la contraseña…"));
        entry.add_css_class("glass-search");
        entry.set_visibility(false);
        entry.set_input_purpose(gtk4::InputPurpose::Password);

        let tex_open = create_texture(svgs::EYE, "rgba(255, 255, 255, 0.65)", 16);
        let tex_closed = create_texture(svgs::EYE_OFF, "rgba(255, 255, 255, 0.65)", 16);
        entry.set_icon_from_paintable(gtk4::EntryIconPosition::Secondary, tex_closed.as_ref());

        // Estado de visibilidad manual (GTK no expone getter aquí)
        let e_toggle = entry.clone();
        let t_open = tex_open.clone();
        let t_closed = tex_closed.clone();
        let visible = std::cell::Cell::new(false);
        entry.connect_icon_press(move |e, icon_pos| {
            if icon_pos == gtk4::EntryIconPosition::Secondary {
                let now = !visible.get();
                visible.set(now);
                e_toggle.set_visibility(now);
                let tex = if now { &t_open } else { &t_closed };
                e.set_icon_from_paintable(gtk4::EntryIconPosition::Secondary, tex.as_ref());
            }
        });
        container.append(&entry);

        // Botones Cancelar / Conectar
        let btn_box = Box::new(Orientation::Horizontal, 10);
        btn_box.set_halign(gtk4::Align::End);
        btn_box.set_margin_top(12);

        let cancel_btn = Button::with_label("Cancelar");
        cancel_btn.add_css_class("btn-action");
        cancel_btn.add_css_class("btn-disconnect");
        let d_cancel = dialog.clone();
        cancel_btn.connect_clicked(move |_| {
            d_cancel.close();
        });
        btn_box.append(&cancel_btn);

        let connect_btn = Button::with_label("Conectar");
        connect_btn.add_css_class("btn-action");
        connect_btn.add_css_class("btn-connect");
        let d_accept = dialog.clone();
        let tx_accept = cmd_tx.clone();
        let e_accept = entry.clone();
        connect_btn.connect_clicked(move |_| {
            let password = e_accept.text().to_string();
            let _ = tx_accept.send_blocking(NetCommand::SubmitPassword {
                req_id,
                password,
            });
            d_accept.close();
        });
        btn_box.append(&connect_btn);

        // Enter en la entrada también conecta
        let d_enter = dialog.clone();
        let tx_enter = cmd_tx;
        let e_enter = entry.clone();
        entry.connect_activate(move |_| {
            let password = e_enter.text().to_string();
            let _ = tx_enter.send_blocking(NetCommand::SubmitPassword {
                req_id,
                password,
            });
            d_enter.close();
        });

        container.append(&btn_box);
        dialog.set_child(Some(&container));
        dialog.present();
        entry.grab_focus();
    }
}
