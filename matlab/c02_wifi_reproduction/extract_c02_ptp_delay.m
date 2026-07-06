%% Extract C02 Wi-Fi PTP delay from public raw JSON
% V2-4 only: real PTP path delay reproduction from JSON.
% No MANET, no fallback, no Wi-Fi PHY simulation, no ROS control delay.

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
        [ptp_delay_ms, time_s, unit_note] = getPtpDelayAndTimeMs(D);
        unit_notes(end + 1, 1) = unit_note;

        n = numel(ptp_delay_ms);
        T = table( ...
            repmat(scenario_order(loc_idx), n, 1), ...
            repmat(scenario_names(loc_idx), n, 1), ...
            repmat(location_ids(loc_idx), n, 1), ...
            repmat(distance_values(loc_idx), n, 1), ...
            repmat(los_values(loc_idx), n, 1), ...
            repmat(config_order(cfg_idx), n, 1), ...
            time_s(:), ptp_delay_ms(:), repmat(string(json_path), n, 1), ...
            'VariableNames', {'unified_scenario', 'scenario_name', 'location_id', ...
            'distance_m', 'los_condition', 'protocol_or_config', 'time_s', ...
            'ptp_delay_ms', 'source_json_file'});
        R = [R; T]; %#ok<AGROW>
    end
end

raw_out = fullfile(results_dir, "c02_ptp_delay_raw_cleaned.csv");
writetable(R, raw_out);

S = buildSummary(R, scenario_order, scenario_names, location_ids, ...
    distance_values, los_values, config_order);
summary_out = fullfile(results_dir, "c02_ptp_delay_summary_by_config.csv");
writetable(S, summary_out);

validatePtpTables(R, S, scenario_order, config_order);

B = bestByScenario(S, scenario_order);
best_out = fullfile(results_dir, "c02_ptp_best_config_by_low_delay.csv");
writetable(B, best_out);

plotHeatmap(S, scenario_order, config_order, ...
    fullfile(results_dir, "fig_c02_ptp_delay_mean_heatmap.png"), ...
    fullfile(results_dir, "fig_c02_ptp_delay_mean_heatmap.fig"));
plotBestBar(B, ...
    fullfile(results_dir, "fig_c02_ptp_best_low_delay_bar.png"), ...
    fullfile(results_dir, "fig_c02_ptp_best_low_delay_bar.fig"));
plotCdf(R, scenario_order, ...
    fullfile(results_dir, "fig_c02_ptp_delay_cdf.png"), ...
    fullfile(results_dir, "fig_c02_ptp_delay_cdf.fig"));

writeReport(fullfile(results_dir, "c02_ptp_delay_reproduction_report.md"), ...
    json_path, R, S, B, unique(unit_notes));

fprintf("\nC02 Wi-Fi PTP delay reproduction V2-4\n");
fprintf("Main JSON: %s\n", json_path);
fprintf("Raw PTP delay rows: %d\n", height(R));
fprintf("Summary rows: %d\n", height(S));
fprintf("Scenario count: %d\n", numel(unique(S.unified_scenario)));
fprintf("Wi-Fi config count: %d\n", numel(unique(S.protocol_or_config)));
fprintf("Best low PTP delay config per scenario:\n");
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

function [ptp_delay_ms, time_s, unit_note] = getPtpDelayAndTimeMs(D)
    if isfield(D, "ptp_path_delay_current_ms")
        raw_delay = getNumericFieldKeepNaN(D, "ptp_path_delay_current_ms");
        unit_note = "used ptp_path_delay_current_ms as ms";
    elseif isfield(D, "ptp_delay_ms")
        raw_delay = getNumericFieldKeepNaN(D, "ptp_delay_ms");
        unit_note = "used ptp_delay_ms as ms";
    elseif isfield(D, "ptp_path_delay_ms")
        raw_delay = getNumericFieldKeepNaN(D, "ptp_path_delay_ms");
        unit_note = "used ptp_path_delay_ms as ms";
    else
        fields = string(fieldnames(D));
        candidates = fields(contains(lower(fields), "ptp") & contains(lower(fields), "delay") & contains(lower(fields), "ms"));
        if isempty(candidates)
            warning("No clearly named PTP delay field with ms unit found.");
            error("No clearly named PTP delay field found; unit cannot be determined.");
        end
        raw_delay = getNumericFieldKeepNaN(D, candidates(1));
        unit_note = "used detected ms field " + candidates(1);
    end
    valid = ~isnan(raw_delay);
    ptp_delay_ms = raw_delay(valid);
    if isempty(ptp_delay_ms)
        error("PTP delay field is empty.");
    end
    if isfield(D, "ptp_timestamp_s")
        raw_time = getNumericFieldKeepNaN(D, "ptp_timestamp_s");
    elseif isfield(D, "ptp_time_s")
        raw_time = getNumericFieldKeepNaN(D, "ptp_time_s");
    elseif isfield(D, "time_s")
        raw_time = getNumericFieldKeepNaN(D, "time_s");
    else
        raw_time = NaN(size(raw_delay));
    end
    if numel(raw_time) == numel(raw_delay)
        time_s = raw_time(valid);
    else
        warning("PTP time vector is missing or length-mismatched; writing NaN time_s.");
        time_s = NaN(numel(ptp_delay_ms), 1);
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

function values = getNumericFieldKeepNaN(S, field)
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
    ptp_delay_ms_mean = NaN(row_count, 1);
    ptp_delay_ms_median = NaN(row_count, 1);
    ptp_delay_ms_p25 = NaN(row_count, 1);
    ptp_delay_ms_p75 = NaN(row_count, 1);
    ptp_delay_ms_p95 = NaN(row_count, 1);
    ptp_delay_ms_min = NaN(row_count, 1);
    ptp_delay_ms_max = NaN(row_count, 1);

    r = 0;
    for s = 1:numel(scenario_order)
        for c = 1:numel(config_order)
            r = r + 1;
            mask = R.unified_scenario == scenario_order(s) & R.protocol_or_config == config_order(c);
            x = R.ptp_delay_ms(mask);
            x = x(~isnan(x));
            unified_scenario(r) = scenario_order(s);
            scenario_name(r) = scenario_names(s);
            location_id(r) = location_ids(s);
            distance_m(r) = distance_values(s);
            los_condition(r) = los_values(s);
            protocol_or_config(r) = config_order(c);
            sample_count(r) = numel(x);
            if ~isempty(x)
                ptp_delay_ms_mean(r) = mean(x);
                ptp_delay_ms_median(r) = median(x);
                ptp_delay_ms_p25(r) = percentile(x, 25);
                ptp_delay_ms_p75(r) = percentile(x, 75);
                ptp_delay_ms_p95(r) = percentile(x, 95);
                ptp_delay_ms_min(r) = min(x);
                ptp_delay_ms_max(r) = max(x);
            end
        end
    end

    S = table(unified_scenario, scenario_name, location_id, distance_m, los_condition, ...
        protocol_or_config, sample_count, ptp_delay_ms_mean, ptp_delay_ms_median, ...
        ptp_delay_ms_p25, ptp_delay_ms_p75, ptp_delay_ms_p95, ptp_delay_ms_min, ptp_delay_ms_max);
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

function validatePtpTables(R, S, scenario_order, config_order)
    if numel(unique(S.unified_scenario)) ~= 4 || ~all(ismember(scenario_order, unique(S.unified_scenario)))
        error("PTP delay extraction check failed: expected 4 scenarios S1-S4.");
    end
    if numel(unique(S.protocol_or_config)) ~= 9 || ~all(ismember(config_order, unique(S.protocol_or_config)))
        error("PTP delay extraction check failed: expected 9 Wi-Fi configs.");
    end
    if height(S) ~= 36
        error("PTP delay extraction check failed: summary should have 36 rows, got %d.", height(S));
    end
    if any(R.ptp_delay_ms < 0, "all") || any(S.ptp_delay_ms_mean < 0, "all")
        error("PTP delay extraction check failed: ptp_delay_ms must be >= 0.");
    end
    if any(S.sample_count == 0)
        error("PTP delay extraction check failed: at least one scenario/config has no PTP samples.");
    end
end

function B = bestByScenario(S, scenario_order)
    unified_scenario = strings(numel(scenario_order), 1);
    scenario_name = strings(numel(scenario_order), 1);
    best_config_by_low_ptp_delay = strings(numel(scenario_order), 1);
    best_ptp_delay_ms_mean = NaN(numel(scenario_order), 1);
    for s = 1:numel(scenario_order)
        rows = find(S.unified_scenario == scenario_order(s));
        [best_ptp_delay_ms_mean(s), k] = min(S.ptp_delay_ms_mean(rows));
        idx = rows(k);
        unified_scenario(s) = S.unified_scenario(idx);
        scenario_name(s) = S.scenario_name(idx);
        best_config_by_low_ptp_delay(s) = S.protocol_or_config(idx);
    end
    B = table(unified_scenario, scenario_name, best_config_by_low_ptp_delay, best_ptp_delay_ms_mean);
end

function plotHeatmap(S, scenario_order, config_order, png_path, fig_path)
    M = NaN(numel(config_order), numel(scenario_order));
    for i = 1:height(S)
        row = find(config_order == S.protocol_or_config(i), 1);
        col = find(scenario_order == S.unified_scenario(i), 1);
        M(row, col) = S.ptp_delay_ms_mean(i);
    end

    fig = figure("Visible", "off", "Color", "w", "Position", [100 100 980 620]);
    h = heatmap(scenario_order, config_order, M);
    h.Title = "C02 PTP Delay Mean from Raw JSON (lower is better)";
    h.XLabel = "Scenario";
    h.YLabel = "Wi-Fi config";
    h.CellLabelFormat = "%.2f";
    h.Colormap = flipud(parula(256));
    savefig(fig, fig_path);
    exportgraphics(fig, png_path, "Resolution", 300);
    close(fig);
end

function plotBestBar(B, png_path, fig_path)
    fig = figure("Visible", "off", "Color", "w", "Position", [100 100 850 500]);
    b = bar(categorical(B.unified_scenario), B.best_ptp_delay_ms_mean, 0.55);
    b.FaceColor = [0.20 0.55 0.45];
    grid on;
    ylabel("Mean PTP delay (ms)");
    title("Best Wi-Fi Configuration by Lowest PTP Delay");
    ymax = max(B.best_ptp_delay_ms_mean) * 1.20;
    ylim([0 ymax]);
    for i = 1:height(B)
        text(i, B.best_ptp_delay_ms_mean(i) + ymax * 0.025, ...
            B.best_config_by_low_ptp_delay(i), "HorizontalAlignment", "center", ...
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
        x = sort(R.ptp_delay_ms(R.unified_scenario == scenario_order(s)));
        y = (1:numel(x))' / numel(x);
        plot(x, y, "LineWidth", 1.8, "Color", colors(s, :), "DisplayName", scenario_order(s));
    end
    grid on;
    xlabel("PTP delay (ms)");
    ylabel("Empirical CDF");
    title("C02 PTP Delay CDF by Scenario");
    legend("Location", "southeast");
    hold off;
    savefig(fig, fig_path);
    exportgraphics(fig, png_path, "Resolution", 300);
    close(fig);
end

function writeReport(report_path, json_path, R, S, B, unit_notes)
    expected_match = B.best_config_by_low_ptp_delay(1) == "ax/6/80" && ...
        B.best_config_by_low_ptp_delay(2) == "ax/6/80" && ...
        B.best_config_by_low_ptp_delay(3) == "ax/5/20" && ...
        B.best_config_by_low_ptp_delay(4) == "ax/5/80";

    best_lines = strings(height(B), 1);
    for i = 1:height(B)
        best_lines(i) = "- " + B.unified_scenario(i) + " (" + B.scenario_name(i) + "): " + ...
            B.best_config_by_low_ptp_delay(i) + ", mean " + ...
            sprintf("%.2f", B.best_ptp_delay_ms_mean(i)) + " ms";
    end

    lines = [
        "# C02 PTP Delay Reproduction Report"
        ""
        "## Purpose"
        "Reproduce PTP path delay from the public C02 Wi-Fi raw JSON and summarize the real measurement data by scenario and Wi-Fi configuration."
        ""
        "## Data source"
        "`" + string(json_path) + "`"
        ""
        "## Important note"
        "This is raw JSON reproduction, not Wi-Fi PHY simulation. No MANET, fallback, ROS delay, or fabricated values are used."
        ""
        "## Scenario mapping"
        "- Location 1 -> S1 Short LoS, 13 m"
        "- Location 2 -> S2 Medium LoS, 60 m"
        "- Location 3 -> S3 Long NLoS, 130 m"
        "- Location 4 -> S4 Long mixed, 150 m"
        ""
        "## Sample count"
        "- Raw PTP delay rows: " + string(height(R))
        "- Summary rows: " + string(height(S))
        "- Per scenario/config sample count range: " + string(min(S.sample_count)) + " to " + string(max(S.sample_count))
        "- Unit handling: " + strjoin(unit_notes(:)', "; ")
        ""
        "## Best low-delay config per scenario"
        best_lines
        ""
        "## Qualitative paper statement check"
        "The expected qualitative pattern is: S1 and S2 favor ax/6/80 for PTP delay; S3 favors ax/5/20; S4 favors ax/5/80."
        "- Qualitative match from extracted means: " + string(expected_match)
        ""
        "## Limitations"
        "The script reports PTP delay exactly from the JSON fields with clear ms units. It does not infer ambiguous units, smooth traces, or introduce any model."
    ];
    writelines(lines, report_path);
end
