%% C02 Wi-Fi CDR_75ms reproduction display version
% Formal MATLAB display of C02 literature measurement CDR_75ms results.
% This is not MANET simulation and not packet-level Wi-Fi PHY simulation.

clear;
clc;

data_file = "shipyard_network_unified_dataset_checked.xlsx";
cdr_threshold = 0.90;

script_dir = string(fileparts(mfilename("fullpath")));
if strlength(script_dir) == 0
    script_dir = string(pwd);
end

project_root = locateProjectRoot(data_file);
data_path = fullfile(project_root, data_file);

preferred_sheet = "2_C02_WiFi真实";
fallback_sheet = "1_总表_Unified";
sheet_list = string(sheetnames(data_path));

if any(sheet_list == preferred_sheet)
    selected_sheet = preferred_sheet;
elseif any(sheet_list == fallback_sheet)
    selected_sheet = fallback_sheet;
else
    error("Neither required sheet exists. Missing '%s' and fallback '%s'.", preferred_sheet, fallback_sheet);
end

raw = readtable(data_path, ...
    "Sheet", selected_sheet, ...
    "VariableNamingRule", "preserve", ...
    "TextType", "string");

required_columns = [
    "data_group"
    "technology"
    "source_type"
    "unified_scenario"
    "scenario_name"
    "distance_m"
    "los_condition"
    "protocol_or_config"
    "wifi_generation"
    "rf_band_GHz"
    "bandwidth_MHz"
    "CDR_75ms"
    "best_for_reliability"
];

raw = normalizeInputAliases(raw);
missing_columns = setdiff(required_columns, string(raw.Properties.VariableNames), "stable");
if ~isempty(missing_columns) && selected_sheet == preferred_sheet && any(sheet_list == fallback_sheet)
    selected_sheet = fallback_sheet;
    raw = readtable(data_path, ...
        "Sheet", selected_sheet, ...
        "VariableNamingRule", "preserve", ...
        "TextType", "string");
    raw = normalizeInputAliases(raw);
    missing_columns = setdiff(required_columns, string(raw.Properties.VariableNames), "stable");
end

if ~isempty(missing_columns)
    error("Missing required column(s): %s", strjoin(missing_columns, ", "));
end

data_group = asStringColumn(raw.(char("data_group")));
technology = asStringColumn(raw.(char("technology")));
source_type = asStringColumn(raw.(char("source_type")));

is_c02_wifi = strcmpi(data_group, "D1") ...
    & strcmpi(technology, "Wi-Fi") ...
    & strcmpi(source_type, "literature_measurement");

keep_columns = [
    "unified_scenario"
    "scenario_name"
    "distance_m"
    "los_condition"
    "protocol_or_config"
    "wifi_generation"
    "rf_band_GHz"
    "bandwidth_MHz"
    "CDR_75ms"
    "best_for_reliability"
];

cleaned = raw(is_c02_wifi, cellstr(keep_columns));

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

scenario = normalizeScenarioCodes(cleaned.(char("unified_scenario")));
cleaned.(char("unified_scenario")) = scenario;

cdr_raw = toNumericColumn(cleaned.(char("CDR_75ms")), "CDR_75ms");
percent_style_mask = cdr_raw > 1 & cdr_raw <= 100;
cdr = cdr_raw;
cdr(percent_style_mask) = cdr(percent_style_mask) ./ 100;
cleaned.(char("CDR_75ms")) = cdr;

config_label = buildConfigLabels(cleaned);

if height(cleaned) ~= 36
    error("Expected 36 C02 Wi-Fi rows, found %d.", height(cleaned));
end

if any(isnan(cdr))
    error("CDR_75ms contains NaN or non-numeric values after conversion.");
end

if any(cdr < 0 | cdr > 1)
    bad_values = cdr(cdr < 0 | cdr > 1);
    error("CDR_75ms must be in [0, 1] after conversion. Bad value example: %.6g", bad_values(1));
end

unique_scenarios = unique(scenario, "stable");
missing_scenarios = setdiff(scenario_order, unique_scenarios, "stable");
extra_scenarios = setdiff(unique_scenarios, scenario_order, "stable");
if numel(unique_scenarios) ~= 4 || ~isempty(missing_scenarios) || ~isempty(extra_scenarios)
    error("Expected scenarios S1,S2,S3,S4. Found: %s", strjoin(unique_scenarios, ", "));
end

unique_configs = unique(config_label, "stable");
missing_configs = setdiff(config_order, unique_configs, "stable");
extra_configs = setdiff(unique_configs, config_order, "stable");
if numel(unique_configs) ~= 9 || ~isempty(missing_configs) || ~isempty(extra_configs)
    error("Expected 9 Wi-Fi configs. Found: %s", strjoin(unique_configs, ", "));
end

[~, scenario_idx] = ismember(scenario, scenario_order);
[~, config_idx] = ismember(config_label, config_order);
if any(scenario_idx == 0) || any(config_idx == 0)
    error("Scenario or Wi-Fi config could not be mapped to the required ordering.");
end

row_keys = scenario + "|" + config_label;
if numel(unique(row_keys)) ~= height(cleaned)
    error("Duplicate scenario/config rows found. Each S1-S4 and Wi-Fi config pair must appear exactly once.");
end

[~, sort_idx] = sortrows([scenario_idx(:), config_idx(:)], [1 2]);
cleaned = cleaned(sort_idx, :);
scenario = scenario(sort_idx);
config_label = config_label(sort_idx);
cdr = cdr(sort_idx);
cleaned.(char("protocol_or_config")) = config_label;

cdr_matrix = NaN(numel(config_order), numel(scenario_order));
for i = 1:height(cleaned)
    row = find(config_order == config_label(i), 1);
    col = find(scenario_order == scenario(i), 1);
    cdr_matrix(row, col) = cdr(i);
end

if any(isnan(cdr_matrix(:)))
    error("CDR_75ms matrix is incomplete; at least one scenario/config pair is missing.");
end

passfail_matrix = double(cdr_matrix >= cdr_threshold);

scenario_map = buildScenarioMap(cleaned, scenario_order);
best_table = buildBestConfigTable(cleaned, scenario_order, config_order, cdr_matrix);
threshold_table = buildThresholdDecisionTable(cleaned, cdr_threshold);

acceptable_links = sum(threshold_table.fallback_needed == "no");
fallback_needed_cases = sum(threshold_table.fallback_needed == "yes");

results_dir = fullfile(script_dir, "results");
if ~isfolder(results_dir)
    mkdir(results_dir);
end

cleaned_out = fullfile(results_dir, "c02_cdr75_cleaned_36rows.csv");
best_out = fullfile(results_dir, "c02_cdr75_best_config.csv");
threshold_out = fullfile(results_dir, "c02_cdr75_threshold_decision.csv");
report_out = fullfile(results_dir, "c02_cdr75_reproduction_report.md");

writetable(cleaned, cleaned_out);
writetable(best_table, best_out);
writetable(threshold_table, threshold_out);

heatmap_png = fullfile(results_dir, "fig_c02_cdr75_heatmap.png");
heatmap_fig = fullfile(results_dir, "fig_c02_cdr75_heatmap.fig");
plotCdrHeatmap(scenario_order, config_order, cdr_matrix, heatmap_png, heatmap_fig);

bar_png = fullfile(results_dir, "fig_c02_cdr75_best_config_bar.png");
bar_fig = fullfile(results_dir, "fig_c02_cdr75_best_config_bar.fig");
plotBestConfigBar(best_table, bar_png, bar_fig);

passfail_png = fullfile(results_dir, "fig_c02_cdr75_threshold_passfail.png");
passfail_fig = fullfile(results_dir, "fig_c02_cdr75_threshold_passfail.fig");
plotThresholdPassFailHeatmap(scenario_order, config_order, passfail_matrix, passfail_png, passfail_fig);

writeMarkdownReport(report_out, scenario_map, best_table, threshold_table, ...
    height(cleaned), numel(scenario_order), numel(config_order), cdr_threshold, ...
    acceptable_links, fallback_needed_cases, selected_sheet, data_file);

fprintf("\nC02 Wi-Fi CDR_75ms reproduction display summary\n");
fprintf("Data source: C02 Rady 2024 real shipyard Wi-Fi measurement\n");
fprintf("Experiment type: MATLAB reproduction, not Wi-Fi PHY simulation\n");
fprintf("Input file: %s\n", data_path);
fprintf("Sheet used: %s\n", selected_sheet);
fprintf("Total records: %d\n", height(cleaned));
fprintf("Number of scenarios: %d\n", numel(scenario_order));
fprintf("Number of Wi-Fi configurations: %d\n", numel(config_order));
fprintf("CDR threshold: %.2f\n", cdr_threshold);
fprintf("Percent-style CDR values converted: %d\n", nnz(percent_style_mask));
fprintf("\nBest config per scenario:\n");
disp(best_table);
fprintf("Number of acceptable links: %d\n", acceptable_links);
fprintf("Number of fallback-needed cases: %d\n", fallback_needed_cases);
fprintf("\nSaved results folder: %s\n", results_dir);
fprintf("Saved report: %s\n\n", report_out);

function project_root = locateProjectRoot(data_file)
    current_dir = string(pwd);
    project_root = "";

    for depth = 0:3
        candidate = current_dir;
        for k = 1:depth
            candidate = string(fileparts(char(candidate)));
        end

        if isfile(fullfile(candidate, data_file))
            project_root = candidate;
            break;
        end
    end

    if strlength(project_root) == 0
        error("Cannot find shipyard_network_unified_dataset_checked.xlsx. Please place it in the project root.");
    end
end

function T = normalizeInputAliases(T)
    names = string(T.Properties.VariableNames);

    if ~any(names == "best_for_reliability") && any(names == "best_for_reliability_CDR")
        T.(char("best_for_reliability")) = T.(char("best_for_reliability_CDR"));
    end
end

function s = asStringColumn(x)
    if iscell(x)
        s = strings(numel(x), 1);
        for k = 1:numel(x)
            value = x{k};
            if isempty(value)
                s(k) = "";
            elseif isstring(value) || ischar(value)
                s(k) = string(value);
            elseif isnumeric(value) || islogical(value)
                s(k) = string(value);
            elseif iscategorical(value)
                s(k) = string(value);
            else
                s(k) = string(value);
            end
        end
    else
        s = string(x);
        s = s(:);
    end
    s = strtrim(s);
end

function scenario = normalizeScenarioCodes(x)
    raw = upper(regexprep(asStringColumn(x), "\s+", ""));
    scenario = strings(numel(raw), 1);

    for k = 1:numel(raw)
        token = regexp(char(raw(k)), "S([1-4])", "tokens", "once");
        if isempty(token)
            scenario(k) = raw(k);
        else
            scenario(k) = "S" + string(token{1});
        end
    end
end

function values = toNumericColumn(x, column_name)
    if isnumeric(x) || islogical(x)
        values = double(x);
        values = values(:);
        return;
    end

    text_values = asStringColumn(x);
    text_values = erase(text_values, "%");
    text_values = erase(text_values, ",");
    values = str2double(text_values);

    missing_mask = ismissing(text_values) | strlength(text_values) == 0;
    bad_mask = isnan(values) & ~missing_mask;
    if any(bad_mask)
        bad_text = text_values(find(bad_mask, 1));
        error("Column %s contains a non-numeric value: %s", column_name, bad_text);
    end
end

function values = toOptionalNumericColumn(x)
    if isnumeric(x) || islogical(x)
        values = double(x);
        values = values(:);
        return;
    end

    text_values = asStringColumn(x);
    values = NaN(numel(text_values), 1);
    for k = 1:numel(text_values)
        token = regexp(char(text_values(k)), "[-+]?\d+(\.\d+)?", "match", "once");
        if ~isempty(token)
            values(k) = str2double(token);
        end
    end
end

function labels = buildConfigLabels(T)
    protocol = asStringColumn(T.(char("protocol_or_config")));
    generation = asStringColumn(T.(char("wifi_generation")));
    band_values = toOptionalNumericColumn(T.(char("rf_band_GHz")));
    bandwidth_values = toOptionalNumericColumn(T.(char("bandwidth_MHz")));

    labels = strings(height(T), 1);
    for k = 1:height(T)
        direct_label = normalizeDirectConfig(protocol(k));
        if strlength(direct_label) > 0
            labels(k) = direct_label;
            continue;
        end

        gen = extractGeneration(protocol(k), generation(k));
        band = band_values(k);
        bandwidth = bandwidth_values(k);

        if isnan(band)
            band = extractBandGHz(protocol(k));
        end
        if isnan(bandwidth)
            bandwidth = extractBandwidthMHz(protocol(k));
        end

        if strlength(gen) == 0 || isnan(band) || isnan(bandwidth)
            error("Could not derive Wi-Fi config for row %d from protocol_or_config='%s'.", k, protocol(k));
        end

        labels(k) = gen + "/" + formatBandGHz(band) + "/" + string(round(bandwidth));
    end
end

function label = normalizeDirectConfig(text_value)
    label = "";
    compact = lower(strtrim(string(text_value)));
    compact = regexprep(compact, "\s+", "");
    compact = replace(compact, "_", "/");
    compact = replace(compact, "-", "/");

    tokens = regexp(char(compact), "^(ax|ac|n)/(2\.4|24|5|6)/(20|80|160)$", "tokens", "once");
    if ~isempty(tokens)
        band = string(tokens{2});
        if band == "24"
            band = "2.4";
        end
        label = string(tokens{1}) + "/" + band + "/" + string(tokens{3});
    end
end

function gen = extractGeneration(protocol_text, generation_text)
    combined = lower(strtrim(string(protocol_text) + " " + string(generation_text)));
    gen_text = lower(strtrim(string(generation_text)));

    if contains(combined, "ax") || ismember(gen_text, ["6", "6e", "wifi 6", "wi-fi 6", "wifi 6e", "wi-fi 6e", "802.11ax"])
        gen = "ax";
    elseif contains(combined, "ac") || ismember(gen_text, ["5", "wifi 5", "wi-fi 5", "802.11ac"])
        gen = "ac";
    elseif contains(combined, "802.11n") || contains(combined, "wi-fi 4") || contains(combined, "wifi 4") ...
            || ~isempty(regexp(char(combined), "(^|[^a-z])n([^a-z]|$)", "once"))
        gen = "n";
    else
        gen = "";
    end
end

function band = extractBandGHz(text_value)
    text_value = lower(string(text_value));
    if ~isempty(regexp(char(text_value), "(^|[^0-9.])(2\.4|24)\s*g?hz", "once")) || startsWith(text_value, "2.4")
        band = 2.4;
    elseif ~isempty(regexp(char(text_value), "(^|[^0-9.])6\s*g?hz", "once"))
        band = 6;
    elseif ~isempty(regexp(char(text_value), "(^|[^0-9.])5\s*g?hz", "once"))
        band = 5;
    else
        band = NaN;
    end
end

function bandwidth = extractBandwidthMHz(text_value)
    tokens = regexp(char(lower(string(text_value))), "(160|80|20)\s*mhz", "tokens", "once");
    if isempty(tokens)
        bandwidth = NaN;
    else
        bandwidth = str2double(tokens{1});
    end
end

function band_text = formatBandGHz(band)
    if abs(band - 2.4) < 0.15 || abs(band - 24) < 0.15
        band_text = "2.4";
    elseif abs(band - 5) < 0.15
        band_text = "5";
    elseif abs(band - 6) < 0.15
        band_text = "6";
    else
        error("Unsupported Wi-Fi RF band: %.6g GHz", band);
    end
end

function scenario_map = buildScenarioMap(cleaned, scenario_order)
    scenario_name = strings(numel(scenario_order), 1);
    distance_m = strings(numel(scenario_order), 1);
    los_condition = strings(numel(scenario_order), 1);

    for s = 1:numel(scenario_order)
        idx = find(cleaned.(char("unified_scenario")) == scenario_order(s), 1);
        scenario_name(s) = asStringColumn(cleaned.(char("scenario_name"))(idx));
        distance_m(s) = asStringColumn(cleaned.(char("distance_m"))(idx));
        los_condition(s) = asStringColumn(cleaned.(char("los_condition"))(idx));
    end

    unified_scenario = scenario_order(:);
    scenario_map = table(unified_scenario, scenario_name, distance_m, los_condition);
end

function best_table = buildBestConfigTable(cleaned, scenario_order, config_order, cdr_matrix)
    unified_scenario = scenario_order(:);
    scenario_name = strings(numel(scenario_order), 1);
    best_config_by_CDR = strings(numel(scenario_order), 1);
    best_CDR_75ms = zeros(numel(scenario_order), 1);
    distance_m = strings(numel(scenario_order), 1);
    los_condition = strings(numel(scenario_order), 1);

    for s = 1:numel(scenario_order)
        scenario_idx = find(cleaned.(char("unified_scenario")) == scenario_order(s), 1);
        scenario_name(s) = asStringColumn(cleaned.(char("scenario_name"))(scenario_idx));
        distance_m(s) = asStringColumn(cleaned.(char("distance_m"))(scenario_idx));
        los_condition(s) = asStringColumn(cleaned.(char("los_condition"))(scenario_idx));

        values = cdr_matrix(:, s);
        best_value = max(values);
        best_config_by_CDR(s) = strjoin(config_order(values == best_value), "; ");
        best_CDR_75ms(s) = best_value;
    end

    best_table = table(unified_scenario, scenario_name, best_config_by_CDR, ...
        best_CDR_75ms, distance_m, los_condition);
end

function threshold_table = buildThresholdDecisionTable(cleaned, cdr_threshold)
    unified_scenario = asStringColumn(cleaned.(char("unified_scenario")));
    protocol_or_config = asStringColumn(cleaned.(char("protocol_or_config")));
    CDR_75ms = cleaned.(char("CDR_75ms"));
    cdr_threshold_col = repmat(cdr_threshold, height(cleaned), 1);

    is_acceptable = CDR_75ms >= cdr_threshold;
    wifi_status = strings(height(cleaned), 1);
    fallback_needed = strings(height(cleaned), 1);
    wifi_status(is_acceptable) = "acceptable";
    wifi_status(~is_acceptable) = "not_acceptable";
    fallback_needed(is_acceptable) = "no";
    fallback_needed(~is_acceptable) = "yes";

    threshold_table = table(unified_scenario, protocol_or_config, CDR_75ms, ...
        cdr_threshold_col, wifi_status, fallback_needed, ...
        'VariableNames', {'unified_scenario', 'protocol_or_config', 'CDR_75ms', ...
        'cdr_threshold', 'wifi_status', 'fallback_needed'});
end

function plotCdrHeatmap(scenario_order, config_order, cdr_matrix, png_path, fig_path)
    fig = figure("Visible", "off", "Color", "w", "Position", [100 100 980 620]);
    h = heatmap(scenario_order, config_order, cdr_matrix);
    h.Title = "C02 Wi-Fi Real Measurement: CDR_75ms Reproduction";
    h.XLabel = "Scenario";
    h.YLabel = "Wi-Fi configuration";
    h.CellLabelFormat = "%.3f";
    h.ColorLimits = [0 1];
    h.Colormap = parula(256);
    savefig(fig, fig_path);
    exportgraphics(fig, png_path, "Resolution", 300);
    close(fig);
end

function plotBestConfigBar(best_table, png_path, fig_path)
    fig = figure("Visible", "off", "Color", "w", "Position", [100 100 900 560]);
    values = best_table.best_CDR_75ms;
    x = categorical(best_table.unified_scenario);
    x = reordercats(x, cellstr(best_table.unified_scenario));

    bar(x, values, 0.62, "FaceColor", [0.12 0.42 0.64]);
    ylim([0 1]);
    grid on;
    ylabel("best_CDR_75ms");
    xlabel("Scenario");
    title("Best Wi-Fi Configuration by CDR_75ms");

    for k = 1:numel(values)
        text(k, min(values(k) + 0.025, 0.98), best_table.best_config_by_CDR(k), ...
            "HorizontalAlignment", "center", ...
            "VerticalAlignment", "bottom", ...
            "FontSize", 9, ...
            "Interpreter", "none");
    end

    savefig(fig, fig_path);
    exportgraphics(fig, png_path, "Resolution", 300);
    close(fig);
end

function plotThresholdPassFailHeatmap(scenario_order, config_order, passfail_matrix, png_path, fig_path)
    fig = figure("Visible", "off", "Color", "w", "Position", [100 100 980 620]);
    h = heatmap(scenario_order, config_order, passfail_matrix);
    h.Title = "Wi-Fi Control Link Acceptability under CDR_75ms >= 0.90";
    h.XLabel = "Scenario";
    h.YLabel = "Wi-Fi configuration";
    h.CellLabelFormat = "%.0f";
    h.ColorLimits = [0 1];
    h.Colormap = [0.82 0.22 0.20; 0.14 0.55 0.31];
    savefig(fig, fig_path);
    exportgraphics(fig, png_path, "Resolution", 300);
    close(fig);
end

function writeMarkdownReport(report_out, scenario_map, best_table, threshold_table, ...
    total_records, scenario_count, config_count, cdr_threshold, acceptable_links, ...
    fallback_needed_cases, selected_sheet, data_file)

    unified_scenario = scenario_map.unified_scenario;
    acceptable_count = zeros(height(scenario_map), 1);
    fallback_needed_count = zeros(height(scenario_map), 1);
    for k = 1:height(scenario_map)
        mask = threshold_table.unified_scenario == unified_scenario(k);
        acceptable_count(k) = sum(threshold_table.fallback_needed(mask) == "no");
        fallback_needed_count(k) = sum(threshold_table.fallback_needed(mask) == "yes");
    end
    threshold_summary = table(unified_scenario, acceptable_count, fallback_needed_count);

    lines = [
        "# C02 Wi-Fi CDR_75ms Reproduction Report"
        ""
        "## Purpose"
        "Reproduce and display the C02 Wi-Fi control delivery ratio under the 75 ms threshold using MATLAB."
        ""
        "## Data source"
        "- Data source: C02 Rady 2024 real shipyard Wi-Fi measurement"
        "- Input workbook: `" + data_file + "`"
        "- Sheet used: `" + selected_sheet + "`"
        "- Experiment type: MATLAB reproduction, not Wi-Fi PHY simulation"
        ""
        "## Scenario mapping S1-S4"
        tableToMarkdown(scenario_map)
        ""
        "## CDR_75ms definition"
        "`CDR_75ms` is the ratio of valid control-link measurement samples with control delay less than or equal to 75 ms."
        ""
        "## Validation checks"
        "- Total records: " + string(total_records) + " (required: 36)"
        "- Number of scenarios: " + string(scenario_count) + " (required: S1, S2, S3, S4)"
        "- Number of Wi-Fi configurations: " + string(config_count) + " (required: 9)"
        "- CDR_75ms range: validated in [0, 1] after automatic percent-to-ratio conversion"
        "- CDR threshold: " + sprintf("%.2f", cdr_threshold)
        ""
        "## Best configuration result"
        tableToMarkdown(best_table)
        ""
        "## Threshold decision result"
        "- Rule: CDR_75ms >= " + sprintf("%.2f", cdr_threshold) + " is acceptable; otherwise fallback_candidate_needed."
        "- Number of acceptable links: " + string(acceptable_links)
        "- Number of fallback-needed cases: " + string(fallback_needed_cases)
        ""
        tableToMarkdown(threshold_summary)
        ""
        "## Important note"
        "This is a MATLAB reproduction of literature measurement data, not a packet-level Wi-Fi 6 PHY simulation."
        ""
        "## Generated artifacts"
        "- `c02_cdr75_cleaned_36rows.csv`"
        "- `c02_cdr75_best_config.csv`"
        "- `c02_cdr75_threshold_decision.csv`"
        "- `fig_c02_cdr75_heatmap.png` and `.fig`"
        "- `fig_c02_cdr75_best_config_bar.png` and `.fig`"
        "- `fig_c02_cdr75_threshold_passfail.png` and `.fig`"
    ];

    writelines(lines, report_out);
end

function md = tableToMarkdown(T)
    names = string(T.Properties.VariableNames);
    md = strings(height(T) + 2, 1);
    md(1) = "| " + strjoin(names, " | ") + " |";
    md(2) = "| " + strjoin(repmat("---", 1, numel(names)), " | ") + " |";

    for r = 1:height(T)
        row_values = strings(1, numel(names));
        for c = 1:numel(names)
            column = T.(char(names(c)));
            row_values(c) = markdownCell(column(r));
        end
        md(r + 2) = "| " + strjoin(row_values, " | ") + " |";
    end
end

function text_value = markdownCell(value)
    if iscell(value)
        if isempty(value{1})
            text_value = "";
        else
            text_value = string(value{1});
        end
    elseif isnumeric(value) || islogical(value)
        text_value = string(sprintf("%.6g", double(value)));
    elseif iscategorical(value)
        text_value = string(value);
    else
        text_value = string(value);
    end

    text_value = replace(text_value, "|", "\|");
    text_value = replace(text_value, newline, " ");
end
