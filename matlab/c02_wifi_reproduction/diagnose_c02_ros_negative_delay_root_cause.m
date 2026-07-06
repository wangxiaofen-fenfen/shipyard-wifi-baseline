%% Diagnose C02 ROS/control negative delay root cause
% V2-5-2 only: diagnose negative ROS/control delay cause and distribution.
% No MANET, no fallback, no Wi-Fi PHY simulation, no Excel edits,
% no comprehensive KPI, no direct deletion/absolute-value conversion, and
% no formal ROS/control delay conclusion.

clear;
clc;

project_root = ".";
results_dir = fullfile(project_root, "matlab", "c02_wifi_reproduction", "results");
raw_file = fullfile(results_dir, "c02_ros_control_delay_raw_cleaned.csv");

by_config_out = fullfile(results_dir, "c02_ros_negative_rootcause_by_config.csv");
before_after_out = fullfile(results_dir, "c02_ros_negative_before_vs_after120_summary.csv");
magnitude_out = fullfile(results_dir, "c02_ros_negative_magnitude_bins.csv");
bursts_out = fullfile(results_dir, "c02_ros_negative_bursts.csv");
label_out = fullfile(results_dir, "c02_ros_negative_rootcause_label.csv");
report_out = fullfile(results_dir, "c02_ros_negative_delay_rootcause_report.md");

fig_time_png = fullfile(results_dir, "fig_c02_ros_negative_delay_over_time.png");
fig_time_fig = fullfile(results_dir, "fig_c02_ros_negative_delay_over_time.fig");
fig_before_after_png = fullfile(results_dir, "fig_c02_ros_negative_before_after120_bar.png");
fig_before_after_fig = fullfile(results_dir, "fig_c02_ros_negative_before_after120_bar.fig");
fig_bins_png = fullfile(results_dir, "fig_c02_ros_negative_magnitude_bins.png");
fig_bins_fig = fullfile(results_dir, "fig_c02_ros_negative_magnitude_bins.fig");

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

R.unified_scenario = string(R.unified_scenario);
R.scenario_name = string(R.scenario_name);
R.los_condition = string(R.los_condition);
R.protocol_or_config = string(R.protocol_or_config);
R.time_s = asNumeric(R.time_s);
R.control_delay_ms = asNumeric(R.control_delay_ms);

valid_delay = ~isnan(R.time_s) & ~isnan(R.control_delay_ms);
if ~all(valid_delay)
    warning("Dropping %d rows with NaN time_s or control_delay_ms for diagnosis tables.", sum(~valid_delay));
    R = R(valid_delay, :);
end

scenario_order = unique(R.unified_scenario, "stable");
config_order = unique(R.protocol_or_config, "stable");

overview = buildOverview(R);
N = buildByConfig(R, scenario_order, config_order);
writetable(N, by_config_out);

BA = buildBeforeAfterSummary(R);
writetable(BA, before_after_out);

M = buildMagnitudeBins(R, scenario_order, config_order);
writetable(M, magnitude_out);

B = buildNegativeBursts(R, scenario_order, config_order);
writetable(B, bursts_out);

L = buildRootcauseLabels(N, M, B);
writetable(L, label_out);

plotNegativeOverTime(R, scenario_order, fig_time_png, fig_time_fig);
plotBeforeAfterBar(BA, fig_before_after_png, fig_before_after_fig);
plotMagnitudeBinsBar(M, fig_bins_png, fig_bins_fig);

writeReport(report_out, overview, BA, N, M, B, L);

fprintf("\nC02 ROS/control negative delay root-cause check V2-5-2\n");
fprintf("Input: %s\n", raw_file);
fprintf("Total samples: %d\n", overview.total_samples);
fprintf("Total negative samples: %d (%.6f)\n", overview.total_negative_count, overview.total_negative_ratio);
fprintf("Steady-state samples (time_s >= 120): %d\n", overview.steady_sample_count);
fprintf("Steady-state negative samples: %d (%.6f)\n", overview.steady_negative_count, overview.steady_negative_ratio);
fprintf("Minimum negative delay: %.6f ms\n", overview.min_negative_all);
fprintf("Steady-state minimum negative delay: %.6f ms\n", overview.min_negative_steady);
fprintf("Negative before 120s: %d\n", BA.negative_count(BA.region == "before_120s"));
fprintf("Negative after 120s: %d\n", BA.negative_count(BA.region == "after_120s"));

target_mask = N.unified_scenario == "S3" & N.protocol_or_config == "ax/6/80";
if any(target_mask)
    target_negative_share = N.negative_count_all(target_mask) / max(overview.total_negative_count, 1);
    fprintf("S3 ax/6/80 negative samples: %d (share %.6f)\n", ...
        N.negative_count_all(target_mask), target_negative_share);
end

if height(B) > 0
    max_burst = max(B.duration_s);
else
    max_burst = 0;
end
fprintf("Negative burst count: %d, largest burst duration: %.6f s\n", height(B), max_burst);
fprintf("Saved by-config root-cause stats: %s\n", by_config_out);
fprintf("Saved before/after summary: %s\n", before_after_out);
fprintf("Saved magnitude bins: %s\n", magnitude_out);
fprintf("Saved negative bursts: %s\n", bursts_out);
fprintf("Saved root-cause labels: %s\n", label_out);
fprintf("Saved report: %s\n", report_out);
fprintf("Saved figures:\n  %s\n  %s\n  %s\n\n", fig_time_png, fig_before_after_png, fig_bins_png);

try
    openfig(char(fig_time_fig), 'new', 'visible');
    openfig(char(fig_before_after_fig), 'new', 'visible');
    openfig(char(fig_bins_fig), 'new', 'visible');
catch ME
    warning("Could not open FIG files with openfig: %s", ME.message);
end

try
    if ismac
        cmd = "open -a Preview " + string(quotePath(fig_time_png)) + " " + ...
            string(quotePath(fig_before_after_png)) + " " + string(quotePath(fig_bins_png));
        [status, msg] = system(char(cmd));
        if status ~= 0
            warning("Could not open PNG files in Preview: %s", string(msg));
        end
    end
catch ME
    warning("Could not open PNG files in Preview: %s", ME.message);
end

function overview = buildOverview(R)
    total_samples = height(R);
    total_negative_count = sum(R.control_delay_ms < 0);
    total_negative_ratio = safeRatio(total_negative_count, total_samples);
    steady = R.time_s >= 120;
    steady_sample_count = sum(steady);
    steady_negative_count = sum(steady & R.control_delay_ms < 0);
    steady_negative_ratio = safeRatio(steady_negative_count, steady_sample_count);
    min_negative_all = minOrNaN(R.control_delay_ms(R.control_delay_ms < 0));
    min_negative_steady = minOrNaN(R.control_delay_ms(steady & R.control_delay_ms < 0));

    overview = struct();
    overview.total_samples = total_samples;
    overview.total_negative_count = total_negative_count;
    overview.total_negative_ratio = total_negative_ratio;
    overview.steady_sample_count = steady_sample_count;
    overview.steady_negative_count = steady_negative_count;
    overview.steady_negative_ratio = steady_negative_ratio;
    overview.min_negative_all = min_negative_all;
    overview.min_negative_steady = min_negative_steady;
end

function N = buildByConfig(R, scenario_order, config_order)
    rows = numel(scenario_order) * numel(config_order);
    unified_scenario = strings(rows, 1);
    scenario_name = strings(rows, 1);
    protocol_or_config = strings(rows, 1);
    sample_count_all = zeros(rows, 1);
    negative_count_all = zeros(rows, 1);
    negative_ratio_all = NaN(rows, 1);
    sample_count_before120 = zeros(rows, 1);
    negative_count_before120 = zeros(rows, 1);
    negative_ratio_before120 = NaN(rows, 1);
    sample_count_steady = zeros(rows, 1);
    negative_count_steady = zeros(rows, 1);
    negative_ratio_steady = NaN(rows, 1);
    min_negative_all = NaN(rows, 1);
    min_negative_steady = NaN(rows, 1);
    median_negative_all = NaN(rows, 1);
    median_negative_steady = NaN(rows, 1);
    p05_negative_steady = NaN(rows, 1);
    p95_negative_steady = NaN(rows, 1);
    note = strings(rows, 1);

    r = 0;
    for s = 1:numel(scenario_order)
        for c = 1:numel(config_order)
            r = r + 1;
            mask = R.unified_scenario == scenario_order(s) & R.protocol_or_config == config_order(c);
            before = mask & R.time_s < 120;
            steady = mask & R.time_s >= 120;
            x_neg_all = R.control_delay_ms(mask & R.control_delay_ms < 0);
            x_neg_steady = R.control_delay_ms(steady & R.control_delay_ms < 0);

            unified_scenario(r) = scenario_order(s);
            protocol_or_config(r) = config_order(c);
            if any(mask)
                scenario_name(r) = R.scenario_name(find(mask, 1));
            end

            sample_count_all(r) = sum(mask);
            negative_count_all(r) = numel(x_neg_all);
            negative_ratio_all(r) = safeRatio(negative_count_all(r), sample_count_all(r));

            sample_count_before120(r) = sum(before);
            negative_count_before120(r) = sum(before & R.control_delay_ms < 0);
            negative_ratio_before120(r) = safeRatio(negative_count_before120(r), sample_count_before120(r));

            sample_count_steady(r) = sum(steady);
            negative_count_steady(r) = numel(x_neg_steady);
            negative_ratio_steady(r) = safeRatio(negative_count_steady(r), sample_count_steady(r));

            min_negative_all(r) = minOrNaN(x_neg_all);
            min_negative_steady(r) = minOrNaN(x_neg_steady);
            median_negative_all(r) = medianOrNaN(x_neg_all);
            median_negative_steady(r) = medianOrNaN(x_neg_steady);
            p05_negative_steady(r) = percentileOrNaN(x_neg_steady, 5);
            p95_negative_steady(r) = percentileOrNaN(x_neg_steady, 95);

            before_share = safeRatio(negative_count_before120(r), negative_count_all(r));
            small_share = safeRatio(sum(x_neg_steady >= -5 & x_neg_steady < 0), numel(x_neg_steady));
            has_large_or_extreme = any(x_neg_steady < -50);
            if negative_count_all(r) == 0
                note(r) = "no_negative_delay";
            elseif before_share >= 0.80 && negative_ratio_steady(r) < 0.02
                note(r) = "mostly_before_120s";
            elseif has_large_or_extreme
                note(r) = "steady_large_or_extreme_present";
            elseif negative_count_steady(r) > 0 && small_share >= 0.80
                note(r) = "steady_small_negative_dominant";
            elseif negative_count_steady(r) > 0
                note(r) = "steady_negative_present";
            else
                note(r) = "negative_only_before_120s";
            end
        end
    end

    N = table(unified_scenario, scenario_name, protocol_or_config, sample_count_all, ...
        negative_count_all, negative_ratio_all, sample_count_before120, ...
        negative_count_before120, negative_ratio_before120, sample_count_steady, ...
        negative_count_steady, negative_ratio_steady, min_negative_all, ...
        min_negative_steady, median_negative_all, median_negative_steady, ...
        p05_negative_steady, p95_negative_steady, note);
end

function BA = buildBeforeAfterSummary(R)
    region = ["before_120s"; "after_120s"];
    before = R.time_s < 120;
    after = R.time_s >= 120;
    sample_count = [sum(before); sum(after)];
    negative_count = [sum(before & R.control_delay_ms < 0); sum(after & R.control_delay_ms < 0)];
    negative_ratio = [safeRatio(negative_count(1), sample_count(1)); ...
        safeRatio(negative_count(2), sample_count(2))];
    total_neg = sum(negative_count);
    negative_share_of_all_negative = [safeRatio(negative_count(1), total_neg); ...
        safeRatio(negative_count(2), total_neg)];
    BA = table(region, sample_count, negative_count, negative_ratio, negative_share_of_all_negative);
end

function M = buildMagnitudeBins(R, scenario_order, config_order)
    bin_names = ["small_negative"; "medium_negative"; "large_negative"; "extreme_negative"];
    rows = numel(scenario_order) * numel(config_order) * numel(bin_names);
    unified_scenario = strings(rows, 1);
    scenario_name = strings(rows, 1);
    protocol_or_config = strings(rows, 1);
    bin_name = strings(rows, 1);
    count = zeros(rows, 1);
    ratio_in_steady_negative = NaN(rows, 1);

    r = 0;
    for s = 1:numel(scenario_order)
        for c = 1:numel(config_order)
            mask = R.unified_scenario == scenario_order(s) & R.protocol_or_config == config_order(c);
            steady_neg = R.control_delay_ms(mask & R.time_s >= 120 & R.control_delay_ms < 0);
            total_steady_neg = numel(steady_neg);
            scenario_name_value = "";
            if any(mask)
                scenario_name_value = R.scenario_name(find(mask, 1));
            end
            bin_counts = [
                sum(steady_neg >= -5 & steady_neg < 0)
                sum(steady_neg >= -50 & steady_neg < -5)
                sum(steady_neg >= -500 & steady_neg < -50)
                sum(steady_neg < -500)
            ];
            for b = 1:numel(bin_names)
                r = r + 1;
                unified_scenario(r) = scenario_order(s);
                scenario_name(r) = scenario_name_value;
                protocol_or_config(r) = config_order(c);
                bin_name(r) = bin_names(b);
                count(r) = bin_counts(b);
                ratio_in_steady_negative(r) = safeRatio(bin_counts(b), total_steady_neg);
            end
        end
    end

    M = table(unified_scenario, scenario_name, protocol_or_config, bin_name, ...
        count, ratio_in_steady_negative);
end

function B = buildNegativeBursts(R, scenario_order, config_order)
    unified_scenario = strings(0, 1);
    scenario_name = strings(0, 1);
    protocol_or_config = strings(0, 1);
    burst_id = zeros(0, 1);
    start_time_s = zeros(0, 1);
    end_time_s = zeros(0, 1);
    duration_s = zeros(0, 1);
    negative_count = zeros(0, 1);
    min_delay_ms = zeros(0, 1);
    median_delay_ms = zeros(0, 1);

    for s = 1:numel(scenario_order)
        for c = 1:numel(config_order)
            mask = R.unified_scenario == scenario_order(s) & ...
                R.protocol_or_config == config_order(c) & R.control_delay_ms < 0;
            if ~any(mask)
                continue;
            end
            T = R(mask, :);
            T = sortrows(T, "time_s");
            starts = [1; find(diff(T.time_s) > 2) + 1];
            ends = [starts(2:end) - 1; height(T)];
            scenario_name_value = T.scenario_name(1);
            for k = 1:numel(starts)
                idx = starts(k):ends(k);
                unified_scenario(end + 1, 1) = scenario_order(s); %#ok<AGROW>
                scenario_name(end + 1, 1) = scenario_name_value; %#ok<AGROW>
                protocol_or_config(end + 1, 1) = config_order(c); %#ok<AGROW>
                burst_id(end + 1, 1) = k; %#ok<AGROW>
                start_time_s(end + 1, 1) = T.time_s(idx(1)); %#ok<AGROW>
                end_time_s(end + 1, 1) = T.time_s(idx(end)); %#ok<AGROW>
                duration_s(end + 1, 1) = T.time_s(idx(end)) - T.time_s(idx(1)); %#ok<AGROW>
                negative_count(end + 1, 1) = numel(idx); %#ok<AGROW>
                min_delay_ms(end + 1, 1) = min(T.control_delay_ms(idx)); %#ok<AGROW>
                median_delay_ms(end + 1, 1) = median(T.control_delay_ms(idx)); %#ok<AGROW>
            end
        end
    end

    B = table(unified_scenario, scenario_name, protocol_or_config, burst_id, ...
        start_time_s, end_time_s, duration_s, negative_count, min_delay_ms, median_delay_ms);
end

function L = buildRootcauseLabels(N, M, B)
    rows = height(N);
    unified_scenario = N.unified_scenario;
    scenario_name = N.scenario_name;
    protocol_or_config = N.protocol_or_config;
    negative_ratio_all = N.negative_ratio_all;
    negative_ratio_steady = N.negative_ratio_steady;
    largest_negative_burst_duration_s = zeros(rows, 1);
    has_large_or_extreme_negative_steady = false(rows, 1);
    rootcause_label = strings(rows, 1);
    recommendation = strings(rows, 1);

    total_negative_all = sum(N.negative_count_all);
    total_negative_steady = sum(N.negative_count_steady);
    negative_share_all = N.negative_count_all ./ max(total_negative_all, 1);
    negative_share_steady = N.negative_count_steady ./ max(total_negative_steady, 1);
    localized_share_threshold = 0.20;
    global_localized = any(negative_share_all >= localized_share_threshold) || ...
        any(negative_share_steady >= localized_share_threshold);

    for i = 1:rows
        burst_mask = B.unified_scenario == N.unified_scenario(i) & ...
            B.protocol_or_config == N.protocol_or_config(i);
        if any(burst_mask)
            largest_negative_burst_duration_s(i) = max(B.duration_s(burst_mask));
        end

        mag_mask = M.unified_scenario == N.unified_scenario(i) & ...
            M.protocol_or_config == N.protocol_or_config(i);
        large_count = sum(M.count(mag_mask & (M.bin_name == "large_negative" | M.bin_name == "extreme_negative")));
        small_count = sum(M.count(mag_mask & M.bin_name == "small_negative"));
        steady_negative_count = N.negative_count_steady(i);
        has_large_or_extreme_negative_steady(i) = large_count > 0;

        before_share = safeRatio(N.negative_count_before120(i), N.negative_count_all(i));
        small_share = safeRatio(small_count, steady_negative_count);
        localized_row = global_localized && ...
            (negative_share_all(i) >= localized_share_threshold || ...
            negative_share_steady(i) >= localized_share_threshold);

        if N.negative_count_all(i) > 0 && before_share >= 0.80 && N.negative_ratio_steady(i) < 0.02
            rootcause_label(i) = "mostly_startup";
            recommendation(i) = "steady-state filtering likely sufficient";
        elseif steady_negative_count > 0 && small_share >= 0.80 && ...
                N.negative_ratio_steady(i) < 0.05 && ~has_large_or_extreme_negative_steady(i)
            rootcause_label(i) = "steady_minor";
            recommendation(i) = "use steady-state with caution";
        elseif N.negative_ratio_steady(i) >= 0.05 || has_large_or_extreme_negative_steady(i)
            rootcause_label(i) = "steady_problematic";
            recommendation(i) = "do not use raw ROS delay as main result for this config";
        elseif localized_row
            rootcause_label(i) = "localized_issue";
            recommendation(i) = "inspect this scenario/config separately";
        else
            rootcause_label(i) = "unknown";
            recommendation(i) = "check raw logs manually";
        end
    end

    L = table(unified_scenario, scenario_name, protocol_or_config, negative_ratio_all, ...
        negative_ratio_steady, largest_negative_burst_duration_s, ...
        has_large_or_extreme_negative_steady, rootcause_label, recommendation);
end

function plotNegativeOverTime(R, scenario_order, png_path, fig_path)
    neg = R(R.control_delay_ms < 0, :);
    fig = figure("Visible", "off", "Color", "w", "Position", [100 100 980 560]);
    hold on;
    colors = lines(max(numel(scenario_order), 1));
    for s = 1:numel(scenario_order)
        mask = neg.unified_scenario == scenario_order(s);
        if any(mask)
            scatter(neg.time_s(mask), neg.control_delay_ms(mask), 18, ...
                "MarkerFaceColor", colors(s, :), "MarkerEdgeColor", "none", ...
                "MarkerFaceAlpha", 0.65, "DisplayName", char(scenario_order(s)));
        end
    end
    startup_line = xline(120, "k--", "120 s", "LabelVerticalAlignment", "bottom");
    zero_line = yline(0, "k-");
    startup_line.HandleVisibility = "off";
    zero_line.HandleVisibility = "off";
    grid on;
    xlabel("time_s");
    ylabel("control_delay_ms (negative samples only)");
    title("C02 ROS/Control Negative Delay over Time");
    if height(neg) > 0
        legend("Location", "best");
    end
    savefig(fig, fig_path);
    exportgraphics(fig, png_path, "Resolution", 300);
    close(fig);
end

function plotBeforeAfterBar(BA, png_path, fig_path)
    fig = figure("Visible", "off", "Color", "w", "Position", [100 100 720 480]);
    x = 1:height(BA);
    b = bar(x, BA.negative_count, 0.6);
    b.FaceColor = [0.20 0.45 0.65];
    grid on;
    xticks(x);
    xticklabels(["before 120s", "after 120s"]);
    ylabel("Negative sample count");
    title("C02 ROS/Control Negative Delay: Before vs After 120 s");
    text(1:height(BA), BA.negative_count, string(BA.negative_count), ...
        "HorizontalAlignment", "center", "VerticalAlignment", "bottom");
    savefig(fig, fig_path);
    exportgraphics(fig, png_path, "Resolution", 300);
    close(fig);
end

function plotMagnitudeBinsBar(M, png_path, fig_path)
    bin_order = ["small_negative"; "medium_negative"; "large_negative"; "extreme_negative"];
    bin_labels = ["small negative"; "medium negative"; "large negative"; "extreme negative"];
    bin_counts = zeros(numel(bin_order), 1);
    for i = 1:numel(bin_order)
        bin_counts(i) = sum(M.count(M.bin_name == bin_order(i)));
    end

    fig = figure("Visible", "off", "Color", "w", "Position", [100 100 820 500]);
    x = 1:numel(bin_order);
    b = bar(x, bin_counts, 0.6);
    b.FaceColor = [0.32 0.55 0.38];
    grid on;
    xticks(x);
    xticklabels(bin_labels);
    ylabel("Steady-state negative sample count");
    title("C02 ROS/Control Steady-State Negative Delay Magnitude Bins");
    text(1:numel(bin_order), bin_counts, string(bin_counts), ...
        "HorizontalAlignment", "center", "VerticalAlignment", "bottom");
    savefig(fig, fig_path);
    exportgraphics(fig, png_path, "Resolution", 300);
    close(fig);
end

function writeReport(report_path, overview, BA, N, M, B, L)
    before_neg = BA.negative_count(BA.region == "before_120s");
    after_neg = BA.negative_count(BA.region == "after_120s");
    before_share = BA.negative_share_of_all_negative(BA.region == "before_120s");
    after_share = BA.negative_share_of_all_negative(BA.region == "after_120s");

    steady_small_total = sum(M.count(M.bin_name == "small_negative"));
    steady_medium_total = sum(M.count(M.bin_name == "medium_negative"));
    steady_large_total = sum(M.count(M.bin_name == "large_negative"));
    steady_extreme_total = sum(M.count(M.bin_name == "extreme_negative"));
    steady_negative_total = steady_small_total + steady_medium_total + steady_large_total + steady_extreme_total;
    steady_small_share = safeRatio(steady_small_total, steady_negative_total);
    has_large_or_extreme = steady_large_total + steady_extreme_total > 0;
    any_config_problematic = any(L.rootcause_label == "steady_problematic");

    if height(N) > 0 && any(N.negative_count_steady > 0)
        candidate = find(N.negative_count_steady > 0);
        score = N.negative_ratio_steady(candidate) + 10 * double(L.has_large_or_extreme_negative_steady(candidate));
        [~, k] = max(score);
        most_idx = candidate(k);
    elseif height(N) > 0
        [~, most_idx] = max(N.negative_count_all);
    else
        most_idx = 1;
    end

    total_negative = max(overview.total_negative_count, 1);
    top_share = N.negative_count_all(most_idx) / total_negative;
    top_steady_share = N.negative_count_steady(most_idx) / max(overview.steady_negative_count, 1);
    s3_mask = N.unified_scenario == "S3" & N.protocol_or_config == "ax/6/80";
    if any(s3_mask)
        s3_share = N.negative_count_all(s3_mask) / total_negative;
        s3_steady_share = N.negative_count_steady(s3_mask) / max(overview.steady_negative_count, 1);
        s3_line = sprintf("- S3 / ax/6/80 negative count: %d (share of all negatives: %.2f%%); steady negative count: %d (share of steady negatives: %.2f%%).\n", ...
            N.negative_count_all(s3_mask), 100 * s3_share, N.negative_count_steady(s3_mask), 100 * s3_steady_share);
    else
        s3_line = "- S3 / ax/6/80 was not present in the input table.\n";
    end

    if before_share >= 0.80
        startup_text = "Yes, the negative delay is mainly before 120 s under the 80% startup-dominance threshold.";
    elseif before_share > after_share
        startup_text = "Partly, more negatives are before 120 s, but the 80% startup-dominance threshold is not met.";
    else
        startup_text = "No, negative delay is not mainly a startup synchronization issue because after-120 s negatives are comparable or larger.";
    end

    if any_config_problematic
        steady_text = "Yes for specific scenario/config rows: at least one config is steady_problematic even though the global steady negative ratio is lower.";
    elseif overview.steady_negative_ratio >= 0.05 || has_large_or_extreme
        steady_text = "Yes, steady-state negative delay remains serious by the global diagnostic rule because the steady negative ratio is high and/or large/extreme negatives appear.";
    elseif overview.steady_negative_count > 0 && steady_small_share >= 0.80
        steady_text = "Steady-state negatives remain, but they are mainly small_negative samples.";
    elseif overview.steady_negative_count > 0 && steady_small_share >= 0.50
        steady_text = "Steady-state negatives remain and are mostly small_negative by simple majority, but below the 80% dominant threshold.";
    elseif overview.steady_negative_count > 0
        steady_text = "Steady-state negatives remain and are not dominated by small_negative samples.";
    else
        steady_text = "No steady-state negative samples remain after 120 s.";
    end

    if height(B) > 0
        [largest_burst, burst_idx] = max(B.duration_s);
        burst_text = sprintf("Negative values are burst-like when adjacent negative samples are within 2 s. The largest burst is %.3f s in %s / %s with %d negative samples.", ...
            largest_burst, B.unified_scenario(burst_idx), B.protocol_or_config(burst_idx), B.negative_count(burst_idx));
    else
        largest_burst = 0;
        burst_text = "No negative bursts were found.";
    end

    if any_config_problematic || overview.steady_negative_ratio >= 0.05 || has_large_or_extreme
        next_step = "Use this as supplementary diagnostic evidence and inspect timestamp/log synchronization before any formal ROS/control delay reproduction.";
    else
        next_step = "Proceed to a formal ROS/control delay re-check only after keeping the steady-state filter explicit and documenting the negative-delay diagnostic.";
    end

    fid = fopen(report_path, "w");
    if fid < 0
        error("Cannot write report: %s", report_path);
    end
    cleaner = onCleanup(@() fclose(fid));

    fprintf(fid, "# C02 ROS/Control Negative Delay Root-Cause Check\n\n");
    fprintf(fid, "## Purpose\n");
    fprintf(fid, "This step diagnoses negative ROS/control delay only. It checks when negative `control_delay_ms` appears, how large it is, whether it is concentrated by scenario/config, and whether it appears in isolated samples or bursts.\n\n");
    fprintf(fid, "Do not make final ROS/control delay conclusion in this step.\n\n");

    fprintf(fid, "## Summary\n");
    fprintf(fid, "- Total samples: %d\n", overview.total_samples);
    fprintf(fid, "- Total negative samples: %d (%.4f%%)\n", overview.total_negative_count, 100 * overview.total_negative_ratio);
    fprintf(fid, "- Negative samples before 120s: %d (%.2f%% of all negatives)\n", before_neg, 100 * before_share);
    fprintf(fid, "- Negative samples after 120s: %d (%.2f%% of all negatives)\n", after_neg, 100 * after_share);
    fprintf(fid, "- Steady-state samples (`time_s >= 120`): %d\n", overview.steady_sample_count);
    fprintf(fid, "- Steady-state negative samples: %d (%.4f%% of steady samples)\n", overview.steady_negative_count, 100 * overview.steady_negative_ratio);
    fprintf(fid, "- Minimum negative delay: %.6f ms\n", overview.min_negative_all);
    fprintf(fid, "- Steady-state minimum negative delay: %.6f ms\n\n", overview.min_negative_steady);

    fprintf(fid, "## Startup Synchronization Check\n");
    fprintf(fid, "%s\n\n", startup_text);

    fprintf(fid, "## Steady-State Magnitude Check\n");
    fprintf(fid, "%s\n", steady_text);
    fprintf(fid, "- small_negative: %d (%.2f%% of steady negatives)\n", steady_small_total, 100 * safeRatio(steady_small_total, steady_negative_total));
    fprintf(fid, "- medium_negative: %d (%.2f%% of steady negatives)\n", steady_medium_total, 100 * safeRatio(steady_medium_total, steady_negative_total));
    fprintf(fid, "- large_negative: %d (%.2f%% of steady negatives)\n", steady_large_total, 100 * safeRatio(steady_large_total, steady_negative_total));
    fprintf(fid, "- extreme_negative: %d (%.2f%% of steady negatives)\n\n", steady_extreme_total, 100 * safeRatio(steady_extreme_total, steady_negative_total));

    fprintf(fid, "## Most Problematic Scenario/Config\n");
    fprintf(fid, "- Most problematic by steady diagnostic score: %s / %s (%s)\n", ...
        N.unified_scenario(most_idx), N.protocol_or_config(most_idx), N.scenario_name(most_idx));
    fprintf(fid, "- Negative ratio all: %.4f%%\n", 100 * N.negative_ratio_all(most_idx));
    fprintf(fid, "- Steady negative ratio: %.4f%%\n", 100 * N.negative_ratio_steady(most_idx));
    fprintf(fid, "- Share of all negative samples: %.2f%%\n", 100 * top_share);
    fprintf(fid, "- Share of steady negative samples: %.2f%%\n", 100 * top_steady_share);
    fprintf(fid, "%s\n", s3_line);

    fprintf(fid, "## Isolation vs Burst Check\n");
    fprintf(fid, "%s\n", burst_text);
    fprintf(fid, "- Total negative bursts: %d\n", height(B));
    fprintf(fid, "- Largest negative burst duration: %.3f s\n\n", largest_burst);

    fprintf(fid, "## Recommended Next Step\n");
    fprintf(fid, "%s\n\n", next_step);

    fprintf(fid, "## Generated Outputs\n");
    fprintf(fid, "- `c02_ros_negative_rootcause_by_config.csv`\n");
    fprintf(fid, "- `c02_ros_negative_before_vs_after120_summary.csv`\n");
    fprintf(fid, "- `c02_ros_negative_magnitude_bins.csv`\n");
    fprintf(fid, "- `c02_ros_negative_bursts.csv`\n");
    fprintf(fid, "- `c02_ros_negative_rootcause_label.csv`\n");
    fprintf(fid, "- `fig_c02_ros_negative_delay_over_time.png/.fig`\n");
    fprintf(fid, "- `fig_c02_ros_negative_before_after120_bar.png/.fig`\n");
    fprintf(fid, "- `fig_c02_ros_negative_magnitude_bins.png/.fig`\n");
end

function x = asNumeric(v)
    if isnumeric(v)
        x = double(v);
    else
        x = str2double(string(v));
    end
end

function r = safeRatio(num, den)
    if den == 0
        r = NaN;
    else
        r = num / den;
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

function y = medianOrNaN(x)
    x = x(~isnan(x));
    if isempty(x)
        y = NaN;
    else
        y = median(x);
    end
end

function y = percentileOrNaN(x, pct)
    x = x(~isnan(x));
    if isempty(x)
        y = NaN;
    else
        y = percentile(x, pct);
    end
end

function p = percentile(values, pct)
    values = sort(values(:));
    idx = 1 + (numel(values) - 1) * pct / 100;
    lo = floor(idx);
    hi = ceil(idx);
    if lo == hi
        p = values(lo);
    else
        p = values(lo) + (idx - lo) * (values(hi) - values(lo));
    end
end

function q = quotePath(path_value)
    q = ['"', strrep(char(path_value), '"', '\"'), '"'];
end
