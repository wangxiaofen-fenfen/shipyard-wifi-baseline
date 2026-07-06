%% Build C02 Wi-Fi baseline rule table
% V2-7 only: build a demand-profile rule table from reproduced C02 Wi-Fi
% KPI baselines. No MANET, no fallback data, no Wi-Fi PHY simulation,
% no formal ROS/control delay reproduction, no Excel edits, and no
% fabricated data.

clear;
clc;

project_root = ".";
results_dir = fullfile(project_root, "matlab", "c02_wifi_reproduction", "results");

integrated_file = fullfile(results_dir, "c02_integrated_kpi_baseline_v2.csv");
best_file = fullfile(results_dir, "c02_best_config_by_kpi_v2.csv");
tradeoff_file = fullfile(results_dir, "c02_kpi_tradeoff_summary_v2.csv");
score_file = fullfile(results_dir, "c02_integrated_kpi_normalized_score_v2.csv");

rule_out = fullfile(results_dir, "c02_wifi_baseline_rule_table.csv");
description_out = fullfile(results_dir, "c02_wifi_baseline_demand_profile_description.csv");
summary_out = fullfile(results_dir, "c02_wifi_baseline_rule_summary_by_scenario.csv");
role_out = fullfile(results_dir, "c02_wifi_config_role_summary.csv");
report_out = fullfile(results_dir, "c02_wifi_baseline_rule_table_report.md");

fig_rule_png = fullfile(results_dir, "fig_c02_wifi_baseline_rule_table.png");
fig_rule_fig = fullfile(results_dir, "fig_c02_wifi_baseline_rule_table.fig");
fig_count_png = fullfile(results_dir, "fig_c02_wifi_config_recommended_count.png");
fig_count_fig = fullfile(results_dir, "fig_c02_wifi_config_recommended_count.fig");

if ~isfile(integrated_file)
    error("Cannot find integrated KPI baseline v2 file: %s", integrated_file);
end
if ~isfile(best_file)
    error("Cannot find best config by KPI v2 file: %s", best_file);
end
if ~isfile(tradeoff_file)
    error("Cannot find trade-off summary v2 file: %s", tradeoff_file);
end
if ~isfile(score_file)
    error("Cannot find normalized score v2 file: %s", score_file);
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
demand_order = [
    "high_throughput_priority"
    "low_ptp_delay_priority"
    "control_reliability_priority"
    "balanced_equal_weight"
    "conservative_control_plus_delay"
];

K = readtable(integrated_file, "TextType", "string", "VariableNamingRule", "preserve");
B = readtable(best_file, "TextType", "string", "VariableNamingRule", "preserve");
TR = readtable(tradeoff_file, "TextType", "string", "VariableNamingRule", "preserve");
S = readtable(score_file, "TextType", "string", "VariableNamingRule", "preserve");

assertRequiredFields(K, ["unified_scenario", "scenario_name", "protocol_or_config", ...
    "throughput_mbps_mean", "ptp_delay_ms_steady_mean", "ptp_data_status", ...
    "cdr75_percent_table2", "cdr75_ratio_table2", "ros_control_delay_status", ...
    "data_source_note"], "integrated KPI baseline v2");
assertRequiredFields(B, ["unified_scenario", "scenario_name", "kpi_name", "best_config", ...
    "best_value"], "best config by KPI v2");
assertRequiredFields(TR, ["unified_scenario", "scenario_name", "main_tradeoff_note", ...
    "missing_ptp_config_note"], "trade-off summary v2");
assertRequiredFields(S, ["unified_scenario", "scenario_name", "protocol_or_config", ...
    "throughput_score", "ptp_score", "cdr_score", "overall_equal_weight_score", ...
    "rank_in_scenario", "score_note"], "normalized score v2");

K = normalizeIntegratedTypes(K);
B = normalizeBestTypes(B);
TR = normalizeTradeoffTypes(TR);
S = normalizeScoreTypes(S);

validateInputs(K, S, scenario_order, config_order);

R = buildRuleTable(K, S, scenario_order, config_order, demand_order);
validateRuleTable(R, scenario_order, demand_order);
writetable(R, rule_out);

D = buildDemandProfileDescription();
writetable(D, description_out);

RS = buildScenarioSummary(R, TR, K, scenario_order);
writetable(RS, summary_out);

CR = buildConfigRoleSummary(R, config_order, demand_order);
writetable(CR, role_out);

plotRuleTable(R, scenario_order, demand_order, config_order, fig_rule_png, fig_rule_fig);
plotConfigRecommendedCount(CR, config_order, fig_count_png, fig_count_fig);

writeReport(report_out, integrated_file, best_file, tradeoff_file, score_file, ...
    R, D, RS, CR, K, scenario_order);

fprintf("\nC02 Wi-Fi baseline rule table V2-7\n");
fprintf("Input integrated KPI baseline v2: %s\n", integrated_file);
fprintf("Rule table rows: %d\n", height(R));
fprintf("Scenario count: %d\n", numel(unique(R.unified_scenario)));
fprintf("Demand profiles per scenario: %s\n", strjoin(string(groupcounts(R.unified_scenario)), ", "));
fprintf("Recommended config counts:\n");
disp(CR);
fprintf("Scenario-wise recommendations:\n");
disp(RS);
fprintf("Saved rule table: %s\n", rule_out);
fprintf("Saved demand profile descriptions: %s\n", description_out);
fprintf("Saved scenario summary: %s\n", summary_out);
fprintf("Saved config role summary: %s\n", role_out);
fprintf("Saved report: %s\n", report_out);
fprintf("Saved figures:\n  %s\n  %s\n\n", fig_rule_png, fig_count_png);

try
    openfig(char(fig_rule_fig), 'new', 'visible');
    openfig(char(fig_count_fig), 'new', 'visible');
catch ME
    warning("Could not open FIG files with openfig: %s", ME.message);
end

try
    if ismac
        cmd = "open -a Preview " + string(quotePath(fig_rule_png)) + " " + string(quotePath(fig_count_png));
        [status, msg] = system(char(cmd));
        if status ~= 0
            warning("Could not open PNG files in Preview: %s", string(msg));
        end
    end
catch ME
    warning("Could not open PNG files in Preview: %s", ME.message);
end

function R = buildRuleTable(K, S, scenario_order, config_order, demand_order)
    row_count = numel(scenario_order) * numel(demand_order);
    unified_scenario = strings(row_count, 1);
    scenario_name = strings(row_count, 1);
    demand_profile = strings(row_count, 1);
    recommended_config = strings(row_count, 1);
    primary_reason = strings(row_count, 1);
    primary_kpi_name = strings(row_count, 1);
    primary_kpi_value = NaN(row_count, 1);
    secondary_kpi_name = strings(row_count, 1);
    secondary_kpi_value = NaN(row_count, 1);
    throughput_mbps_mean = NaN(row_count, 1);
    ptp_delay_ms_steady_mean = NaN(row_count, 1);
    cdr75_percent_table2 = NaN(row_count, 1);
    ptp_data_status = strings(row_count, 1);
    ros_control_delay_status = strings(row_count, 1);
    rule_note = strings(row_count, 1);
    data_source_note = strings(row_count, 1);

    r = 0;
    for s = 1:numel(scenario_order)
        scen = scenario_order(s);
        scen_rows = find(K.unified_scenario == scen);
        score_rows = find(S.unified_scenario == scen);

        for d = 1:numel(demand_order)
            r = r + 1;
            profile = demand_order(d);
            note = "";
            switch profile
                case "high_throughput_priority"
                    [~, local_idx] = max(K.throughput_mbps_mean(scen_rows), [], "omitnan");
                    idx = scen_rows(local_idx);
                    reason = "highest throughput_mbps_mean";
                    pk = "throughput_mbps_mean";
                    pv = K.throughput_mbps_mean(idx);
                    sk = "cdr75_percent_table2";
                    sv = K.cdr75_percent_table2(idx);
                    note = "throughput ranking uses all rows";

                case "low_ptp_delay_priority"
                    candidate_rows = scen_rows(K.ptp_data_status(scen_rows) == "ok" & ...
                        ~isnan(K.ptp_delay_ms_steady_mean(scen_rows)));
                    [~, local_idx] = min(K.ptp_delay_ms_steady_mean(candidate_rows), [], "omitnan");
                    idx = candidate_rows(local_idx);
                    reason = "lowest ptp_delay_ms_steady_mean among valid PTP rows";
                    pk = "ptp_delay_ms_steady_mean";
                    pv = K.ptp_delay_ms_steady_mean(idx);
                    sk = "cdr75_percent_table2";
                    sv = K.cdr75_percent_table2(idx);
                    note = missingNoteForScenario(K, scen);

                case "control_reliability_priority"
                    [~, local_idx] = max(K.cdr75_percent_table2(scen_rows), [], "omitnan");
                    idx = scen_rows(local_idx);
                    reason = "highest cdr75_percent_table2";
                    pk = "cdr75_percent_table2";
                    pv = K.cdr75_percent_table2(idx);
                    sk = "ptp_delay_ms_steady_mean";
                    sv = K.ptp_delay_ms_steady_mean(idx);
                    note = "CDR ranking uses Table 2 percent";

                case "balanced_equal_weight"
                    valid_score_rows = score_rows(~isnan(S.overall_equal_weight_score(score_rows)));
                    [~, local_idx] = min(S.rank_in_scenario(valid_score_rows), [], "omitnan");
                    score_idx = valid_score_rows(local_idx);
                    idx = find(K.unified_scenario == scen & K.protocol_or_config == S.protocol_or_config(score_idx), 1);
                    reason = "rank 1 overall_equal_weight_score among valid score rows";
                    pk = "overall_equal_weight_score";
                    pv = S.overall_equal_weight_score(score_idx);
                    sk = "rank_in_scenario";
                    sv = S.rank_in_scenario(score_idx);
                    note = missingNoteForScenario(K, scen);

                case "conservative_control_plus_delay"
                    valid_ptp_rows = scen_rows(K.ptp_data_status(scen_rows) == "ok" & ...
                        ~isnan(K.ptp_delay_ms_steady_mean(scen_rows)));
                    cdr90_rows = valid_ptp_rows(K.cdr75_percent_table2(valid_ptp_rows) >= 90);
                    if ~isempty(cdr90_rows)
                        [~, local_idx] = min(K.ptp_delay_ms_steady_mean(cdr90_rows), [], "omitnan");
                        idx = cdr90_rows(local_idx);
                        reason = "lowest PTP delay among valid rows with cdr75_percent_table2 >= 90";
                        note = "cdr90_candidate";
                    else
                        [~, local_idx] = max(K.cdr75_percent_table2(valid_ptp_rows), [], "omitnan");
                        idx = valid_ptp_rows(local_idx);
                        reason = "highest CDR among valid PTP rows because no cdr75 >= 90 candidate exists";
                        note = "no_cdr90_candidate";
                    end
                    pk = "ptp_delay_ms_steady_mean";
                    pv = K.ptp_delay_ms_steady_mean(idx);
                    sk = "cdr75_percent_table2";
                    sv = K.cdr75_percent_table2(idx);

                otherwise
                    error("Unknown demand profile: %s", profile);
            end

            unified_scenario(r) = scen;
            scenario_name(r) = K.scenario_name(idx);
            demand_profile(r) = profile;
            recommended_config(r) = K.protocol_or_config(idx);
            primary_reason(r) = reason;
            primary_kpi_name(r) = pk;
            primary_kpi_value(r) = pv;
            secondary_kpi_name(r) = sk;
            secondary_kpi_value(r) = sv;
            throughput_mbps_mean(r) = K.throughput_mbps_mean(idx);
            ptp_delay_ms_steady_mean(r) = K.ptp_delay_ms_steady_mean(idx);
            cdr75_percent_table2(r) = K.cdr75_percent_table2(idx);
            ptp_data_status(r) = K.ptp_data_status(idx);
            ros_control_delay_status(r) = K.ros_control_delay_status(idx);
            rule_note(r) = note;
            data_source_note(r) = K.data_source_note(idx);
        end
    end

    R = table(unified_scenario, scenario_name, demand_profile, recommended_config, ...
        primary_reason, primary_kpi_name, primary_kpi_value, secondary_kpi_name, ...
        secondary_kpi_value, throughput_mbps_mean, ptp_delay_ms_steady_mean, ...
        cdr75_percent_table2, ptp_data_status, ros_control_delay_status, ...
        rule_note, data_source_note);
end

function D = buildDemandProfileDescription()
    demand_profile = [
        "high_throughput_priority"
        "low_ptp_delay_priority"
        "control_reliability_priority"
        "balanced_equal_weight"
        "conservative_control_plus_delay"
    ];
    meaning = [
        "Maximize reproduced iPerf throughput."
        "Minimize reproduced steady-state PTP delay."
        "Maximize paper Table 2 CDR_75ms."
        "Use equal-weight descriptive normalized throughput, PTP, and CDR score."
        "Prioritize CDR >= 90 percent, then minimize steady-state PTP delay."
    ];
    when_to_use = [
        "Bulk data transfer or telemetry-heavy operation."
        "Time-sensitive coordination where low network delay is central."
        "Control reliability is the dominant requirement."
        "Exploratory baseline where no single KPI dominates."
        "Control-oriented use where reliability and delay both matter."
    ];
    selection_rule = [
        "Select highest throughput_mbps_mean."
        "Select lowest ptp_delay_ms_steady_mean among ptp_data_status = ok rows."
        "Select highest cdr75_percent_table2."
        "Select rank_in_scenario = 1 by overall_equal_weight_score, excluding NaN scores."
        "Filter cdr75_percent_table2 >= 90 and ptp_data_status = ok, then select lowest PTP delay; if no CDR>=90 candidate exists, select highest CDR among valid PTP rows."
    ];
    limitation = [
        "May sacrifice PTP delay or CDR reliability."
        "Excludes rows with missing PTP steady-state data such as S3/ac/5/20."
        "Uses paper Table 2 CDR rather than newly simulated control delay."
        "Descriptive only; not a final AI optimization model."
        "Still excludes missing PTP rows and does not use all_mean fallback."
    ];
    D = table(demand_profile, meaning, when_to_use, selection_rule, limitation);
end

function RS = buildScenarioSummary(R, TR, K, scenario_order)
    row_count = numel(scenario_order);
    unified_scenario = strings(row_count, 1);
    scenario_name = strings(row_count, 1);
    high_throughput_recommendation = strings(row_count, 1);
    low_ptp_delay_recommendation = strings(row_count, 1);
    control_reliability_recommendation = strings(row_count, 1);
    balanced_recommendation = strings(row_count, 1);
    conservative_control_delay_recommendation = strings(row_count, 1);
    main_tradeoff_note = strings(row_count, 1);
    missing_data_note = strings(row_count, 1);

    for i = 1:numel(scenario_order)
        scen = scenario_order(i);
        rows = R.unified_scenario == scen;
        tr_row = TR.unified_scenario == scen;
        unified_scenario(i) = scen;
        scenario_name(i) = R.scenario_name(find(rows, 1));
        high_throughput_recommendation(i) = getRecommendation(R, scen, "high_throughput_priority");
        low_ptp_delay_recommendation(i) = getRecommendation(R, scen, "low_ptp_delay_priority");
        control_reliability_recommendation(i) = getRecommendation(R, scen, "control_reliability_priority");
        balanced_recommendation(i) = getRecommendation(R, scen, "balanced_equal_weight");
        conservative_control_delay_recommendation(i) = getRecommendation(R, scen, "conservative_control_plus_delay");
        if any(tr_row)
            main_tradeoff_note(i) = TR.main_tradeoff_note(find(tr_row, 1));
        else
            main_tradeoff_note(i) = "not_available";
        end
        missing_data_note(i) = missingNoteForScenario(K, scen);
    end

    RS = table(unified_scenario, scenario_name, high_throughput_recommendation, ...
        low_ptp_delay_recommendation, control_reliability_recommendation, ...
        balanced_recommendation, conservative_control_delay_recommendation, ...
        main_tradeoff_note, missing_data_note);
end

function CR = buildConfigRoleSummary(R, config_order, demand_order)
    protocol_or_config = config_order;
    recommended_count_total = zeros(numel(config_order), 1);
    recommended_for_high_throughput_count = zeros(numel(config_order), 1);
    recommended_for_low_ptp_delay_count = zeros(numel(config_order), 1);
    recommended_for_control_reliability_count = zeros(numel(config_order), 1);
    recommended_for_balanced_count = zeros(numel(config_order), 1);
    recommended_for_conservative_count = zeros(numel(config_order), 1);
    role_summary = strings(numel(config_order), 1);

    for i = 1:numel(config_order)
        cfg = config_order(i);
        recommended_count_total(i) = sum(R.recommended_config == cfg);
        recommended_for_high_throughput_count(i) = sum(R.recommended_config == cfg & R.demand_profile == "high_throughput_priority");
        recommended_for_low_ptp_delay_count(i) = sum(R.recommended_config == cfg & R.demand_profile == "low_ptp_delay_priority");
        recommended_for_control_reliability_count(i) = sum(R.recommended_config == cfg & R.demand_profile == "control_reliability_priority");
        recommended_for_balanced_count(i) = sum(R.recommended_config == cfg & R.demand_profile == "balanced_equal_weight");
        recommended_for_conservative_count(i) = sum(R.recommended_config == cfg & R.demand_profile == "conservative_control_plus_delay");

        role_summary(i) = classifyRole( ...
            recommended_for_high_throughput_count(i), ...
            recommended_for_low_ptp_delay_count(i), ...
            recommended_for_control_reliability_count(i), ...
            recommended_for_balanced_count(i), ...
            recommended_for_conservative_count(i), ...
            recommended_count_total(i));
    end

    CR = table(protocol_or_config, recommended_count_total, ...
        recommended_for_high_throughput_count, recommended_for_low_ptp_delay_count, ...
        recommended_for_control_reliability_count, recommended_for_balanced_count, ...
        recommended_for_conservative_count, role_summary);
end

function validateRuleTable(R, scenario_order, demand_order)
    if height(R) ~= numel(scenario_order) * numel(demand_order)
        error("Rule table check failed: expected %d rows, got %d.", numel(scenario_order) * numel(demand_order), height(R));
    end
    for s = 1:numel(scenario_order)
        rows = R.unified_scenario == scenario_order(s);
        if sum(rows) ~= numel(demand_order)
            error("Rule table check failed: %s should have %d rules, got %d.", scenario_order(s), numel(demand_order), sum(rows));
        end
        if ~all(ismember(demand_order, R.demand_profile(rows)))
            error("Rule table check failed: %s does not contain all demand profiles.", scenario_order(s));
        end
    end
    bad_low_ptp = R.unified_scenario == "S3" & R.recommended_config == "ac/5/20" & ...
        R.demand_profile == "low_ptp_delay_priority";
    if any(bad_low_ptp)
        error("Rule table check failed: S3 / ac/5/20 cannot be recommended for low_ptp_delay_priority.");
    end
    bad_balanced = R.unified_scenario == "S3" & R.recommended_config == "ac/5/20" & ...
        R.demand_profile == "balanced_equal_weight";
    if any(bad_balanced)
        error("Rule table check failed: S3 / ac/5/20 cannot be recommended for balanced_equal_weight.");
    end
    target_rec = R.unified_scenario == "S3" & R.recommended_config == "ac/5/20";
    if any(target_rec & R.ptp_data_status ~= "ptp_missing_case_time_short")
        error("Rule table check failed: any S3 / ac/5/20 recommendation must retain ptp_missing flag.");
    end
end

function validateInputs(K, S, scenario_order, config_order)
    if height(K) ~= 36
        error("Input check failed: integrated KPI baseline v2 must have 36 rows, got %d.", height(K));
    end
    if numel(unique(K.unified_scenario)) ~= 4 || ~all(ismember(scenario_order, unique(K.unified_scenario)))
        error("Input check failed: integrated KPI baseline v2 must cover S1-S4.");
    end
    if numel(unique(K.protocol_or_config)) ~= 9 || ~all(ismember(config_order, unique(K.protocol_or_config)))
        error("Input check failed: integrated KPI baseline v2 must cover all 9 Wi-Fi configs.");
    end
    target = K.unified_scenario == "S3" & K.protocol_or_config == "ac/5/20";
    if sum(target) ~= 1
        error("Input check failed: S3 / ac/5/20 must be retained exactly once.");
    end
    ptp_missing = isnan(K.ptp_delay_ms_steady_mean);
    if sum(ptp_missing) ~= 1 || ~all(ptp_missing == target)
        error("Input check failed: PTP missing must be only S3 / ac/5/20.");
    end
    if K.ptp_data_status(target) ~= "ptp_missing_case_time_short"
        error("Input check failed: S3 / ac/5/20 must carry ptp_missing_case_time_short.");
    end
    score_target = S.unified_scenario == "S3" & S.protocol_or_config == "ac/5/20";
    if sum(score_target) ~= 1 || ~isnan(S.overall_equal_weight_score(score_target))
        error("Input check failed: S3 / ac/5/20 normalized score must be NaN.");
    end
end

function plotRuleTable(R, scenario_order, demand_order, config_order, png_path, fig_path)
    M = NaN(numel(demand_order), numel(scenario_order));
    labels = strings(numel(demand_order), numel(scenario_order));
    for s = 1:numel(scenario_order)
        for d = 1:numel(demand_order)
            row = R.unified_scenario == scenario_order(s) & R.demand_profile == demand_order(d);
            cfg = R.recommended_config(row);
            M(d, s) = find(config_order == cfg, 1);
            labels(d, s) = cfg;
        end
    end

    fig = figure("Visible", "off", "Color", "w", "Position", [100 100 980 620]);
    imagesc(M);
    cmap = lines(numel(config_order));
    colormap(gca, cmap);
    clim([1 numel(config_order)]);
    colorbar("Ticks", 1:numel(config_order), "TickLabels", config_order, "TickLabelInterpreter", "none");
    xticks(1:numel(scenario_order));
    xticklabels(scenario_order);
    yticks(1:numel(demand_order));
    yticklabels(demand_order);
    xlabel("Scenario", "Interpreter", "none");
    ylabel("Demand profile", "Interpreter", "none");
    title("C02 Wi-Fi Baseline Rule Table", "Interpreter", "none");
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

function plotConfigRecommendedCount(CR, config_order, png_path, fig_path)
    fig = figure("Visible", "off", "Color", "w", "Position", [100 100 980 500]);
    x = 1:numel(config_order);
    b = bar(x, CR.recommended_count_total, 0.65);
    b.FaceColor = [0.20 0.45 0.65];
    grid on;
    xticks(x);
    xticklabels(config_order);
    xtickangle(35);
    ylabel("Recommended count", "Interpreter", "none");
    xlabel("Wi-Fi config", "Interpreter", "none");
    title("C02 Wi-Fi Config Recommended Count Across Rule Table", "Interpreter", "none");
    set(gca, "TickLabelInterpreter", "none");
    text(x, CR.recommended_count_total, string(CR.recommended_count_total), ...
        "HorizontalAlignment", "center", "VerticalAlignment", "bottom");
    savefig(fig, fig_path);
    exportgraphics(fig, png_path, "Resolution", 300);
    close(fig);
end

function writeReport(report_path, integrated_file, best_file, tradeoff_file, score_file, ...
    R, D, RS, CR, K, scenario_order)
    profile_lines = strings(height(D), 1);
    for i = 1:height(D)
        profile_lines(i) = "- " + D.demand_profile(i) + ": " + D.selection_rule(i);
    end

    scenario_lines = strings(height(RS), 1);
    for i = 1:height(RS)
        scenario_lines(i) = "- " + RS.unified_scenario(i) + ": high=" + ...
            RS.high_throughput_recommendation(i) + ", low_ptp=" + ...
            RS.low_ptp_delay_recommendation(i) + ", control=" + ...
            RS.control_reliability_recommendation(i) + ", balanced=" + ...
            RS.balanced_recommendation(i) + ", conservative=" + ...
            RS.conservative_control_delay_recommendation(i) + ", note=" + ...
            RS.main_tradeoff_note(i);
    end

    role_lines = strings(height(CR), 1);
    for i = 1:height(CR)
        role_lines(i) = "- " + CR.protocol_or_config(i) + ": total=" + ...
            string(CR.recommended_count_total(i)) + ", role=" + CR.role_summary(i);
    end

    [top_count, top_idx] = max(CR.recommended_count_total);
    top_configs = CR.protocol_or_config(CR.recommended_count_total == top_count);
    no_single_best = ~any(allScenarioProfilesSame(R, scenario_order));
    can_enter_v28 = height(R) == 20 && no_single_best;

    missing_row = K.unified_scenario == "S3" & K.protocol_or_config == "ac/5/20";
    missing_status = K.ptp_data_status(missing_row);

    lines = [
        "# C02 Wi-Fi Baseline Rule Table"
        ""
        "## Purpose"
        "Build a scenario-wise Wi-Fi baseline rule table from reproduced C02 shipyard Wi-Fi KPI data."
        ""
        "This is a rule table based on real C02 shipyard Wi-Fi data reproduction, not simulation."
        ""
        "## Input Data"
        "- Integrated KPI baseline v2: `" + string(integrated_file) + "`"
        "- Best config by KPI v2: `" + string(best_file) + "`"
        "- Trade-off summary v2: `" + string(tradeoff_file) + "`"
        "- Normalized score v2: `" + string(score_file) + "`"
        ""
        "## Demand Profiles"
        profile_lines
        ""
        "## Recommendation Rule for Each Profile"
        "- high_throughput_priority: highest throughput_mbps_mean."
        "- low_ptp_delay_priority: lowest ptp_delay_ms_steady_mean among ptp_data_status = ok rows."
        "- control_reliability_priority: highest cdr75_percent_table2."
        "- balanced_equal_weight: rank 1 overall_equal_weight_score, excluding NaN score rows."
        "- conservative_control_plus_delay: cdr75_percent_table2 >= 90 first, then lowest valid PTP delay; otherwise highest CDR among valid PTP rows."
        ""
        "## Scenario-Wise Recommendations"
        scenario_lines
        ""
        "## Config Role Summary"
        "- Most frequently recommended config(s): " + strjoin(top_configs, ", ") + " (" + string(top_count) + " recommendations)"
        role_lines
        ""
        "## Main Conclusion"
        "- No single Wi-Fi configuration is best for all KPI objectives: " + string(no_single_best)
        ""
        "## Missing Data Handling"
        "- S3 / ac/5/20 PTP steady-state is missing because max time_s < 120s."
        "- Missing PTP status retained as: " + missing_status
        "- S3 / ac/5/20 is not used as a valid PTP-ranked row."
        "- No imputation, no all_mean fallback, and no deletion were applied."
        ""
        "## ROS/Control Delay Status"
        "- ROS/control delay is supplementary only due to negative delay risk."
        ""
        "## Next Step"
        "- Whether next step can enter own testbed Wi-Fi experiment design: " + string(can_enter_v28)
    ];

    writelines(lines, report_path);
end

function same_flags = allScenarioProfilesSame(R, scenario_order)
    same_flags = false(numel(scenario_order), 1);
    for s = 1:numel(scenario_order)
        rows = R.unified_scenario == scenario_order(s);
        same_flags(s) = numel(unique(R.recommended_config(rows))) == 1;
    end
end

function rec = getRecommendation(R, scen, profile)
    row = R.unified_scenario == scen & R.demand_profile == profile;
    rec = R.recommended_config(find(row, 1));
end

function note = missingNoteForScenario(K, scen)
    rows = K.unified_scenario == scen & K.ptp_data_status ~= "ok";
    if any(rows)
        note = "excluded_missing_ptp_steady_mean:" + joinScenarioConfig(K, find(rows));
    else
        note = "none";
    end
end

function role = classifyRole(high_count, low_count, control_count, balanced_count, conservative_count, total_count)
    if total_count == 0
        role = "rarely_recommended";
        return;
    end
    counts = [high_count, low_count, control_count, balanced_count, conservative_count];
    max_count = max(counts);
    if high_count == max_count && high_count >= 2
        role = "high_throughput_dominant";
    elseif low_count == max_count && low_count >= 2
        role = "low_delay_dominant";
    elseif control_count == max_count && control_count >= 2
        role = "control_reliability_dominant";
    elseif conservative_count == max_count && conservative_count >= 2
        role = "conservative_control_delay_dominant";
    elseif balanced_count == max_count && balanced_count >= 1
        role = "balanced_candidate";
    else
        role = "specialized_candidate";
    end
end

function K = normalizeIntegratedTypes(K)
    K.unified_scenario = string(K.unified_scenario);
    K.scenario_name = string(K.scenario_name);
    K.protocol_or_config = string(K.protocol_or_config);
    K.throughput_mbps_mean = asNumeric(K.throughput_mbps_mean);
    K.ptp_delay_ms_steady_mean = asNumeric(K.ptp_delay_ms_steady_mean);
    K.ptp_data_status = string(K.ptp_data_status);
    K.cdr75_percent_table2 = asNumeric(K.cdr75_percent_table2);
    K.cdr75_ratio_table2 = asNumeric(K.cdr75_ratio_table2);
    K.ros_control_delay_status = string(K.ros_control_delay_status);
    K.data_source_note = string(K.data_source_note);
end

function B = normalizeBestTypes(B)
    B.unified_scenario = string(B.unified_scenario);
    B.scenario_name = string(B.scenario_name);
    B.kpi_name = string(B.kpi_name);
    B.best_config = string(B.best_config);
    B.best_value = asNumeric(B.best_value);
end

function TR = normalizeTradeoffTypes(TR)
    TR.unified_scenario = string(TR.unified_scenario);
    TR.scenario_name = string(TR.scenario_name);
    TR.main_tradeoff_note = string(TR.main_tradeoff_note);
    TR.missing_ptp_config_note = string(TR.missing_ptp_config_note);
end

function S = normalizeScoreTypes(S)
    S.unified_scenario = string(S.unified_scenario);
    S.scenario_name = string(S.scenario_name);
    S.protocol_or_config = string(S.protocol_or_config);
    S.throughput_score = asNumeric(S.throughput_score);
    S.ptp_score = asNumeric(S.ptp_score);
    S.cdr_score = asNumeric(S.cdr_score);
    S.overall_equal_weight_score = asNumeric(S.overall_equal_weight_score);
    S.rank_in_scenario = asNumeric(S.rank_in_scenario);
    S.score_note = string(S.score_note);
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

function txt = joinScenarioConfig(T, rows)
    parts = strings(numel(rows), 1);
    for i = 1:numel(rows)
        parts(i) = T.unified_scenario(rows(i)) + "/" + T.protocol_or_config(rows(i));
    end
    txt = strjoin(parts, ";");
end

function q = quotePath(path_value)
    q = ['"', strrep(char(path_value), '"', '\"'), '"'];
end
