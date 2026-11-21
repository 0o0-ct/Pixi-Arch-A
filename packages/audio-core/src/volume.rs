//! Conversión de volumen ↔ dB (fórmula de pavucontrol / PulseAudio `pa_sw_volume_to_dB`).
//!
//! `dB = 60 × log10(vol / 65536)` donde `vol` es el valor crudo de PulseAudio
//! (`PA_VOLUME_NORM = 65536` equivale a 100% = 0.00 dB).

/// `PA_VOLUME_NORM` de PulseAudio.
pub const PA_VOLUME_NORM: u32 = 65536;

/// Convierte un valor crudo de PulseAudio (0..=∞) a dB usando la fórmula de pavucontrol.
///
/// - 100% (65536) → 0.00 dB
/// - 47%  (≈30801) → ≈ −19.67 dB
/// - 20%  (≈13107) → ≈ −41.94 dB
/// - 150% (98304) → ≈ +10.57 dB
///
/// Para `vol == 0` devuelve `-100.0` (silencio absoluto, evita `-inf`).
pub fn sw_volume_to_db(vol: u32) -> f64 {
    if vol == 0 {
        return -100.0;
    }
    60.0 * (vol as f64 / PA_VOLUME_NORM as f64).log10()
}

/// Convierte un porcentaje (0.0–1.5+ , donde 1.0 = 100%) a dB.
pub fn percent_to_db(percent: f32) -> f64 {
    if percent <= 0.0 {
        return -100.0;
    }
    60.0 * (percent as f64).log10()
}

/// Formatea un porcentaje y sus dB como etiqueta de una sola línea: `47% · -19.67 dB`.
pub fn format_volume_label(percent: f32) -> String {
    let db = percent_to_db(percent);
    format!("{:.0}% · {:.2} dB", percent * 100.0, db)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn full_scale_is_zero_db() {
        let db = sw_volume_to_db(PA_VOLUME_NORM);
        assert!((db - 0.0).abs() < 1e-9, "100% debería ser 0.00 dB, fue {db}");
    }

    #[test]
    fn fortyseven_percent_is_neg_nineteen() {
        let db = percent_to_db(0.47);
        assert!(
            (db - (-19.67)).abs() < 0.01,
            "47% debería ser ≈ −19.67 dB, fue {db}"
        );
    }

    #[test]
    fn twenty_percent_is_neg_forty_one() {
        let db = percent_to_db(0.20);
        assert!(
            (db - (-41.94)).abs() < 0.01,
            "20% debería ser ≈ −41.94 dB, fue {db}"
        );
    }

    #[test]
    fn hundred_fifty_percent_is_pos_ten() {
        let db = percent_to_db(1.50);
        assert!(
            (db - 10.57).abs() < 0.01,
            "150% debería ser ≈ +10.57 dB, fue {db}"
        );
    }

    #[test]
    fn raw_volume_matches_percent() {
        // 47% en crudo ≈ 0.47 * 65536 = 30801.92 → 30801
        let raw = (0.47 * PA_VOLUME_NORM as f32) as u32;
        let db = sw_volume_to_db(raw);
        assert!((db - (-19.67)).abs() < 0.02, "crudo 47% → {db}");
    }

    #[test]
    fn zero_volume_returns_floor() {
        assert_eq!(sw_volume_to_db(0), -100.0);
        assert_eq!(percent_to_db(0.0), -100.0);
    }

    #[test]
    fn label_format() {
        let l = format_volume_label(0.47);
        assert!(l.starts_with("47%"), "etiqueta: {l}");
        assert!(l.contains("dB"), "etiqueta: {l}");
    }
}
