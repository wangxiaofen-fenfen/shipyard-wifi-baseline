# C02 Wi-Fi Baseline Rule Table

## Purpose
Build a scenario-wise Wi-Fi baseline rule table from reproduced C02 shipyard Wi-Fi KPI data.

This is a rule table based on real C02 shipyard Wi-Fi data reproduction, not simulation.

## Input Data
- Integrated KPI baseline v2: `results/c02/c02_integrated_kpi_baseline_v2.csv`
- Best config by KPI v2: `results/c02/c02_best_config_by_kpi_v2.csv`
- Trade-off summary v2: `results/c02/c02_kpi_tradeoff_summary_v2.csv`
- Normalized score v2: `results/c02/c02_integrated_kpi_normalized_score_v2.csv`

## Demand Profiles
- high_throughput_priority: Select highest throughput_mbps_mean.
- low_ptp_delay_priority: Select lowest ptp_delay_ms_steady_mean among ptp_data_status = ok rows.
- control_reliability_priority: Select highest cdr75_percent_table2.
- balanced_equal_weight: Select rank_in_scenario = 1 by overall_equal_weight_score, excluding NaN scores.
- conservative_control_plus_delay: Filter cdr75_percent_table2 >= 90 and ptp_data_status = ok, then select lowest PTP delay; if no CDR>=90 candidate exists, select highest CDR among valid PTP rows.

## Recommendation Rule for Each Profile
- high_throughput_priority: highest throughput_mbps_mean.
- low_ptp_delay_priority: lowest ptp_delay_ms_steady_mean among ptp_data_status = ok rows.
- control_reliability_priority: highest cdr75_percent_table2.
- balanced_equal_weight: rank 1 overall_equal_weight_score, excluding NaN score rows.
- conservative_control_plus_delay: cdr75_percent_table2 >= 90 first, then lowest valid PTP delay; otherwise highest CDR among valid PTP rows.

## Scenario-Wise Recommendations
- S1: high=ax/6/160, low_ptp=ax/6/80, control=ax/6/160, balanced=ax/6/160, conservative=ax/6/80, note=throughput_and_cdr_align_ptp_differs
- S2: high=ax/6/160, low_ptp=ax/6/80, control=ax/6/160, balanced=ax/6/160, conservative=ax/6/80, note=throughput_and_cdr_align_ptp_differs
- S3: high=ax/6/160, low_ptp=ax/5/20, control=ax/6/80, balanced=ax/6/160, conservative=ax/5/20, note=three_kpis_select_different_configs
- S4: high=ax/6/80, low_ptp=ax/5/80, control=ax/6/20, balanced=ax/6/80, conservative=ax/5/80, note=three_kpis_select_different_configs

## Config Role Summary
- Most frequently recommended config(s): ax/6/160 (8 recommendations)
- ax/6/160: total=8, role=high_throughput_dominant
- ax/5/80: total=2, role=specialized_candidate
- ac/5/80: total=0, role=rarely_recommended
- ax/6/80: total=7, role=low_delay_dominant
- ax/2.4/20: total=0, role=rarely_recommended
- ax/5/20: total=2, role=specialized_candidate
- ac/5/20: total=0, role=rarely_recommended
- ax/6/20: total=1, role=specialized_candidate
- n/2.4/20: total=0, role=rarely_recommended

## Main Conclusion
- No single Wi-Fi configuration is best for all KPI objectives: true

## Missing Data Handling
- S3 / ac/5/20 PTP steady-state is missing because max time_s < 120s.
- Missing PTP status retained as: ptp_missing_case_time_short
- S3 / ac/5/20 is not used as a valid PTP-ranked row.
- No imputation, no all_mean fallback, and no deletion were applied.

## ROS/Control Delay Status
- ROS/control delay is supplementary only due to negative delay risk.

## Next Step
- Whether next step can enter own testbed Wi-Fi experiment design: true
