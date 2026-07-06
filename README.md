# Shipyard Wi-Fi Baseline

This repository contains a local GitHub-ready export of the C02 real shipyard Wi-Fi data reproduction and baseline rule table.

This project is a C02 real shipyard Wi-Fi data reproduction, not a Wi-Fi physical-layer simulation.

## Data Sources

- Throughput comes from raw JSON MATLAB reproduction.
- PTP delay uses steady-state `steady_mean` with `time_s >= 120`.
- `CDR_75ms` uses the paper Table 2 values.
- ROS/control delay is supplementary only because negative delay risk exists.

## Main Conclusion

No single Wi-Fi configuration fits all KPI objectives at the same time. The baseline therefore uses demand-profile rules instead of one universal best configuration.

## Repository Layout

- `matlab/c02_wifi_reproduction/`: MATLAB scripts used for the C02 reproduction and rule table.
- `results/c02/`: selected CSV outputs for the C02 baseline.
- `figures/c02/`: selected PNG figures.
- `docs/`: summary reports and data-quality notes.
- `data/templates/`: KOSORI pilot test data template.

## Next Step

KOSORI Wi-Fi5 pilot test.
