# Perama ROS/Control Negative Delay Root-Cause Check

## Purpose
This step diagnoses negative ROS/control delay only. It checks when negative `control_delay_ms` appears, how large it is, whether it is concentrated by scenario/config, and whether it appears in isolated samples or bursts.

Do not make final ROS/control delay conclusion in this step.

## Summary
- Total samples: 12758
- Total negative samples: 1730 (13.5601%)
- Negative samples before 120s: 1661 (96.01% of all negatives)
- Negative samples after 120s: 69 (3.99% of all negatives)
- Steady-state samples (`time_s >= 120`): 4151
- Steady-state negative samples: 69 (1.6623% of steady samples)
- Minimum negative delay: -1173.137509 ms
- Steady-state minimum negative delay: -14.526541 ms

## Startup Synchronization Check
Yes, the negative delay is mainly before 120 s under the 80% startup-dominance threshold.

## Steady-State Magnitude Check
Yes for specific scenario/config rows: at least one config is steady_problematic even though the global steady negative ratio is lower.
- small_negative: 54 (78.26% of steady negatives)
- medium_negative: 15 (21.74% of steady negatives)
- large_negative: 0 (0.00% of steady negatives)
- extreme_negative: 0 (0.00% of steady negatives)

## Most Problematic Scenario/Config
- Most problematic by steady diagnostic score: S3 / ax/6/80 (Long NLoS)
- Negative ratio all: 62.3269%
- Steady negative ratio: 21.4876%
- Share of all negative samples: 13.01%
- Share of steady negative samples: 37.68%
- S3 / ax/6/80 negative count: 225 (share of all negatives: 13.01%); steady negative count: 26 (share of steady negatives: 37.68%).

## Isolation vs Burst Check
Negative values are burst-like when adjacent negative samples are within 2 s. The largest burst is 104.024 s in S3 / ax/6/80 with 162 negative samples.
- Total negative bursts: 283
- Largest negative burst duration: 104.024 s

## Recommended Next Step
Use this as supplementary diagnostic evidence and inspect timestamp/log synchronization before any formal ROS/control delay reproduction.

## Generated Outputs
- `perama_ros_negative_rootcause_by_config.csv`
- `perama_ros_negative_before_vs_after120_summary.csv`
- `perama_ros_negative_magnitude_bins.csv`
- `perama_ros_negative_bursts.csv`
- `perama_ros_negative_rootcause_label.csv`
- `fig_perama_ros_negative_delay_over_time.png/.fig`
- `fig_perama_ros_negative_before_after120_bar.png/.fig`
- `fig_perama_ros_negative_magnitude_bins.png/.fig`
