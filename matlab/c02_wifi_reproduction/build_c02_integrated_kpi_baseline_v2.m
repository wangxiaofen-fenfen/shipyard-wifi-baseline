%% Build C02 integrated KPI baseline with missing PTP flag
% V2-6 revised only: integrate reproduced C02 Wi-Fi throughput, PTP delay,
% PTP steady-state availability, and literature Table 2 CDR_75ms into a
% baseline KPI table.
% No MANET, no fallback, no Wi-Fi PHY simulation, no formal ROS/control
% delay reproduction, no Excel edits, no fabricated data, no all_mean
% substitution, and no deletion of S3 / ac/5/20.

clear;
clc;

project_root = ".";
results_dir = fullfile(project_root, "matlab", "c02_wifi_reproduction", "results");

throughput_file = fullfile(results_dir, "c02_iperf_throughput_summary_by_config.csv");
ptp_file = fullfile(results_dir, "c02_ptp_simple_rule_summary.csv");
availability_file = fullfile(results_dir, "c02_ptp_steady_sample_availability.csv");

integrated_out = fullfile(results_dir, "c02_integrated_kpi_baseline_v2.csv");
best_out = fullfile(results_dir, "c02_best_config_by_kpi_v2.csv");
tradeoff_out = fullfile(results_dir, "c02_kpi_tradeoff_summary_v2.csv");
score_out = fullfile(results_dir, "c02_integrated_kpi_normalized_score_v2.csv");
report_out = fullfile(results_dir, "c02_integrated_kpi_baseline_report_v2.md");

fig_heatmap_png = fullfile(results_dir, "fig_c02_integrated_kpi_heatmap_v2.png");
fig_heatmap_fig = fullfile(results_dir, "fig_c02_integrated_kpi_heatmap_v2.fig");
fig_best_png = fullfile(results_dir, "fig_c02_best_config_by_kpi_v2.png");
fig_best_fig = fullfile(results_dir, "fig_c02_best_config_by_kpi_v2.fig");
fig_score_png = fullfile(results_dir, "fig_c02_integrated_normalized_score_heatmap_v2.png");
fig_score_fig = fullfile(results_dir, "fig_c02_integrated_normalized_score_heatmap_v2.fig");

if ~isfile(throughput_file)
    error("Cannot find throughput summary file: %s", throughput_file);
end
if ~isfile(ptp_file)
    error("Cannot find PTP simple rule summary file: %s", ptp_file);
end
if ~isfile(availability_file)
    error("Cannot find PTP steady-state availability file: %s", availability_file);
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

T = readtable(throughput_file, "TextType", "string", "VariableNamingRule", "preserve");
P = readtable(ptp_file, "TextType", "string", "VariableNamingRule", "preserve");
A = readtable(availability_file, "TextType", "string", "VariableNamingRule", "preserve");

required_throughput = ["unified_scenario", "scenario_name", "protocol_or_config"];
required_ptp = ["unified_scenario", "scenario_name", "protocol_or_config", "steady_mean"];
required_availability = ["unified_scenario", "protocol_or_config", "availability_status"];
assertRequiredFields(T, required_throughput, "throughput summary");
assertRequiredFields(P, required_ptp, "PTP simple rule summary");
assertRequiredFields(A, required_availability, "PTP steady-state availability");

throughput_col = findThroughputMeanColumn(T);

T.unified_scenario = string(T.unified_scenario);
T.scenario_name = string(T.scenario_name);
T.protocol_or_config = string(T.protocol_or_config);
P.unified_scenario = string(P.unified_scenario);
P.scenario_name = string(P.scenario_name);
P.protocol_or_config = string(P.protocol_or_config);
A.unified_scenario = string(A.unified_scenario);
A.protocol_or_config = string(A.protocol_or_config);
A.availability_status = string(A.availability_status);
T.(throughput_col) = asNumeric(T.(throughput_col));
P.steady_mean = asNumeric(P.steady_mean);

cdr75_percent_table2_matrix = [
    94 89 90 91 84 91 93 87 90
    97 93 90 90 93 92 91 93 88
    93 98 90 99 87 98  0 49 83
    92 94 93 88 94 93 93 95 83
];

K = buildIntegratedTable(T, P, A, throughput_col, scenario_order, config_order, cdr75_percent_table2_matrix);
validateIntegratedTable(K, scenario_order, config_order);
writetable(K, integrated_out);

B = buildBestConfigTable(K, scenario_order);
writetable(B, best_out);

TR = buildTradeoffSummary(B, scenario_order);
writetable(TR, tradeoff_out);

S = buildNormalizedScore(K, scenario_order, config_order);
writetable(S, score_out);

plotIntegratedKpiHeatmap(K, scenario_order, config_order, fig_heatmap_png, fig_heatmap_fig);
plotBestConfigByKpi(B, scenario_order, config_order, fig_best_png, fig_best_fig);
plotNormalizedScoreHeatmap(S, scenario_order, config_order, fig_score_png, fig_score_fig);

writeReport(report_out, throughput_file, ptp_file, availability_file, K, B, TR, S, scenario_order, config_order);

fprintf("\nC02 integrated KPI baseline V2-6 revised with missing PTP flag\n");
fprintf("Throughput input: %s\n", throughput_file);
fprintf("PTP input: %s\n", ptp_file);
fprintf("PTP availability input: %s\n", availability_file);
fprintf("Throughput mean column used: %s\n", throughput_col);
fprintf("Integrated KPI rows: %d\n", height(K));
fprintf("Scenario coverage: %d\n", numel(unique(K.unified_scenario)));
fprintf("Wi-Fi config coverage: %d\n", numel(unique(K.protocol_or_config)));
fprintf("PTP missing rows: %d\n", sum(isnan(K.ptp_delay_ms_steady_mean)));
fprintf("Best config by KPI and scenario:\n");
disp(B);
fprintf("Trade-off summary:\n");
disp(TR);
fprintf("Saved integrated KPI baseline: %s\n", integrated_out);
fprintf("Saved best config by KPI: %s\n", best_out);
fprintf("Saved trade-off summary: %s\n", tradeoff_out);
fprintf("Saved normalized score: %s\n", score_out);
fprintf("Saved report: %s\n", report_out);
fprintf("Saved figures:\n  %s\n  %s\n  %s\n\n", fig_heatmap_png, fig_best_png, fig_score_png);

try
    openfig(char(fig_heatmap_fig), 'new', 'visible');
    openfig(char(fig_best_fig), 'new', 'visible');
    openfig(char(fig_score_fig), 'new', 'visible');
catch ME
    warning("Could not open FIG files with openfig: %s", ME.message);
end

try
    if ismac
        cmd = "open -a Preview " + string(quotePath(fig_heatmap_png)) + " " + ...
            string(quotePath(fig_best_png)) + " " + string(quotePath(fig_score_png));
        [status, msg] = system(char(cmd));
        if status ~= 0
            warning("Could not open PNG files in Preview: %s", string(msg));
        end
    end
catch ME
    warning("Could not open PNG files in Preview: %s", ME.message);
end

function K = buildIntegratedTable(T, P, A, throughput_col, scenario_order, config_order, cdr_matrix)
    row_count = numel(scenario_order) * numel(config_order);
    unified_scenario = strings(row_count, 1);
    scenario_name = strings(row_count, 1);
    protocol_or_config = strings(row_count, 1);
    throughput_mbps_mean = NaN(row_count, 1);
    ptp_delay_ms_steady_mean = NaN(row_count, 1);
    ptp_data_status = strings(row_count, 1);
    cdr75_percent_table2 = NaN(row_count, 1);
    cdr75_ratio_table2 = NaN(row_count, 1);
    ros_control_delay_status = repmat("supplementary_only_due_to_negative_delay_risk", row_count, 1);
    data_source_note = repmat("throughput_raw_json_ptp_raw_json_steady_mean_cdr_table2_ros_limitation", row_count, 1);

    r = 0;
    for s = 1:numel(scenario_order)
        for c = 1:numel(config_order)
            r = r + 1;
            scen = scenario_order(s);
            cfg = config_order(c);
            t_mask = T.unified_scenario == scen & T.protocol_or_config == cfg;
            p_mask = P.unified_scenario == scen & P.protocol_or_config == cfg;
            a_mask = A.unified_scenario == scen & A.protocol_or_config == cfg;

            if sum(t_mask) ~= 1
                error("Expected exactly one throughput row for %s / %s, found %d.", scen, cfg, sum(t_mask));
            end
            if sum(p_mask) ~= 1
                error("Expected exactly one PTP row for %s / %s, found %d.", scen, cfg, sum(p_mask));
            end
            if sum(a_mask) ~= 1
                error("Expected exactly one PTP availability row for %s / %s, found %d.", scen, cfg, sum(a_mask));
            end

            unified_scenario(r) = scen;
            scenario_name(r) = T.scenario_name(find(t_mask, 1));
            protocol_or_config(r) = cfg;
            throughput_mbps_mean(r) = T.(throughput_col)(t_mask);
            ptp_delay_ms_steady_mean(r) = P.steady_mean(p_mask);
            availability_status = A.availability_status(a_mask);
            if availability_status == "time_short" || availability_status == "no_steady_samples"
                ptp_data_status(r) = "ptp_missing_case_time_short";
            else
                ptp_data_status(r) = "ok";
            end
            cdr75_percent_table2(r) = cdr_matrix(s, c);
            cdr75_ratio_table2(r) = cdr75_percent_table2(r) / 100;
        end
    end

    K = table(unified_scenario, scenario_name, protocol_or_config, throughput_mbps_mean, ...
        ptp_delay_ms_steady_mean, ptp_data_status, cdr75_percent_table2, cdr75_ratio_table2, ...
        ros_control_delay_status, data_source_note);
end

function validateIntegratedTable(K, scenario_order, config_order)
    if height(K) ~= 36
        error("Integrated KPI table check failed: expected 36 rows, got %d.", height(K));
    end
    scenarios = unique(K.unified_scenario, "stable");
    configs = unique(K.protocol_or_config, "stable");
    if numel(scenarios) ~= 4 || ~all(ismember(scenario_order, scenarios))
        error("Integrated KPI table check failed: expected 4 scenarios S1-S4.");
    end
    if numel(configs) ~= 9 || ~all(ismember(config_order, configs))
        error("Integrated KPI table check failed: expected 9 Wi-Fi configs.");
    end
    if any(isnan(K.throughput_mbps_mean))
        error("Integrated KPI table check failed: throughput_mbps_mean contains missing values for: %s.", ...
            missingRowList(K, isnan(K.throughput_mbps_mean)));
    end
    if any(isnan(K.cdr75_percent_table2))
        error("Integrated KPI table check failed: cdr75_percent_table2 contains missing values for: %s.", ...
            missingRowList(K, isnan(K.cdr75_percent_table2)));
    end
    target_mask = K.unified_scenario == "S3" & K.protocol_or_config == "ac/5/20";
    if sum(target_mask) ~= 1
        error("Integrated KPI table check failed: S3 / ac/5/20 must be retained exactly once.");
    end

    ptp_missing = isnan(K.ptp_delay_ms_steady_mean);
    if sum(ptp_missing) > 1
        error("Integrated KPI table check failed: ptp_delay_ms_steady_mean has more than one missing row: %s.", ...
            missingRowList(K, ptp_missing));
    end
    if sum(ptp_missing) == 1
        if ~all(target_mask == ptp_missing)
            error("Integrated KPI table check failed: the only allowed PTP missing row is S3 / ac/5/20, got: %s.", ...
                missingRowList(K, ptp_missing));
        end
        if K.ptp_data_status(target_mask) ~= "ptp_missing_case_time_short"
            error("Integrated KPI table check failed: S3 / ac/5/20 missing PTP row must have ptp_data_status = ptp_missing_case_time_short.");
        end
    end
    nonmissing_ptp = ~ptp_missing;
    if any(K.ptp_data_status(nonmissing_ptp) ~= "ok")
        error("Integrated KPI table check failed: non-missing PTP rows must have ptp_data_status = ok.");
    end
end

function txt = missingRowList(K, mask)
    rows = find(mask);
    parts = strings(numel(rows), 1);
    for i = 1:numel(rows)
        parts(i) = K.unified_scenario(rows(i)) + " / " + K.protocol_or_config(rows(i));
    end
    txt = strjoin(parts, "; ");
end

function txt = joinScenarioConfig(T, rows)
    parts = strings(numel(rows), 1);
    for i = 1:numel(rows)
        parts(i) = T.unified_scenario(rows(i)) + "/" + T.protocol_or_config(rows(i));
    end
    txt = strjoin(parts, ";");
end

function B = buildBestConfigTable(K, scenario_order)
    kpi_names = ["throughput_mbps_mean"; "ptp_delay_ms_steady_mean"; "cdr75_percent_table2"];
    higher_flags = [true; false; true];
    data_sources = [
        "raw JSON MATLAB throughput reproduction"
        "raw JSON PTP steady_mean time_s >= 120"
        "paper Table 2"
    ];
    row_count = numel(scenario_order) * numel(kpi_names);
    unified_scenario = strings(row_count, 1);
    scenario_name = strings(row_count, 1);
    kpi_name = strings(row_count, 1);
    best_config = strings(row_count, 1);
    best_value = NaN(row_count, 1);
    higher_is_better = false(row_count, 1);
    data_source = strings(row_count, 1);
    excluded_missing_rows_note = strings(row_count, 1);

    r = 0;
    for s = 1:numel(scenario_order)
        rows = find(K.unified_scenario == scenario_order(s));
        for k = 1:numel(kpi_names)
            r = r + 1;
            candidate_rows = rows;
            excluded_rows = [];
            if kpi_names(k) == "ptp_delay_ms_steady_mean"
                missing_rows = rows(isnan(K.ptp_delay_ms_steady_mean(rows)));
                candidate_rows = rows(~isnan(K.ptp_delay_ms_steady_mean(rows)));
                excluded_rows = missing_rows;
            end
            if isempty(candidate_rows)
                error("No valid candidate rows for %s in %s.", kpi_names(k), scenario_order(s));
            end
            vals = K.(kpi_names(k))(candidate_rows);
            if higher_flags(k)
                [best_value(r), local_idx] = max(vals, [], "omitnan");
            else
                [best_value(r), local_idx] = min(vals, [], "omitnan");
            end
            idx = candidate_rows(local_idx);
            unified_scenario(r) = K.unified_scenario(idx);
            scenario_name(r) = K.scenario_name(idx);
            kpi_name(r) = kpi_names(k);
            best_config(r) = K.protocol_or_config(idx);
            higher_is_better(r) = higher_flags(k);
            data_source(r) = data_sources(k);
            if isempty(excluded_rows)
                excluded_missing_rows_note(r) = "none";
            else
                excluded_missing_rows_note(r) = "excluded_missing_ptp_steady_mean:" + joinScenarioConfig(K, excluded_rows);
            end
        end
    end

    B = table(unified_scenario, scenario_name, kpi_name, best_config, best_value, ...
        higher_is_better, data_source, excluded_missing_rows_note);
end

function TR = buildTradeoffSummary(B, scenario_order)
    row_count = numel(scenario_order);
    unified_scenario = strings(row_count, 1);
    scenario_name = strings(row_count, 1);
    best_throughput_config = strings(row_count, 1);
    best_ptp_delay_config = strings(row_count, 1);
    best_cdr75_config = strings(row_count, 1);
    all_three_same_config = false(row_count, 1);
    throughput_vs_ptp_same = false(row_count, 1);
    throughput_vs_cdr_same = false(row_count, 1);
    ptp_vs_cdr_same = false(row_count, 1);
    missing_ptp_config_note = strings(row_count, 1);
    main_tradeoff_note = strings(row_count, 1);

    for s = 1:numel(scenario_order)
        scen = scenario_order(s);
        rows = B.unified_scenario == scen;
        unified_scenario(s) = scen;
        scenario_name(s) = B.scenario_name(find(rows, 1));
        best_throughput_config(s) = B.best_config(rows & B.kpi_name == "throughput_mbps_mean");
        best_ptp_delay_config(s) = B.best_config(rows & B.kpi_name == "ptp_delay_ms_steady_mean");
        best_cdr75_config(s) = B.best_config(rows & B.kpi_name == "cdr75_percent_table2");
        missing_ptp_config_note(s) = B.excluded_missing_rows_note(rows & B.kpi_name == "ptp_delay_ms_steady_mean");

        throughput_vs_ptp_same(s) = best_throughput_config(s) == best_ptp_delay_config(s);
        throughput_vs_cdr_same(s) = best_throughput_config(s) == best_cdr75_config(s);
        ptp_vs_cdr_same(s) = best_ptp_delay_config(s) == best_cdr75_config(s);
        all_three_same_config(s) = throughput_vs_ptp_same(s) && throughput_vs_cdr_same(s);

        if all_three_same_config(s)
            main_tradeoff_note(s) = "all_three_kpis_same_best_config";
        elseif throughput_vs_ptp_same(s)
            main_tradeoff_note(s) = "throughput_and_ptp_align_cdr_differs";
        elseif throughput_vs_cdr_same(s)
            main_tradeoff_note(s) = "throughput_and_cdr_align_ptp_differs";
        elseif ptp_vs_cdr_same(s)
            main_tradeoff_note(s) = "ptp_and_cdr_align_throughput_differs";
        else
            main_tradeoff_note(s) = "three_kpis_select_different_configs";
        end
    end

    TR = table(unified_scenario, scenario_name, best_throughput_config, ...
        best_ptp_delay_config, best_cdr75_config, all_three_same_config, ...
        throughput_vs_ptp_same, throughput_vs_cdr_same, ptp_vs_cdr_same, ...
        missing_ptp_config_note, main_tradeoff_note);
end

function S = buildNormalizedScore(K, scenario_order, config_order)
    row_count = height(K);
    throughput_score = NaN(row_count, 1);
    ptp_score = NaN(row_count, 1);
    cdr_score = NaN(row_count, 1);
    overall_equal_weight_score = NaN(row_count, 1);
    rank_in_scenario = NaN(row_count, 1);
    score_note = repmat("ok", row_count, 1);

    for s = 1:numel(scenario_order)
        rows = find(K.unified_scenario == scenario_order(s));
        max_throughput = max(K.throughput_mbps_mean(rows));
        valid_ptp_rows = rows(~isnan(K.ptp_delay_ms_steady_mean(rows)));
        min_ptp = min(K.ptp_delay_ms_steady_mean(valid_ptp_rows));
        max_cdr = max(K.cdr75_percent_table2(rows));

        throughput_score(rows) = K.throughput_mbps_mean(rows) ./ max_throughput;
        ptp_score(valid_ptp_rows) = min_ptp ./ K.ptp_delay_ms_steady_mean(valid_ptp_rows);
        cdr_score(rows) = K.cdr75_percent_table2(rows) ./ max_cdr;
        overall_equal_weight_score(valid_ptp_rows) = mean([throughput_score(valid_ptp_rows), ...
            ptp_score(valid_ptp_rows), cdr_score(valid_ptp_rows)], 2);
        missing_ptp_rows = rows(isnan(K.ptp_delay_ms_steady_mean(rows)));
        score_note(missing_ptp_rows) = "excluded_due_to_missing_ptp_steady_mean";

        [~, order] = sort(overall_equal_weight_score(valid_ptp_rows), "descend");
        ranks = zeros(numel(valid_ptp_rows), 1);
        ranks(order) = (1:numel(valid_ptp_rows))';
        rank_in_scenario(valid_ptp_rows) = ranks;
    end

    S = table(K.unified_scenario, K.scenario_name, K.protocol_or_config, ...
        throughput_score, ptp_score, cdr_score, overall_equal_weight_score, rank_in_scenario, score_note, ...
        'VariableNames', {'unified_scenario', 'scenario_name', 'protocol_or_config', ...
        'throughput_score', 'ptp_score', 'cdr_score', 'overall_equal_weight_score', ...
        'rank_in_scenario', 'score_note'});

    S = sortByScenarioConfig(S, scenario_order, config_order);
end

function plotIntegratedKpiHeatmap(K, scenario_order, config_order, png_path, fig_path)
    metrics = ["throughput_mbps_mean", "ptp_delay_ms_steady_mean", "cdr75_percent_table2"];
    titles = ["Throughput mean (Mbps)", "PTP steady mean delay (ms)", "CDR_75ms Table 2 (%)"];

    fig = figure("Visible", "off", "Color", "w", "Position", [100 100 1280 760]);
    tiledlayout(1, 3, "TileSpacing", "compact", "Padding", "compact");
    for k = 1:numel(metrics)
        nexttile;
        M = metricMatrix(K, metrics(k), scenario_order, config_order);
        h = imagesc(M);
        set(h, "AlphaData", ~isnan(M));
        set(gca, "Color", [0.92 0.92 0.92]);
        colormap(gca, parula(256));
        colorbar;
        if metrics(k) == "ptp_delay_ms_steady_mean"
            title({"PTP steady mean delay (ms)", "S3/ac/5/20 PTP missing because time_s max = 105.91s < 120s"}, ...
                "Interpreter", "none");
        else
            title(titles(k), "Interpreter", "none");
        end
        xticks(1:numel(scenario_order));
        xticklabels(scenario_order);
        yticks(1:numel(config_order));
        if k == 1
            yticklabels(config_order);
        else
            yticklabels([]);
        end
        xlabel("Scenario", "Interpreter", "none");
        if k == 1
            ylabel("Wi-Fi config", "Interpreter", "none");
        end
        addCellLabels(M, k == 1);
        set(gca, "TickLabelInterpreter", "none");
    end
    sgtitle("C02 Integrated KPI Baseline Heatmaps", "Interpreter", "none");
    savefig(fig, fig_path);
    exportgraphics(fig, png_path, "Resolution", 300);
    close(fig);
end

function plotBestConfigByKpi(B, scenario_order, config_order, png_path, fig_path)
    kpi_names = ["throughput_mbps_mean"; "ptp_delay_ms_steady_mean"; "cdr75_percent_table2"];
    display_names = ["Throughput", "PTP delay", "CDR_75ms"];
    M = NaN(numel(kpi_names), numel(scenario_order));
    labels = strings(numel(kpi_names), numel(scenario_order));

    for s = 1:numel(scenario_order)
        for k = 1:numel(kpi_names)
            row = B.unified_scenario == scenario_order(s) & B.kpi_name == kpi_names(k);
            cfg = B.best_config(row);
            M(k, s) = find(config_order == cfg, 1);
            labels(k, s) = cfg;
        end
    end

    fig = figure("Visible", "off", "Color", "w", "Position", [100 100 860 460]);
    imagesc(M);
    cmap = lines(numel(config_order));
    colormap(gca, cmap);
    clim([1 numel(config_order)]);
    colorbar("Ticks", 1:numel(config_order), "TickLabels", config_order, "TickLabelInterpreter", "none");
    xticks(1:numel(scenario_order));
    xticklabels(scenario_order);
    yticks(1:numel(kpi_names));
    yticklabels(display_names);
    xlabel("Scenario", "Interpreter", "none");
    title({"C02 Best Wi-Fi Config by KPI", "PTP ranking excludes S3/ac/5/20 missing steady-state row"}, ...
        "Interpreter", "none");
    set(gca, "TickLabelInterpreter", "none");
    for r = 1:size(labels, 1)
        for c = 1:size(labels, 2)
            text(c, r, labels(r, c), "HorizontalAlignment", "center", ...
                "VerticalAlignment", "middle", "FontSize", 9, "Color", "k", ...
                "Interpreter", "none");
        end
    end
    savefig(fig, fig_path);
    exportgraphics(fig, png_path, "Resolution", 300);
    close(fig);
end

function plotNormalizedScoreHeatmap(S, scenario_order, config_order, png_path, fig_path)
    M = metricMatrix(S, "overall_equal_weight_score", scenario_order, config_order);
    fig = figure("Visible", "off", "Color", "w", "Position", [100 100 900 620]);
    h = imagesc(M);
    set(h, "AlphaData", ~isnan(M));
    set(gca, "Color", [0.92 0.92 0.92]);
    colormap(gca, parula(256));
    colorbar;
    finite_values = M(~isnan(M));
    clim([min(finite_values) 1]);
    xticks(1:numel(scenario_order));
    xticklabels(scenario_order);
    yticks(1:numel(config_order));
    yticklabels(config_order);
    xlabel("Scenario", "Interpreter", "none");
    ylabel("Wi-Fi config", "Interpreter", "none");
    title({"C02 Descriptive Equal-Weight Normalized KPI Score", "S3/ac/5/20 is NaN due to missing PTP steady_mean"}, ...
        "Interpreter", "none");
    set(gca, "TickLabelInterpreter", "none");
    addCellLabels(M, false);
    savefig(fig, fig_path);
    exportgraphics(fig, png_path, "Resolution", 300);
    close(fig);
end

function writeReport(report_path, throughput_file, ptp_file, availability_file, K, B, TR, S, scenario_order, config_order)
    best_lines = strings(height(B), 1);
    for i = 1:height(B)
        best_lines(i) = "- " + B.unified_scenario(i) + " / " + B.kpi_name(i) + ": " + ...
            B.best_config(i) + " (" + sprintf("%.6g", B.best_value(i)) + ...
            "), excluded=" + B.excluded_missing_rows_note(i);
    end

    tradeoff_lines = strings(height(TR), 1);
    for i = 1:height(TR)
        tradeoff_lines(i) = "- " + TR.unified_scenario(i) + ": throughput=" + ...
            TR.best_throughput_config(i) + ", PTP=" + TR.best_ptp_delay_config(i) + ...
            ", CDR=" + TR.best_cdr75_config(i) + ", missing_ptp=" + ...
            TR.missing_ptp_config_note(i) + ", note=" + TR.main_tradeoff_note(i);
    end

    coverage_ok = height(K) == 36 && numel(unique(K.unified_scenario)) == 4 && ...
        numel(unique(K.protocol_or_config)) == 9 && ...
        all(ismember(scenario_order, unique(K.unified_scenario))) && ...
        all(ismember(config_order, unique(K.protocol_or_config)));
    target_mask = K.unified_scenario == "S3" & K.protocol_or_config == "ac/5/20";
    ptp_missing = isnan(K.ptp_delay_ms_steady_mean);
    missing_ok = sum(ptp_missing) == 1 && all(ptp_missing == target_mask) && ...
        K.ptp_data_status(target_mask) == "ptp_missing_case_time_short";
    can_enter_v27 = coverage_ok && missing_ok;
    top_score_lines = topScoreLines(S, scenario_order);

    lines = [
        "# C02 Integrated KPI Baseline V2"
        ""
        "## Purpose"
        "Build a 36-row integrated KPI baseline for C02 Wi-Fi configurations using reproduced throughput, reproduced PTP steady-state delay where available, PTP missing flags, and paper Table 2 CDR_75ms."
        ""
        "This is literature raw-data reproduction and baseline integration, not Wi-Fi PHY simulation."
        ""
        "## Input Data"
        "- Throughput source: raw JSON MATLAB reproduction"
        "- Throughput file: `" + string(throughput_file) + "`"
        "- PTP source: raw JSON steady_mean, time_s >= 120"
        "- PTP file: `" + string(ptp_file) + "`"
        "- PTP availability file: `" + string(availability_file) + "`"
        "- PTP limitation: S3 / ac/5/20 has raw samples only from 0 to 105.91s, so no steady-state PTP sample exists"
        "- CDR source: paper Table 2"
        "- ROS/control delay status: supplementary only because negative delay risk exists"
        ""
        "## 36-Row Coverage Check"
        "- Integrated row count: " + string(height(K))
        "- Scenario coverage: " + string(numel(unique(K.unified_scenario))) + " / 4"
        "- Wi-Fi config coverage: " + string(numel(unique(K.protocol_or_config))) + " / 9"
        "- Coverage check passed: " + string(coverage_ok)
        "- PTP missing row count: " + string(sum(ptp_missing))
        "- PTP missing is only S3 / ac/5/20 with ptp_missing_case_time_short: " + string(missing_ok)
        ""
        "## Missing Data Handling Rule"
        "- No imputation."
        "- No all_mean fallback."
        "- No deletion of S3 / ac/5/20."
        "- PTP ranking and normalized score exclude rows with missing ptp_delay_ms_steady_mean."
        "- Throughput and CDR ranking still include S3 / ac/5/20."
        ""
        "## Best Config by KPI and Scenario"
        best_lines
        ""
        "## Trade-Off Observation"
        tradeoff_lines
        "- Any scenario with one config best for all three KPIs: " + string(any(TR.all_three_same_config))
        ""
        "## Descriptive Normalized Baseline"
        "The equal-weight normalized score is descriptive only. It is not a final AI model and is not used as a formal optimization conclusion."
        top_score_lines
        ""
        "## Limitation"
        "- Throughput and PTP are reproduced from raw JSON summaries."
        "- CDR_75ms is embedded from paper Table 2 in percent units."
        "- S3 / ac/5/20 keeps throughput and CDR values, but PTP steady_mean remains missing because the raw time series ends before 120 s."
        "- ROS/control delay is not included in the ranking because V2-5-2 found negative-delay risk; it remains supplementary only."
        "- This step does not perform MANET, fallback, Wi-Fi PHY simulation, Excel edits, or formal ROS/control delay reproduction."
        ""
        "## Next Step"
        "- Whether next step can enter V2-7 Wi-Fi baseline rule table: " + string(can_enter_v27)
        "- V2-7 should carry the ptp_missing flag and avoid treating S3 / ac/5/20 as a valid PTP-ranked row."
    ];

    writelines(lines, report_path);
end

function lines = topScoreLines(S, scenario_order)
    lines = strings(numel(scenario_order), 1);
    for s = 1:numel(scenario_order)
        rows = find(S.unified_scenario == scenario_order(s));
        valid_rows = rows(~isnan(S.overall_equal_weight_score(rows)));
        [best_score, k] = max(S.overall_equal_weight_score(valid_rows));
        idx = valid_rows(k);
        excluded_rows = rows(isnan(S.overall_equal_weight_score(rows)));
        if isempty(excluded_rows)
            excluded_note = "none";
        else
            excluded_note = joinScenarioConfig(S, excluded_rows);
        end
        lines(s) = "- Top descriptive score " + S.unified_scenario(idx) + ": " + ...
            S.protocol_or_config(idx) + " (" + sprintf("%.4f", best_score) + ...
            "), excluded=" + excluded_note;
    end
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

function addCellLabels(M, whole_number)
    for r = 1:size(M, 1)
        for c = 1:size(M, 2)
            if isnan(M(r, c))
                label = "NA";
            elseif whole_number
                label = string(sprintf("%.0f", M(r, c)));
            else
                label = string(sprintf("%.2f", M(r, c)));
            end
            text(c, r, label, "HorizontalAlignment", "center", ...
                "VerticalAlignment", "middle", "FontSize", 7, "Color", "k");
        end
    end
end

function sorted = sortByScenarioConfig(T, scenario_order, config_order)
    scenario_rank = NaN(height(T), 1);
    config_rank = NaN(height(T), 1);
    for i = 1:height(T)
        scenario_rank(i) = find(scenario_order == T.unified_scenario(i), 1);
        config_rank(i) = find(config_order == T.protocol_or_config(i), 1);
    end
    T.scenario_rank_tmp = scenario_rank;
    T.config_rank_tmp = config_rank;
    sorted = sortrows(T, ["scenario_rank_tmp", "config_rank_tmp"]);
    sorted.scenario_rank_tmp = [];
    sorted.config_rank_tmp = [];
end

function throughput_col = findThroughputMeanColumn(T)
    vars = string(T.Properties.VariableNames);
    preferred = "throughput_mbps_mean";
    lower_vars = lower(vars);
    hit = find(lower_vars == preferred, 1);
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

function q = quotePath(path_value)
    q = ['"', strrep(char(path_value), '"', '\"'), '"'];
end
