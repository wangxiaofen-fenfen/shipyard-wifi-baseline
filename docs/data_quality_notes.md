# Data Quality Notes

- CDR raw JSON and Table 2 only partially match, so the main CDR result uses the paper Table 2 values.
- PTP uses steady-state samples with `time_s >= 120`.
- `S3 / ac/5/20` has no PTP steady-state sample because `max time_s = 105.91s`.
- `S3 / ac/5/20` is retained, but marked as `ptp_missing_case_time_short`.
- ROS/control delay has negative delay risk.
- ROS/control delay is not included in the main KPI ranking.
- No values are imputed.
- `all_mean` is not used as a replacement for `steady_mean`.
- Missing rows are not deleted.
