%% Validate Table 2 CDR_75ms against raw-JSON CDR_75ms
% V2-2.5 only: compare CDR values, no modeling or simulation.

clear;
clc;

project_root = ".";
results_dir = fullfile(project_root, "matlab", "c02_wifi_reproduction", "results");
table2_file = fullfile(results_dir, "c02_cdr75_cleaned_36rows.csv");
json_file = fullfile(results_dir, "c02_wifi_kpi_extracted_36rows.csv");

if ~isfile(table2_file)
    error("Missing Table 2 CDR file: %s", table2_file);
end
if ~isfile(json_file)
    error("Missing JSON KPI file: %s", json_file);
end

T = readtable(table2_file, "TextType", "string", "VariableNamingRule", "preserve");
J = readtable(json_file, "TextType", "string", "VariableNamingRule", "preserve");

T = normalizeKeyColumns(T);
J = normalizeKeyColumns(J);

required_T = ["unified_scenario", "scenario_name", "protocol_or_config", "CDR_75ms"];
required_J = ["unified_scenario", "protocol_or_config", "CDR_75ms_from_raw"];
assertRequiredColumns(T, required_T, "Table 2");
assertRequiredColumns(J, required_J, "JSON KPI");

T.CDR_75ms_table2 = T.CDR_75ms;
T = T(:, ["unified_scenario", "scenario_name", "protocol_or_config", "CDR_75ms_table2"]);
J = J(:, ["unified_scenario", "protocol_or_config", "CDR_75ms_from_raw"]);

V = innerjoin(T, J, "Keys", ["unified_scenario", "protocol_or_config"]);
if height(V) ~= 36
    error("Expected 36 matched rows, found %d.", height(V));
end

V.cdr_abs_error = abs(V.CDR_75ms_table2 - V.CDR_75ms_from_raw);
V.cdr_error_percent = 100 * V.cdr_abs_error ./ max(abs(V.CDR_75ms_table2), eps);
V.match_status = strings(height(V), 1);
V.match_status(V.cdr_abs_error <= 0.005) = "exact_or_near_match";
V.match_status(V.cdr_abs_error > 0.005 & V.cdr_abs_error <= 0.02) = "small_difference";
V.match_status(V.cdr_abs_error > 0.02) = "mismatch";

V = sortValidationRows(V);
validation_out = fullfile(results_dir, "c02_cdr_table2_vs_json_validation.csv");
writetable(V, validation_out);

total_matched_rows = height(V);
max_abs_error = max(V.cdr_abs_error);
mean_abs_error = mean(V.cdr_abs_error);
near_match_count = sum(V.match_status == "exact_or_near_match");
small_difference_count = sum(V.match_status == "small_difference");
mismatch_count = sum(V.match_status == "mismatch");
if mismatch_count == 0
    validation_status = "pass";
else
    validation_status = "check_needed";
end
S = table(total_matched_rows, max_abs_error, mean_abs_error, near_match_count, ...
    small_difference_count, mismatch_count, validation_status);

summary_out = fullfile(results_dir, "c02_cdr_table2_vs_json_validation_summary.csv");
writetable(S, summary_out);

B = buildBestConfigComparison(V);
best_out = fullfile(results_dir, "c02_cdr_best_config_table2_vs_json.csv");
writetable(B, best_out);

plotScatter(V, fullfile(results_dir, "fig_c02_cdr_table2_vs_json_scatter.png"), ...
    fullfile(results_dir, "fig_c02_cdr_table2_vs_json_scatter.fig"));
plotErrorHeatmap(V, fullfile(results_dir, "fig_c02_cdr_table2_json_error_heatmap.png"), ...
    fullfile(results_dir, "fig_c02_cdr_table2_json_error_heatmap.fig"));

writeReport(fullfile(results_dir, "c02_cdr_table2_vs_json_validation_report.md"), S, B);

fprintf("\nC02 Table 2 vs JSON CDR validation\n");
disp(V);
disp(S);
disp(B);
fprintf("Saved validation: %s\n", validation_out);
fprintf("Saved summary: %s\n", summary_out);
fprintf("Saved best-config comparison: %s\n\n", best_out);

function T = normalizeKeyColumns(T)
    names = string(T.Properties.VariableNames);
    if ~any(names == "protocol_or_config") && any(names == "config")
        T.protocol_or_config = T.config;
    end
    if ~any(names == "unified_scenario") && any(names == "scenario")
        T.unified_scenario = T.scenario;
    end
    if any(string(T.Properties.VariableNames) == "unified_scenario")
        T.unified_scenario = upper(strtrim(string(T.unified_scenario)));
    end
    if any(string(T.Properties.VariableNames) == "protocol_or_config")
        T.protocol_or_config = strtrim(string(T.protocol_or_config));
    end
end

function assertRequiredColumns(T, required, label)
    missing = setdiff(required, string(T.Properties.VariableNames), "stable");
    if ~isempty(missing)
        error("%s missing required column(s): %s", label, strjoin(missing, ", "));
    end
end

function V = sortValidationRows(V)
    scenario_order = ["S1", "S2", "S3", "S4"];
    config_order = ["ax/6/160", "ax/5/80", "ac/5/80", "ax/6/80", ...
        "ax/2.4/20", "ax/5/20", "ac/5/20", "ax/6/20", "n/2.4/20"];
    [~, sidx] = ismember(string(V.unified_scenario), scenario_order);
    [~, cidx] = ismember(string(V.protocol_or_config), config_order);
    [~, idx] = sortrows([sidx, cidx]);
    V = V(idx, :);
end

function B = buildBestConfigComparison(V)
    scenario_order = ["S1"; "S2"; "S3"; "S4"];
    best_config_table2 = strings(4, 1);
    best_CDR_table2 = zeros(4, 1);
    best_config_json = strings(4, 1);
    best_CDR_json = zeros(4, 1);
    best_config_match = false(4, 1);

    for i = 1:numel(scenario_order)
        mask = string(V.unified_scenario) == scenario_order(i);
        rows = V(mask, :);
        max_table2 = max(rows.CDR_75ms_table2);
        max_json = max(rows.CDR_75ms_from_raw);
        best_config_table2(i) = strjoin(string(rows.protocol_or_config(rows.CDR_75ms_table2 == max_table2)), "; ");
        best_CDR_table2(i) = max_table2;
        best_config_json(i) = strjoin(string(rows.protocol_or_config(rows.CDR_75ms_from_raw == max_json)), "; ");
        best_CDR_json(i) = max_json;
        best_config_match(i) = best_config_table2(i) == best_config_json(i);
    end

    unified_scenario = scenario_order;
    B = table(unified_scenario, best_config_table2, best_CDR_table2, ...
        best_config_json, best_CDR_json, best_config_match);
end

function plotScatter(V, png_path, fig_path)
    fig = figure("Visible", "off", "Color", "w", "Position", [100 100 620 560]);
    scatter(V.CDR_75ms_table2, V.CDR_75ms_from_raw, 44, "filled");
    hold on;
    plot([0 1], [0 1], "k--", "LineWidth", 1.2);
    grid on;
    axis([0 1 0 1]);
    xlabel("CDR_75ms Table 2");
    ylabel("CDR_75ms from raw JSON");
    title("C02 Table 2 vs Raw JSON CDR_75ms");
    savefig(fig, fig_path);
    exportgraphics(fig, png_path, "Resolution", 300);
    close(fig);
end

function plotErrorHeatmap(V, png_path, fig_path)
    scenario_order = ["S1", "S2", "S3", "S4"];
    config_order = ["ax/6/160", "ax/5/80", "ac/5/80", "ax/6/80", ...
        "ax/2.4/20", "ax/5/20", "ac/5/20", "ax/6/20", "n/2.4/20"];
    M = NaN(numel(config_order), numel(scenario_order));
    for i = 1:height(V)
        row = find(config_order == string(V.protocol_or_config(i)), 1);
        col = find(scenario_order == string(V.unified_scenario(i)), 1);
        M(row, col) = V.cdr_abs_error(i);
    end
    fig = figure("Visible", "off", "Color", "w", "Position", [100 100 960 610]);
    h = heatmap(scenario_order, config_order, M);
    h.Title = "CDR_75ms Absolute Error: Table 2 vs Raw JSON";
    h.XLabel = "Scenario";
    h.YLabel = "Wi-Fi config";
    h.CellLabelFormat = "%.4f";
    h.Colormap = parula(256);
    savefig(fig, fig_path);
    exportgraphics(fig, png_path, "Resolution", 300);
    close(fig);
end

function writeReport(report_path, S, B)
    all_best_match = all(B.best_config_match);
    lines = [
        "# C02 CDR Table 2 vs Raw JSON Validation"
        ""
        "## Purpose"
        "Validate that the CDR_75ms recomputed from raw JSON is consistent with the previously reproduced Table 2 CDR_75ms values."
        ""
        "## Why this check matters"
        "This check confirms whether the V2-2 JSON KPI extraction is trustworthy before proceeding to throughput and PTP delay reproduction."
        ""
        "## Matched rows"
        "- Matched rows: " + string(S.total_matched_rows)
        "- Expected rows: 36"
        ""
        "## Error summary"
        "- Max absolute error: " + sprintf("%.6f", S.max_abs_error)
        "- Mean absolute error: " + sprintf("%.6f", S.mean_abs_error)
        "- Near matches: " + string(S.near_match_count)
        "- Small differences: " + string(S.small_difference_count)
        "- Mismatches: " + string(S.mismatch_count)
        "- Validation status: " + string(S.validation_status)
        ""
        "## Best configuration consistency"
        "- S1-S4 best config all match: " + string(all_best_match)
        ""
        "## Next step"
        "If validation_status is pass, proceed to V2-3 throughput reproduction."
    ];
    writelines(lines, report_path);
end
