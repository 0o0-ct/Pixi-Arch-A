use gtk4::prelude::*;
use gtk4::{Box, Button, Label, Orientation, Window};
use crate::events::{BtCommand, PairingKind, PairingRequest};

pub struct PairingDialog;

impl PairingDialog {
    pub fn show(req: PairingRequest, parent: &impl IsA<Window>, cmd_tx: async_channel::Sender<BtCommand>) {
        let dialog = Window::builder()
            .transient_for(parent)
            .modal(true)
            .title("Solicitud de emparejamiento")
            .default_width(320)
            .build();

        dialog.add_css_class("dialog-box");

        let container = Box::new(Orientation::Vertical, 12);
        container.set_margin_top(16);
        container.set_margin_bottom(16);
        container.set_margin_start(16);
        container.set_margin_end(16);

        let title = Label::new(Some("Vincular dispositivo"));
        title.add_css_class("panel-title");
        container.append(&title);

        let device_info = Label::new(Some(&format!("¿Deseas vincular con {}?", req.device_name)));
        device_info.add_css_class("device-sub");
        device_info.set_wrap(true);
        container.append(&device_info);

        match req.kind {
            PairingKind::ConfirmPin(pin) => {
                let pin_label = Label::new(Some(&format!("{pin:06}")));
                pin_label.add_css_class("dialog-pin");
                container.append(&pin_label);

                let hint = Label::new(Some("Verifica que el código coincida en ambos dispositivos."));
                hint.add_css_class("device-sub");
                hint.set_wrap(true);
                container.append(&hint);
            }
            PairingKind::DisplayPin(pin) => {
                let pin_label = Label::new(Some(&format!("{pin:06}")));
                pin_label.add_css_class("dialog-pin");
                container.append(&pin_label);
            }
            _ => {}
        }

        // Botones Cancelar / Aceptar
        let btn_box = Box::new(Orientation::Horizontal, 10);
        btn_box.set_halign(gtk4::Align::End);
        btn_box.set_margin_top(12);

        let cancel_btn = Button::with_label("Rechazar");
        cancel_btn.add_css_class("btn-action");
        cancel_btn.add_css_class("btn-disconnect");

        let d_cancel = dialog.clone();
        let tx_cancel = cmd_tx.clone();
        let id_cancel = req.req_id;
        cancel_btn.connect_clicked(move |_| {
            let _ = tx_cancel.send_blocking(BtCommand::PairingResponse {
                req_id: id_cancel,
                accept: false,
                pin_code: None,
            });
            d_cancel.close();
        });
        btn_box.append(&cancel_btn);

        let accept_btn = Button::with_label("Aceptar");
        accept_btn.add_css_class("btn-action");
        accept_btn.add_css_class("btn-connect");

        let d_accept = dialog.clone();
        let tx_accept = cmd_tx;
        let id_accept = req.req_id;
        accept_btn.connect_clicked(move |_| {
            let _ = tx_accept.send_blocking(BtCommand::PairingResponse {
                req_id: id_accept,
                accept: true,
                pin_code: None,
            });
            d_accept.close();
        });
        btn_box.append(&accept_btn);

        container.append(&btn_box);
        dialog.set_child(Some(&container));
        dialog.present();
    }
}
