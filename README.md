# Perama Shipyard Wi-Fi Baseline

This repository contains the Perama Shipyard Wi-Fi Baseline, derived from the public dataset of Rady et al.'s Wi-Fi shipyard study.

This project is a literature-derived Perama Wi-Fi Data Reproduction and baseline integration, not a Wi-Fi physical-layer simulation.

## Data Sources

- Throughput comes from clean JSON-derived MATLAB reproduction.
- PTP delay uses steady-state `steady_mean` with `time_s >= 120`.
- `CDR_75ms` uses the paper Table 2 values.
- ROS/control delay is supplementary only because negative delay risk exists.

## Main Conclusion

No single Wi-Fi configuration fits all KPI objectives at the same time. The baseline therefore uses demand-profile rules instead of one universal best configuration.

## Repository Layout

- `matlab/c02_wifi_reproduction/`: original reproduction scripts for the Perama Shipyard Wi-Fi Baseline.
- `matlab/laboratory_wifi5_pilot/`: laboratory Wi-Fi5 CDR workflow templates.
- `results/perama/`: selected CSV outputs for the Perama Shipyard Wi-Fi Baseline.
- `results/laboratory/`: laboratory workflow notes and generated summaries.
- `figures/perama/`: selected PNG figures.
- `docs/`: summary reports and data-quality notes.
- `data/templates/`: Laboratory pilot test data template.

## CDR_75ms Handling

- Perama baseline uses published Table 2 `CDR_75ms` values.
- The author's repository does not include an official Table 2 exporter.
- Repository inspection suggests a 75 ms threshold over a steady-state window around `[120,181]` s.
- Laboratory experiments will compute `CDR_75ms` from raw control logs using `docs/laboratory_raw_log_cdr_definition.md`.

Related files:

- `docs/perama_table2_cdr_method_investigation.md`
- `docs/laboratory_raw_log_cdr_definition.md`
- `matlab/laboratory_wifi5_pilot/compute_laboratory_cdr75_from_raw_log.m`
- `data/templates/laboratory_wifi5_pilot_template.csv`

## Next Step

Laboratory Wi-Fi5 pilot test.
