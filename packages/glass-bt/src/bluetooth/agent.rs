use std::collections::HashMap;
use std::sync::atomic::{AtomicU64, Ordering};
use std::sync::Arc;
use tokio::sync::{oneshot, Mutex};
use bluer::agent::{Agent, ReqError};

use crate::events::{PairingKind, PairingRequest};

static REQ_COUNTER: AtomicU64 = AtomicU64::new(1);

pub enum AgentResponse {
    Confirmation(bool),
    Pin(Option<String>),
    Passkey(Option<u32>),
}

#[derive(Clone)]
pub struct AgentController {
    pending: Arc<Mutex<HashMap<u64, oneshot::Sender<AgentResponse>>>>,
    ui_tx: async_channel::Sender<crate::events::BtEvent>,
}

impl AgentController {
    pub fn new(ui_tx: async_channel::Sender<crate::events::BtEvent>) -> Self {
        Self {
            pending: Arc::new(Mutex::new(HashMap::new())),
            ui_tx,
        }
    }

    pub async fn handle_response(&self, req_id: u64, accept: bool, pin_code: Option<String>) {
        let mut map = self.pending.lock().await;
        if let Some(sender) = map.remove(&req_id) {
            let res = if let Some(pin) = pin_code {
                if let Ok(num) = pin.parse::<u32>() {
                    AgentResponse::Passkey(Some(num))
                } else {
                    AgentResponse::Pin(Some(pin))
                }
            } else {
                AgentResponse::Confirmation(accept)
            };
            let _ = sender.send(res);
        }
    }

    pub fn build_agent(&self) -> Agent {
        let pending = self.pending.clone();
        let ui_tx = self.ui_tx.clone();

        Agent {
            request_default: true,
            request_confirmation: Some(Box::new(move |req| {
                let pending = pending.clone();
                let ui_tx = ui_tx.clone();
                Box::pin(async move {
                    let req_id = REQ_COUNTER.fetch_add(1, Ordering::SeqCst);
                    let (tx, rx) = oneshot::channel();
                    pending.lock().await.insert(req_id, tx);

                    let addr = req.device;
                    let pin = req.passkey;
                    let _ = ui_tx.send(crate::events::BtEvent::PairingPrompt(PairingRequest {
                        req_id,
                        device_mac: addr.to_string(),
                        device_name: format!("Dispositivo ({})", addr),
                        kind: PairingKind::ConfirmPin(pin),
                    })).await;

                    match rx.await {
                        Ok(AgentResponse::Confirmation(true)) => Ok(()),
                        _ => Err(ReqError::Rejected),
                    }
                })
            })),
            request_authorization: Some(Box::new(move |_req| {
                Box::pin(async move {
                    Ok(())
                })
            })),
            authorize_service: Some(Box::new(move |_req| {
                Box::pin(async move {
                    Ok(())
                })
            })),
            ..Default::default()
        }
    }
}
