# Wi-Fi 7 Adjusted Final MATLAB 实验结果

本目录整理 MATLAB Wi-Fi 7 adjusted final 实验的正式数值结果。仓库内不提交本地绝对路径；所有来源均以 `SOURCE_ROOT` 下的相对路径标注。实际本地源目录由提交者在 PR/交付说明中记录。

## 数据来源

正式数据来自只读 MATLAB 实验目录 `SOURCE_ROOT`，核心来源文件为：

- `results/wifi7_mlo_adjusted_final_experiment_raw.csv`
- `results/wifi7_mlo_adjusted_final_table_main_32rows.csv`
- `results/wifi7_mlo_adjusted_final_experiment_summary_by_config_scene.csv`
- `results/wifi7_mlo_adjusted_final_issue_audit_summary.csv`
- `results/wifi7_mlo_adjusted_final_issue_audit_sl6160.csv`
- `results/wifi7_mlo_adjusted_final_result_readiness_decision.csv`
- `run_wifi7_mlo_adjusted_final_experiment.m`
- `analyze_wifi7_mlo_adjusted_final_issue_audit.m`
- `analyze_wifi7_mlo_adjusted_final_plots_and_tables.m`

没有重新运行仿真；本次只做读取、核验、重排字段和生成 manifest。

## 正式实验规模和验证

正式主实验是 `8 configs x 4 scenes x 3 seeds`：

- raw 行数：96 / 96
- summary 行数：32 / 32
- 成功运行：96
- 失败运行：0
- 重复组合：无
- 缺失组合：无
- pilot/test 数据：未混入正式 96 raw 或 32 summary
- `MLO-5+6-160+320`：属于正式 8 配置之一，不标记为 unsupported
- `SL-6-320`：仅作为 unsupported/unstable 诊断数据，单独放在 `results/wifi7_diagnostics/`

完整校验见 `wifi7_adjusted_final_validation.csv`。

## 指标和单位

- `throughput_mbps`：吞吐量，单位 Mbps。raw 中来自 `throughput_mbps`，summary 中来自 `throughput_mean_mbps`。
- `throughput_original_value` 和 `throughput_original_unit`：保留原始值和原始单位标注。
- `app_loss_rate`：应用层丢包率，0 到 1 比例，来自 `app_packet_loss_ratio` 或 `app_loss_mean`。
- `app_loss_pct`：应用层丢包百分比，由同一正式比例字段转换为百分比。
- `run_status`：仿真运行是否成功，与通信性能分列。运行 PASS 不代表吞吐量非零。
- 缺失值保留为空或原始 `NaN` 语义，不用 0 替代。真实 0 吞吐量保留为 `0`。

## Summary 聚合方法

32 行 summary 来自正式 `results/wifi7_mlo_adjusted_final_table_main_32rows.csv`，其上游是 `results/wifi7_mlo_adjusted_final_experiment_summary_by_config_scene.csv`。`run_wifi7_mlo_adjusted_final_experiment.m` 中 `buildSummaryByConfigScene` 对每个 config x scene 的 3 个 seed 进行算术平均和标准差统计，字段包括：

- `throughput_mean_mbps`, `throughput_std_mbps`
- `app_loss_mean`, `app_loss_std`
- `mac_loss_mean`, `mac_loss_std`
- `run_success_count`, `run_fail_count`

`analyze_wifi7_mlo_adjusted_final_plots_and_tables.m` 读取上述正式 summary 并生成主 32 行表，没有重新运行仿真。

## Warning 和 Audit

`SL-6-160` 在 S3/S4 出现 zero-throughput/full-loss warning。audit 文件确认：

- S1/S2 正常；
- S3/S4 六个 seed 均为 `throughput_mbps=0` 且 `app_packet_loss_ratio=1`；
- 六行 `run_status=PASS`，`channel_selection_status=PASS`，实际带宽保持 160 MHz；
- audit 结论为 `valid_weak_link_degradation`，即有效弱链路退化，不按仿真失败处理。

因此正式验证状态为 `PASS_READY_WITH_CAUTION`。

## MLO 排名依据

MLO 排名结论来自 `results/wifi7_mlo_adjusted_final_table_config_ranking.csv`。该 ranking 的综合 robustness 排名第一是 `MLO-5+6-160+160`；`MLO-5+6-160+320` 仍是正式配置，且不是 unsupported。不要把 `SL-6-320` 的诊断结论套用到 MLO 320 MHz 配置上。

## 可以写出的结论

- 在这个 MATLAB adjusted final 实验设定内，96 次正式运行全部成功。
- 在 S3/S4 长距离退化场景中，MLO 配置保持非零吞吐量；`SL-6-160` 出现经 audit 确认的弱链路退化。
- 可以报告 `SL-6-160` S3/S4 的 0 Mbps 和 100% 应用层丢包，但必须同时说明 run/channel/audit 状态。
- 可以引用 `wifi7_adjusted_final_32summary.csv` 和 `wifi7_adjusted_final_96raw.csv` 中的数值复核 summary。

## 不能由这些数据推出的结论

- 不能宣称真实世界所有 Wi-Fi 7 6 GHz 160 MHz 链路都会在长距离场景全断。
- 不能宣称 320 MHz 在 Wi-Fi 7 中普遍 unsupported；这里只有 `SL-6-320` 诊断为 unsupported/unstable，`MLO-5+6-160+320` 是正式配置。
- 不能把 pilot/test/smoke/diagnostic 数据与正式 32 行 summary 混合排名。
- 不能把 3 个 seed、0.5 秒 MATLAB system-level 仿真外推为生产网络保证。

## MAT 文件处理

只发现 Wi-Fi 7 相关 `.mat` 为 pilot/supporting 性质，例如 `results/wifi7_mlo_s3_160_160_seed1_pilot_stats.mat`。本次没有上传 `.mat`：它不是正式 96 raw / 32 summary 的必要证据，且二进制文件不利于审计。正式 CSV 中的具体数值足以复核 32 行 summary。
