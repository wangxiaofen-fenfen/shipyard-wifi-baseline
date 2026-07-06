# C02 Integrated KPI Baseline V2

## Purpose
Build a 36-row integrated KPI baseline for C02 Wi-Fi configurations using reproduced throughput, reproduced PTP steady-state delay where available, PTP missing flags, and paper Table 2 CDR_75ms.

This is literature raw-data reproduction and baseline integration, not Wi-Fi PHY simulation.

## Input Data
- Throughput source: raw JSON MATLAB reproduction
- Throughput file: `results/c02/c02_iperf_throughput_summary_by_config.csv`
- PTP source: raw JSON steady_mean, time_s >= 120
- PTP file: `results/c02/c02_ptp_simple_rule_summary.csv`
- PTP availability file: `results/c02/c02_ptp_steady_sample_availability.csv`
- PTP limitation: S3 / ac/5/20 has raw samples only from 0 to 105.91s, so no steady-state PTP sample exists
- CDR source: paper Table 2
- ROS/control delay status: supplementary only because negative delay risk exists

## 36-Row Coverage Check
- Integrated row count: 36
- Scenario coverage: 4 / 4
- Wi-Fi config coverage: 9 / 9
- Coverage check passed: true
- PTP missing row count: 1
- PTP missing is only S3 / ac/5/20 with ptp_missing_case_time_short: true

## Missing Data Handling Rule
- No imputation.
- No all_mean fallback.
- No deletion of S3 / ac/5/20.
- PTP ranking and normalized score exclude rows with missing ptp_delay_ms_steady_mean.
- Throughput and CDR ranking still include S3 / ac/5/20.

## Best Config by KPI and Scenario
- S1 / throughput_mbps_mean: ax/6/160 (633.495), excluded=none
- S1 / ptp_delay_ms_steady_mean: ax/6/80 (9.69054), excluded=none
- S1 / cdr75_percent_table2: ax/6/160 (94), excluded=none
- S2 / throughput_mbps_mean: ax/6/160 (563.587), excluded=none
- S2 / ptp_delay_ms_steady_mean: ax/6/80 (11.6194), excluded=none
- S2 / cdr75_percent_table2: ax/6/160 (97), excluded=none
- S3 / throughput_mbps_mean: ax/6/160 (84.6611), excluded=none
- S3 / ptp_delay_ms_steady_mean: ax/5/20 (8.71991), excluded=excluded_missing_ptp_steady_mean:S3/ac/5/20
- S3 / cdr75_percent_table2: ax/6/80 (99), excluded=none
- S4 / throughput_mbps_mean: ax/6/80 (185.917), excluded=none
- S4 / ptp_delay_ms_steady_mean: ax/5/80 (10.8708), excluded=none
- S4 / cdr75_percent_table2: ax/6/20 (95), excluded=none

## Trade-Off Observation
- S1: throughput=ax/6/160, PTP=ax/6/80, CDR=ax/6/160, missing_ptp=none, note=throughput_and_cdr_align_ptp_differs
- S2: throughput=ax/6/160, PTP=ax/6/80, CDR=ax/6/160, missing_ptp=none, note=throughput_and_cdr_align_ptp_differs
- S3: throughput=ax/6/160, PTP=ax/5/20, CDR=ax/6/80, missing_ptp=excluded_missing_ptp_steady_mean:S3/ac/5/20, note=three_kpis_select_different_configs
- S4: throughput=ax/6/80, PTP=ax/5/80, CDR=ax/6/20, missing_ptp=none, note=three_kpis_select_different_configs
- Any scenario with one config best for all three KPIs: false

## Descriptive Normalized Baseline
The equal-weight normalized score is descriptive only. It is not a final AI model and is not used as a formal optimization conclusion.
- Top descriptive score S1: ax/6/160 (0.9469), excluded=none
- Top descriptive score S2: ax/6/160 (0.9614), excluded=none
- Top descriptive score S3: ax/6/160 (0.8460), excluded=S3/ac/5/20
- Top descriptive score S4: ax/6/80 (0.9052), excluded=none

## Limitation
- Throughput and PTP are reproduced from raw JSON summaries.
- CDR_75ms is embedded from paper Table 2 in percent units.
- S3 / ac/5/20 keeps throughput and CDR values, but PTP steady_mean remains missing because the raw time series ends before 120 s.
- ROS/control delay is not included in the ranking because V2-5-2 found negative-delay risk; it remains supplementary only.
- This step does not perform MANET, fallback, Wi-Fi PHY simulation, Excel edits, or formal ROS/control delay reproduction.

## Next Step
- Whether next step can enter V2-7 Wi-Fi baseline rule table: true
- V2-7 should carry the ptp_missing flag and avoid treating S3 / ac/5/20 as a valid PTP-ranked row.
