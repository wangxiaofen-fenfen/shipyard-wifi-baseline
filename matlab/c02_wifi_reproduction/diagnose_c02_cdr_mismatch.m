%% Diagnose Table 2 vs raw JSON CDR mismatch
% V2-2.6 only: compare alternate CDR definitions. No simulation/modeling.

clear;
clc;

project_root = ".";
results_dir = fullfile(project_root, "matlab", "c02_wifi_reproduction", "results");
validation_file = fullfile(results_dir, "c02_cdr_table2_vs_json_validation.csv");
json_path = fullfile(project_root, "external_data", "c02_wifi_raw", ...
    "wifi_for_industrial_robotics", "plots", "perama_range_testing.json");

if ~isfile(validation_file)
    error("Missing validation file: %s", validation_file);
end
if ~isfile(json_path)
    error("Missing raw JSON file: %s", json_path);
end

V = readtable(validation_file, "TextType", "string", "VariableNamingRule", "preserve");
V = normalizeValidationTable(V);

json_data = jsondecode(fileread(json_path));

scenario_order = ["S1", "S2", "S3", "S4"];
json_location_fields = ["x1", "x2", "x3", "x4"];
location_id_map = (1:4)';
distance_map = [13; 60; 130; 150];
los_map = ["LoS"; "LoS"; "NLoS"; "mixed"];

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
json_config_fields = [
    "ax_160mhz_6ghz"
    "ax_80mhz_5ghz"
    "ac_80mhz_5ghz"
    "ax_80mhz_6ghz"
    "ax_20mhz_24ghz"
    "ax_20mhz_5ghz"
    "ac_20mhz_5ghz"
    "ax_20mhz_6ghz"
    "n_20mhz_24ghz"
];

diagnosis = buildMultiRuleTable(V, json_data, scenario_order, json_location_fields, ...
    config_order, json_config_fields);
diagnosis_out = fullfile(results_dir, "c02_cdr_multi_rule_diagnosis.csv");
writetable(diagnosis, diagnosis_out);

mismatch = V(V.cdr_abs_error > 0.01, :);
[~, midx] = ismember(string(mismatch.unified_scenario), scenario_order);
mismatch.location_id = location_id_map(midx);
mismatch.distance_m = distance_map(midx);
mismatch.los_condition = los_map(midx);
mismatch.CDR_75ms_json = mismatch.CDR_75ms_from_raw;
mismatch.abs_error = mismatch.cdr_abs_error;
mismatch.relative_error = mismatch.cdr_error_percent;
mismatch = mismatch(:, ["unified_scenario", "scenario_name", "protocol_or_config", ...
    "CDR_75ms_table2", "CDR_75ms_json", "abs_error", "relative_error", ...
    "location_id", "distance_m", "los_condition"]);
mismatch_out = fullfile(results_dir, "c02_cdr_mismatch_rows.csv");
writetable(mismatch, mismatch_out);

rule_summary = buildRuleSummary(diagnosis);
summary_out = fullfile(results_dir, "c02_cdr_rule_error_summary.csv");
writetable(rule_summary, summary_out);

plotRuleSummary(rule_summary, fullfile(results_dir, "fig_c02_cdr_rule_error_summary.png"), ...
    fullfile(results_dir, "fig_c02_cdr_rule_error_summary.fig"));
plotBestRuleErrorHeatmap(diagnosis, scenario_order, config_order, ...
    fullfile(results_dir, "fig_c02_cdr_best_rule_error_heatmap.png"), ...
    fullfile(results_dir, "fig_c02_cdr_best_rule_error_heatmap.fig"));

writeReport(fullfile(results_dir, "c02_cdr_mismatch_diagnosis_report.md"), ...
    mismatch, rule_summary, diagnosis);

fprintf("\nC02 CDR mismatch diagnosis\n");
fprintf("Mismatch rows (abs_error > 0.01): %d\n", height(mismatch));
disp(mismatch);
disp(rule_summary);
fprintf("Saved mismatch rows: %s\n", mismatch_out);
fprintf("Saved multi-rule diagnosis: %s\n", diagnosis_out);
fprintf("Saved rule summary: %s\n\n", summary_out);

function V = normalizeValidationTable(V)
    names = string(V.Properties.VariableNames);
    if ~any(names == "cdr_abs_error") && any(names == "abs_error")
        V.cdr_abs_error = V.abs_error;
    end
    if ~any(names == "cdr_error_percent") && any(names == "relative_error")
        V.cdr_error_percent = V.relative_error;
    end
    if ~any(names == "CDR_75ms_from_raw") && any(names == "CDR_75ms_json")
        V.CDR_75ms_from_raw = V.CDR_75ms_json;
    end
    V.unified_scenario = upper(strtrim(string(V.unified_scenario)));
    V.protocol_or_config = strtrim(string(V.protocol_or_config));
end

function D = buildMultiRuleTable(V, json_data, scenario_order, loc_fields, config_order, cfg_fields)
    n = height(V);
    cdr_all_received_ms75 = NaN(n, 1);
    cdr_steady_received_ms75 = NaN(n, 1);
    cdr_all_expected_ms75 = NaN(n, 1);
    cdr_steady_expected_ms75 = NaN(n, 1);
    unit_check_seconds75 = NaN(n, 1);
    unit_check_microseconds75 = NaN(n, 1);
    best_matching_rule = strings(n, 1);
    best_matching_error = NaN(n, 1);

    for i = 1:n
        sidx = find(scenario_order == string(V.unified_scenario(i)), 1);
        cidx = find(config_order == string(V.protocol_or_config(i)), 1);
        if isempty(sidx) || isempty(cidx)
            best_matching_rule(i) = "unavailable";
            continue;
        end

        D0 = json_data.(loc_fields(sidx)).(cfg_fields(cidx));
        delay_ms = getNumericField(D0, "control_delay_ms");
        t = getNumericField(D0, "control_timestamp_s");
        if numel(t) ~= numel(delay_ms)
            t = NaN(size(delay_ms));
        end

        cdr_all_received_ms75(i) = ratioReceived(delay_ms, delay_ms <= 75);
        steady_mask = t >= 120;
        cdr_steady_received_ms75(i) = ratioReceived(delay_ms(steady_mask), delay_ms(steady_mask) <= 75);
        cdr_all_expected_ms75(i) = ratioExpected(delay_ms <= 75, 360);
        cdr_steady_expected_ms75(i) = ratioExpected(delay_ms(steady_mask) <= 75, 120);
        unit_check_seconds75(i) = ratioReceived(delay_ms, delay_ms <= 0.075);
        unit_check_microseconds75(i) = ratioReceived(delay_ms, delay_ms <= 75000);

        rule_names = ["cdr_all_received_ms75", "cdr_steady_received_ms75", ...
            "cdr_all_expected_ms75", "cdr_steady_expected_ms75", ...
            "unit_check_seconds75", "unit_check_microseconds75"];
        rule_values = [cdr_all_received_ms75(i), cdr_steady_received_ms75(i), ...
            cdr_all_expected_ms75(i), cdr_steady_expected_ms75(i), ...
            unit_check_seconds75(i), unit_check_microseconds75(i)];
        errors = abs(rule_values - V.CDR_75ms_table2(i));
        if all(isnan(errors))
            best_matching_rule(i) = "unavailable";
        else
            [best_matching_error(i), best_idx] = min(errors, [], "omitnan");
            best_matching_rule(i) = rule_names(best_idx);
        end
    end

    D = table(V.unified_scenario, V.protocol_or_config, V.CDR_75ms_table2, ...
        cdr_all_received_ms75, cdr_steady_received_ms75, cdr_all_expected_ms75, ...
        cdr_steady_expected_ms75, unit_check_seconds75, unit_check_microseconds75, ...
        best_matching_rule, best_matching_error, ...
        'VariableNames', {'unified_scenario', 'protocol_or_config', 'CDR_75ms_table2', ...
        'cdr_all_received_ms75', 'cdr_steady_received_ms75', 'cdr_all_expected_ms75', ...
        'cdr_steady_expected_ms75', 'unit_check_seconds75', 'unit_check_microseconds75', ...
        'best_matching_rule', 'best_matching_error'});
end

function values = getNumericField(S, field)
    if ~isfield(S, field)
        values = [];
        return;
    end
    raw = S.(field);
    if isnumeric(raw) || islogical(raw)
        values = double(raw(:));
    elseif iscell(raw)
        values = NaN(numel(raw), 1);
        for i = 1:numel(raw)
            v = raw{i};
            if isnumeric(v) || islogical(v)
                if ~isempty(v), values(i) = double(v(1)); end
            else
                values(i) = str2double(string(v));
            end
        end
    else
        values = str2double(string(raw(:)));
    end
    values = values(~isnan(values));
end

function r = ratioReceived(values, pass_mask)
    if isempty(values)
        r = NaN;
    else
        r = sum(pass_mask) / numel(values);
    end
end

function r = ratioExpected(pass_mask, expected_count)
    if isempty(pass_mask) || isnan(expected_count) || expected_count <= 0
        r = NaN;
    else
        r = sum(pass_mask) / expected_count;
    end
end

function S = buildRuleSummary(D)
    rule_name = [
        "cdr_all_received_ms75"
        "cdr_steady_received_ms75"
        "cdr_all_expected_ms75"
        "cdr_steady_expected_ms75"
        "unit_check_seconds75"
        "unit_check_microseconds75"
    ];
    mean_abs_error = NaN(numel(rule_name), 1);
    max_abs_error = NaN(numel(rule_name), 1);
    mismatch_count_error_gt_0_01 = zeros(numel(rule_name), 1);
    match_count_error_le_0_01 = zeros(numel(rule_name), 1);
    note = strings(numel(rule_name), 1);

    for i = 1:numel(rule_name)
        vals = D.(rule_name(i));
        err = abs(vals - D.CDR_75ms_table2);
        mean_abs_error(i) = mean(err, "omitnan");
        max_abs_error(i) = max(err, [], "omitnan");
        mismatch_count_error_gt_0_01(i) = sum(err > 0.01);
        match_count_error_le_0_01(i) = sum(err <= 0.01);
        if contains(rule_name(i), "microseconds")
            note(i) = "unit check: threshold 75000";
        elseif contains(rule_name(i), "seconds")
            note(i) = "unit check: threshold 0.075";
        elseif contains(rule_name(i), "expected")
            note(i) = "expected denominator assumes 0.5 s period; all=360, steady=120";
        elseif contains(rule_name(i), "steady")
            note(i) = "steady state uses control_timestamp_s >= 120";
        else
            note(i) = "received denominator; all control_delay_ms samples";
        end
    end
    S = table(rule_name, mean_abs_error, max_abs_error, mismatch_count_error_gt_0_01, ...
        match_count_error_le_0_01, note);
end

function plotRuleSummary(S, png_path, fig_path)
    fig = figure("Visible", "off", "Color", "w", "Position", [100 100 860 470]);
    labels = categorical(S.rule_name);
    labels = reordercats(labels, cellstr(S.rule_name));
    bar(labels, S.mean_abs_error, 0.62, "FaceColor", [0.18 0.45 0.67]);
    ylabel("mean absolute error");
    title("CDR Rule Mean Absolute Error vs Table 2");
    grid on;
    xtickangle(25);
    savefig(fig, fig_path);
    exportgraphics(fig, png_path, "Resolution", 300);
    close(fig);
end

function plotBestRuleErrorHeatmap(D, scenario_order, config_order, png_path, fig_path)
    M = NaN(numel(config_order), numel(scenario_order));
    for i = 1:height(D)
        row = find(config_order == string(D.protocol_or_config(i)), 1);
        col = find(scenario_order == string(D.unified_scenario(i)), 1);
        M(row, col) = D.best_matching_error(i);
    end
    fig = figure("Visible", "off", "Color", "w", "Position", [100 100 970 620]);
    h = heatmap(scenario_order, config_order, M);
    h.Title = "Best-Rule CDR Absolute Error vs Table 2";
    h.XLabel = "Scenario";
    h.YLabel = "Wi-Fi config";
    h.CellLabelFormat = "%.4f";
    h.Colormap = parula(256);
    savefig(fig, fig_path);
    exportgraphics(fig, png_path, "Resolution", 300);
    close(fig);
end

function writeReport(path, mismatch, summary, diagnosis)
    [~, worst_idx] = max(mismatch.abs_error);
    if isempty(worst_idx)
        worst_text = "none";
    else
        worst_text = string(mismatch.unified_scenario(worst_idx)) + " / " ...
            + string(mismatch.protocol_or_config(worst_idx)) + " / abs_error=" ...
            + sprintf("%.6f", mismatch.abs_error(worst_idx));
    end

    [~, best_rule_idx] = min(summary.mean_abs_error);
    best_rule = summary.rule_name(best_rule_idx);
    steady_improved = summary.mean_abs_error(summary.rule_name == "cdr_steady_received_ms75") ...
        < summary.mean_abs_error(summary.rule_name == "cdr_all_received_ms75");
    seconds_err = summary.mean_abs_error(summary.rule_name == "unit_check_seconds75");
    micros_err = summary.mean_abs_error(summary.rule_name == "unit_check_microseconds75");
    unit_issue = seconds_err < 0.02 || micros_err < 0.02;
    expected_issue = summary.mean_abs_error(summary.rule_name == "cdr_all_expected_ms75") ...
        < summary.mean_abs_error(summary.rule_name == "cdr_all_received_ms75");

    lines = [
        "# C02 CDR Mismatch Diagnosis"
        ""
        "## Current problem"
        "Table 2 CDR and raw JSON recomputed CDR are not fully consistent."
        ""
        "## Summary"
        "- mismatch_count (abs_error > 0.01): " + string(height(mismatch))
        "- maximum error location: " + worst_text
        "- rule closest to Table 2 overall: " + best_rule
        "- steady state rule closer than all received rule: " + string(steady_improved)
        "- delay unit issue likely from seconds/us checks: " + string(unit_issue)
        "- expected packet denominator improves all-received rule: " + string(expected_issue)
        "- best-rule unresolved rows (error > 0.01): " + string(sum(diagnosis.best_matching_error > 0.01))
        ""
        "## Interpretation"
        "The diagnosis checks all received samples, t >= 120 s steady state, expected-packet denominators, and seconds/us threshold assumptions. If none explains all differences, the Table 2 values and raw JSON CDR use different processing definitions or filtering."
        ""
        "## Should throughput/delay reproduction proceed?"
        "Do not use this CDR validation as a pass condition yet. Throughput/PTP extraction can proceed as raw-data extraction, but CDR should be reported with a definition caveat until the Table 2 processing rule is confirmed."
        ""
        "## Conclusion"
        "If the tested rules still cannot explain the differences, temporarily use Table 2 as the manuscript reproduction baseline, use raw JSON as a supplementary data source, and explicitly mark the CDR definition difference in the report."
    ];
    writelines(lines, path);
end
