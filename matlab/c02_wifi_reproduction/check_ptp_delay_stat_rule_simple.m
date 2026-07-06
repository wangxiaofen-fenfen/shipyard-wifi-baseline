%% Simple PTP delay statistic rule check
% Only checks all/steady mean/median against paper expected best configs.
% No MANET, no fallback, no PHY simulation, no ROS control delay.

clear;
clc;

project_root = ".";
results_dir = fullfile(project_root, "matlab", "c02_wifi_reproduction", "results");
raw_file = fullfile(results_dir, "c02_ptp_delay_raw_cleaned.csv");

if ~isfile(raw_file)
    error("Cannot find PTP raw cleaned file: %s", raw_file);
end

R = readtable(raw_file, "TextType", "string", "VariableNamingRule", "preserve");
required_fields = ["unified_scenario", "scenario_name", "protocol_or_config", "time_s", "ptp_delay_ms"];
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
paper_expected = containers.Map( ...
    {'S1', 'S2', 'S3', 'S4'}, ...
    {'ax/6/80', 'ax/6/80', 'ax/5/20', 'ax/5/80'});

S = buildRuleSummary(R, scenario_order, config_order);
summary_out = fullfile(results_dir, "c02_ptp_simple_rule_summary.csv");
writetable(S, summary_out);

B = buildBestTable(S, scenario_order, paper_expected);
best_out = fullfile(results_dir, "c02_ptp_simple_rule_best_config.csv");
writetable(B, best_out);

M = buildMatchSummary(B);
match_out = fullfile(results_dir, "c02_ptp_simple_rule_match_summary.csv");
writetable(M, match_out);

plotMatchCount(M, fullfile(results_dir, "fig_c02_ptp_simple_rule_match.png"), ...
    fullfile(results_dir, "fig_c02_ptp_simple_rule_match.fig"));

writeReport(fullfile(results_dir, "c02_ptp_simple_rule_check_report.md"), M, B);

fprintf("\nC02 PTP delay simple statistic rule check\n");
fprintf("Input: %s\n", raw_file);
fprintf("Summary rows: %d\n", height(S));
fprintf("Best-config rows: %d\n", height(B));
disp(M);
disp(B);
fprintf("Saved summary: %s\n", summary_out);
fprintf("Saved best config: %s\n", best_out);
fprintf("Saved match summary: %s\n\n", match_out);

function S = buildRuleSummary(R, scenario_order, config_order)
    n = numel(scenario_order) * numel(config_order);
    unified_scenario = strings(n, 1);
    scenario_name = strings(n, 1);
    protocol_or_config = strings(n, 1);
    all_mean = NaN(n, 1);
    steady_mean = NaN(n, 1);
    all_median = NaN(n, 1);
    steady_median = NaN(n, 1);
    sample_count_all = zeros(n, 1);
    sample_count_steady = zeros(n, 1);

    r = 0;
    for s = 1:numel(scenario_order)
        for c = 1:numel(config_order)
            r = r + 1;
            mask = R.unified_scenario == scenario_order(s) & R.protocol_or_config == config_order(c);
            x_all = R.ptp_delay_ms(mask);
            t_all = R.time_s(mask);
            x_all = x_all(~isnan(x_all));
            x_steady = R.ptp_delay_ms(mask & R.time_s >= 120);
            x_steady = x_steady(~isnan(x_steady));

            unified_scenario(r) = scenario_order(s);
            if any(mask)
                scenario_name(r) = R.scenario_name(find(mask, 1));
            end
            protocol_or_config(r) = config_order(c);
            sample_count_all(r) = numel(x_all);
            sample_count_steady(r) = numel(x_steady);
            if ~isempty(x_all)
                all_mean(r) = mean(x_all);
                all_median(r) = median(x_all);
            end
            if ~isempty(x_steady)
                steady_mean(r) = mean(x_steady);
                steady_median(r) = median(x_steady);
            end
        end
    end

    S = table(unified_scenario, scenario_name, protocol_or_config, ...
        all_mean, steady_mean, all_median, steady_median, ...
        sample_count_all, sample_count_steady);
end

function B = buildBestTable(S, scenario_order, paper_expected)
    rule_name = ["all_mean"; "steady_mean"; "all_median"; "steady_median"];
    n = numel(rule_name) * numel(scenario_order);
    rule_col = strings(n, 1);
    unified_scenario = strings(n, 1);
    scenario_name = strings(n, 1);
    best_config = strings(n, 1);
    best_delay_ms = NaN(n, 1);
    paper_expected_best_config = strings(n, 1);
    match_paper = false(n, 1);

    r = 0;
    for k = 1:numel(rule_name)
        for s = 1:numel(scenario_order)
            r = r + 1;
            rows = find(S.unified_scenario == scenario_order(s));
            vals = S.(rule_name(k))(rows);
            [best_delay_ms(r), idx0] = min(vals, [], "omitnan");
            idx = rows(idx0);
            rule_col(r) = rule_name(k);
            unified_scenario(r) = S.unified_scenario(idx);
            scenario_name(r) = S.scenario_name(idx);
            best_config(r) = S.protocol_or_config(idx);
            paper_expected_best_config(r) = string(paper_expected(char(scenario_order(s))));
            match_paper(r) = best_config(r) == paper_expected_best_config(r);
        end
    end

    B = table(rule_col, unified_scenario, scenario_name, best_config, best_delay_ms, ...
        paper_expected_best_config, match_paper, ...
        'VariableNames', {'rule_name', 'unified_scenario', 'scenario_name', ...
        'best_config', 'best_delay_ms', 'paper_expected_best_config', 'match_paper'});
end

function M = buildMatchSummary(B)
    rules = unique(B.rule_name, "stable");
    match_count = zeros(numel(rules), 1);
    mismatch_count = zeros(numel(rules), 1);
    matched_scenarios = strings(numel(rules), 1);
    mismatched_scenarios = strings(numel(rules), 1);

    for i = 1:numel(rules)
        rows = B.rule_name == rules(i);
        matched = B.unified_scenario(rows & B.match_paper);
        mismatched = B.unified_scenario(rows & ~B.match_paper);
        match_count(i) = numel(matched);
        mismatch_count(i) = numel(mismatched);
        matched_scenarios(i) = strjoin(matched, ",");
        mismatched_scenarios(i) = strjoin(mismatched, ",");
    end

    M = table(rules, match_count, mismatch_count, matched_scenarios, mismatched_scenarios, ...
        'VariableNames', {'rule_name', 'match_count', 'mismatch_count', ...
        'matched_scenarios', 'mismatched_scenarios'});
end

function plotMatchCount(M, png_path, fig_path)
    fig = figure("Visible", "off", "Color", "w", "Position", [100 100 760 460]);
    bar(categorical(M.rule_name), M.match_count, 0.55, "FaceColor", [0.18 0.45 0.65]);
    ylim([0 4]);
    grid on;
    ylabel("match_count");
    title("PTP Delay Rule Match Count vs Paper Expected Best Config");
    savefig(fig, fig_path);
    exportgraphics(fig, png_path, "Resolution", 300);
    close(fig);
end

function writeReport(report_path, M, B)
    [best_count, best_idx] = max(M.match_count);
    best_rule = M.rule_name(best_idx);
    best_rows = B(B.rule_name == best_rule, :);
    best_lines = strings(height(best_rows), 1);
    for i = 1:height(best_rows)
        best_lines(i) = "- " + best_rows.unified_scenario(i) + ": " + best_rows.best_config(i) + ...
            " (" + sprintf("%.2f", best_rows.best_delay_ms(i)) + " ms), expected " + ...
            best_rows.paper_expected_best_config(i) + ", match=" + string(best_rows.match_paper(i));
    end

    recommend = "No";
    if any(M.rule_name == "steady_mean" & M.match_count == best_count)
        recommend = "Yes, steady_mean is tied for the closest rule and matches the paper's steady-state mean wording.";
    end

    lines = [
        "# C02 PTP Delay Simple Rule Check"
        ""
        "## Purpose"
        "Check whether all/steady mean/median PTP delay rules reproduce the paper-expected best Wi-Fi configurations."
        ""
        "## Directly visible from paper"
        "- Fig.9 uses steady state after 120 s."
        "- Table 4 uses steady-state mean."
        ""
        "## Not directly visible from paper"
        "- The precise 36 PTP mean values are not directly visible."
        "- Whether Fig.9 is closer to median or CDF-based judgment is not directly visible."
        ""
        "## Closest rule"
        "- Closest rule: " + best_rule + " (" + string(best_count) + "/4 matches)"
        best_lines
        ""
        "## Recommendation"
        "- Use steady_mean for Table 4 comparison: " + recommend
        "- If rules still do not fully match, treat raw JSON PTP results as supplementary data and use the paper wording as qualitative reference."
    ];
    writelines(lines, report_path);
end
