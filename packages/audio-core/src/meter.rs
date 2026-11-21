//! Medidor de nivel (VU) en vivo.
//!
//! Abre un stream de captura (record) sobre un source/monitor y calcula el pico
//! real de las muestras, enviándolo por un canal a la UI. Cada medidor corre en
//! su propio hilo con su `ThreadedMainloop`.
//!
//! El hilo queda bloqueado en `recv_blocking()` del canal de parada (cero CPU
//! en reposo: no hay polling ni timers).

use async_channel::{Receiver, Sender};
use libpulse_binding as pulse;
use libpulse_binding::context::{Context, State as ContextState};
use libpulse_binding::mainloop::threaded::Mainloop;
use libpulse_binding::sample::{Format, Spec};
use libpulse_binding::stream::{FlagSet as StreamFlagSet, PeekResult, Stream};
use std::time::Duration;
use tracing::debug;

/// Handle para detener un medidor (se detiene al hacer `drop`).
pub struct PeakMeter {
    stop: Sender<()>,
}

impl PeakMeter {
    /// Inicia un medidor para el source dado y envía `(source_index, pico 0.0..1.0)`
    /// por `tx` mientras haya datos. Se detiene al hacer `drop` del handle.
    pub fn spawn(source_index: u32, source_name: String, tx: Sender<(u32, f32)>) -> Self {
        let (stop_tx, stop_rx) = async_channel::bounded::<()>(1);
        let spawned = std::thread::Builder::new()
            .name(format!("peak-{source_index}"))
            .spawn(move || run_meter(source_index, source_name, tx, stop_rx));
        if let Err(e) = spawned {
            tracing::error!("No se pudo crear el hilo del medidor VU: {e:?}");
        }
        Self { stop: stop_tx }
    }
}

impl Drop for PeakMeter {
    fn drop(&mut self) {
        let _ = self.stop.try_send(());
    }
}

fn run_meter(index: u32, name: String, tx: Sender<(u32, f32)>, stop_rx: Receiver<()>) {
    let Some(mut mainloop) = Mainloop::new() else {
        return;
    };
    let Some(mut context) = Context::new(&mainloop, "glass-audio-peak") else {
        return;
    };
    if context
        .connect(None, pulse::context::FlagSet::NOFLAGS, None)
        .is_err()
    {
        return;
    }
    if mainloop.start().is_err() {
        return;
    }

    // Esperar a que el contexto esté listo (el mainloop interno procesa eventos).
    let mut ready = false;
    for _ in 0..120 {
        mainloop.lock();
        let st = context.get_state();
        mainloop.unlock();
        match st {
            ContextState::Ready => {
                ready = true;
                break;
            }
            ContextState::Failed | ContextState::Terminated => break,
            _ => std::thread::sleep(Duration::from_millis(25)),
        }
    }
    if !ready {
        mainloop.stop();
        return;
    }

    // Formato garantizado s16le / 44100 Hz / mono (PulseAudio convierte).
    let spec = Spec {
        format: Format::S16le,
        channels: 1,
        rate: 44100,
    };
    if !spec.is_valid() {
        mainloop.stop();
        return;
    }

    // Stream en Box: la dirección es estable y el callback puede apuntar a él.
    let mut stream = match Stream::new(&mut context, "glass-audio-peak", &spec, None) {
        Some(s) => Box::new(s),
        None => {
            mainloop.stop();
            return;
        }
    };
    let stream_ptr: *mut Stream = &mut *stream;

    let tx_cb = tx.clone();
    stream.set_read_callback(Some(Box::new(move |_len| unsafe {
        let s = &mut *stream_ptr;
        match s.peek() {
            Ok(PeekResult::Data(data)) => {
                let peak = peak_s16(data);
                // Si el receptor se cierra, el envío falla (no importa).
                let _ = tx_cb.send_blocking((index, peak));
                let _ = s.discard();
            }
            Ok(PeekResult::Hole(_)) | Ok(PeekResult::Empty) => {
                let _ = s.discard();
            }
            Err(_) => {}
        }
    })));

    if stream
        .connect_record(
            Some(&name),
            None,
            StreamFlagSet::FIX_FORMAT | StreamFlagSet::FIX_RATE | StreamFlagSet::FIX_CHANNELS,
        )
        .is_err()
    {
        drop(stream);
        mainloop.stop();
        return;
    }

    debug!("Medidor VU iniciado para source {index} ({name})");

    // Bloqueado a la espera de la orden de parada (sin polling).
    let _ = stop_rx.recv_blocking();

    // Parar el hilo interno del mainloop ANTES de soltar el stream (sin carreras).
    mainloop.stop();
    drop(stream);
    drop(context);
    debug!("Medidor VU detenido para source {index}");
}

/// Pico normalizado (0.0..1.0) de muestras s16le.
fn peak_s16(data: &[u8]) -> f32 {
    let mut peak: i32 = 0;
    let mut i = 0;
    while i + 1 < data.len() {
        let s = i16::from_le_bytes([data[i], data[i + 1]]) as i32;
        let a = if s < 0 { -s } else { s };
        if a > peak {
            peak = a;
        }
        i += 2;
    }
    peak as f32 / 32768.0
}
