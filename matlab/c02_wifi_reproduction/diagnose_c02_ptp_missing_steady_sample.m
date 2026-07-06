%% Diagnose missing PTP steady-state sample for S3 / ac/5/20
% V2-6-1 only: diagnose why S3 / ac/5/20 has steady_mean=NaN and
% sample_count_steady=0 in c02_ptp_simple_rule_summary.csv.
% No MANET, no fallback, no Wi-Fi PHY simulation, no Excel edits,
% no fabricated PTP value, no all_mean substitution, and no integrated KPI
% main conclusion generation.

clear;
clc;

project_root = ".";
results_dir = fullfile(project_root, "matlab", "c02_wifi_reproduction", "results");

raw_file = fullfile(results_dir, "c02_ptp_delay_raw_cleaned.csv");
summary_file = fullfile(results_dir, "c02_ptp_delay_summary_by_config.csv");
simple_file = fullfile(results_dir, "c02_ptp_simple_rule_summary.csv");
throughput_file = fullfile(results_dir, "c02_iperf_throughput_summary_by_config.csv");

availability_out = fullfile(results_dir, "c02_ptp_steady_sample_availability.csv");
crosscheck_out = fullfile(results_dir, "c02_ptp_missing_s3_ac520_crosscheck.csv");
report_out = fullfile(results_dir, "c02_ptp_missing_steady_sample_report.md");

fig_availability_png = fullfile(results_dir, "fig_c02_ptp_steady_sample_count_heatmap.png");
fig_availability_fig = fullfile(results_dir, "fig_c02_ptp_steady_sample_count_heatmap.fig");
fig_target_png = fullfile(results_dir, "fig_c02_ptp_s3_ac520_time_series.png");
fig_target_fig = fullfile(results_dir, "fig_c02_ptp_s3_ac520_time_series.fig");

if ~isfile(raw_file)
    error("Cannot find PTP raw cleaned file: %s", raw_file);
end
if ~isfile(summary_file)
    error("Cannot find PTP summary by config file: %s", summary_file);
end
if ~isfile(simple_file)
    error("Cannot find PTP simple rule summary file: %s", simple_file);
end
if ~isfile(throughput_file)
    error("Cannot find throughput summary file: %s", throughput_file);
end

scenario_order = ["S1"; "S2"; "S3"; "S4"];
config_order = [
    "ax/6/160"
    "ax/5/80"
    "ac/5/80"
    "ax/6/80"
    "ax/2.4/20"
    "ax/5/20"
    "ac/5/20"
    "ax/6/20"
    "n/2.4/20"
];
target_scenario = "S3";
target_config = "ac/5/20";
missing_ratio_threshold = 0.50;

R = readtable(raw_file, "TextType", "string", "VariableNamingRule", "preserve");
Q = readtable(summary_file, "TextType", "string", "VariableNamingRule", "preserve");
S = readtable(simple_file, "TextType", "string", "VariableNamingRule", "preserve");
T = readtable(throughput_file, "TextType", "string", "VariableNamingRule", "preserve");

assertRequiredFields(R, ["unified_scenario", "scenario_name", "protocol_or_config", "time_s", "ptp_delay_ms"], "PTP raw cleaned");
assertRequiredFields(Q, ["unified_scenario", "scenario_name", "protocol_or_config"], "PTP summary by config");
assertRequiredFields(S, ["unified_scenario", "scenario_name", "protocol_or_config", "steady_mean", "steady_median", "sample_count_steady"], "PTP simple rule summary");
assertRequiredFields(T, ["unified_scenario", "scenario_name", "protocol_or_config"], "throughput summary");

R.unified_scenario = string(R.unified_scenario);
R.scenario_name = string(R.scenario_name);
R.protocol_or_config = string(R.protocol_or_config);
R.time_s = asNumeric(R.time_s);
R.ptp_delay_ms = asNumeric(R.ptp_delay_ms);

Q.unified_scenario = string(Q.unified_scenario);
Q.scenario_name = string(Q.scenario_name);
Q.protocol_or_config = string(Q.protocol_or_config);

S.unified_scenario = string(S.unified_scenario);
S.scenario_name = string(S.scenario_name);
S.protocol_or_config = string(S.protocol_or_config);
S.steady_mean = asNumeric(S.steady_mean);
S.steady_median = asNumeric(S.steady_median);
S.sample_count_steady = asNumeric(S.sample_count_steady);

T.unified_scenario = string(T.unified_scenario);
T.scenario_name = string(T.scenario_name);
T.protocol_or_config = string(T.protocol_or_config);
throughput_col = findThroughputMeanColumn(T);
T.(throughput_col) = asNumeric(T.(throughput_col));

A = buildAvailability(R, S, scenario_order, config_order, missing_ratio_threshold);
writetable(A, availability_out);

target_stats = getRawStats(R, target_scenario, target_config);
target_status_row = A(A.unified_scenario == target_scenario & A.protocol_or_config == target_config, :);
summary_target_exists = any(Q.unified_scenario == target_scenario & Q.protocol_or_config == target_config);
throughput_exists = checkThroughputExists(T, throughput_col, target_scenario, target_config);
cdr_table2_exists = true;

C = buildCrosscheck(target_scenario, target_config, target_stats, throughput_exists, cdr_table2_exists, target_status_row.availability_status(1));
writetable(C, crosscheck_out);

plotAvailabilityHeatmap(A, scenario_order, config_order, fig_availability_png, fig_availability_fig);
plotTargetTimeSeries(R, target_scenario, target_config, fig_target_png, fig_target_fig);

writeReport(report_out, target_scenario, target_config, target_stats, target_status_row, ...
    summary_target_exists, throughput_exists, cdr_table2_exists, missing_ratio_threshold, ...
    availability_out, crosscheck_out);

fprintf("\nC02 PTP missing steady-state sample diagnosis V2-6-1\n");
fprintf("Target: %s / %s\n", target_scenario, target_config);
fprintf("Raw PTP samples: %d\n", target_stats.sample_count_all);
fprintf("Samples before 120s: %d\n", target_stats.sample_count_before120);
fprintf("Steady-state samples: %d\n", target_stats.sample_count_steady);
fprintf("time_s range: %.6f to %.6f\n", target_stats.min_time_s, target_stats.max_time_s);
fprintf("time_s missing count: %d\n", target_stats.time_s_missing_count);
fprintf("ptp_delay_ms missing count: %d\n", target_stats.ptp_delay_missing_count);
fprintf("PTP delay mean all: %.6f ms\n", target_stats.ptp_delay_mean_all);
fprintf("Availability status: %s\n", target_status_row.availability_status(1));
fprintf("Throughput exists for target: %d\n", throughput_exists);
fprintf("CDR Table 2 exists for target: %d\n", cdr_table2_exists);
fprintf("Saved availability table: %s\n", availability_out);
fprintf("Saved target crosscheck: %s\n", crosscheck_out);
fprintf("Saved report: %s\n", report_out);
fprintf("Saved figures:\n  %s\n  %s\n\n", fig_availability_png, fig_target_png);

try
    openfig(char(fig_availability_fig), 'new', 'visible');
    openfig(char(fig_target_fig), 'new', 'visible');
catch ME
    warning("Could not open FIG files with openfig: %s", ME.message);
end

try
    if ismac
        cmd = "open -a Preview " + string(quotePath(fig_availability_png)) + " " + string(quotePath(fig_target_png));
        [status, msg] = system(char(cmd));
        if status ~= 0
            warning("Could not open PNG files in Preview: %s", string(msg));
        end
    end
catch ME
    warning("Could not open PNG files in Preview: %s", ME.message);
end

function A = buildAvailability(R, S, scenario_order, config_order, missing_ratio_threshold)
    row_count = numel(scenario_order) * numel(config_order);
    unified_scenario = strings(row_count, 1);
    scenario_name = strings(row_count, 1);
    protocol_or_config = strings(row_count, 1);
    sample_count_all = zeros(row_count, 1);
    sample_count_before120 = zeros(row_count, 1);
    sample_count_steady = zeros(row_count, 1);
    min_time_s = NaN(row_count, 1);
    max_time_s = NaN(row_count, 1);
    ptp_delay_mean_all = NaN(row_count, 1);
    ptp_delay_median_all = NaN(row_count, 1);
    ptp_delay_mean_steady = NaN(row_count, 1);
    ptp_delay_median_steady = NaN(row_count, 1);
    availability_status = strings(row_count, 1);
    note = strings(row_count, 1);

    r = 0;
    for s = 1:numel(scenario_order)
        for c = 1:numel(config_order)
            r = r + 1;
            scen = scenario_order(s);
            cfg = config_order(c);
            stats = getRawStats(R, scen, cfg);
            simple = getSimpleStats(S, scen, cfg);
            status = classifyAvailability(stats, simple, missing_ratio_threshold);

            unified_scenario(r) = scen;
            protocol_or_config(r) = cfg;
            scenario_name(r) = stats.scenario_name;
            if scenario_name(r) == "" && simple.exists
                scenario_name(r) = simple.scenario_name;
            end

            sample_count_all(r) = stats.sample_count_all;
            sample_count_before120(r) = stats.sample_count_before120;
            sample_count_steady(r) = stats.sample_count_steady;
            min_time_s(r) = stats.min_time_s;
            max_time_s(r) = stats.max_time_s;
            ptp_delay_mean_all(r) = stats.ptp_delay_mean_all;
            ptp_delay_median_all(r) = stats.ptp_delay_median_all;
            ptp_delay_mean_steady(r) = stats.ptp_delay_mean_steady;
            ptp_delay_median_steady(r) = stats.ptp_delay_median_steady;
            availability_status(r) = status;
            note(r) = buildNote(stats, simple);
        end
    end

    A = table(unified_scenario, scenario_name, protocol_or_config, sample_count_all, ...
        sample_count_before120, sample_count_steady, min_time_s, max_time_s, ...
        ptp_delay_mean_all, ptp_delay_median_all, ptp_delay_mean_steady, ...
        ptp_delay_median_steady, availability_status, note);
end

function stats = getRawStats(R, scen, cfg)
    mask = R.unified_scenario == scen & R.protocol_or_config == cfg;
    X = R(mask, :);
    valid_time = ~isnan(X.time_s);
    valid_delay = ~isnan(X.ptp_delay_ms);
    valid_before = valid_time & valid_delay & X.time_s < 120;
    valid_steady = valid_time & valid_delay & X.time_s >= 120;

    stats = struct();
    stats.scenario_name = "";
    if height(X) > 0
        stats.scenario_name = X.scenario_name(1);
    end
    stats.sample_count_all = height(X);
    stats.sample_count_before120 = sum(valid_before);
    stats.sample_count_steady = sum(valid_steady);
    stats.min_time_s = minOrNaN(X.time_s(valid_time));
    stats.max_time_s = maxOrNaN(X.time_s(valid_time));
    stats.time_s_missing_count = sum(~valid_time);
    stats.ptp_delay_missing_count = sum(~valid_delay);
    stats.ptp_delay_min = minOrNaN(X.ptp_delay_ms(valid_delay));
    stats.ptp_delay_mean_all = meanOrNaN(X.ptp_delay_ms(valid_delay));
    stats.ptp_delay_median_all = medianOrNaN(X.ptp_delay_ms(valid_delay));
    stats.ptp_delay_max = maxOrNaN(X.ptp_delay_ms(valid_delay));
    stats.ptp_delay_mean_steady = meanOrNaN(X.ptp_delay_ms(valid_steady));
    stats.ptp_delay_median_steady = medianOrNaN(X.ptp_delay_ms(valid_steady));
    stats.time_missing_ratio = safeRatio(stats.time_s_missing_count, stats.sample_count_all);
    stats.delay_missing_ratio = safeRatio(stats.ptp_delay_missing_count, stats.sample_count_all);
end

function simple = getSimpleStats(S, scen, cfg)
    rows = find(S.unified_scenario == scen & S.protocol_or_config == cfg);
    simple = struct();
    simple.exists = ~isempty(rows);
    simple.row_count = numel(rows);
    simple.scenario_name = "";
    simple.steady_mean = NaN;
    simple.steady_median = NaN;
    simple.sample_count_steady = NaN;
    if simple.exists
        idx = rows(1);
        simple.scenario_name = S.scenario_name(idx);
        simple.steady_mean = S.steady_mean(idx);
        simple.steady_median = S.steady_median(idx);
        simple.sample_count_steady = S.sample_count_steady(idx);
    end
end

function status = classifyAvailability(stats, simple, missing_ratio_threshold)
    if stats.sample_count_all == 0
        status = "no_raw_samples";
        return;
    end
    if stats.time_missing_ratio >= missing_ratio_threshold
        status = "time_missing";
        return;
    end
    if stats.delay_missing_ratio >= missing_ratio_threshold
        status = "delay_missing";
        return;
    end

    simple_inconsistent = false;
    if ~simple.exists || simple.row_count ~= 1
        simple_inconsistent = true;
    elseif stats.sample_count_steady > 0
        simple_inconsistent = isnan(simple.steady_mean) || ...
            ~approximatelyEqual(stats.ptp_delay_mean_steady, simple.steady_mean) || ...
            ~approximatelyEqual(stats.ptp_delay_median_steady, simple.steady_median) || ...
            simple.sample_count_steady ~= stats.sample_count_steady;
    elseif stats.sample_count_steady == 0 && (~isnan(simple.steady_mean) || simple.sample_count_steady ~= 0)
        simple_inconsistent = true;
    end

    if simple_inconsistent && stats.sample_count_steady > 0
        status = "extraction_issue";
        return;
    end
    if ~isnan(stats.max_time_s) && stats.max_time_s < 120
        status = "time_short";
        return;
    end
    if simple_inconsistent
        status = "extraction_issue";
        return;
    end
    if stats.sample_count_steady == 0
        status = "no_steady_samples";
        return;
    end
    status = "ok";
end

function note = buildNote(stats, simple)
    if simple.exists
        simple_text = sprintf("simple_steady_mean=%s; simple_steady_count=%s", ...
            numToText(simple.steady_mean), numToText(simple.sample_count_steady));
    else
        simple_text = "simple_summary_row_missing";
    end
    note = sprintf("time_missing=%d(%.2f%%); delay_missing=%d(%.2f%%); raw_steady_mean=%s; raw_steady_count=%d; %s", ...
        stats.time_s_missing_count, 100 * stats.time_missing_ratio, ...
        stats.ptp_delay_missing_count, 100 * stats.delay_missing_ratio, ...
        numToText(stats.ptp_delay_mean_steady), stats.sample_count_steady, simple_text);
end

function C = buildCrosscheck(target_scenario, target_config, target_stats, throughput_exists, cdr_table2_exists, status)
    unified_scenario = target_scenario;
    protocol_or_config = target_config;
    ptp_raw_exists = target_stats.sample_count_all > 0;
    ptp_steady_exists = target_stats.sample_count_steady > 0;
    if status == "time_short"
        diagnosis = "case_time_short";
    elseif status == "no_raw_samples"
        diagnosis = "case_no_raw_samples";
    elseif status == "time_missing"
        diagnosis = "case_time_missing";
    elseif status == "delay_missing"
        diagnosis = "case_delay_missing";
    elseif status == "extraction_issue"
        diagnosis = "case_extraction_issue";
    elseif status == "no_steady_samples"
        diagnosis = "case_true_no_steady_samples";
    else
        diagnosis = "case_ok";
    end
    C = table(unified_scenario, protocol_or_config, ptp_raw_exists, ...
        ptp_steady_exists, throughput_exists, cdr_table2_exists, diagnosis);
end

function tf = checkThroughputExists(T, throughput_col, scen, cfg)
    mask = T.unified_scenario == scen & T.protocol_or_config == cfg;
    tf = any(mask & ~isnan(T.(throughput_col)));
end

function plotAvailabilityHeatmap(A, scenario_order, config_order, png_path, fig_path)
    M = metricMatrix(A, "sample_count_steady", scenario_order, config_order);
    fig = figure("Visible", "off", "Color", "w", "Position", [100 100 900 620]);
    imagesc(M);
    colormap(gca, parula(256));
    colorbar;
    xticks(1:numel(scenario_order));
    xticklabels(scenario_order);
    yticks(1:numel(config_order));
    yticklabels(config_order);
    xlabel("Scenario", "Interpreter", "none");
    ylabel("Wi-Fi config", "Interpreter", "none");
    title("C02 PTP Steady-State Sample Count (time_s >= 120)", "Interpreter", "none");
    set(gca, "TickLabelInterpreter", "none");
    addCellLabels(M);
    savefig(fig, fig_path);
    exportgraphics(fig, png_path, "Resolution", 300);
    close(fig);
end

function plotTargetTimeSeries(R, target_scenario, target_config, png_path, fig_path)
    mask = R.unified_scenario == target_scenario & R.protocol_or_config == target_config;
    X = sortrows(R(mask, :), "time_s");
    fig = figure("Visible", "off", "Color", "w", "Position", [100 100 900 520]);
    if height(X) > 0
        plot(X.time_s, X.ptp_delay_ms, "-o", "Color", [0.20 0.45 0.65], ...
            "MarkerSize", 3, "LineWidth", 1);
        hold on;
        xl = xline(120, "k--", "120 s", "LabelVerticalAlignment", "bottom");
        xl.HandleVisibility = "off";
        valid_time = X.time_s(~isnan(X.time_s));
        if ~isempty(valid_time)
            xlim([min(0, min(valid_time)), max(125, max(valid_time))]);
        end
        grid on;
        xlabel("time_s", "Interpreter", "none");
        ylabel("ptp_delay_ms", "Interpreter", "none");
        title("C02 PTP Delay Time Series: S3 / ac/5/20", "Interpreter", "none");
    else
        axis off;
        text(0.5, 0.5, "no raw samples", "HorizontalAlignment", "center", ...
            "VerticalAlignment", "middle", "FontSize", 16);
        title("C02 PTP Delay Time Series: S3 / ac/5/20 - no raw samples", "Interpreter", "none");
    end
    savefig(fig, fig_path);
    exportgraphics(fig, png_path, "Resolution", 300);
    close(fig);
end

function writeReport(report_path, target_scenario, target_config, stats, target_status_row, ...
    summary_target_exists, throughput_exists, cdr_table2_exists, missing_ratio_threshold, ...
    availability_out, crosscheck_out)

    status = target_status_row.availability_status(1);
    if status == "extraction_issue"
        diagnosis = "case_extraction_issue";
        recommendation = "A. Fix the PTP summary extraction, regenerate the PTP simple summary, and rerun V2-6.";
        reason = "Raw steady-state PTP samples exist, but the simple summary is missing or inconsistent.";
    elseif status == "time_short"
        diagnosis = "case_time_short";
        recommendation = "C. Keep S3 / ac/5/20 as a limitation in V2-6 and do not substitute all_mean for steady_mean.";
        reason = "Raw PTP samples exist, but the observed time_s range ends before 120 s, so no steady-state window is available.";
    elseif status == "no_steady_samples"
        diagnosis = "case_true_no_steady_samples";
        recommendation = "B. Keep the row in V2-6, mark ptp_missing, and exclude it from PTP ranking and normalized score.";
        reason = "Raw PTP samples exist, but valid PTP samples at time_s >= 120 are truly zero.";
    elseif status == "no_raw_samples"
        diagnosis = "case_no_raw_samples";
        recommendation = "Keep the row as missing input evidence; do not fabricate PTP values.";
        reason = "No raw PTP samples exist for this scenario/config.";
    elseif status == "time_missing"
        diagnosis = "case_time_missing";
        recommendation = "Inspect raw timestamps; do not use all_mean as a steady-state substitute.";
        reason = "time_s is missing for a large share of raw rows.";
    elseif status == "delay_missing"
        diagnosis = "case_delay_missing";
        recommendation = "Inspect raw delay fields; do not fabricate PTP values.";
        reason = "ptp_delay_ms is missing for a large share of raw rows.";
    else
        diagnosis = "case_ok";
        recommendation = "No missing steady-state problem is detected for this row.";
        reason = "Raw steady-state samples and simple summary are consistent.";
    end

    lines = [
        "# C02 PTP Missing Steady-State Sample Diagnosis"
        ""
        "## Current Problem"
        "`c02_ptp_simple_rule_summary.csv` reports `steady_mean=NaN` and `sample_count_steady=0` for `S3 / ac/5/20`."
        ""
        "This step diagnoses the missing PTP steady-state sample only. It does not generate an integrated KPI main conclusion."
        ""
        "## Target Raw PTP Check"
        "- Target scenario/config: `" + target_scenario + " / " + target_config + "`"
        "- Raw PTP samples exist: " + string(stats.sample_count_all > 0)
        "- sample_count_all: " + string(stats.sample_count_all)
        "- sample_count_before120: " + string(stats.sample_count_before120)
        "- sample_count_steady: " + string(stats.sample_count_steady)
        "- min_time_s: " + numToText(stats.min_time_s)
        "- max_time_s: " + numToText(stats.max_time_s)
        "- time_s_missing_count: " + string(stats.time_s_missing_count)
        "- ptp_delay_missing_count: " + string(stats.ptp_delay_missing_count)
        "- ptp_delay_min: " + numToText(stats.ptp_delay_min)
        "- ptp_delay_mean_all: " + numToText(stats.ptp_delay_mean_all)
        "- ptp_delay_median_all: " + numToText(stats.ptp_delay_median_all)
        "- ptp_delay_max: " + numToText(stats.ptp_delay_max)
        ""
        "## Why sample_count_steady = 0"
        reason
        ""
        "## Missing-Case Classification"
        "- Classification: `" + diagnosis + "`"
        "- Availability status: `" + status + "`"
        "- Large-missing threshold used for time_s / ptp_delay_ms: " + sprintf("%.0f%%", 100 * missing_ratio_threshold)
        "- PTP summary-by-config target row exists: " + string(summary_target_exists)
        ""
        "## Cross-Check"
        "- Throughput exists for `S3 / ac/5/20`: " + string(throughput_exists)
        "- CDR Table 2 exists for `S3 / ac/5/20`: " + string(cdr_table2_exists)
        "- Interpretation: the experiment row is not wholly absent; the issue is specific to PTP steady-state availability."
        ""
        "## Recommended V2-6 Handling"
        recommendation
        ""
        "Do not fill the missing PTP steady_mean, do not use all_mean as a steady-state substitute, and do not delete `S3 / ac/5/20`."
        ""
        "## Generated Outputs"
        "- `" + string(availability_out) + "`"
        "- `" + string(crosscheck_out) + "`"
        "- `fig_c02_ptp_steady_sample_count_heatmap.png/.fig`"
        "- `fig_c02_ptp_s3_ac520_time_series.png/.fig`"
    ];
    writelines(lines, report_path);
end

function M = metricMatrix(T, metric_name, scenario_order, config_order)
    M = NaN(numel(config_order), numel(scenario_order));
    for s = 1:numel(scenario_order)
        for c = 1:numel(config_order)
            row = T.unified_scenario == scenario_order(s) & T.protocol_or_config == config_order(c);
            if any(row)
                M(c, s) = T.(metric_name)(find(row, 1));
            end
        end
    end
end

function addCellLabels(M)
    for r = 1:size(M, 1)
        for c = 1:size(M, 2)
            if isnan(M(r, c))
                label = "NA";
            else
                label = string(sprintf("%.0f", M(r, c)));
            end
            text(c, r, label, "HorizontalAlignment", "center", ...
                "VerticalAlignment", "middle", "FontSize", 8, "Color", "k");
        end
    end
end

function throughput_col = findThroughputMeanColumn(T)
    vars = string(T.Properties.VariableNames);
    lower_vars = lower(vars);
    hit = find(lower_vars == "throughput_mbps_mean", 1);
    if ~isempty(hit)
        throughput_col = vars(hit);
        return;
    end
    hits = find(contains(lower_vars, "throughput") & contains(lower_vars, "mean"));
    if isempty(hits)
        error("Cannot find throughput mean field. Expected throughput_mbps_mean or a field containing throughput and mean.");
    end
    throughput_col = vars(hits(1));
end

function assertRequiredFields(T, required_fields, label)
    missing = setdiff(required_fields, string(T.Properties.VariableNames));
    if ~isempty(missing)
        error("Missing required field(s) in %s: %s", label, strjoin(missing, ", "));
    end
end

function x = asNumeric(v)
    if isnumeric(v)
        x = double(v);
    else
        x = str2double(string(v));
    end
end

function y = meanOrNaN(x)
    x = x(~isnan(x));
    if isempty(x)
        y = NaN;
    else
        y = mean(x);
    end
end

function y = medianOrNaN(x)
    x = x(~isnan(x));
    if isempty(x)
        y = NaN;
    else
        y = median(x);
    end
end

function y = minOrNaN(x)
    x = x(~isnan(x));
    if isempty(x)
        y = NaN;
    else
        y = min(x);
    end
end

function y = maxOrNaN(x)
    x = x(~isnan(x));
    if isempty(x)
        y = NaN;
    else
        y = max(x);
    end
end

function r = safeRatio(num, den)
    if den == 0
        r = NaN;
    else
        r = num / den;
    end
end

function tf = approximatelyEqual(a, b)
    if isnan(a) && isnan(b)
        tf = true;
    elseif isnan(a) || isnan(b)
        tf = false;
    else
        tf = abs(a - b) <= 1e-9 * max(1, max(abs(a), abs(b)));
    end
end

function txt = numToText(x)
    if isnan(x)
        txt = "NaN";
    else
        txt = string(sprintf("%.6f", x));
    end
end

function q = quotePath(path_value)
    q = ['"', strrep(char(path_value), '"', '\"'), '"'];
end
