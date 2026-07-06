%% Extract C02 Wi-Fi iPerf throughput from public raw JSON
% V2-3 only: real iPerf throughput reproduction from JSON.
% No MANET, no fallback, no Wi-Fi PHY simulation, no fabricated values.

clear;
clc;

project_root = ".";
repo_dir = fullfile(project_root, "external_data", "c02_wifi_raw", ...
    "wifi_for_industrial_robotics");
results_dir = fullfile(project_root, "matlab", "c02_wifi_reproduction", "results");

if ~isfolder(repo_dir)
    error("Cannot find C02 raw data repo. Please run V2-1 first.");
end
if ~isfolder(results_dir)
    mkdir(results_dir);
end

json_path = findMainJson(repo_dir, results_dir);
J = jsondecode(fileread(json_path));

scenario_order = ["S1", "S2", "S3", "S4"];
json_location_fields = ["x1", "x2", "x3", "x4"];
scenario_names = ["Short LoS", "Medium LoS", "Long NLoS", "Long mixed"];
location_ids = (1:4)';
distance_values = [13; 60; 130; 150];
los_values = ["LoS"; "LoS"; "NLoS"; "mixed"];

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

R = table();
unit_notes = strings(0, 1);

for loc_idx = 1:numel(json_location_fields)
    loc_field = json_location_fields(loc_idx);
    if ~isfield(J, loc_field)
        error("Missing expected location in JSON: %s", loc_field);
    end
    loc_struct = J.(loc_field);

    for cfg_idx = 1:numel(json_config_fields)
        cfg_field = json_config_fields(cfg_idx);
        if ~isfield(loc_struct, cfg_field)
            error("Missing expected config in JSON: %s.%s", loc_field, cfg_field);
        end

        D = loc_struct.(cfg_field);
        [throughput_Mbps, unit_note] = getThroughputMbps(D);
        unit_notes(end + 1, 1) = unit_note;
        time_s = getTimeSeconds(D, numel(throughput_Mbps));

        n = numel(throughput_Mbps);
        T = table( ...
            repmat(scenario_order(loc_idx), n, 1), ...
            repmat(scenario_names(loc_idx), n, 1), ...
            repmat(location_ids(loc_idx), n, 1), ...
            repmat(distance_values(loc_idx), n, 1), ...
            repmat(los_values(loc_idx), n, 1), ...
            repmat(config_order(cfg_idx), n, 1), ...
            time_s(:), throughput_Mbps(:), repmat(string(json_path), n, 1), ...
            'VariableNames', {'unified_scenario', 'scenario_name', 'location_id', ...
            'distance_m', 'los_condition', 'protocol_or_config', 'time_s', ...
            'throughput_Mbps', 'source_json_file'});
        R = [R; T]; %#ok<AGROW>
    end
end

raw_out = fullfile(results_dir, "c02_iperf_throughput_raw_cleaned.csv");
writetable(R, raw_out);

S = buildSummary(R, scenario_order, scenario_names, location_ids, ...
    distance_values, los_values, config_order);
summary_out = fullfile(results_dir, "c02_iperf_throughput_summary_by_config.csv");
writetable(S, summary_out);

validateThroughputTables(R, S, scenario_order, config_order);

B = bestByScenario(S, scenario_order);
best_out = fullfile(results_dir, "c02_iperf_best_config_by_throughput.csv");
writetable(B, best_out);

plotHeatmap(S, scenario_order, config_order, ...
    fullfile(results_dir, "fig_c02_iperf_throughput_mean_heatmap.png"), ...
    fullfile(results_dir, "fig_c02_iperf_throughput_mean_heatmap.fig"));
plotBestBar(B, ...
    fullfile(results_dir, "fig_c02_iperf_best_throughput_bar.png"), ...
    fullfile(results_dir, "fig_c02_iperf_best_throughput_bar.fig"));
plotCdf(R, scenario_order, ...
    fullfile(results_dir, "fig_c02_iperf_throughput_cdf.png"), ...
    fullfile(results_dir, "fig_c02_iperf_throughput_cdf.fig"));

writeReport(fullfile(results_dir, "c02_iperf_throughput_reproduction_report.md"), ...
    json_path, R, S, B, unique(unit_notes));

fprintf("\nC02 Wi-Fi iPerf throughput reproduction V2-3\n");
fprintf("Main JSON: %s\n", json_path);
fprintf("Raw throughput rows: %d\n", height(R));
fprintf("Summary rows: %d\n", height(S));
fprintf("Scenario count: %d\n", numel(unique(S.unified_scenario)));
fprintf("Wi-Fi config count: %d\n", numel(unique(S.protocol_or_config)));
fprintf("Best throughput config per scenario:\n");
disp(B);
fprintf("Saved raw cleaned CSV: %s\n", raw_out);
fprintf("Saved summary CSV: %s\n", summary_out);
fprintf("Saved best config CSV: %s\n\n", best_out);

function json_path = findMainJson(repo_dir, results_dir)
    summary_file = fullfile(results_dir, "c02_raw_data_source_summary.csv");
    if isfile(summary_file)
        S = readtable(summary_file, "TextType", "string", "VariableNamingRule", "preserve");
        if any(string(S.Properties.VariableNames) == "main_json_file") && height(S) >= 1
            candidate = fullfile(repo_dir, S.main_json_file(1));
            if isfile(candidate)
                json_path = string(candidate);
                return;
            end
        end
    end

    files = dir(fullfile(repo_dir, "**", "*.json"));
    names = lower(string({files.name}));
    paths = lower(string({files.folder}) + filesep + names);
    hit = contains(paths, "perama") & contains(paths, "range") & contains(paths, "testing");
    if ~any(hit)
        hit = contains(paths, "perama") | contains(paths, "database");
    end
    if ~any(hit)
        error("Cannot find main JSON database in raw repo.");
    end
    idx = find(hit, 1);
    json_path = string(fullfile(files(idx).folder, files(idx).name));
end

function [throughput_Mbps, unit_note] = getThroughputMbps(D)
    if isfield(D, "iperf_mbps")
        throughput_Mbps = getNumericField(D, "iperf_mbps");
        unit_note = "used iperf_mbps as Mbps";
    elseif isfield(D, "throughput_Mbps")
        throughput_Mbps = getNumericField(D, "throughput_Mbps");
        unit_note = "used throughput_Mbps as Mbps";
    elseif isfield(D, "iperf_kbps")
        throughput_Mbps = getNumericField(D, "iperf_kbps") / 1000;
        unit_note = "converted iperf_kbps to Mbps";
    elseif isfield(D, "throughput_kbps")
        throughput_Mbps = getNumericField(D, "throughput_kbps") / 1000;
        unit_note = "converted throughput_kbps to Mbps";
    elseif isfield(D, "iperf_bps")
        throughput_Mbps = getNumericField(D, "iperf_bps") / 1e6;
        unit_note = "converted iperf_bps to Mbps";
    else
        error("No clearly named iPerf throughput field found; unit cannot be determined.");
    end
    if isempty(throughput_Mbps)
        error("iPerf throughput field is empty.");
    end
end

function time_s = getTimeSeconds(D, n)
    if isfield(D, "iperf_start")
        time_s = getNumericField(D, "iperf_start");
    elseif isfield(D, "iperf_timestamp_s")
        time_s = getNumericField(D, "iperf_timestamp_s");
    elseif isfield(D, "time_s")
        time_s = getNumericField(D, "time_s");
    else
        time_s = NaN(n, 1);
    end
    if numel(time_s) ~= n
        warning("iPerf time vector is missing or length-mismatched; writing NaN time_s.");
        time_s = NaN(n, 1);
    end
end

function values = getNumericField(S, field)
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

function S = buildSummary(R, scenario_order, scenario_names, location_ids, distance_values, los_values, config_order)
    row_count = numel(scenario_order) * numel(config_order);
    unified_scenario = strings(row_count, 1);
    scenario_name = strings(row_count, 1);
    location_id = NaN(row_count, 1);
    distance_m = NaN(row_count, 1);
    los_condition = strings(row_count, 1);
    protocol_or_config = strings(row_count, 1);
    sample_count = zeros(row_count, 1);
    throughput_Mbps_mean = NaN(row_count, 1);
    throughput_Mbps_median = NaN(row_count, 1);
    throughput_Mbps_p25 = NaN(row_count, 1);
    throughput_Mbps_p75 = NaN(row_count, 1);
    throughput_Mbps_min = NaN(row_count, 1);
    throughput_Mbps_max = NaN(row_count, 1);

    r = 0;
    for s = 1:numel(scenario_order)
        for c = 1:numel(config_order)
            r = r + 1;
            mask = R.unified_scenario == scenario_order(s) & R.protocol_or_config == config_order(c);
            x = R.throughput_Mbps(mask);
            x = x(~isnan(x));
            unified_scenario(r) = scenario_order(s);
            scenario_name(r) = scenario_names(s);
            location_id(r) = location_ids(s);
            distance_m(r) = distance_values(s);
            los_condition(r) = los_values(s);
            protocol_or_config(r) = config_order(c);
            sample_count(r) = numel(x);
            if ~isempty(x)
                throughput_Mbps_mean(r) = mean(x);
                throughput_Mbps_median(r) = median(x);
                throughput_Mbps_p25(r) = percentile(x, 25);
                throughput_Mbps_p75(r) = percentile(x, 75);
                throughput_Mbps_min(r) = min(x);
                throughput_Mbps_max(r) = max(x);
            end
        end
    end

    S = table(unified_scenario, scenario_name, location_id, distance_m, los_condition, ...
        protocol_or_config, sample_count, throughput_Mbps_mean, throughput_Mbps_median, ...
        throughput_Mbps_p25, throughput_Mbps_p75, throughput_Mbps_min, throughput_Mbps_max);
end

function p = percentile(values, pct)
    values = sort(values(:));
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

function validateThroughputTables(R, S, scenario_order, config_order)
    if numel(unique(S.unified_scenario)) ~= 4 || ~all(ismember(scenario_order, unique(S.unified_scenario)))
        error("Throughput extraction check failed: expected 4 scenarios S1-S4.");
    end
    if numel(unique(S.protocol_or_config)) ~= 9 || ~all(ismember(config_order, unique(S.protocol_or_config)))
        error("Throughput extraction check failed: expected 9 Wi-Fi configs.");
    end
    if height(S) ~= 36
        error("Throughput extraction check failed: summary should have 36 rows, got %d.", height(S));
    end
    if any(R.throughput_Mbps < 0, "all") || any(S.throughput_Mbps_mean < 0, "all")
        error("Throughput extraction check failed: throughput_Mbps must be >= 0.");
    end
    if any(S.sample_count == 0)
        error("Throughput extraction check failed: at least one scenario/config has no iPerf samples.");
    end
end

function B = bestByScenario(S, scenario_order)
    unified_scenario = strings(numel(scenario_order), 1);
    scenario_name = strings(numel(scenario_order), 1);
    best_config_by_throughput = strings(numel(scenario_order), 1);
    best_throughput_Mbps_mean = NaN(numel(scenario_order), 1);
    for s = 1:numel(scenario_order)
        rows = find(S.unified_scenario == scenario_order(s));
        [best_throughput_Mbps_mean(s), k] = max(S.throughput_Mbps_mean(rows));
        idx = rows(k);
        unified_scenario(s) = S.unified_scenario(idx);
        scenario_name(s) = S.scenario_name(idx);
        best_config_by_throughput(s) = S.protocol_or_config(idx);
    end
    B = table(unified_scenario, scenario_name, best_config_by_throughput, best_throughput_Mbps_mean);
end

function plotHeatmap(S, scenario_order, config_order, png_path, fig_path)
    M = NaN(numel(config_order), numel(scenario_order));
    for i = 1:height(S)
        row = find(config_order == S.protocol_or_config(i), 1);
        col = find(scenario_order == S.unified_scenario(i), 1);
        M(row, col) = S.throughput_Mbps_mean(i);
    end

    fig = figure("Visible", "off", "Color", "w", "Position", [100 100 980 620]);
    h = heatmap(scenario_order, config_order, M);
    h.Title = "C02 iPerf Throughput Mean from Raw JSON";
    h.XLabel = "Scenario";
    h.YLabel = "Wi-Fi config";
    h.CellLabelFormat = "%.1f";
    h.Colormap = parula(256);
    savefig(fig, fig_path);
    exportgraphics(fig, png_path, "Resolution", 300);
    close(fig);
end

function plotBestBar(B, png_path, fig_path)
    fig = figure("Visible", "off", "Color", "w", "Position", [100 100 850 500]);
    b = bar(categorical(B.unified_scenario), B.best_throughput_Mbps_mean, 0.55);
    b.FaceColor = [0.15 0.45 0.70];
    grid on;
    ylabel("Mean throughput (Mbps)");
    title("Best Wi-Fi Configuration by iPerf Throughput");
    ymax = max(B.best_throughput_Mbps_mean) * 1.18;
    ylim([0 ymax]);
    for i = 1:height(B)
        text(i, B.best_throughput_Mbps_mean(i) + ymax * 0.025, ...
            B.best_config_by_throughput(i), "HorizontalAlignment", "center", ...
            "FontSize", 9, "Interpreter", "none");
    end
    savefig(fig, fig_path);
    exportgraphics(fig, png_path, "Resolution", 300);
    close(fig);
end

function plotCdf(R, scenario_order, png_path, fig_path)
    fig = figure("Visible", "off", "Color", "w", "Position", [100 100 900 560]);
    hold on;
    colors = lines(numel(scenario_order));
    for s = 1:numel(scenario_order)
        x = sort(R.throughput_Mbps(R.unified_scenario == scenario_order(s)));
        y = (1:numel(x))' / numel(x);
        plot(x, y, "LineWidth", 1.8, "Color", colors(s, :), "DisplayName", scenario_order(s));
    end
    grid on;
    xlabel("Throughput (Mbps)");
    ylabel("Empirical CDF");
    title("C02 iPerf Throughput CDF by Scenario");
    legend("Location", "southeast");
    hold off;
    savefig(fig, fig_path);
    exportgraphics(fig, png_path, "Resolution", 300);
    close(fig);
end

function writeReport(report_path, json_path, R, S, B, unit_notes)
    expected_match = B.best_config_by_throughput(1) == "ax/6/160" && ...
        B.best_config_by_throughput(2) == "ax/6/160" && ...
        B.best_config_by_throughput(3) == "ax/6/160" && ...
        (B.best_config_by_throughput(4) == "ax/6/80" || B.best_config_by_throughput(4) == "ax/6/160");

    best_lines = strings(height(B), 1);
    for i = 1:height(B)
        best_lines(i) = "- " + B.unified_scenario(i) + " (" + B.scenario_name(i) + "): " + ...
            B.best_config_by_throughput(i) + ", mean " + ...
            sprintf("%.2f", B.best_throughput_Mbps_mean(i)) + " Mbps";
    end

    lines = [
        "# C02 iPerf Throughput Reproduction Report"
        ""
        "## Purpose"
        "Reproduce iPerf throughput from the public C02 Wi-Fi raw JSON and summarize the real measurement data by scenario and Wi-Fi configuration."
        ""
        "## Data source"
        "`" + string(json_path) + "`"
        ""
        "## Important note"
        "This is raw JSON reproduction, not PHY simulation. No MANET, fallback, or fabricated throughput values are used."
        ""
        "## Scenario mapping"
        "- Location 1 -> S1 Short LoS, 13 m"
        "- Location 2 -> S2 Medium LoS, 60 m"
        "- Location 3 -> S3 Long NLoS, 130 m"
        "- Location 4 -> S4 Long mixed, 150 m"
        ""
        "## Sample count"
        "- Raw iPerf rows: " + string(height(R))
        "- Summary rows: " + string(height(S))
        "- Per scenario/config sample count range: " + string(min(S.sample_count)) + " to " + string(max(S.sample_count))
        "- Unit handling: " + strjoin(unit_notes(:)', "; ")
        ""
        "## Best config per scenario"
        best_lines
        ""
        "## Qualitative paper statement check"
        "The expected qualitative pattern is: ax/6/160 strongest in Short LoS, Medium LoS, Long NLoS; ax/6/80 strong in Long mixed."
        "- Qualitative match from extracted means: " + string(expected_match)
        ""
        "## Limitations"
        "The script reports iPerf throughput exactly from the JSON fields with clear units. It does not infer missing units, smooth traces, or introduce any model."
    ];
    writelines(lines, report_path);
end
