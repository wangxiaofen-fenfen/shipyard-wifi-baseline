# Laboratory Wi-Fi5 Test Plan Draft

## Purpose

Run a small Wi-Fi5 pilot measurement at Laboratory.

## Equipment

- 2 computers
- Wi-Fi5 AP

## Software

- iPerf3
- ping
- PTP can be added later

## Scenarios

- S1: short-distance LoS
- S2: medium-distance LoS
- S3: obstructed / NLoS
- S4: mixed

## Wi-Fi Configurations

- ac/5/80
- ac/5/20
- n/2.4/20

## Measurement Plan

- Recommended duration: 180 seconds per run.
- Mark the first 120 seconds as startup.
- Compare only against the Perama Wi-Fi5 subset.
- Do not claim full Wi-Fi6 reproduction.

## CDR_75ms Workflow

- Definition: `docs/laboratory_raw_log_cdr_definition.md`
- MATLAB template: `matlab/laboratory_wifi5_pilot/compute_laboratory_cdr75_from_raw_log.m`
- Data template: `data/templates/laboratory_wifi5_pilot_template.csv`
