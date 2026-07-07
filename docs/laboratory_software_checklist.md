# Laboratory Wi-Fi5 Software Checklist

## Required software

| software | required_on | purpose | check_command | install_command |
| --- | --- | --- | --- | --- |
| Homebrew | both computers | macOS package manager for command-line tools | `brew --version` | Install from https://brew.sh/ |
| iPerf3 | both computers | throughput smoke test and pilot throughput logging | `iperf3 --version` | `brew install iperf3` |
| Python 3 | analysis computer; optional on sender/receiver if parsing locally | data parsing and lightweight validation | `python3 --version` | `brew install python` |
| pip3 | analysis computer | Python package management | `pip3 --version` | Included with most Python 3 installs |
| pandas | analysis computer | tabular data processing | `python3 -c "import pandas; print(pandas.__version__)"` | `pip3 install pandas` |
| numpy | analysis computer | numeric processing | `python3 -c "import numpy; print(numpy.__version__)"` | `pip3 install numpy` |
| MATLAB | analysis computer | run MATLAB templates and analysis scripts | `matlab -batch "disp(version)"` | Install from MathWorks |
| Git | analysis computer | version control for the public workflow repository | `git --version` | `brew install git` |
| ping | both computers | connectivity check between laptops | `ping -c 10 <COMPUTER_A_IP>` | Included with macOS |
| Wi-Fi RSSI checking method | both computers | record RSSI, noise, channel, PHY mode, and Tx rate | Option-click Wi-Fi icon | Included with macOS |

## Optional software

| software | purpose |
| --- | --- |
| VS Code | edit notes, scripts, and CSV templates |
| Wireshark | optional packet-level inspection during debugging |

## Mac check commands

Run these checks before the Laboratory Wi-Fi5 pilot test:

```bash
brew --version
iperf3 --version
python3 --version
pip3 --version
pip3 install pandas numpy
python3 -c "import pandas, numpy; print('pandas', pandas.__version__); print('numpy', numpy.__version__)"
matlab -batch "disp(version)"
git --version
ipconfig getifaddr en0
ipconfig getifaddr en1
networksetup -getairportnetwork en0
networksetup -getairportnetwork en1
```

The `pip3 install pandas numpy` command is listed as a preparation command. The repository check script does not install software.

## Two-laptop connectivity check

Computer A = server / receiver.

Computer B = client / sender.

On Computer A, check the Wi-Fi IP address:

```bash
ipconfig getifaddr en0
```

On Computer B, ping Computer A:

```bash
ping -c 10 <COMPUTER_A_IP>
```

Pass criterion:

```text
10 packets transmitted, 10 packets received, 0.0% packet loss
```

## iPerf3 smoke test

On Computer A:

```bash
iperf3 -s
```

On Computer B:

```bash
iperf3 -c <COMPUTER_A_IP> -t 10 -i 1
```

Pass criterion:

The client output shows Mbps or Mbits/sec throughput values.

## RSSI check

On macOS:

1. Hold the Option key.
2. Click the Wi-Fi icon in the menu bar.
3. Record RSSI, Noise, Channel, PHY Mode, and Tx Rate.

## Pass criteria

- iPerf3 works on both computers
- Python3 works on both computers
- pandas/numpy import successfully
- computers can ping each other
- iPerf3 client can connect to server
- RSSI/channel can be recorded
- MATLAB runs on analysis computer
- Git works on analysis computer
