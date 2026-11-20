//! Comandos que la UI envía al servicio de audio.

use crate::state::DeviceType;

/// Comandos para controlar el audio.
#[derive(Debug, Clone)]
pub enum AudioCommand {
    /// Establecer volumen de un sink/source/stream.
    SetVolume { target: VolumeTarget, volume: f32 },
    /// Establecer mute.
    SetMute { target: VolumeTarget, muted: bool },
    /// Establecer dispositivo predeterminado.
    SetDefault { device_type: DeviceType, name: String },
    /// Establecer puerto activo.
    SetPort { device_type: DeviceType, device_index: u32, port_name: String },
    /// Mover un stream a otro dispositivo.
    MoveStream { stream_index: u32, device_index: u32, device_type: DeviceType },
    /// Establecer perfil de una card.
    SetCardProfile { card_index: u32, profile_name: String },
    /// Establecer offset de latencia.
    SetLatencyOffset { device_type: DeviceType, device_index: u32, offset_usec: i64 },
    /// Suscribirse a eventos (se llama automáticamente).
    Subscribe,
    /// Desconectar y reconectar.
    Reconnect,
}

/// Objetivo de un comando de volumen/mute.
#[derive(Debug, Clone)]
pub enum VolumeTarget {
    Sink(u32),
    Source(u32),
    PlaybackStream(u32),
    RecordStream(u32),
}