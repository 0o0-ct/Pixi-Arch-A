//! Servicio de audio con libpulse-binding.
//!
//! Usa un ThreadedMainloop de PulseAudio para comunicarse con el servidor.
//! El servicio corre en un hilo dedicado y envía eventos a la UI vía canales.

use crate::commands::{AudioCommand, VolumeTarget};
use crate::state::{AudioState, DeviceType, SinkInfo, SourceInfo, PortInfo, ChannelInfo, CardInfo, ProfileInfo, PlaybackStream, RecordStream};
use async_channel::{Receiver, Sender};
use libpulse_binding as pulse;
use libpulse_binding::callbacks::ListResult;
use libpulse_binding::context::{Context, State as ContextState};
use libpulse_binding::mainloop::threaded::Mainloop;
use libpulse_binding::volume::Volume;
use std::sync::{Arc, Mutex};
use tracing::{error, info, warn};

/// Servicio de audio.
pub struct AudioService {
    cmd_rx: Receiver<AudioCommand>,
    event_tx: Sender<AudioState>,
}

impl AudioService {
    pub fn new(cmd_rx: Receiver<AudioCommand>, event_tx: Sender<AudioState>) -> Self {
        Self { cmd_rx, event_tx }
    }

    pub async fn run(&self) {
        info!("Iniciando servicio de audio con libpulse-binding");

        // Crear el mainloop
        let mut mainloop = match Mainloop::new() {
            Some(ml) => ml,
            None => {
                error!("No se pudo crear el mainloop de PulseAudio");
                return;
            }
        };

        // Crear el contexto
        let mut context = match Context::new(&mainloop, "glass-audio") {
            Some(ctx) => ctx,
            None => {
                error!("No se pudo crear el contexto de PulseAudio");
                return;
            }
        };

        // Conectar
        if let Err(e) = context.connect(None, pulse::context::FlagSet::NOFLAGS, None) {
            error!("Error al conectar al servidor PulseAudio: {:?}", e);
            return;
        }

        // Iniciar el mainloop
        if let Err(e) = mainloop.start() {
            error!("Error al iniciar el mainloop: {:?}", e);
            return;
        }

        // Esperar a que el contexto esté listo
        loop {
            let state = context.get_state();
            match state {
                ContextState::Ready => break,
                ContextState::Failed | ContextState::Terminated => {
                    error!("Contexto PulseAudio falló o terminó");
                    mainloop.stop();
                    return;
                }
                _ => {
                    mainloop.lock();
                    mainloop.wait();
                    mainloop.unlock();
                }
            }
        }

        info!("Contexto PulseAudio listo");

        // Procesar comandos
        while let Ok(cmd) = self.cmd_rx.recv().await {
            mainloop.lock();
            let mut intro = context.introspect();
            match cmd {
                AudioCommand::Subscribe => {
                    info!("Suscribiéndose a eventos de PulseAudio");
                }
                AudioCommand::SetVolume { target, volume } => {
                    let mut cv = pulse::volume::ChannelVolumes::default();
                    cv.set(0, pulse::volume::Volume((volume * 65536.0) as u32));
                    match target {
                        VolumeTarget::Sink(idx) => {
                            intro.set_sink_volume_by_index(idx, &cv, None);
                        }
                        VolumeTarget::Source(idx) => {
                            intro.set_source_volume_by_index(idx, &cv, None);
                        }
                        _ => {}
                    }
                }
                AudioCommand::SetMute { target, muted } => {
                    match target {
                        VolumeTarget::Sink(idx) => {
                            intro.set_sink_mute_by_index(idx, muted, None);
                        }
                        VolumeTarget::Source(idx) => {
                            intro.set_source_mute_by_index(idx, muted, None);
                        }
                        _ => {}
                    }
                }
                AudioCommand::SetDefault { device_type, name } => {
                    match device_type {
                        DeviceType::Sink => {
                            context.set_default_sink(&name, |_| {});
                        }
                        DeviceType::Source => {
                            context.set_default_source(&name, |_| {});
                        }
                    }
                }
                AudioCommand::Reconnect => {
                    info!("Reconectando...");
                }
                _ => {
                    warn!("Comando no implementado aún: {:?}", cmd);
                }
            }
            mainloop.unlock();
        }

        mainloop.stop();
        info!("Servicio de audio detenido");
    }
}