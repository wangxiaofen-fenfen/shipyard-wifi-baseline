# Perama Shipyard Wi-Fi Baseline

This repository contains the Perama Shipyard Wi-Fi Baseline, derived from the public dataset of Rady et al.'s Wi-Fi shipyard study.

This project is a literature-derived Perama Wi-Fi Data Reproduction and baseline integration, not a Wi-Fi physical-layer simulation.

## Data Sources

- Throughput comes from raw JSON MATLAB reproduction.
- PTP delay uses steady-state `steady_mean` with `time_s >= 120`.
- `CDR_75ms` uses the paper Table 2 values.
- ROS/control delay is supplementary only because negative delay risk exists.

## Main Conclusion

No single Wi-Fi configuration fits all KPI objectives at the same time. The baseline therefore uses demand-profile rules instead of one universal best configuration.

## Repository Layout

- `matlab/c02_wifi_reproduction/`: original reproduction scripts for the Perama Shipyard Wi-Fi Baseline.
- `results/perama/`: selected CSV outputs for the Perama Shipyard Wi-Fi Baseline.
- `figures/perama/`: selected PNG figures.
- `docs/`: summary reports and data-quality notes.
- `data/templates/`: KOSORI pilot test data template.

## Next Step

KOSORI Wi-Fi5 pilot test.
