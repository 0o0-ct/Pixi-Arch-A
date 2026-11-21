//! Servicio de audio con libpulse-binding.
//!
//! Corre en un hilo dedicado con un `ThreadedMainloop` de PulseAudio.
//! Es event-driven: se suscribe a los eventos del servidor y solo consulta
//! de nuevo cuando algo cambia o la UI envía un comando (sin polling).

use crate::commands::{AudioCommand, VolumeTarget};
use crate::state::{
    AudioState, CardInfo, ChannelInfo, DeviceType, PlaybackStream, PortInfo, ProfileInfo,
    RecordStream, SinkInfo, SourceInfo,
};
use async_channel::{Receiver, Sender};
use libpulse_binding as pulse;
use libpulse_binding::callbacks::ListResult;
use libpulse_binding::channelmap::Position as ChannelPosition;
use libpulse_binding::context::introspect::Introspector;
use libpulse_binding::context::subscribe::InterestMaskSet;
use libpulse_binding::context::{Context, State as ContextState};
use libpulse_binding::mainloop::threaded::Mainloop;
use libpulse_binding::volume::{ChannelVolumes, Volume};
use std::sync::mpsc;
use std::sync::Mutex;
use std::time::Duration;
use tracing::{error, info};

/// Conversión de un valor crudo de PulseAudio a f32 (0.0 = 0%, 1.0 = 100%).
fn raw_to_f32(v: Volume) -> f32 {
    v.0 as f32 / crate::volume::PA_VOLUME_NORM as f32
}

/// Extrae los canales y sus volúmenes de un `ChannelVolumes` + `ChannelMap`.
fn channels_of(cv: &ChannelVolumes, map: Option<&pulse::channelmap::Map>) -> Vec<ChannelInfo> {
    let positions: Vec<ChannelPosition> = map.map(|m| m.get().to_vec()).unwrap_or_default();
    cv.get()
        .iter()
        .enumerate()
        .map(|(i, v)| {
            let name = positions
                .get(i)
                .and_then(|p| ChannelPosition::to_string(*p))
                .map(|s| s.to_string())
                .unwrap_or_else(|| format!("ch{i}"));
            ChannelInfo {
                name,
                volume: raw_to_f32(*v),
            }
        })
        .collect()
}

/// Convierte `Vec<PortInfo>` genérico desde los puertos de un sink/source.
fn map_ports<T, F>(ports: &[T], name_of: F) -> Vec<PortInfo>
where
    F: Fn(&T) -> (String, String, bool),
{
    ports
        .iter()
        .map(|p| {
            let (name, description, available) = name_of(p);
            PortInfo {
                name,
                description,
                available,
            }
        })
        .collect()
}

/// Servicio de audio.
pub struct AudioService {
    cmd_rx: Receiver<AudioCommand>,
    /// Clone del sender de comandos: lo usa el callback de suscripción para
    /// avisar de cambios (event-driven, sin polling).
    ping_tx: Sender<AudioCommand>,
    event_tx: Sender<AudioState>,
}

impl AudioService {
    pub fn new(
        cmd_rx: Receiver<AudioCommand>,
        ping_tx: Sender<AudioCommand>,
        event_tx: Sender<AudioState>,
    ) -> Self {
        Self {
            cmd_rx,
            ping_tx,
            event_tx,
        }
    }

    /// Ejecuta el servicio (bloqueante, pensado para un hilo dedicado).
    pub fn run(&self) {
        info!("Iniciando servicio de audio (libpulse-binding)");

        let mut mainloop = match Mainloop::new() {
            Some(ml) => ml,
            None => {
                error!("No se pudo crear el mainloop de PulseAudio");
                return;
            }
        };
        let mut context = match Context::new(&mainloop, "glass-audio") {
            Some(ctx) => ctx,
            None => {
                error!("No se pudo crear el contexto de PulseAudio");
                return;
            }
        };

        // Callback de estado vacío: evita que PulseAudio aborte por callback nulo.
        context.set_state_callback(Some(Box::new(|| {})));

        // Conectar ANTES de iniciar el mainloop.
        if let Err(e) = context.connect(None, pulse::context::FlagSet::NOFLAGS, None) {
            error!("Error al conectar al servidor PulseAudio: {:?}", e);
            return;
        }
        if let Err(e) = mainloop.start() {
            error!("Error al iniciar el mainloop: {:?}", e);
            return;
        }

        // Esperar a que el contexto esté listo (polling breve de estado).
        let mut ready = false;
        for _ in 0..200 {
            mainloop.lock();
            let state = context.get_state();
            mainloop.unlock();
            match state {
                ContextState::Ready => {
                    ready = true;
                    break;
                }
                ContextState::Failed | ContextState::Terminated => {
                    error!("Contexto PulseAudio falló (state={:?})", state);
                    mainloop.stop();
                    return;
                }
                _ => std::thread::sleep(Duration::from_millis(25)),
            }
        }
        if !ready {
            error!("Timeout esperando a que PulseAudio esté listo");
            mainloop.stop();
            return;
        }
        info!("Contexto PulseAudio listo (Ready)");

        // Suscribirse a eventos: cada cambio dispara un ping `Refresh` por el
        // mismo canal de comandos (event-driven).
        let ping = self.ping_tx.clone();
        mainloop.lock();
        context.set_subscribe_callback(Some(Box::new(move |_fac, _op, _idx| {
            let _ = ping.send_blocking(AudioCommand::Refresh);
        })));
        let _op_sub = context.subscribe(InterestMaskSet::ALL, |_| {});
        mainloop.unlock();

        // Estado inicial completo.
        let state = self.full_fetch(&mut context, &mut mainloop);
        info!(
            "Estado inicial: {} sinks, {} sources, {} playback, {} record, {} cards",
            state.sinks.len(),
            state.sources.len(),
            state.playback_streams.len(),
            state.record_streams.len(),
            state.cards.len()
        );
        let _ = self.event_tx.send_blocking(state);

        // Bucle principal: event-driven (bloquea esperando comandos/pings).
        while let Ok(cmd) = self.cmd_rx.recv_blocking() {
            // Coalescer los mensajes pendientes para evitar refetches repetidos.
            let mut batch = vec![cmd];
            while let Ok(next) = self.cmd_rx.try_recv() {
                batch.push(next);
            }

            let mut refresh = false;
            for c in batch {
                match c {
                    AudioCommand::Refresh | AudioCommand::Subscribe => refresh = true,
                    AudioCommand::Reconnect => {
                        info!("Reconexión solicitada (ya conectado)");
                        refresh = true;
                    }
                    other => {
                        self.exec(&mut context, &mut mainloop, other);
                        // Ejecutar un comando dispara eventos → habrá pings; el
                        // fetch final los consolidará.
                        refresh = true;
                    }
                }
            }

            if refresh {
                let state = self.full_fetch(&mut context, &mut mainloop);
                let _ = self.event_tx.send_blocking(state);
            }
        }

        mainloop.stop();
        info!("Servicio de audio detenido");
    }

    // ── Ejecución de comandos ────────────────────────────────────────────────

    fn exec(&self, context: &mut Context, mainloop: &mut Mainloop, cmd: AudioCommand) {
        mainloop.lock();
        let mut intro = context.introspect();
        match cmd {
            AudioCommand::SetVolume {
                target,
                volume,
                channels,
            } => {
                let mut cv = ChannelVolumes::default();
                let n = channels.clamp(1, ChannelVolumes::CHANNELS_MAX as usize) as u8;
                cv.set(n, Volume((volume * crate::volume::PA_VOLUME_NORM as f32) as u32));
                Self::apply_volume(&mut intro, target, &cv);
            }
            AudioCommand::SetBalance { target, balance } => {
                // Requiere el channel map del objetivo: se lee y se re-aplica.
                drop(intro);
                mainloop.unlock();
                self.exec_balance(context, mainloop, target, balance);
                return;
            }
            AudioCommand::SetChannelVolumes { target, channels } => {
                let mut cv = ChannelVolumes::default();
                cv.set_len(channels.len().clamp(1, ChannelVolumes::CHANNELS_MAX as usize) as u8);
                for (i, v) in channels.iter().enumerate() {
                    if let Some(slot) = cv.get_mut().get_mut(i) {
                        *slot = Volume((v * crate::volume::PA_VOLUME_NORM as f32) as u32);
                    }
                }
                Self::apply_volume(&mut intro, target, &cv);
            }
            AudioCommand::SetMute { target, muted } => Self::apply_mute(&mut intro, target, muted),
            AudioCommand::SetDefault { device_type, name } => match device_type {
                DeviceType::Sink => {
                    let _ = context.set_default_sink(&name, |_| {});
                }
                DeviceType::Source => {
                    let _ = context.set_default_source(&name, |_| {});
                }
            },
            AudioCommand::SetPort {
                device_type,
                device_index,
                port_name,
            } => match device_type {
                DeviceType::Sink => {
                    let _ = intro.set_sink_port_by_index(device_index, &port_name, None);
                }
                DeviceType::Source => {
                    let _ = intro.set_source_port_by_index(device_index, &port_name, None);
                }
            },
            AudioCommand::MoveStream {
                stream_index,
                device_index,
                device_type,
            } => match device_type {
                DeviceType::Sink => {
                    let _ = intro.move_sink_input_by_index(stream_index, device_index, None);
                }
                DeviceType::Source => {
                    let _ = intro.move_source_output_by_index(stream_index, device_index, None);
                }
            },
            AudioCommand::SetCardProfile {
                card_index,
                profile_name,
            } => {
                let _ = intro.set_card_profile_by_index(card_index, &profile_name, None);
            }
            AudioCommand::SetLatencyOffset {
                card_name,
                port_name,
                offset_usec,
            } => {
                let _ = intro.set_port_latency_offset(&card_name, &port_name, offset_usec, None);
            }
            AudioCommand::Refresh | AudioCommand::Subscribe | AudioCommand::Reconnect => {}
        }
        mainloop.unlock();
    }

    fn apply_volume(intro: &mut Introspector, target: VolumeTarget, cv: &ChannelVolumes) {
        match target {
            VolumeTarget::Sink(i) => {
                let _ = intro.set_sink_volume_by_index(i, cv, None);
            }
            VolumeTarget::Source(i) => {
                let _ = intro.set_source_volume_by_index(i, cv, None);
            }
            VolumeTarget::PlaybackStream(i) => {
                let _ = intro.set_sink_input_volume(i, cv, None);
            }
            VolumeTarget::RecordStream(i) => {
                let _ = intro.set_source_output_volume(i, cv, None);
            }
        }
    }

    /// Lee el volumen y channel map actuales de un objetivo, aplica `set_balance` y re-aplica.
    fn exec_balance(
        &self,
        context: &mut Context,
        mainloop: &mut Mainloop,
        target: VolumeTarget,
        balance: f32,
    ) {
        // 1. Leer (cv, map) actuales. Cada brazo maneja su propio tipo de Operation.
        let data: std::sync::Arc<Mutex<Option<(ChannelVolumes, pulse::channelmap::Map)>>> =
            std::sync::Arc::new(Mutex::new(None));
        let result: Option<(ChannelVolumes, pulse::channelmap::Map)>;

        mainloop.lock();
        match target {
            VolumeTarget::Sink(i) => {
                let data_c = data.clone();
                let (done_tx, done_rx) = mpsc::channel();
                let op = context.introspect().get_sink_info_by_index(i, move |res| {
                    if let ListResult::Item(s) = res {
                        *data_c.lock().unwrap() = Some((s.volume, s.channel_map));
                    }
                    if matches!(res, ListResult::End | ListResult::Error) {
                        let _ = done_tx.send(());
                    }
                });
                mainloop.unlock();
                let _ = done_rx.recv_timeout(Duration::from_secs(3));
                drop(op);
                result = data.lock().unwrap().take();
            }
            VolumeTarget::Source(i) => {
                let data_c = data.clone();
                let (done_tx, done_rx) = mpsc::channel();
                let op = context.introspect().get_source_info_by_index(i, move |res| {
                    if let ListResult::Item(s) = res {
                        *data_c.lock().unwrap() = Some((s.volume, s.channel_map));
                    }
                    if matches!(res, ListResult::End | ListResult::Error) {
                        let _ = done_tx.send(());
                    }
                });
                mainloop.unlock();
                let _ = done_rx.recv_timeout(Duration::from_secs(3));
                drop(op);
                result = data.lock().unwrap().take();
            }
            VolumeTarget::PlaybackStream(i) => {
                let data_c = data.clone();
                let (done_tx, done_rx) = mpsc::channel();
                let op = context.introspect().get_sink_input_info(i, move |res| {
                    if let ListResult::Item(s) = res {
                        *data_c.lock().unwrap() = Some((s.volume, s.channel_map));
                    }
                    if matches!(res, ListResult::End | ListResult::Error) {
                        let _ = done_tx.send(());
                    }
                });
                mainloop.unlock();
                let _ = done_rx.recv_timeout(Duration::from_secs(3));
                drop(op);
                result = data.lock().unwrap().take();
            }
            VolumeTarget::RecordStream(i) => {
                let data_c = data.clone();
                let (done_tx, done_rx) = mpsc::channel();
                let op = context.introspect().get_source_output_info(i, move |res| {
                    if let ListResult::Item(s) = res {
                        *data_c.lock().unwrap() = Some((s.volume, s.channel_map));
                    }
                    if matches!(res, ListResult::End | ListResult::Error) {
                        let _ = done_tx.send(());
                    }
                });
                mainloop.unlock();
                let _ = done_rx.recv_timeout(Duration::from_secs(3));
                drop(op);
                result = data.lock().unwrap().take();
            }
        }

        let Some((mut cv, map)) = result else {
            return;
        };
        if cv.set_balance(&map, balance).is_none() {
            return;
        }

        // 2. Re-aplicar.
        mainloop.lock();
        let mut intro = context.introspect();
        Self::apply_volume(&mut intro, target, &cv);
        mainloop.unlock();
    }

    fn apply_mute(intro: &mut Introspector, target: VolumeTarget, muted: bool) {
        match target {
            VolumeTarget::Sink(i) => {
                let _ = intro.set_sink_mute_by_index(i, muted, None);
            }
            VolumeTarget::Source(i) => {
                let _ = intro.set_source_mute_by_index(i, muted, None);
            }
            VolumeTarget::PlaybackStream(i) => {
                let _ = intro.set_sink_input_mute(i, muted, None);
            }
            VolumeTarget::RecordStream(i) => {
                let _ = intro.set_source_output_mute(i, muted, None);
            }
        }
    }

    // ── Consulta completa del estado ──────────────────────────────────────────

    fn full_fetch(&self, context: &mut Context, mainloop: &mut Mainloop) -> AudioState {
        // Información del servidor (nombres por defecto + nombre del server).
        let server = self.fetch_server(context, mainloop);
        let default_sink = server.0.clone();
        let default_source = server.1.clone();
        let server_name = server.2.clone();

        let mut sinks = self.fetch_sinks(context, mainloop);
        for s in sinks.iter_mut() {
            s.is_default = default_sink.as_deref() == Some(s.name.as_str());
        }

        let mut sources = self.fetch_sources(context, mainloop);
        for s in sources.iter_mut() {
            s.is_default = default_source.as_deref() == Some(s.name.as_str());
        }

        let playback = self.fetch_playback(context, mainloop);
        let record = self.fetch_record(context, mainloop);
        let cards = self.fetch_cards(context, mainloop);

        AudioState {
            server_name,
            sinks,
            sources,
            playback_streams: playback,
            record_streams: record,
            cards,
            default_sink,
            default_source,
        }
    }

    fn fetch_server(&self, context: &mut Context, mainloop: &mut Mainloop) -> (Option<String>, Option<String>, String) {
        let cell: std::sync::Arc<Mutex<Option<(Option<String>, Option<String>, String)>>> =
            std::sync::Arc::new(Mutex::new(None));
        let cell_c = cell.clone();
        let (done_tx, done_rx) = mpsc::channel();
        mainloop.lock();
        let op = context.introspect().get_server_info(move |info| {
            let name = info
                .server_name
                .as_ref()
                .map(|s| s.to_string())
                .unwrap_or_else(|| "PulseAudio".into());
            *cell_c.lock().unwrap() = Some((
                info.default_sink_name.as_ref().map(|s| s.to_string()),
                info.default_source_name.as_ref().map(|s| s.to_string()),
                name,
            ));
            let _ = done_tx.send(());
        });
        mainloop.unlock();
        let _ = done_rx.recv_timeout(Duration::from_secs(3));
        let _ = op;
        cell.lock()
            .unwrap()
            .take()
            .unwrap_or((None, None, "PulseAudio".into()))
    }

    fn fetch_sinks(&self, context: &mut Context, mainloop: &mut Mainloop) -> Vec<SinkInfo> {
        let out: std::sync::Arc<Mutex<Vec<SinkInfo>>> = std::sync::Arc::new(Mutex::new(Vec::new()));
        let out_c = out.clone();
        let (done_tx, done_rx) = mpsc::channel();
        mainloop.lock();
        let op = context.introspect().get_sink_info_list(move |res| {
            if let ListResult::Item(s) = res {
                let info = SinkInfo {
                    index: s.index,
                    name: s.name.as_ref().map(|x| x.to_string()).unwrap_or_default(),
                    description: s
                        .description
                        .as_ref()
                        .map(|x| x.to_string())
                        .unwrap_or_else(|| s.name.as_ref().map(|x| x.to_string()).unwrap_or_default()),
                    volume: raw_to_f32(s.volume.avg()),
                    muted: s.mute,
                    is_default: false,
                    ports: map_ports(&s.ports, |p| {
                        (
                            p.name.as_ref().map(|x| x.to_string()).unwrap_or_default(),
                            p.description.as_ref().map(|x| x.to_string()).unwrap_or_default(),
                            p.available != pulse::def::PortAvailable::No,
                        )
                    }),
                    active_port: s
                        .active_port
                        .as_ref()
                        .and_then(|p| p.name.as_ref().map(|x| x.to_string())),
                    channels: channels_of(&s.volume, Some(&s.channel_map)),
                    card: s.card,
                    monitor_source: Some(s.monitor_source),
                };
                out_c.lock().unwrap().push(info);
            }
            if matches!(res, ListResult::End | ListResult::Error) {
                let _ = done_tx.send(());
            }
        });
        mainloop.unlock();
        let _ = done_rx.recv_timeout(Duration::from_secs(3));
        let _ = op;
        out.lock().unwrap().clone()
    }

    fn fetch_sources(&self, context: &mut Context, mainloop: &mut Mainloop) -> Vec<SourceInfo> {
        let out: std::sync::Arc<Mutex<Vec<SourceInfo>>> = std::sync::Arc::new(Mutex::new(Vec::new()));
        let out_c = out.clone();
        let (done_tx, done_rx) = mpsc::channel();
        mainloop.lock();
        let op = context.introspect().get_source_info_list(move |res| {
            if let ListResult::Item(s) = res {
                let name = s.name.as_ref().map(|x| x.to_string()).unwrap_or_default();
                let info = SourceInfo {
                    index: s.index,
                    name: name.clone(),
                    description: s
                        .description
                        .as_ref()
                        .map(|x| x.to_string())
                        .unwrap_or_else(|| name.clone()),
                    volume: raw_to_f32(s.volume.avg()),
                    muted: s.mute,
                    is_default: false,
                    ports: map_ports(&s.ports, |p| {
                        (
                            p.name.as_ref().map(|x| x.to_string()).unwrap_or_default(),
                            p.description.as_ref().map(|x| x.to_string()).unwrap_or_default(),
                            p.available != pulse::def::PortAvailable::No,
                        )
                    }),
                    active_port: s
                        .active_port
                        .as_ref()
                        .and_then(|p| p.name.as_ref().map(|x| x.to_string())),
                    channels: channels_of(&s.volume, Some(&s.channel_map)),
                    card: s.card,
                    is_monitor: s.monitor_of_sink.is_some() || name.ends_with(".monitor"),
                    monitor_of_sink: s.monitor_of_sink,
                };
                out_c.lock().unwrap().push(info);
            }
            if matches!(res, ListResult::End | ListResult::Error) {
                let _ = done_tx.send(());
            }
        });
        mainloop.unlock();
        let _ = done_rx.recv_timeout(Duration::from_secs(3));
        let _ = op;
        out.lock().unwrap().clone()
    }

    fn fetch_playback(&self, context: &mut Context, mainloop: &mut Mainloop) -> Vec<PlaybackStream> {
        let out: std::sync::Arc<Mutex<Vec<PlaybackStream>>> =
            std::sync::Arc::new(Mutex::new(Vec::new()));
        let out_c = out.clone();
        let (done_tx, done_rx) = mpsc::channel();
        mainloop.lock();
        let op = context.introspect().get_sink_input_info_list(move |res| {
            if let ListResult::Item(s) = res {
                let pl = &s.proplist;
                let info = PlaybackStream {
                    index: s.index,
                    name: s.name.as_ref().map(|x| x.to_string()).unwrap_or_default(),
                    app_name: pl
                        .get_str("application.name")
                        .or_else(|| pl.get_str("application.process.binary"))
                        .unwrap_or_else(|| "Aplicación".into()),
                    media_name: pl.get_str("media.name").unwrap_or_default(),
                    icon_name: pl.get_str("application.icon_name"),
                    media_role: pl.get_str("media.role").unwrap_or_default(),
                    volume: raw_to_f32(s.volume.avg()),
                    muted: s.mute,
                    sink_index: s.sink,
                    channels: channels_of(&s.volume, Some(&s.channel_map)),
                };
                out_c.lock().unwrap().push(info);
            }
            if matches!(res, ListResult::End | ListResult::Error) {
                let _ = done_tx.send(());
            }
        });
        mainloop.unlock();
        let _ = done_rx.recv_timeout(Duration::from_secs(3));
        let _ = op;
        out.lock().unwrap().clone()
    }

    fn fetch_record(&self, context: &mut Context, mainloop: &mut Mainloop) -> Vec<RecordStream> {
        let out: std::sync::Arc<Mutex<Vec<RecordStream>>> = std::sync::Arc::new(Mutex::new(Vec::new()));
        let out_c = out.clone();
        let (done_tx, done_rx) = mpsc::channel();
        mainloop.lock();
        let op = context.introspect().get_source_output_info_list(move |res| {
            if let ListResult::Item(s) = res {
                let pl = &s.proplist;
                let info = RecordStream {
                    index: s.index,
                    name: s.name.as_ref().map(|x| x.to_string()).unwrap_or_default(),
                    app_name: pl
                        .get_str("application.name")
                        .or_else(|| pl.get_str("application.process.binary"))
                        .unwrap_or_else(|| "Aplicación".into()),
                    media_name: pl.get_str("media.name").unwrap_or_default(),
                    icon_name: pl.get_str("application.icon_name"),
                    media_role: pl.get_str("media.role").unwrap_or_default(),
                    volume: raw_to_f32(s.volume.avg()),
                    muted: s.mute,
                    source_index: s.source,
                    channels: channels_of(&s.volume, Some(&s.channel_map)),
                };
                out_c.lock().unwrap().push(info);
            }
            if matches!(res, ListResult::End | ListResult::Error) {
                let _ = done_tx.send(());
            }
        });
        mainloop.unlock();
        let _ = done_rx.recv_timeout(Duration::from_secs(3));
        let _ = op;
        out.lock().unwrap().clone()
    }

    fn fetch_cards(&self, context: &mut Context, mainloop: &mut Mainloop) -> Vec<CardInfo> {
        let out: std::sync::Arc<Mutex<Vec<CardInfo>>> = std::sync::Arc::new(Mutex::new(Vec::new()));
        let out_c = out.clone();
        let (done_tx, done_rx) = mpsc::channel();
        mainloop.lock();
        let op = context.introspect().get_card_info_list(move |res| {
            if let ListResult::Item(c) = res {
                let name = c.name.as_ref().map(|x| x.to_string()).unwrap_or_default();
                let description = c
                    .proplist
                    .get_str("device.description")
                    .unwrap_or_else(|| name.clone());
                let info = CardInfo {
                    index: c.index,
                    name: name.clone(),
                    description,
                    profiles: c
                        .profiles
                        .iter()
                        .map(|p| ProfileInfo {
                            name: p.name.as_ref().map(|x| x.to_string()).unwrap_or_default(),
                            description: p
                                .description
                                .as_ref()
                                .map(|x| x.to_string())
                                .unwrap_or_default(),
                            available: p.available,
                        })
                        .collect(),
                    active_profile: c
                        .active_profile
                        .as_ref()
                        .and_then(|p| p.name.as_ref().map(|x| x.to_string())),
                };
                out_c.lock().unwrap().push(info);
            }
            if matches!(res, ListResult::End | ListResult::Error) {
                let _ = done_tx.send(());
            }
        });
        mainloop.unlock();
        let _ = done_rx.recv_timeout(Duration::from_secs(3));
        let _ = op;
        out.lock().unwrap().clone()
    }
}
