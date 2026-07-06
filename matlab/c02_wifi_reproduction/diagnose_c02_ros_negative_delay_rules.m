%% Diagnose negative ROS/control delay handling rules
% V2-5-1 only: negative-value口径 diagnosis. No formal ROS reproduction.
% No MANET, no fallback, no Wi-Fi PHY simulation, no Excel edits.

clear;
clc;

project_root = ".";
results_dir = fullfile(project_root, "matlab", "c02_wifi_reproduction", "results");
raw_file = fullfile(results_dir, "c02_ros_control_delay_raw_cleaned.csv");

if ~isfile(raw_file)
    error("Cannot find ROS/control delay raw cleaned file: %s", raw_file);
end

R = readtable(raw_file, "TextType", "string", "VariableNamingRule", "preserve");
required_fields = ["unified_scenario", "scenario_name", "location_id", "distance_m", ...
    "los_condition", "protocol_or_config", "time_s", "control_delay_ms"];
missing = setdiff(required_fields, string(R.Properties.VariableNames));
if ~isempty(missing)
    error("Missing required field(s): %s", strjoin(missing, ", "));
end

scenario_order = ["S1", "S2", "S3", "S4"];
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
rule_names = ["rule_raw_keep", "rule_drop_negative", "rule_zero_floor", ...
    "rule_abs", "rule_moving_median_5s"];

N = buildNegativeCounts(R, scenario_order, config_order);
neg_out = fullfile(results_dir, "c02_ros_negative_delay_count_by_config.csv");
writetable(N, neg_out);

plotNegativeHeatmap(N, scenario_order, config_order, ...
    fullfile(results_dir, "fig_c02_ros_negative_ratio_steady_heatmap.png"), ...
    fullfile(results_dir, "fig_c02_ros_negative_ratio_steady_heatmap.fig"));
plotSteadyHistogram(R, ...
    fullfile(results_dir, "fig_c02_ros_delay_histogram_steady.png"), ...
    fullfile(results_dir, "fig_c02_ros_delay_histogram_steady.fig"));

D = buildRuleDiagnosis(R, scenario_order, config_order, rule_names);
diag_out = fullfile(results_dir, "c02_ros_delay_rule_diagnosis_summary.csv");
writetable(D, diag_out);

C = buildCdrTable(R, scenario_order, config_order, rule_names);
cdr_out = fullfile(results_dir, "c02_ros_cdr75_by_negative_rule.csv");
writetable(C, cdr_out);

E = buildCdrErrorSummary(C);
err_out = fullfile(results_dir, "c02_ros_cdr75_negative_rule_error_summary.csv");
writetable(E, err_out);

writeReport(fullfile(results_dir, "c02_ros_negative_delay_rule_diagnosis_report.md"), ...
    R, N, D, E);

fprintf("\nC02 ROS/control negative delay rule diagnosis V2-5-1\n");
fprintf("Input: %s\n", raw_file);
fprintf("Total samples: %d\n", height(R));
fprintf("Total negative samples: %d\n", sum(R.control_delay_ms < 0));
fprintf("Steady negative samples: %d\n", sum(R.time_s >= 120 & R.control_delay_ms < 0));
[~, top_idx] = max(N.negative_ratio_steady);
fprintf("Highest steady negative ratio: %s %s = %.4f\n", ...
    N.unified_scenario(top_idx), N.protocol_or_config(top_idx), N.negative_ratio_steady(top_idx));
disp(E);
fprintf("Saved negative counts: %s\n", neg_out);
fprintf("Saved rule diagnosis: %s\n", diag_out);
fprintf("Saved CDR table: %s\n", cdr_out);
fprintf("Saved CDR error summary: %s\n\n", err_out);

function N = buildNegativeCounts(R, scenario_order, config_order)
    n = numel(scenario_order) * numel(config_order);
    unified_scenario = strings(n, 1);
    scenario_name = strings(n, 1);
    protocol_or_config = strings(n, 1);
    sample_count_all = zeros(n, 1);
    negative_count_all = zeros(n, 1);
    negative_ratio_all = NaN(n, 1);
    sample_count_steady = zeros(n, 1);
    negative_count_steady = zeros(n, 1);
    negative_ratio_steady = NaN(n, 1);
    min_delay_all = NaN(n, 1);
    min_delay_steady = NaN(n, 1);
    mean_delay_all = NaN(n, 1);
    mean_delay_steady = NaN(n, 1);
    median_delay_all = NaN(n, 1);
    median_delay_steady = NaN(n, 1);
    r = 0;
    for s = 1:numel(scenario_order)
        for c = 1:numel(config_order)
            r = r + 1;
            mask = R.unified_scenario == scenario_order(s) & R.protocol_or_config == config_order(c);
            steady_mask = mask & R.time_s >= 120;
            x = R.control_delay_ms(mask);
            xs = R.control_delay_ms(steady_mask);
            unified_scenario(r) = scenario_order(s);
            protocol_or_config(r) = config_order(c);
            if any(mask), scenario_name(r) = R.scenario_name(find(mask, 1)); end
            sample_count_all(r) = numel(x);
            negative_count_all(r) = sum(x < 0);
            sample_count_steady(r) = numel(xs);
            negative_count_steady(r) = sum(xs < 0);
            if sample_count_all(r) > 0
                negative_ratio_all(r) = negative_count_all(r) / sample_count_all(r);
                min_delay_all(r) = min(x);
                mean_delay_all(r) = mean(x);
                median_delay_all(r) = median(x);
            end
            if sample_count_steady(r) > 0
                negative_ratio_steady(r) = negative_count_steady(r) / sample_count_steady(r);
                min_delay_steady(r) = min(xs);
                mean_delay_steady(r) = mean(xs);
                median_delay_steady(r) = median(xs);
            end
        end
    end
    N = table(unified_scenario, scenario_name, protocol_or_config, sample_count_all, ...
        negative_count_all, negative_ratio_all, sample_count_steady, negative_count_steady, ...
        negative_ratio_steady, min_delay_all, min_delay_steady, mean_delay_all, ...
        mean_delay_steady, median_delay_all, median_delay_steady);
end

function plotNegativeHeatmap(N, scenario_order, config_order, png_path, fig_path)
    M = NaN(numel(config_order), numel(scenario_order));
    for i = 1:height(N)
        row = find(config_order == N.protocol_or_config(i), 1);
        col = find(scenario_order == N.unified_scenario(i), 1);
        M(row, col) = N.negative_ratio_steady(i);
    end
    fig = figure("Visible", "off", "Color", "w", "Position", [100 100 980 620]);
    h = heatmap(scenario_order, config_order, M);
    h.Title = "Steady-State Negative ROS/Control Delay Ratio";
    h.XLabel = "Scenario";
    h.YLabel = "Wi-Fi config";
    h.CellLabelFormat = "%.3f";
    h.Colormap = parula(256);
    savefig(fig, fig_path);
    exportgraphics(fig, png_path, "Resolution", 300);
    close(fig);
end

function plotSteadyHistogram(R, png_path, fig_path)
    x = R.control_delay_ms(R.time_s >= 120);
    lo = percentile(x, 1);
    hi = percentile(x, 99);
    fig = figure("Visible", "off", "Color", "w", "Position", [100 100 850 500]);
    histogram(x, 80, "FaceColor", [0.20 0.45 0.65], "EdgeColor", "none");
    xlim([lo hi]);
    grid on;
    xlabel("control_delay_ms (steady-state, clipped to 1%-99%)");
    ylabel("Count");
    title("Steady-State ROS/Control Delay Distribution");
    savefig(fig, fig_path);
    exportgraphics(fig, png_path, "Resolution", 300);
    close(fig);
end

function D = buildRuleDiagnosis(R, scenario_order, config_order, rule_names)
    rows = numel(rule_names) * numel(scenario_order) * numel(config_order);
    rule_name = strings(rows, 1);
    unified_scenario = strings(rows, 1);
    scenario_name = strings(rows, 1);
    protocol_or_config = strings(rows, 1);
    sample_count_steady = zeros(rows, 1);
    steady_mean = NaN(rows, 1);
    steady_median = NaN(rows, 1);
    steady_p25 = NaN(rows, 1);
    steady_p75 = NaN(rows, 1);
    steady_p95 = NaN(rows, 1);
    r = 0;
    for k = 1:numel(rule_names)
        Rr = applyRule(R, rule_names(k));
        for s = 1:numel(scenario_order)
            for c = 1:numel(config_order)
                r = r + 1;
                mask = Rr.unified_scenario == scenario_order(s) & ...
                    Rr.protocol_or_config == config_order(c) & Rr.time_s >= 120;
                x = Rr.delay_rule_ms(mask);
                x = x(~isnan(x));
                rule_name(r) = rule_names(k);
                unified_scenario(r) = scenario_order(s);
                protocol_or_config(r) = config_order(c);
                base_mask = R.unified_scenario == scenario_order(s) & R.protocol_or_config == config_order(c);
                if any(base_mask), scenario_name(r) = R.scenario_name(find(base_mask, 1)); end
                sample_count_steady(r) = numel(x);
                if ~isempty(x)
                    steady_mean(r) = mean(x);
                    steady_median(r) = median(x);
                    steady_p25(r) = percentile(x, 25);
                    steady_p75(r) = percentile(x, 75);
                    steady_p95(r) = percentile(x, 95);
                end
            end
        end
    end
    D = table(rule_name, unified_scenario, scenario_name, protocol_or_config, ...
        sample_count_steady, steady_mean, steady_median, steady_p25, steady_p75, steady_p95);
end

function C = buildCdrTable(R, scenario_order, config_order, rule_names)
    rows = numel(rule_names) * numel(scenario_order) * numel(config_order);
    rule_name = strings(rows, 1);
    unified_scenario = strings(rows, 1);
    scenario_name = strings(rows, 1);
    protocol_or_config = strings(rows, 1);
    cdr75 = NaN(rows, 1);
    sample_count_steady = zeros(rows, 1);
    r = 0;
    for k = 1:numel(rule_names)
        Rr = applyRule(R, rule_names(k));
        for s = 1:numel(scenario_order)
            for c = 1:numel(config_order)
                r = r + 1;
                mask = Rr.unified_scenario == scenario_order(s) & ...
                    Rr.protocol_or_config == config_order(c) & Rr.time_s >= 120;
                x = Rr.delay_rule_ms(mask);
                x = x(~isnan(x));
                rule_name(r) = rule_names(k);
                unified_scenario(r) = scenario_order(s);
                protocol_or_config(r) = config_order(c);
                base_mask = R.unified_scenario == scenario_order(s) & R.protocol_or_config == config_order(c);
                if any(base_mask), scenario_name(r) = R.scenario_name(find(base_mask, 1)); end
                sample_count_steady(r) = numel(x);
                if ~isempty(x)
                    cdr75(r) = sum(x < 75) / numel(x);
                end
            end
        end
    end
    C = table(rule_name, unified_scenario, scenario_name, protocol_or_config, cdr75, sample_count_steady);
end

function Rr = applyRule(R, rule_name)
    Rr = R;
    x = R.control_delay_ms;
    switch rule_name
        case "rule_raw_keep"
            y = x;
        case "rule_drop_negative"
            y = x;
            y(y < 0) = NaN;
        case "rule_zero_floor"
            y = x;
            y(y < 0) = 0;
        case "rule_abs"
            y = abs(x);
        case "rule_moving_median_5s"
            y = NaN(size(x));
            groups = unique(R(:, ["unified_scenario", "protocol_or_config"]), "rows");
            for i = 1:height(groups)
                mask = R.unified_scenario == groups.unified_scenario(i) & ...
                    R.protocol_or_config == groups.protocol_or_config(i);
                idx = find(mask);
                [~, ord] = sort(R.time_s(idx));
                sorted_idx = idx(ord);
                y(sorted_idx) = movmedian(R.control_delay_ms(sorted_idx), 11, "omitnan");
            end
        otherwise
            error("Unknown rule: %s", rule_name);
    end
    Rr.delay_rule_ms = y;
end

function E = buildCdrErrorSummary(C)
    table2 = buildTable2Cdr();
    rules = unique(C.rule_name, "stable");
    rule_name = strings(numel(rules), 1);
    mean_abs_error = NaN(numel(rules), 1);
    max_abs_error = NaN(numel(rules), 1);
    match_count_error_under_0p02 = zeros(numel(rules), 1);
    note = strings(numel(rules), 1);
    for i = 1:numel(rules)
        rows = C(C.rule_name == rules(i), :);
        err = NaN(height(rows), 1);
        for r = 1:height(rows)
            key = rows.unified_scenario(r) + "|" + rows.protocol_or_config(r);
            err(r) = abs(rows.cdr75(r) - table2(key));
        end
        rule_name(i) = rules(i);
        mean_abs_error(i) = mean(err, "omitnan");
        max_abs_error(i) = max(err, [], "omitnan");
        match_count_error_under_0p02(i) = sum(err < 0.02);
        if rules(i) == "rule_moving_median_5s"
            note(i) = "movmedian approximation uses 11 sorted samples, about 5 s at 0.5 s period";
        elseif rules(i) == "rule_abs"
            note(i) = "diagnostic only; not recommended without paper support";
        else
            note(i) = "steady-state CDR75 error vs Table 2";
        end
    end
    E = table(rule_name, mean_abs_error, max_abs_error, match_count_error_under_0p02, note);
end

function m = buildTable2Cdr()
    scenarios = ["S1", "S2", "S3", "S4"];
    configs = ["ax/6/160", "ax/5/80", "ac/5/80", "ax/6/80", "ax/2.4/20", ...
        "ax/5/20", "ac/5/20", "ax/6/20", "n/2.4/20"];
    vals = [
        94 89 90 91 84 91 93 87 90
        97 93 90 90 93 92 91 93 88
        93 98 90 99 87 98 0 49 83
        92 94 93 88 94 93 93 95 83
    ] / 100;
    m = containers.Map("KeyType", "char", "ValueType", "double");
    for s = 1:numel(scenarios)
        for c = 1:numel(configs)
            m(char(scenarios(s) + "|" + configs(c))) = vals(s, c);
        end
    end
end

function p = percentile(values, pct)
    values = sort(values(:));
    values = values(~isnan(values));
    if isempty(values)
        p = NaN;
        return;
    end
    idx = 1 + (numel(values) - 1) * pct / 100;
    lo = floor(idx);
    hi = ceil(idx);
    if lo == hi
        p = values(lo);
    else
        p = values(lo) + (idx - lo) * (values(hi) - values(lo));
    end
end

function writeReport(report_path, R, N, D, E)
    total_neg = sum(R.control_delay_ms < 0);
    steady_neg = sum(R.time_s >= 120 & R.control_delay_ms < 0);
    [~, top_idx] = max(N.negative_ratio_steady);
    [~, best_idx] = min(E.mean_abs_error);
    best_rule = E.rule_name(best_idx);
    delay_rows = D(D.rule_name == best_rule, :);
    delay_mean_min = min(delay_rows.steady_mean, [], "omitnan");
    delay_mean_max = max(delay_rows.steady_mean, [], "omitnan");
    can_continue = E.mean_abs_error(best_idx) < 0.02 && E.max_abs_error(best_idx) < 0.05;
    if can_continue
        recommendation = "A formal ROS/control delay reproduction may proceed only with the selected diagnostic rule documented.";
    else
        recommendation = "ROS delay raw JSON should be treated as supplementary analysis, not a direct main-text result.";
    end

    lines = [
        "# C02 ROS/Control Negative Delay Rule Diagnosis"
        ""
        "## Current problem"
        "- `control_delay_ms` has " + string(total_neg) + " negative samples."
        "- Steady-state negative samples (`time_s >= 120`): " + string(steady_neg)
        ""
        "## Where negatives are concentrated"
        "- Highest steady negative ratio: " + N.unified_scenario(top_idx) + " / " + ...
            N.protocol_or_config(top_idx) + " = " + sprintf("%.4f", N.negative_ratio_steady(top_idx))
        "- Negative values are present in steady state: " + string(steady_neg > 0)
        ""
        "## Candidate rules"
        "- rule_raw_keep: keep original delay, including negative values."
        "- rule_drop_negative: keep only control_delay_ms >= 0."
        "- rule_zero_floor: set negative values to 0."
        "- rule_abs: use abs(control_delay_ms), diagnostic only and not recommended directly."
        "- rule_moving_median_5s: moving median approximation using 11 sorted samples, about 5 s at 0.5 s period."
        ""
        "## Delay statistics under candidate rules"
        "- For the best CDR-matching rule, steady_mean range across 36 scenario/config rows: " + ...
            sprintf("%.2f", delay_mean_min) + " to " + sprintf("%.2f", delay_mean_max) + " ms."
        ""
        "## CDR_75ms comparison with Table 2"
        "- Closest rule by mean_abs_error: " + best_rule
        "- mean_abs_error: " + sprintf("%.4f", E.mean_abs_error(best_idx))
        "- max_abs_error: " + sprintf("%.4f", E.max_abs_error(best_idx))
        "- match_count_error_under_0p02: " + string(E.match_count_error_under_0p02(best_idx)) + "/36"
        ""
        "## Recommendation"
        "- Recommended rule: " + best_rule
        "- Continue formal ROS/control delay reproduction: " + string(can_continue)
        "- " + recommendation
        ""
        "## Note"
        "This is only negative-delay口径 diagnosis. It does not generate formal ROS/control delay conclusions or combined KPI results."
    ];
    writelines(lines, report_path);
end
