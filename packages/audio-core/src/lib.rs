//! # audio-core
//!
//! Capa de abstracción sobre PulseAudio/PipeWire para la app de control de volumen.
//! Proporciona un modelo de estado y comandos para la UI.

pub mod state;
pub mod commands;
pub mod service;
pub mod volume;
pub mod meter;

pub use state::*;
pub use commands::*;
pub use service::*;
pub use volume::*;
pub use meter::*;