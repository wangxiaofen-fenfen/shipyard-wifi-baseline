%% Compute Laboratory CDR_75ms from raw control logs
% This template is independent of the Perama baseline results.

clear; clc;

delay_threshold_ms = 75;
steady_start_s = 120;

script_dir = fileparts(mfilename("fullpath"));
repo_root = fileparts(fileparts(script_dir));
input_file = fullfile(repo_root, "data", "templates", "laboratory_wifi5_pilot_template.csv");
output_dir = fullfile(repo_root, "results", "laboratory");
summary_file = fullfile(output_dir, "laboratory_wifi5_cdr75_summary.csv");
table_file = fullfile(output_dir, "laboratory_wifi5_cdr75_table.csv");
status_file = fullfile(output_dir, "laboratory_cdr75_template_status.txt");

if ~isfolder(output_dir)
    mkdir(output_dir);
end

if ~isfile(input_file)
    error("Missing input template: %s", input_file);
end

opts = detectImportOptions(input_file, "TextType", "string");
T = readtable(input_file, opts);

if height(T) == 0
    fid = fopen(status_file, "w");
    if fid < 0
        error("Cannot write status file: %s", status_file);
    end
    fprintf(fid, "Laboratory raw control log has not been collected yet. CDR_75ms will be computed after field data are added.\n");
    fclose(fid);
    fprintf("No laboratory raw control data found yet. Template only.\n");
    fprintf("Wrote %s\n", status_file);
    return;
end

required_group_fields = ["scenario_id", "wifi_config", "run_id", "time_s"];
for k = 1:numel(required_group_fields)
    if ~hasColumn(T, required_group_fields(k))
        error("Missing required field: %s", required_group_fields(k));
    end
end

scenario_id = getStringColumn(T, "scenario_id");
scenario_name = getStringColumn(T, "scenario_name");
wifi_config = getStringColumn(T, "wifi_config");
run_id = getStringColumn(T, "run_id");
time_s = getNumericColumn(T, "time_s");

[G, group_scenario, group_config, group_run] = findgroups(scenario_id, wifi_config, run_id);
n_groups = max(G);

var_names = ["scenario_id", "scenario_name", "wifi_config", "run_id", ...
    "steady_window", "delay_threshold_ms", "N_expected", "N_good", ...
    "N_bad_delay", "N_lost", "negative_delay_count", "CDR_75ms", ...
    "status", "lost_count_method"];
var_types = ["string", "string", "string", "string", ...
    "string", "double", "double", "double", ...
    "double", "double", "double", "double", ...
    "string", "string"];
Summary = table("Size", [n_groups, numel(var_names)], ...
    "VariableTypes", var_types, "VariableNames", var_names);

for g = 1:n_groups
    idx_group = G == g;
    idx_steady = idx_group & time_s >= steady_start_s;
    S = T(idx_steady, :);

    Summary.scenario_id(g) = group_scenario(g);
    Summary.wifi_config(g) = group_config(g);
    Summary.run_id(g) = group_run(g);
    Summary.delay_threshold_ms(g) = delay_threshold_ms;
    Summary.steady_window(g) = "time_s >= " + string(steady_start_s);
    Summary.scenario_name(g) = firstNonmissing(scenario_name(idx_group));

    if height(S) == 0
        Summary.N_expected(g) = 0;
        Summary.N_good(g) = 0;
        Summary.N_bad_delay(g) = 0;
        Summary.N_lost(g) = 0;
        Summary.negative_delay_count(g) = 0;
        Summary.CDR_75ms(g) = NaN;
        Summary.status(g) = "no_steady_samples";
        Summary.lost_count_method(g) = "not_available";
        continue;
    end

    delay_ms = getNumericColumn(S, "control_delay_ms");
    received = getFlagColumn(S, "control_received");
    if all(isnan(received))
        received = inferReceived(S, delay_ms);
    end

    expected = getFlagColumn(S, "control_expected");
    packet_id = getStringColumn(S, "control_packet_id");
    packet_id_valid = packet_id(~ismissing(packet_id) & strlength(strtrim(packet_id)) > 0);

    if ~all(isnan(expected))
        N_expected = sum(expected == 1);
    elseif ~isempty(packet_id_valid)
        N_expected = numel(unique(packet_id_valid));
    else
        N_expected = NaN;
    end

    valid_delay = ~isnan(delay_ms);
    valid_timestamp = valid_delay & delay_ms >= 0;
    N_good = sum(received == 1 & valid_timestamp & delay_ms < delay_threshold_ms);
    N_bad_delay = sum(received == 1 & valid_timestamp & delay_ms >= delay_threshold_ms);
    negative_delay_count = sum(received == 1 & valid_delay & delay_ms < 0);

    lost = getFlagColumn(S, "control_lost");
    if ~all(isnan(lost))
        N_lost = sum(lost == 1);
        lost_count_method = "observed";
    elseif ~isnan(N_expected)
        received_valid_count = sum(received == 1 & valid_timestamp);
        N_lost = max(N_expected - received_valid_count, 0);
        lost_count_method = "inferred";
    else
        N_lost = NaN;
        lost_count_method = "missing_expected_count";
    end

    if isnan(N_expected) || N_expected <= 0
        cdr75 = NaN;
        status = "missing_expected_count";
    else
        cdr75 = N_good / N_expected;
        if negative_delay_count > 0
            status = "ok_with_invalid_timestamp";
        else
            status = "ok";
        end
    end

    Summary.N_expected(g) = N_expected;
    Summary.N_good(g) = N_good;
    Summary.N_bad_delay(g) = N_bad_delay;
    Summary.N_lost(g) = N_lost;
    Summary.negative_delay_count(g) = negative_delay_count;
    Summary.CDR_75ms(g) = cdr75;
    Summary.status(g) = status;
    Summary.lost_count_method(g) = lost_count_method;
end

TableOut = Summary;
writetable(Summary, summary_file);
writetable(TableOut, table_file);

fprintf("Wrote %s\n", summary_file);
fprintf("Wrote %s\n", table_file);

function tf = hasColumn(T, name)
tf = any(strcmp(T.Properties.VariableNames, char(name)));
end

function values = getStringColumn(T, name)
if hasColumn(T, name)
    values = string(T.(char(name)));
else
    values = strings(height(T), 1);
    values(:) = missing;
end
end

function values = getNumericColumn(T, name)
if ~hasColumn(T, name)
    values = NaN(height(T), 1);
    return;
end

raw = T.(char(name));
if isnumeric(raw) || islogical(raw)
    values = double(raw);
else
    values = str2double(string(raw));
end
values = values(:);
end

function values = getFlagColumn(T, name)
if ~hasColumn(T, name)
    values = NaN(height(T), 1);
    return;
end

raw = T.(char(name));
if islogical(raw)
    values = double(raw(:));
elseif isnumeric(raw)
    raw_double = double(raw(:));
    values = double(raw_double ~= 0);
    values(isnan(raw_double)) = NaN;
else
    text = lower(strtrim(string(raw)));
    values = NaN(numel(text), 1);
    values(ismember(text, ["1", "true", "yes", "y"])) = 1;
    values(ismember(text, ["0", "false", "no", "n"])) = 0;
    values(ismissing(text) | text == "") = NaN;
end
end

function received = inferReceived(T, delay_ms)
received = double(~isnan(delay_ms));
if hasColumn(T, "control_receive_time_s")
    receive_time_s = getNumericColumn(T, "control_receive_time_s");
    received = double(received == 1 | ~isnan(receive_time_s));
end
end

function value = firstNonmissing(values)
idx = find(~ismissing(values) & strlength(strtrim(values)) > 0, 1, "first");
if isempty(idx)
    value = missing;
else
    value = values(idx);
end
end
