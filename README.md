# SolarConnect Home Assistant Add-on

## Description
SolarConnect is a Home Assistant add-on that integrates your Sunsynk Connect account, allowing you to monitor and control your Sunsynk inverter within Home Assistant.

## Requirements
- MQTT must be installed and configured.
- A Sunsynk Connect account with an active inverter.

## Installation
1. Install and configure an MQTT broker in Home Assistant.
2. Add the SolarConnect add-on repository to Home Assistant.
3. Install the SolarConnect add-on from the Add-on Store.
4. Configure the add-on options as required.

## Configuration
To configure the add-on, navigate to the add-on settings and update the following options:

```yaml
mqtt_broker: "127.0.0.1"  # Replace with your MQTT broker address
mqtt_port: 1883  # Change if using a non-default MQTT port
mqtt_username: "your_mqtt_user"
mqtt_password: "your_mqtt_password"
sunsynk_username: "your_sunsynk_username"
sunsynk_password: "your_sunsynk_password"
sunsynk_inverter_serial: "your_inverter_serial"
enable_https: false  # Set to true if using HTTPS
```