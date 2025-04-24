#!/usr/bin/with-contenv bashio

set +e
while :
do

    ########## Configuration ##########

    # Output debug information
    # Current time and date
    echo "Current time and date: $(date)"

    ##########
    # MQTT
    ##########

    MQTT_BROKER=$(bashio::config "mqtt_broker")
    MQTT_PORT=$(bashio::config "mqtt_port")
    MQTT_USERNAME=$(bashio::config "mqtt_username")
    MQTT_PASSWORD=$(bashio::config "mqtt_password")

    # MQTT
    echo "MQTT Broker: ${MQTT_BROKER}"
    echo "MQTT Port: ${MQTT_PORT}"
    echo "MQTT Username: ${MQTT_USERNAME}"
    echo "MQTT Password: ${MQTT_PASSWORD}"

    # Check if the MQTT Broker is set
    if [ -z "${MQTT_BROKER}" ]; then
        echo "MQTT Broker is not set"
        exit 1
    fi

    ##########
    # Sunsynk Connect
    ##########

    SUNSYNK_USERNAME=$(bashio::config 'sunsynk_username')
    SUNSYNK_PASSWORD=$(bashio::config 'sunsynk_password')
    SUNSYNK_INVERTER_SERIAL=$(bashio::config 'sunsynk_inverter_serial')

    # Sunsynk Connect
    echo "Sunsynk Username: ${SUNSYNK_USERNAME}"
    echo "Sunsynk Password: ${SUNSYNK_PASSWORD}"
    echo "Sunsynk Inverter Serial: ${SUNSYNK_INVERTER_SERIAL}"

    # Check if the Sunsynk Username is set
    if [ -z "${SUNSYNK_USERNAME}" ]; then
        echo "Sunsynk Username is not set"
        exit 1
    fi

    # Check if the Sunsynk Inverter Serial is set
    if [ -z "${SUNSYNK_INVERTER_SERIAL}" ]; then
        echo "Sunsynk Inverter Serial is not set"
        exit 1
    fi

    ##########
    # Home Assistant
    ##########

    ENABLE_HTTPS=$(bashio::config 'enable_https')

    if [ "${ENABLE_HTTPS}" == "true" ]; then
        HOME_ASSISTANT_PROTOCOL="https"
    else
        HOME_ASSISTANT_PROTOCOL="http"
    fi

    # Home Assistant
    echo "Home Assistant Protocol: ${HOME_ASSISTANT_PROTOCOL}"

    ########## Helper Functions ##########

    function mqtt_pub_sensor {
        local display_name=$1
        local name=$2
        local value=$3
        local unit=$4
        local device_class=$5
        local state_class=$6

        local topic="homeassistant/sensor/${name}"
        local payload=$(cat <<EOF
{
    "name": "${display_name}",
    "unique_id": "sunsynk_${name}",
    "state_class": "${state_class}",
    "state_topic": "${topic}state",
    "device_class": "${device_class}",
    "unit_of_measurement": "${unit}"
}
EOF
)
        mosquitto_pub -h "${MQTT_BROKER}" -p "${MQTT_PORT}" -u "${MQTT_USERNAME}" -P "${MQTT_PASSWORD}" -t "${topic}/config" -m "${payload}"
        mosquitto_pub -h "${MQTT_BROKER}" -p "${MQTT_PORT}" -u "${MQTT_USERNAME}" -P "${MQTT_PASSWORD}" -t "${topic}state" -m "${value}"
    }

    function mqtt_pub_sensor_text {
        local display_name=$1
        local name=$2
        local value=$3

        local topic="homeassistant/sensor/${name}"
        local payload=$(cat <<EOF
{
    "name": "${display_name}",
    "unique_id": "sunsynk_${name}",
    "state_topic": "${topic}state",
    "value_template": "{{ value }}"
}
EOF
)
        mosquitto_pub -h "${MQTT_BROKER}" -p "${MQTT_PORT}" -u "${MQTT_USERNAME}" -P "${MQTT_PASSWORD}" -t "${topic}/config" -m "${payload}"
        mosquitto_pub -h "${MQTT_BROKER}" -p "${MQTT_PORT}" -u "${MQTT_USERNAME}" -P "${MQTT_PASSWORD}" -t "${topic}state" -m "${value}"
    }


    ########## Main ##########

    # Get the data from the Sunsynk Inverter
    # Get the Sunsynk Token
    echo "Getting data from the Sunsynk Inverter"
    SUNSYNK_TOKEN=$(curl -s -X POST -H 'Content-Type: application/json' -d '{"areaCode": "sunsynk","client_id": "csp-web","grant_type": "password","password": "'$SUNSYNK_PASSWORD'","source": "sunsynk","username": "'$SUNSYNK_USERNAME'"}' https://api.sunsynk.net/oauth/token | jq -r '.data.access_token')

    # Validate the Sunsynk Token
    if [ -z "${SUNSYNK_TOKEN}" ]; then
        echo "Failed to get the Sunsynk Token"
        exit 1
    fi

    # Get the Sunsynk Inverter Data

    ##########
    # Inverter Battery Data
    ##########

    # Get the Inverter Battery Data
    BATTERYDATA=$(curl -s -k -X GET -H "Content-Type: application/json" -H "Authorization: Bearer $SUNSYNK_TOKEN" "https://api.sunsynk.net/api/v1/inverter/battery/$SUNSYNK_INVERTER_SERIAL/realtime?sn=$SUNSYNK_INVERTER_SERIAL&lan=en")

    BATTERY_TEMPERATURE=$(echo $BATTERYDATA | jq -r '.data.temp')
    BATTERY_VOLTAGE=$(echo $BATTERYDATA | jq -r '.data.voltage')
    BATTERY_CURRENT=$(echo $BATTERYDATA | jq -r '.data.current')
    BATTERY_POWER=$(echo $BATTERYDATA | jq -r '.data.power')
    BATTERY_SOC=$(echo $BATTERYDATA | jq -r '.data.soc')
    BATTERY_CHARGEVOLT=$(echo $BATTERYDATA | jq -r '.data.chargeVolt')
    BATTERY_DISCHARGEVOLT=$(echo $BATTERYDATA | jq -r '.data.dischargeVolt')
    BATTERY_CHARGECURRENTLIMIT=$(echo $BATTERYDATA | jq -r '.data.chargeCurrentLimit')
    BATTERY_DISCHARGECURRENTLIMIT=$(echo $BATTERYDATA | jq -r '.data.dischargeCurrentLimit')

    echo "BATTERY_TEMPERATURE: $BATTERY_TEMPERATURE"
    echo "BATTERY_VOLTAGE: $BATTERY_VOLTAGE"
    echo "BATTERY_CURRENT: $BATTERY_CURRENT"
    echo "BATTERY_POWER: $BATTERY_POWER"
    echo "BATTERY_SOC: $BATTERY_SOC"
    echo "BATTERY_CHARGEVOLT: $BATTERY_CHARGEVOLT"
    echo "BATTERY_DISCHARGEVOLT: $BATTERY_DISCHARGEVOLT"
    echo "BATTERY_CHARGECURRENTLIMIT: $BATTERY_CHARGECURRENTLIMIT"
    echo "BATTERY_DISCHARGECURRENTLIMIT: $BATTERY_DISCHARGECURRENTLIMIT"

    # Publish the Inverter Battery Data to MQTT
    mqtt_pub_sensor "Battery Temperature" "battery_temperature" "${BATTERY_TEMPERATURE}" "°C" "temperature" "measurement"
    mqtt_pub_sensor "Battery Voltage" "battery_voltage" "${BATTERY_VOLTAGE}" "V" "voltage" "measurement"
    mqtt_pub_sensor "Battery Current" "battery_current" "${BATTERY_CURRENT}" "A" "current" "measurement"
    mqtt_pub_sensor "Battery Power" "battery_power" "${BATTERY_POWER}" "W" "power" "measurement"
    mqtt_pub_sensor "Battery SOC" "battery_soc" "${BATTERY_SOC}" "%" "battery" "measurement"
    mqtt_pub_sensor "Battery Charge Voltage" "battery_chargevolt" "${BATTERY_CHARGEVOLT}" "V" "voltage" "measurement"
    mqtt_pub_sensor "Battery Discharge Voltage" "battery_dischargevolt" "${BATTERY_DISCHARGEVOLT}" "V" "voltage" "measurement"
    mqtt_pub_sensor "Battery Charge Current Limit" "battery_chargecurrentlimit" "${BATTERY_CHARGECURRENTLIMIT}" "A" "current" "measurement"
    mqtt_pub_sensor "Battery Discharge Current Limit" "battery_dischargecurrentlimit" "${BATTERY_DISCHARGECURRENTLIMIT}" "A" "current" "measurement"

    ##########
    # Inverter Data
    ##########

    OUTPUTDATA=$(curl -s -k -X GET -H "Content-Type: application/json" -H "Authorization: Bearer $SUNSYNK_TOKEN" "https://api.sunsynk.net/api/v1/inverter/$SUNSYNK_INVERTER_SERIAL/realtime/output")

    INVERTER_POWER=$(echo $OUTPUTDATA | jq -r .data.vip[0].power)
    INVERTER_VOLTAGE=$(echo $OUTPUTDATA | jq -r .data.vip[0].volt)
    INVERTER_CURRENT=$(echo $OUTPUTDATA | jq -r .data.vip[0].current)
    INVERTER_FREQUENCY=$(echo $OUTPUTDATA | jq -r .data.fac)

    echo "INVERTER_POWER: $INVERTER_POWER"
    echo "INVERTER_VOLTAGE: $INVERTER_VOLTAGE"
    echo "INVERTER_CURRENT: $INVERTER_CURRENT"
    echo "INVERTER_FREQUENCY: $INVERTER_FREQUENCY"

    # Publish the Inverter Data to MQTT
    mqtt_pub_sensor "Inverter Power" "inverter_power" "${INVERTER_POWER}" "W" "power" "measurement"
    mqtt_pub_sensor "Inverter Voltage" "inverter_voltage" "${INVERTER_VOLTAGE}" "V" "voltage" "measurement"
    mqtt_pub_sensor "Inverter Current" "inverter_current" "${INVERTER_CURRENT}" "A" "current" "measurement"
    mqtt_pub_sensor "Inverter Frequency" "inverter_frequency" "${INVERTER_FREQUENCY}" "Hz" "frequency" "measurement"

    ##########
    # Grid Data
    ##########

    GRIDDATA=$(curl -s -k -X GET -H "Content-Type: application/json" -H "Authorization: Bearer $SUNSYNK_TOKEN" "https://api.sunsynk.net/api/v1/inverter/grid/$SUNSYNK_INVERTER_SERIAL/realtime?sn=$SUNSYNK_INVERTER_SERIAL")

    GRID_POWER=$(echo $GRIDDATA | jq -r .data.vip[0].power)
    GRID_VOLTAGE=$(echo $GRIDDATA | jq -r .data.vip[0].volt)
    GRID_CURRENT=$(echo $GRIDDATA | jq -r .data.vip[0].current)
    GRID_FREQUENCY=$(echo $GRIDDATA | jq -r .data.fac)

    echo "GRID_POWER: $GRID_POWER"
    echo "GRID_VOLTAGE: $GRID_VOLTAGE"
    echo "GRID_CURRENT: $GRID_CURRENT"
    echo "GRID_FREQUENCY: $GRID_FREQUENCY"

    # Publish the Grid Data to MQTT
    mqtt_pub_sensor "Grid Power" "grid_power" "${GRID_POWER}" "W" "power" "measurement"
    mqtt_pub_sensor "Grid Voltage" "grid_voltage" "${GRID_VOLTAGE}" "V" "voltage" "measurement"
    mqtt_pub_sensor "Grid Current" "grid_current" "${GRID_CURRENT}" "A" "current" "measurement"
    mqtt_pub_sensor "Grid Frequency" "grid_frequency" "${GRID_FREQUENCY}" "Hz" "frequency" "measurement"

    ##########
    # Load Data
    ##########

    LOADDATA=$(curl -s -k -X GET -H "Content-Type: application/json" -H "Authorization: Bearer $SUNSYNK_TOKEN" "https://api.sunsynk.net/api/v1/inverter/load/$SUNSYNK_INVERTER_SERIAL/realtime?sn=$SUNSYNK_INVERTER_SERIAL")

    LOAD_POWER=$(echo $LOADDATA | jq -r .data.vip[0].power)
    LOAD_VOLTAGE=$(echo $LOADDATA | jq -r .data.vip[0].volt)
    LOAD_CURRENT=$(echo $LOADDATA | jq -r .data.vip[0].current)
    LOAD_FREQUENCY=$(echo $LOADDATA | jq -r .data.loadFac)

    LOAD_TOTAL_POWER=$(echo $LOADDATA | jq -r .data.totalPower)
    LOAD_ESSENTIAL_POWER=$(echo $LOADDATA | jq -r .data.upsPowerTotal)
    LOAD_NON_ESSENTIAL_POWER=$((LOAD_TOTAL_POWER - $(printf "%.0f" "$LOAD_ESSENTIAL_POWER")))

    echo "LOAD_POWER: $LOAD_POWER"
    echo "LOAD_VOLTAGE: $LOAD_VOLTAGE"
    echo "LOAD_CURRENT: $LOAD_CURRENT"
    echo "LOAD_FREQUENCY: $LOAD_FREQUENCY"
    echo "LOAD_TOTAL_POWER: $LOAD_TOTAL_POWER"
    echo "LOAD_ESSENTIAL_POWER: $LOAD_ESSENTIAL_POWER"
    echo "LOAD_NON_ESSENTIAL_POWER: $LOAD_NON_ESSENTIAL_POWER"

    # Publish the Load Data to MQTT
    mqtt_pub_sensor "Load Power" "load_power" "${LOAD_POWER}" "W" "power" "measurement"
    mqtt_pub_sensor "Load Voltage" "load_voltage" "${LOAD_VOLTAGE}" "V" "voltage" "measurement"
    mqtt_pub_sensor "Load Current" "load_current" "${LOAD_CURRENT}" "A" "current" "measurement"
    mqtt_pub_sensor "Load Frequency" "load_frequency" "${LOAD_FREQUENCY}" "Hz" "frequency" "measurement"
    mqtt_pub_sensor "Load Total Power" "load_total_power" "${LOAD_TOTAL_POWER}" "W" "power" "measurement"
    mqtt_pub_sensor "Load Essential Power" "load_essential_power" "${LOAD_ESSENTIAL_POWER}" "W" "power" "measurement"
    mqtt_pub_sensor "Load Non Essential Power" "load_non_essential_power" "${LOAD_NON_ESSENTIAL_POWER}" "W" "power" "measurement"

    ##########
    # Solar Data
    ##########

    PVDATA=$(curl -s -k -X GET -H "Content-Type: application/json" -H "Authorization: Bearer $SUNSYNK_TOKEN" "https://api.sunsynk.net/api/v1/inverter/$SUNSYNK_INVERTER_SERIAL/realtime/input")

    PV1_POWER=$(echo $PVDATA | jq -r .data.pvIV[0].ppv)
    PV1_VOLTAGE=$(echo $PVDATA | jq -r .data.pvIV[0].vpv)
    PV1_CURRENT=$(echo $PVDATA | jq -r .data.pvIV[0].ipv)
    PV2_POWER=$(echo $PVDATA | jq -r .data.pvIV[1].ppv)
    PV2_VOLTAGE=$(echo $PVDATA | jq -r .data.pvIV[1].vpv)
    PV2_CURRENT=$(echo $PVDATA | jq -r .data.pvIV[1].ipv)

    echo "PV1_POWER: $PV1_POWER"
    echo "PV1_VOLTAGE: $PV1_VOLTAGE"
    echo "PV1_CURRENT: $PV1_CURRENT"
    echo "PV2_POWER: $PV2_POWER"
    echo "PV2_VOLTAGE: $PV2_VOLTAGE"
    echo "PV2_CURRENT: $PV2_CURRENT"

    # Publish the Solar Data to MQTT
    mqtt_pub_sensor "PV1 Power" "pv1_power" "${PV1_POWER}" "W" "power" "measurement"
    mqtt_pub_sensor "PV1 Voltage" "pv1_voltage" "${PV1_VOLTAGE}" "V" "voltage" "measurement"
    mqtt_pub_sensor "PV1 Current" "pv1_current" "${PV1_CURRENT}" "A" "current" "measurement"
    mqtt_pub_sensor "PV2 Power" "pv2_power" "${PV2_POWER}" "W" "power" "measurement"
    mqtt_pub_sensor "PV2 Voltage" "pv2_voltage" "${PV2_VOLTAGE}" "V" "voltage" "measurement"
    mqtt_pub_sensor "PV2 Current" "pv2_current" "${PV2_CURRENT}" "A" "current" "measurement"

    ##########
    # Energy Data
    ##########

    DAY_BATTERY_CHARGE=$(echo $BATTERYDATA | jq -r '.data.etodayChg')
    DAY_BATTERY_DISCHARGE=$(echo $BATTERYDATA | jq -r '.data.etodayDischg')
    DAY_GRID_IMPORT=$(echo $GRIDDATA | jq -r '.data.etodayFrom')
    DAY_GRID_EXPORT=$(echo $GRIDDATA | jq -r '.data.etodayTo')
    DAY_LOAD=$(echo $LOADDATA | jq -r '.data.dailyUsed')
    DAY_PV=$(echo $PVDATA | jq -r '.data.etoday')

    echo "DAY_BATTERY_CHARGE: $DAY_BATTERY_CHARGE"
    echo "DAY_BATTERY_DISCHARGE: $DAY_BATTERY_DISCHARGE"
    echo "DAY_GRID_IMPORT: $DAY_GRID_IMPORT"
    echo "DAY_GRID_EXPORT: $DAY_GRID_EXPORT"
    echo "DAY_LOAD: $DAY_LOAD"
    echo "DAY_PV: $DAY_PV"

    # Publish the Energy Data to MQTT
    mqtt_pub_sensor "Day Battery Charge" "day_battery_charge" "${DAY_BATTERY_CHARGE}" "kWh" "energy" "total_increasing"
    mqtt_pub_sensor "Day Battery Discharge" "day_battery_discharge" "${DAY_BATTERY_DISCHARGE}" "kWh" "energy" "total_increasing"
    mqtt_pub_sensor "Day Grid Import" "day_grid_import" "${DAY_GRID_IMPORT}" "kWh" "energy" "total_increasing"
    mqtt_pub_sensor "Day Grid Export" "day_grid_export" "${DAY_GRID_EXPORT}" "kWh" "energy" "total_increasing"
    mqtt_pub_sensor "Day Load" "day_load" "${DAY_LOAD}" "kWh" "energy" "total_increasing"
    mqtt_pub_sensor "Day PV" "day_pv" "${DAY_PV}" "kWh" "energy" "total_increasing"

    ##########
    # Settings
    ##########

    SETTINGS=$(curl -s -k -X GET -H "Content-Type: application/json" -H "Authorization: Bearer $SUNSYNK_TOKEN" "https://api.sunsynk.net/api/v1/common/setting/$SUNSYNK_INVERTER_SERIAL/read")

    PROG1_TIME=$(echo $SETTINGS | jq -r '.data.sellTime1')
    PROG2_TIME=$(echo $SETTINGS | jq -r '.data.sellTime2')
    PROG3_TIME=$(echo $SETTINGS | jq -r '.data.sellTime3')
    PROG4_TIME=$(echo $SETTINGS | jq -r '.data.sellTime4')
    PROG5_TIME=$(echo $SETTINGS | jq -r '.data.sellTime5')
    PROG6_TIME=$(echo $SETTINGS | jq -r '.data.sellTime6')

    PROG1_CHARGE=$(echo $SETTINGS | jq -r '.data.time1on')
    PROG2_CHARGE=$(echo $SETTINGS | jq -r '.data.time2on')
    PROG3_CHARGE=$(echo $SETTINGS | jq -r '.data.time3on')
    PROG4_CHARGE=$(echo $SETTINGS | jq -r '.data.time4on')
    PROG5_CHARGE=$(echo $SETTINGS | jq -r '.data.time5on')
    PROG6_CHARGE=$(echo $SETTINGS | jq -r '.data.time6on')

    PROG1_CAPACITY=$(echo $SETTINGS | jq -r '.data.cap1')
    PROG2_CAPACITY=$(echo $SETTINGS | jq -r '.data.cap2')
    PROG3_CAPACITY=$(echo $SETTINGS | jq -r '.data.cap3')
    PROG4_CAPACITY=$(echo $SETTINGS | jq -r '.data.cap4')
    PROG5_CAPACITY=$(echo $SETTINGS | jq -r '.data.cap5')
    PROG6_CAPACITY=$(echo $SETTINGS | jq -r '.data.cap6')

    BATTERY_SHUTDOWN_CAP=$(echo $SETTINGS | jq -r '.data.batteryShutdownCap')
    ENERGY_MODE=$(echo $SETTINGS | jq -r '.data.energyMode'); if [ "$ENERGY_MODE" == "0" ]; then ENERGY_MODE="Priority Batt"; elif [ "$ENERGY_MODE" == "1" ]; then ENERGY_MODE="Priority Load"; fi
    WORK_MODE=$(echo $SETTINGS | jq -r '.data.sysWorkMode'); if [ "$WORK_MODE" == "0" ]; then WORK_MODE="Allow Export"; elif [ "$WORK_MODE" == "1" ]; then WORK_MODE="Essentials"; elif [ "$WORK_MODE" == "2" ]; then WORK_MODE="Zero Export"; fi

    echo "PROG1_TIME: $PROG1_TIME"
    echo "PROG2_TIME: $PROG2_TIME"
    echo "PROG3_TIME: $PROG3_TIME"
    echo "PROG4_TIME: $PROG4_TIME"
    echo "PROG5_TIME: $PROG5_TIME"
    echo "PROG6_TIME: $PROG6_TIME"

    echo "PROG1_CHARGE: $PROG1_CHARGE"
    echo "PROG2_CHARGE: $PROG2_CHARGE"
    echo "PROG3_CHARGE: $PROG3_CHARGE"
    echo "PROG4_CHARGE: $PROG4_CHARGE"
    echo "PROG5_CHARGE: $PROG5_CHARGE"
    echo "PROG6_CHARGE: $PROG6_CHARGE"

    echo "PROG1_CAPACITY: $PROG1_CAPACITY"
    echo "PROG2_CAPACITY: $PROG2_CAPACITY"
    echo "PROG3_CAPACITY: $PROG3_CAPACITY"
    echo "PROG4_CAPACITY: $PROG4_CAPACITY"
    echo "PROG5_CAPACITY: $PROG5_CAPACITY"
    echo "PROG6_CAPACITY: $PROG6_CAPACITY"

    echo "BATTERY_SHUTDOWN_CAP: $BATTERY_SHUTDOWN_CAP"
    echo "ENERGY_MODE: $ENERGY_MODE"
    echo "WORK_MODE: $WORK_MODE"

    # Publish the Settings to MQTT
    mqtt_pub_sensor_text "Program 1 Time" "prog1_time" "${PROG1_TIME}"
    mqtt_pub_sensor_text "Program 2 Time" "prog2_time" "${PROG2_TIME}"
    mqtt_pub_sensor_text "Program 3 Time" "prog3_time" "${PROG3_TIME}"
    mqtt_pub_sensor_text "Program 4 Time" "prog4_time" "${PROG4_TIME}"
    mqtt_pub_sensor_text "Program 5 Time" "prog5_time" "${PROG5_TIME}"
    mqtt_pub_sensor_text "Program 6 Time" "prog6_time" "${PROG6_TIME}"

    mqtt_pub_sensor_text "Program 1 Charge" "prog1_charge" "${PROG1_CHARGE}"
    mqtt_pub_sensor_text "Program 2 Charge" "prog2_charge" "${PROG2_CHARGE}"
    mqtt_pub_sensor_text "Program 3 Charge" "prog3_charge" "${PROG3_CHARGE}"
    mqtt_pub_sensor_text "Program 4 Charge" "prog4_charge" "${PROG4_CHARGE}"
    mqtt_pub_sensor_text "Program 5 Charge" "prog5_charge" "${PROG5_CHARGE}"
    mqtt_pub_sensor_text "Program 6 Charge" "prog6_charge" "${PROG6_CHARGE}"

    mqtt_pub_sensor_text "Program 1 Capacity" "prog1_capacity" "${PROG1_CAPACITY}"
    mqtt_pub_sensor_text "Program 2 Capacity" "prog2_capacity" "${PROG2_CAPACITY}"
    mqtt_pub_sensor_text "Program 3 Capacity" "prog3_capacity" "${PROG3_CAPACITY}"
    mqtt_pub_sensor_text "Program 4 Capacity" "prog4_capacity" "${PROG4_CAPACITY}"
    mqtt_pub_sensor_text "Program 5 Capacity" "prog5_capacity" "${PROG5_CAPACITY}"
    mqtt_pub_sensor_text "Program 6 Capacity" "prog6_capacity" "${PROG6_CAPACITY}"

    mqtt_pub_sensor_text "Battery Shutdown Capacity" "battery_shutdown_capacity" "${BATTERY_SHUTDOWN_CAP}"
    mqtt_pub_sensor_text "Energy Mode" "energy_mode" "${ENERGY_MODE}"
    mqtt_pub_sensor_text "Work Mode" "work_mode" "${WORK_MODE}"

    # Sleep for 5 minutes
    sleep $(bashio::config "refresh_time")

done