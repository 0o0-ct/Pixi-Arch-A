//! Modelo de estado del audio.

use serde::{Deserialize, Serialize};

/// Tipo de dispositivo de audio.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
pub enum DeviceType {
    Sink,
    Source,
}

/// Información de un sink (dispositivo de salida).
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct SinkInfo {
    pub index: u32,
    pub name: String,
    pub description: String,
    pub volume: f32,       // 0.0 - 1.5 (1.0 = 100% = 0 dB)
    pub muted: bool,
    pub is_default: bool,
    pub ports: Vec<PortInfo>,
    pub active_port: Option<String>,
    pub channels: Vec<ChannelInfo>,
}

/// Información de un source (dispositivo de entrada).
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct SourceInfo {
    pub index: u32,
    pub name: String,
    pub description: String,
    pub volume: f32,
    pub muted: bool,
    pub is_default: bool,
    pub ports: Vec<PortInfo>,
    pub active_port: Option<String>,
    pub channels: Vec<ChannelInfo>,
    pub peak: f32, // nivel de pico actual (0.0 - 1.0)
}

/// Información de un puerto (conector físico).
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct PortInfo {
    pub name: String,
    pub description: String,
    pub available: bool,
}

/// Información de un canal individual.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ChannelInfo {
    pub name: String,
    pub volume: f32,
}

/// Información de un stream de reproducción.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct PlaybackStream {
    pub index: u32,
    pub name: String,
    pub app_name: String,
    pub icon_name: Option<String>,
    pub volume: f32,
    pub muted: bool,
    pub sink_index: u32,
    pub peak: f32,
}

/// Información de un stream de grabación.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct RecordStream {
    pub index: u32,
    pub name: String,
    pub app_name: String,
    pub icon_name: Option<String>,
    pub volume: f32,
    pub muted: bool,
    pub source_index: u32,
    pub peak: f32,
}

/// Información de una card de audio.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct CardInfo {
    pub index: u32,
    pub name: String,
    pub description: String,
    pub profiles: Vec<ProfileInfo>,
    pub active_profile: Option<String>,
}

/// Información de un perfil de audio.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ProfileInfo {
    pub name: String,
    pub description: String,
    pub available: bool,
}

/// Estado global del audio.
#[derive(Debug, Clone, Default, Serialize, Deserialize)]
pub struct AudioState {
    pub sinks: Vec<SinkInfo>,
    pub sources: Vec<SourceInfo>,
    pub playback_streams: Vec<PlaybackStream>,
    pub record_streams: Vec<RecordStream>,
    pub cards: Vec<CardInfo>,
    pub default_sink: Option<String>,
    pub default_source: Option<String>,
}