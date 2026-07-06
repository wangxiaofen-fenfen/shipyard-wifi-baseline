# C02 PTP Missing Steady-State Sample Diagnosis

## Current Problem
`c02_ptp_simple_rule_summary.csv` reports `steady_mean=NaN` and `sample_count_steady=0` for `S3 / ac/5/20`.

This step diagnoses the missing PTP steady-state sample only. It does not generate an integrated KPI main conclusion.

## Target Raw PTP Check
- Target scenario/config: `S3 / ac/5/20`
- Raw PTP samples exist: true
- sample_count_all: 176
- sample_count_before120: 176
- sample_count_steady: 0
- min_time_s: 0.000000
- max_time_s: 105.913864
- time_s_missing_count: 0
- ptp_delay_missing_count: 0
- ptp_delay_min: 0.000000
- ptp_delay_mean_all: 17.413998
- ptp_delay_median_all: 16.161290
- ptp_delay_max: 36.299912

## Why sample_count_steady = 0
Raw PTP samples exist, but the observed time_s range ends before 120 s, so no steady-state window is available.

## Missing-Case Classification
- Classification: `case_time_short`
- Availability status: `time_short`
- Large-missing threshold used for time_s / ptp_delay_ms: 50%
- PTP summary-by-config target row exists: true

## Cross-Check
- Throughput exists for `S3 / ac/5/20`: true
- CDR Table 2 exists for `S3 / ac/5/20`: true
- Interpretation: the experiment row is not wholly absent; the issue is specific to PTP steady-state availability.

## Recommended V2-6 Handling
C. Keep S3 / ac/5/20 as a limitation in V2-6 and do not substitute all_mean for steady_mean.

Do not fill the missing PTP steady_mean, do not use all_mean as a steady-state substitute, and do not delete `S3 / ac/5/20`.

## Generated Outputs
- `results/c02/c02_ptp_steady_sample_availability.csv`
- `results/c02/c02_ptp_missing_s3_ac520_crosscheck.csv`
- `fig_c02_ptp_steady_sample_count_heatmap.png/.fig`
- `fig_c02_ptp_s3_ac520_time_series.png/.fig`
