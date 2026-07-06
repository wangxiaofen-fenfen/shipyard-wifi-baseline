%% Check C02 ROS/control delay field availability
% V2-5-0 only: field and口径 availability check.
% No MANET, no fallback, no Wi-Fi PHY simulation, no formal ROS delay reproduction.

clear;
clc;

project_root = ".";
repo_dir = fullfile(project_root, "external_data", "c02_wifi_raw", ...
    "wifi_for_industrial_robotics");
results_dir = fullfile(project_root, "matlab", "c02_wifi_reproduction", "results");

if ~isfolder(repo_dir)
    error("Cannot find C02 raw data repo.");
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

A = table();
R = table();

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
        [delay_raw, time_s, delay_field, time_field, seq_field, note] = detectControlFields(D);
        has_delay = strlength(delay_field) > 0 && ~isempty(delay_raw);
        has_time = strlength(time_field) > 0 && ~isempty(time_s) && any(~isnan(time_s));
        has_seq = strlength(seq_field) > 0;
        has_control = hasControlLikeField(D);

        if has_delay
            delay_min = min(delay_raw, [], "omitnan");
            delay_max = max(delay_raw, [], "omitnan");
            delay_mean = mean(delay_raw, "omitnan");
            possible_unit = classifyUnit(delay_max);
            sample_count = sum(~isnan(delay_raw));
        else
            delay_min = NaN; delay_max = NaN; delay_mean = NaN;
            possible_unit = "missing";
            sample_count = 0;
        end

        row = table(string(json_path), location_ids(loc_idx), config_order(cfg_idx), ...
            has_control, has_delay, delay_field, has_time, time_field, has_seq, seq_field, ...
            sample_count, delay_min, delay_max, delay_mean, possible_unit, note, ...
            'VariableNames', {'json_file', 'location_id', 'protocol_or_config', ...
            'has_control_node', 'has_delay_field', 'detected_delay_field', ...
            'has_time_field', 'detected_time_field', 'has_sequence_field', ...
            'detected_sequence_field', 'sample_count', 'delay_min', 'delay_max', ...
            'delay_mean', 'possible_unit', 'note'});
        A = [A; row]; %#ok<AGROW>

        if has_delay
            n = numel(delay_raw);
            if numel(time_s) ~= n
                time_s = NaN(n, 1);
            end
            P = table( ...
                repmat(scenario_order(loc_idx), n, 1), ...
                repmat(scenario_names(loc_idx), n, 1), ...
                repmat(location_ids(loc_idx), n, 1), ...
                repmat(distance_values(loc_idx), n, 1), ...
                repmat(los_values(loc_idx), n, 1), ...
                repmat(config_order(cfg_idx), n, 1), ...
                time_s(:), delay_raw(:), repmat(delay_field, n, 1), ...
                repmat(possible_unit, n, 1), repmat(string(json_path), n, 1), ...
                'VariableNames', {'unified_scenario', 'scenario_name', 'location_id', ...
                'distance_m', 'los_condition', 'protocol_or_config', 'time_s', ...
                'control_delay_raw', 'detected_delay_field', 'possible_unit', ...
                'source_json_file'});
            R = [R; P]; %#ok<AGROW>
        end
    end
end

availability_out = fullfile(results_dir, "c02_ros_control_field_availability.csv");
writetable(A, availability_out);

preview_out = fullfile(results_dir, "c02_ros_control_delay_availability_raw_preview.csv");
if ~isempty(R)
    writetable(R, preview_out);
else
    writetable(table(), preview_out);
end

S = buildSummary(R, A, scenario_order, scenario_names, config_order);
coverage_ok = height(S) == 36 && all(S.sample_count_all > 0) && all(~isnan(S.all_mean_delay_raw));
time_ok = height(S) == 36 && all(S.sample_count_steady > 0);
unit_ok = all(S.possible_unit == "likely_ms");
for i = 1:height(S)
    if S.sample_count_all(i) == 0 || S.sample_count_steady(i) == 0
        S.ready_for_reproduction(i) = "no";
    elseif coverage_ok && time_ok && unit_ok
        S.ready_for_reproduction(i) = "yes";
    else
        S.ready_for_reproduction(i) = "check_needed";
    end
end
summary_out = fullfile(results_dir, "c02_ros_control_delay_availability_summary.csv");
writetable(S, summary_out);

plotAvailability(S, scenario_order, config_order, ...
    fullfile(results_dir, "fig_c02_ros_control_availability_heatmap.png"), ...
    fullfile(results_dir, "fig_c02_ros_control_availability_heatmap.fig"));

writeReport(fullfile(results_dir, "c02_ros_control_delay_availability_report.md"), ...
    json_path, A, R, S, coverage_ok, time_ok, unit_ok);

fprintf("\nC02 ROS/control delay availability check V2-5-0\n");
fprintf("Main JSON: %s\n", json_path);
fprintf("Availability rows: %d\n", height(A));
fprintf("Raw preview rows: %d\n", height(R));
fprintf("Summary rows: %d\n", height(S));
fprintf("Delay fields: %s\n", strjoin(unique(A.detected_delay_field), ", "));
fprintf("Time fields: %s\n", strjoin(unique(A.detected_time_field), ", "));
fprintf("Possible units: %s\n", strjoin(unique(S.possible_unit), ", "));
fprintf("Coverage 4x9: %d\n", coverage_ok);
fprintf("Ready rows: %d yes, %d check_needed, %d no\n", ...
    sum(S.ready_for_reproduction == "yes"), ...
    sum(S.ready_for_reproduction == "check_needed"), ...
    sum(S.ready_for_reproduction == "no"));
fprintf("Saved availability: %s\n", availability_out);
fprintf("Saved raw preview: %s\n", preview_out);
fprintf("Saved summary: %s\n\n", summary_out);

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
    paths = lower(string({files.folder}) + filesep + string({files.name}));
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

function tf = hasControlLikeField(D)
    f = lower(string(fieldnames(D)));
    keys = ["control", "ros", "delay", "latency", "timestamp", "seq", "sequence", "time"];
    tf = any(contains(f, keys));
end

function [delay_raw, time_s, delay_field, time_field, seq_field, note] = detectControlFields(D)
    f = string(fieldnames(D));
    lf = lower(f);
    delay_field = pickField(f, lf, ["control_delay_ms", "ros_delay_ms"]);
    if strlength(delay_field) == 0
        mask = (contains(lf, "control") | contains(lf, "ros")) & ...
            (contains(lf, "delay") | contains(lf, "latency"));
        delay_field = firstOrEmpty(f(mask));
    end

    time_field = pickField(f, lf, ["control_timestamp_s", "ros_timestamp_s", "control_time_s"]);
    if strlength(time_field) == 0
        mask = (contains(lf, "control") | contains(lf, "ros")) & ...
            (contains(lf, "timestamp") | contains(lf, "time"));
        time_field = firstOrEmpty(f(mask));
    end

    mask_seq = (contains(lf, "control") | contains(lf, "ros")) & ...
        (contains(lf, "seq") | contains(lf, "sequence"));
    seq_field = firstOrEmpty(f(mask_seq));

    if strlength(delay_field) > 0
        raw_delay = getNumericFieldKeepNaN(D, delay_field);
    else
        raw_delay = [];
    end
    if strlength(time_field) > 0
        raw_time = getNumericFieldKeepNaN(D, time_field);
    else
        raw_time = [];
    end

    if isempty(raw_delay)
        delay_raw = [];
        time_s = [];
        note = "no control/ros delay field found";
        return;
    end
    valid = ~isnan(raw_delay);
    delay_raw = raw_delay(valid);
    if numel(raw_time) == numel(raw_delay)
        time_s = raw_time(valid);
        note = "delay/time extracted";
    else
        time_s = NaN(numel(delay_raw), 1);
        note = "delay extracted; time missing or length mismatch";
    end
end

function out = pickField(f, lf, preferred)
    out = "";
    for i = 1:numel(preferred)
        idx = find(lf == lower(preferred(i)), 1);
        if ~isempty(idx)
            out = f(idx);
            return;
        end
    end
end

function out = firstOrEmpty(x)
    if isempty(x)
        out = "";
    else
        out = x(1);
    end
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

function unit = classifyUnit(delay_max)
    if isnan(delay_max)
        unit = "missing";
    elseif delay_max < 10
        unit = "check_needed";
    elseif delay_max <= 10000
        unit = "likely_ms";
    else
        unit = "possible_us";
    end
end

function S = buildSummary(R, A, scenario_order, scenario_names, config_order)
    n = numel(scenario_order) * numel(config_order);
    unified_scenario = strings(n, 1);
    scenario_name = strings(n, 1);
    protocol_or_config = strings(n, 1);
    sample_count_all = zeros(n, 1);
    sample_count_steady = zeros(n, 1);
    all_mean_delay_raw = NaN(n, 1);
    steady_mean_delay_raw = NaN(n, 1);
    all_median_delay_raw = NaN(n, 1);
    steady_median_delay_raw = NaN(n, 1);
    possible_unit = strings(n, 1);
    ready_for_reproduction = strings(n, 1);
    r = 0;

    for s = 1:numel(scenario_order)
        for c = 1:numel(config_order)
            r = r + 1;
            unified_scenario(r) = scenario_order(s);
            scenario_name(r) = scenario_names(s);
            protocol_or_config(r) = config_order(c);
            arow = A(A.location_id == s & A.protocol_or_config == config_order(c), :);
            if ~isempty(arow)
                possible_unit(r) = arow.possible_unit(1);
            else
                possible_unit(r) = "missing";
            end
            if isempty(R)
                continue;
            end
            mask = R.unified_scenario == scenario_order(s) & R.protocol_or_config == config_order(c);
            x = R.control_delay_raw(mask);
            xs = R.control_delay_raw(mask & R.time_s >= 120);
            sample_count_all(r) = sum(~isnan(x));
            sample_count_steady(r) = sum(~isnan(xs));
            if sample_count_all(r) > 0
                all_mean_delay_raw(r) = mean(x, "omitnan");
                all_median_delay_raw(r) = median(x, "omitnan");
            end
            if sample_count_steady(r) > 0
                steady_mean_delay_raw(r) = mean(xs, "omitnan");
                steady_median_delay_raw(r) = median(xs, "omitnan");
            end
        end
    end
    S = table(unified_scenario, scenario_name, protocol_or_config, sample_count_all, ...
        sample_count_steady, all_mean_delay_raw, steady_mean_delay_raw, ...
        all_median_delay_raw, steady_median_delay_raw, possible_unit, ready_for_reproduction);
end

function plotAvailability(S, scenario_order, config_order, png_path, fig_path)
    M = zeros(numel(config_order), numel(scenario_order));
    for i = 1:height(S)
        row = find(config_order == S.protocol_or_config(i), 1);
        col = find(scenario_order == S.unified_scenario(i), 1);
        M(row, col) = double(S.sample_count_all(i) > 0 && S.sample_count_steady(i) > 0);
    end
    fig = figure("Visible", "off", "Color", "w", "Position", [100 100 900 560]);
    h = heatmap(scenario_order, config_order, M);
    h.Title = "C02 ROS/Control Delay Availability (delay + time_s)";
    h.XLabel = "Scenario";
    h.YLabel = "Wi-Fi config";
    h.CellLabelFormat = "%.0f";
    h.Colormap = [0.85 0.85 0.85; 0.20 0.55 0.45];
    savefig(fig, fig_path);
    exportgraphics(fig, png_path, "Resolution", 300);
    close(fig);
end

function writeReport(report_path, json_path, A, R, S, coverage_ok, time_ok, unit_ok)
    delay_fields = strjoin(unique(A.detected_delay_field), ", ");
    time_fields = strjoin(unique(A.detected_time_field), ", ");
    units = strjoin(unique(S.possible_unit), ", ");
    ready_yes = sum(S.ready_for_reproduction == "yes");
    can_formal = coverage_ok && time_ok && unit_ok;
    lines = [
        "# C02 ROS/Control Delay Availability Report"
        ""
        "## Purpose"
        "Check whether the public C02 raw JSON contains ROS/control delay fields suitable for later formal reproduction."
        ""
        "## Data source"
        "`" + string(json_path) + "`"
        ""
        "## Field availability"
        "- Found control/ROS delay data: " + string(height(R) > 0)
        "- Delay field name(s): " + delay_fields
        "- Time field name(s): " + time_fields
        "- Possible unit(s): " + units
        "- Covers 4 scenarios x 9 configs: " + string(coverage_ok)
        "- Supports t >= 120 s steady-state check: " + string(time_ok)
        "- Rows marked ready_for_reproduction=yes: " + string(ready_yes) + "/36"
        ""
        "## Can enter formal ROS/control delay reproduction?"
        string(can_formal)
        ""
        "## Note"
        "This V2-5-0 step is only an availability and口径 check. It is not a formal ROS/control delay reproduction."
    ];
    writelines(lines, report_path);
end
