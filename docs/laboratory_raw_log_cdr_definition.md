# Laboratory Raw-Log CDR_75ms Definition

## Purpose

This document defines the raw-log CDR_75ms calculation for future laboratory Wi-Fi measurements.

## Core Formula

```text
CDR_75ms = N_good / N_expected
```

## Definitions

`N_expected`:
number of expected control packets in the selected steady-state window.

`N_good`:
number of received control packets with valid `delay_ms` and `delay_ms < 75`.

`N_bad_delay`:
number of received control packets with `delay_ms >= 75`.

`N_lost`:
number of expected packets not received.

Relationship:

```text
N_expected = N_good + N_bad_delay + N_lost
```

## Negative Delay

If `delay_ms < 0`, mark the packet as `invalid_timestamp`.

Do not count negative-delay packets as `N_good`.

Report negative-delay count separately.

Do not silently correct negative delay to zero.

## Missing Values

Do not impute missing values.

Do not replace `steady_mean` with `all_mean`.

Do not delete missing rows.

Keep missing rows with explicit status labels.

## Steady Window

Default steady-state window:

```text
time_s >= 120
```

For 180-second experiments:

```text
steady window = [120,180]
```

## Perama Comparison

The Perama baseline uses the published Table 2 values for CDR_75ms because no official Table 2 exporter was found in the author's repository.

Laboratory experiments must compute CDR_75ms from raw control logs using the explicit formula above.
