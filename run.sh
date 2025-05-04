#!/usr/bin/with-contenv bashio
# shellcheck disable=SC1091,SC2154
# ==============================================================================
# Home Assistant SolarConnect Add-on:
# Author:   @rfc1918-hub 

set +e

# ==============================================================================

while true; do
    
    # Set the environment variable for the script
    #### MQTT #### 
    MQTT_BROKER=$(bashio::config "mqtt_broker")
    MQTT_PORT=$(bashio::config "mqtt_port")
    MQTT_USERNAME=$(bashio::config "mqtt_username")
    MQTT_PASSWORD=$(bashio::config "mqtt_password")

    #### SolarConnect ####
    SUNSYNK_USERNAME=$(bashio::config 'sunsynk_username')
    SUNSYNK_PASSWORD=$(bashio::config 'sunsynk_password')
    SUNSYNK_INVERTER_SERIAL=$(bashio::config 'sunsynk_inverter_serial')

    #### Home Assistant ####
    ENABLE_HTTPS=$(bashio::config 'enable_https')
    if [ "${ENABLE_HTTPS}" == "true" ]; then
        HOME_ASSISTANT_PROTOCOL="https"
    else
        HOME_ASSISTANT_PROTOCOL="http"
    fi

    ## Print bebugging information
    echo "MQTT Broker: ${MQTT_BROKER}"
    echo "MQTT Port: ${MQTT_PORT}"
    echo "MQTT Username: ${MQTT_USERNAME}"
    echo "MQTT Password: **********"

    echo "SunSynk Username: ${SUNSYNK_USERNAME}"
    echo "SunSynk Password: **********"
    echo "SunSynk Inverter Serial: ${SUNSYNK_INVERTER_SERIAL}"

    echo "Home Assistant Protocol: ${HOME_ASSISTANT_PROTOCOL}"

    #### MQTT Helper Functions ####

    function mqtt_publish() {
        local display_name=$1
        local name=$2
        local value=$3
        local unit=$4
        local device_class=$5
        local state_class=$6

        local topic="homeassistant/sensor/sunsynk_${SUNSYNK_INVERTER_SERIAL}_${name}"
        local state_topic="${topic}/state"

        local payload=$(cat <<EOF
{
"name": "${display_name}",
"unique_id": "sunsynk_${SUNSYNK_INVERTER_SERIAL}_${name}",
"state_topic": "${state_topic}",
"unit_of_measurement": "${unit}",
"device_class": "${device_class}",
"state_class": "${state_class}",
"device": {
    "identifiers": ["sunsynk_${SUNSYNK_INVERTER_SERIAL}"],
    "name": "Sunsynk Inverter",
    "manufacturer": "Sunsynk",
    "model": "Inverter"
}
}
EOF
)

        # Print the payload for debugging
        echo "Publishing MQTT discovery for ${display_name}"
        echo "${payload}"

        # Publish discovery config (retain it)
        mosquitto_pub -h "${MQTT_BROKER}" -p "${MQTT_PORT}" \
            -u "${MQTT_USERNAME}" -P "${MQTT_PASSWORD}" \
            -t "${topic}/config" -m "${payload}" -r

        # Publish the sensor state
        mosquitto_pub -h "${MQTT_BROKER}" -p "${MQTT_PORT}" \
            -u "${MQTT_USERNAME}" -P "${MQTT_PASSWORD}" \
            -t "${state_topic}" -m "${value}"
    }


    function mqtt_publish_text() {
        local display_name=$1
        local name=$2
        local value=$3

        local topic="homeassistant/sensor/${name}"
        local state_topic="${topic}/state"

        local payload=$(cat <<EOF
{
"name": "${display_name}",
"unique_id": "sunsynk_${SUNSYNK_INVERTER_SERIAL}_${name}",
"state_topic": "${state_topic}",
"icon": "mdi:information-outline",
"device": {
    "identifiers": ["sunsynk_${SUNSYNK_INVERTER_SERIAL}"],
    "name": "Sunsynk Inverter",
    "manufacturer": "Sunsynk",
    "model": "Inverter"
}
}
EOF
)

        # Print the payload for debugging
        echo "Publishing MQTT discovery for ${display_name}"
        echo "${payload}"

        # Publish discovery config (retain it)
        mosquitto_pub -h "${MQTT_BROKER}" -p "${MQTT_PORT}" \
            -u "${MQTT_USERNAME}" -P "${MQTT_PASSWORD}" \
            -t "${topic}/config" -m "${payload}" -r

        # Publish the state
        mosquitto_pub -h "${MQTT_BROKER}" -p "${MQTT_PORT}" \
            -u "${MQTT_USERNAME}" -P "${MQTT_PASSWORD}" \
            -t "${state_topic}" -m "${value}"
    }


    #### Main ####
    # Login to the SunSynk inverter
    echo "Logging in to SunSynk Connect..."
    SUNSYNK_TOKEN=$(curl -s -X POST -H 'Content-Type: application/json' -d '{"areaCode": "sunsynk","client_id": "csp-web","grant_type": "password","password": "'$SUNSYNK_PASSWORD'","source": "sunsynk","username": "'$SUNSYNK_USERNAME'"}' https://api.sunsynk.net/oauth/token | jq -r '.data.access_token')

    if [ "${SUNSYNK_TOKEN}" == "null" ]; then
        echo "Failed to login to SunSynk Connect. Please check your username and password."
        continue
    fi
    echo "Logged in to SunSynk Connect."

    # Get the inverter data
    echo "Getting inverter data..."
    BATTERYDATA=$(curl -s -k -X GET -H "Content-Type: application/json" -H "Authorization: Bearer $SUNSYNK_TOKEN" "https://api.sunsynk.net/api/v1/inverter/battery/$SUNSYNK_INVERTER_SERIAL/realtime?sn=$SUNSYNK_INVERTER_SERIAL&lan=en")
    OUTPUTDATA=$(curl -s -k -X GET -H "Content-Type: application/json" -H "Authorization: Bearer $SUNSYNK_TOKEN" "https://api.sunsynk.net/api/v1/inverter/$SUNSYNK_INVERTER_SERIAL/realtime/output")
    GRIDDATA=$(curl -s -k -X GET -H "Content-Type: application/json" -H "Authorization: Bearer $SUNSYNK_TOKEN" "https://api.sunsynk.net/api/v1/inverter/grid/$SUNSYNK_INVERTER_SERIAL/realtime?sn=$SUNSYNK_INVERTER_SERIAL")
    LOADDATA=$(curl -s -k -X GET -H "Content-Type: application/json" -H "Authorization: Bearer $SUNSYNK_TOKEN" "https://api.sunsynk.net/api/v1/inverter/load/$SUNSYNK_INVERTER_SERIAL/realtime?sn=$SUNSYNK_INVERTER_SERIAL")
    PVDATA=$(curl -s -k -X GET -H "Content-Type: application/json" -H "Authorization: Bearer $SUNSYNK_TOKEN" "https://api.sunsynk.net/api/v1/inverter/$SUNSYNK_INVERTER_SERIAL/realtime/input")
    SETTINGS=$(curl -s -k -X GET -H "Content-Type: application/json" -H "Authorization: Bearer $SUNSYNK_TOKEN" "https://api.sunsynk.net/api/v1/common/setting/$SUNSYNK_INVERTER_SERIAL/read")
    echo "Got inverter data."
    # Parse the inverter data
    # Battery data
    BATTERY_VOLTAGE=$(echo "$BATTERYDATA" | jq -r '.data.voltage'); if [ "$BATTERY_VOLTAGE" == "null" ]; then BATTERY_VOLTAGE=0; fi
    BATTERY_CURRENT=$(echo "$BATTERYDATA" | jq -r '.data.current'); if [ "$BATTERY_CURRENT" == "null" ]; then BATTERY_CURRENT=0; fi
    BATTERY_SOC=$(echo "$BATTERYDATA" | jq -r '.data.soc'); if [ "$BATTERY_SOC" == "null" ]; then BATTERY_SOC=0; fi
    BATTERY_POWER=$(echo "$BATTERYDATA" | jq -r '.data.power'); if [ "$BATTERY_POWER" == "null" ]; then BATTERY_POWER=0; fi
    BATTERY_TEMPERATURE=$(echo "$BATTERYDATA" | jq -r '.data.temp'); if [ "$BATTERY_TEMPERATURE" == "null" ]; then BATTERY_TEMPERATURE=0; fi
    TODAY_BATTERY_CHARGE=$(echo "$BATTERYDATA" | jq -r '.data.etodayChg'); if [ "$TODAY_BATTERY_CHARGE" == "null" ]; then TODAY_BATTERY_CHARGE=0; fi
    TODAY_BATTERY_DISCHARGE=$(echo "$BATTERYDATA" | jq -r '.data.etodayDischg'); if [ "$TODAY_BATTERY_DISCHARGE" == "null" ]; then TODAY_BATTERY_DISCHARGE=0; fi
    # Output data
    INVERTER_VOLTAGE=$(echo "$OUTPUTDATA" | jq -r '.data.vip[0].volt'); if [ "$INVERTER_VOLTAGE" == "null" ]; then INVERTER_VOLTAGE=0; fi
    INVERTER_CURRENT=$(echo "$OUTPUTDATA" | jq -r '.data.vip[0].current'); if [ "$INVERTER_CURRENT" == "null" ]; then INVERTER_CURRENT=0; fi
    INVERTER_POWER=$(echo "$OUTPUTDATA" | jq -r '.data.vip[0].power'); if [ "$INVERTER_POWER" == "null" ]; then INVERTER_POWER=0; fi
    INVERTER_FREQUENCY=$(echo "$OUTPUTDATA" | jq -r '.data.fac'); if [ "$INVERTER_FREQUENCY" == "null" ]; then INVERTER_FREQUENCY=0; fi
    # Grid data
    GRID_VOLTAGE=$(echo "$GRIDDATA" | jq -r '.data.vip[0].volt'); if [ "$GRID_VOLTAGE" == "null" ]; then GRID_VOLTAGE=0; fi
    GRID_CURRENT=$(echo "$GRIDDATA" | jq -r '.data.vip[0].current'); if [ "$GRID_CURRENT" == "null" ]; then GRID_CURRENT=0; fi
    GRID_POWER=$(echo "$GRIDDATA" | jq -r '.data.vip[0].power'); if [ "$GRID_POWER" == "null" ]; then GRID_POWER=0; fi
    GRID_FREQUENCY=$(echo "$GRIDDATA" | jq -r '.data.fac'); if [ "$GRID_FREQUENCY" == "null" ]; then GRID_FREQUENCY=0; fi
    TODAY_GRID_IMPORT=$(echo "$GRIDDATA" | jq -r '.data.etodayFrom'); if [ "$TODAY_GRID_IMPORT" == "null" ]; then TODAY_GRID_IMPORT=0; fi
    TODAY_GRID_EXPORT=$(echo "$GRIDDATA" | jq -r '.data.etodayTo'); if [ "$TODAY_GRID_EXPORT" == "null" ]; then TODAY_GRID_EXPORT=0; fi
    GRID_STATUS=$(echo "$GRIDDATA" | jq -r '.data.status'); if [ "$GRID_STATUS" == "0" ]; then GRID_STATUS="Offline"; elif [ "$GRID_STATUS" == "1" ]; then GRID_STATUS="Online"; elif [ "$GRID_STATUS" == "2" ]; then GRID_STATUS="Fault"; fi
    # Load data
    LOAD_VOLTAGE=$(echo "$LOADDATA" | jq -r '.data.vip[0].volt'); if [ "$LOAD_VOLTAGE" == "null" ]; then LOAD_VOLTAGE=0; fi
    LOAD_CURRENT=$(echo "$LOADDATA" | jq -r '.data.vip[0].current'); if [ "$LOAD_CURRENT" == "null" ]; then LOAD_CURRENT=0; fi
    LOAD_POWER=$(echo "$LOADDATA" | jq -r '.data.vip[0].power'); if [ "$LOAD_POWER" == "null" ]; then LOAD_POWER=0; fi
    LOAD_FREQUENCY=$(echo "$LOADDATA" | jq -r '.data.loadFac'); if [ "$LOAD_FREQUENCY" == "null" ]; then LOAD_FREQUENCY=0; fi
    TODAY_LOAD_USAGE=$(echo "$LOADDATA" | jq -r '.data.dailyUsed'); if [ "$TODAY_LOAD_USAGE" == "null" ]; then TODAY_LOAD_USAGE=0; fi
    # PV data
    PV_VOLTAGE=$(echo "$PVDATA" | jq -r '.data.pvIV[0].vpv'); if [ "$PV_VOLTAGE" == "null" ]; then PV_VOLTAGE=0; fi
    PV_CURRENT=$(echo "$PVDATA" | jq -r '.data.pvIV[0].ipv'); if [ "$PV_CURRENT" == "null" ]; then PV_CURRENT=0; fi
    PV_POWER=$(echo "$PVDATA" | jq -r '.data.pvIV[0].ppv'); if [ "$PV_POWER" == "null" ]; then PV_POWER=0; fi
    TODAY_PV_GENERATION=$(echo "$PVDATA" | jq -r '.data.etoday'); if [ "$TODAY_PV_GENERATION" == "null" ]; then TODAY_PV_GENERATION=0; fi
    # Settings data
    PROGRAM_TIME1=$(echo "$SETTINGS" | jq -r '.data.sellTime1'); if [ "$PROGRAM_TIME1" == "null" ]; then PROGRAM_TIME1=0; fi
    PROGRAM_TIME2=$(echo "$SETTINGS" | jq -r '.data.sellTime2'); if [ "$PROGRAM_TIME2" == "null" ]; then PROGRAM_TIME2=0; fi
    PROGRAM_TIME3=$(echo "$SETTINGS" | jq -r '.data.sellTime3'); if [ "$PROGRAM_TIME3" == "null" ]; then PROGRAM_TIME3=0; fi
    PROGRAM_TIME4=$(echo "$SETTINGS" | jq -r '.data.sellTime4'); if [ "$PROGRAM_TIME4" == "null" ]; then PROGRAM_TIME4=0; fi
    PROGRAM_TIME5=$(echo "$SETTINGS" | jq -r '.data.sellTime5'); if [ "$PROGRAM_TIME5" == "null" ]; then PROGRAM_TIME5=0; fi
    PROGRAM_TIME6=$(echo "$SETTINGS" | jq -r '.data.sellTime6'); if [ "$PROGRAM_TIME6" == "null" ]; then PROGRAM_TIME6=0; fi

    PROGRAM_CHARGE1=$(echo "$SETTINGS" | jq -r '.data.time1on'); if [ "$PROGRAM_CHARGE1" == "null" ]; then PROGRAM_CHARGE1=0; fi
    PROGRAM_CHARGE2=$(echo "$SETTINGS" | jq -r '.data.time2on'); if [ "$PROGRAM_CHARGE2" == "null" ]; then PROGRAM_CHARGE2=0; fi
    PROGRAM_CHARGE3=$(echo "$SETTINGS" | jq -r '.data.time3on'); if [ "$PROGRAM_CHARGE3" == "null" ]; then PROGRAM_CHARGE3=0; fi
    PROGRAM_CHARGE4=$(echo "$SETTINGS" | jq -r '.data.time4on'); if [ "$PROGRAM_CHARGE4" == "null" ]; then PROGRAM_CHARGE4=0; fi
    PROGRAM_CHARGE5=$(echo "$SETTINGS" | jq -r '.data.time5on'); if [ "$PROGRAM_CHARGE5" == "null" ]; then PROGRAM_CHARGE5=0; fi
    PROGRAM_CHARGE6=$(echo "$SETTINGS" | jq -r '.data.time6on'); if [ "$PROGRAM_CHARGE6" == "null" ]; then PROGRAM_CHARGE6=0; fi

    PROGRAM_CAPACITY1=$(echo "$SETTINGS" | jq -r '.data.cap1'); if [ "$PROGRAM_CAPACITY1" == "null" ]; then PROGRAM_CAPACITY1=0; fi
    PROGRAM_CAPACITY2=$(echo "$SETTINGS" | jq -r '.data.cap2'); if [ "$PROGRAM_CAPACITY2" == "null" ]; then PROGRAM_CAPACITY2=0; fi
    PROGRAM_CAPACITY3=$(echo "$SETTINGS" | jq -r '.data.cap3'); if [ "$PROGRAM_CAPACITY3" == "null" ]; then PROGRAM_CAPACITY3=0; fi
    PROGRAM_CAPACITY4=$(echo "$SETTINGS" | jq -r '.data.cap4'); if [ "$PROGRAM_CAPACITY4" == "null" ]; then PROGRAM_CAPACITY4=0; fi
    PROGRAM_CAPACITY5=$(echo "$SETTINGS" | jq -r '.data.cap5'); if [ "$PROGRAM_CAPACITY5" == "null" ]; then PROGRAM_CAPACITY5=0; fi
    PROGRAM_CAPACITY6=$(echo "$SETTINGS" | jq -r '.data.cap6'); if [ "$PROGRAM_CAPACITY6" == "null" ]; then PROGRAM_CAPACITY6=0; fi

    ENERGY_MODE=$(echo $SETTINGS | jq -r '.data.energyMode'); if [ "$ENERGY_MODE" == "0" ]; then ENERGY_MODE="Priority Batt"; elif [ "$ENERGY_MODE" == "1" ]; then ENERGY_MODE="Priority Load"; fi
    WORK_MODE=$(echo $SETTINGS | jq -r '.data.sysWorkMode'); if [ "$WORK_MODE" == "0" ]; then WORK_MODE="Allow Export"; elif [ "$WORK_MODE" == "1" ]; then WORK_MODE="Essentials"; elif [ "$WORK_MODE" == "2" ]; then WORK_MODE="Zero Export"; fi
    
    # Publish the data to MQTT
    mqtt_publish "Battery Voltage" "battery_voltage" "${BATTERY_VOLTAGE}" "V" "voltage" "measurement"
    mqtt_publish "Battery Current" "battery_current" "${BATTERY_CURRENT}" "A" "current" "measurement"
    mqtt_publish "Battery SOC" "battery_soc" "${BATTERY_SOC}" "%" "battery" "measurement"
    mqtt_publish "Battery Power" "battery_power" "${BATTERY_POWER}" "W" "power" "measurement"
    mqtt_publish "Battery Temperature" "battery_temperature" "${BATTERY_TEMPERATURE}" "°C" "temperature" "measurement"
    mqtt_publish "Today Battery Charge" "today_battery_charge" "${TODAY_BATTERY_CHARGE}" "kWh" "energy" "total_increasing"
    mqtt_publish "Today Battery Discharge" "today_battery_discharge" "${TODAY_BATTERY_DISCHARGE}" "kWh" "energy" "total_increasing"

    mqtt_publish "Inverter Voltage" "inverter_voltage" "${INVERTER_VOLTAGE}" "V" "voltage" "measurement"
    mqtt_publish "Inverter Current" "inverter_current" "${INVERTER_CURRENT}" "A" "current" "measurement"
    mqtt_publish "Inverter Power" "inverter_power" "${INVERTER_POWER}" "W" "power" "measurement"
    mqtt_publish "Inverter Frequency" "inverter_frequency" "${INVERTER_FREQUENCY}" "Hz" "frequency" "measurement"

    mqtt_publish "Grid Voltage" "grid_voltage" "${GRID_VOLTAGE}" "V" "voltage" "measurement"
    mqtt_publish "Grid Current" "grid_current" "${GRID_CURRENT}" "A" "current" "measurement"
    mqtt_publish "Grid Power" "grid_power" "${GRID_POWER}" "W" "power" "measurement"
    mqtt_publish "Grid Frequency" "grid_frequency" "${GRID_FREQUENCY}" "Hz" "frequency" "measurement"
    mqtt_publish "Today Grid Import" "today_grid_import" "${TODAY_GRID_IMPORT}" "kWh" "energy" "total_increasing"
    mqtt_publish "Today Grid Export" "today_grid_export" "${TODAY_GRID_EXPORT}" "kWh" "energy" "total_increasing"
    mqtt_publish_text "Grid Status" "grid_status" "${GRID_STATUS}"

    mqtt_publish "Load Voltage" "load_voltage" "${LOAD_VOLTAGE}" "V" "voltage" "measurement"
    mqtt_publish "Load Current" "load_current" "${LOAD_CURRENT}" "A" "current" "measurement"
    mqtt_publish "Load Power" "load_power" "${LOAD_POWER}" "W" "power" "measurement"
    mqtt_publish "Load Frequency" "load_frequency" "${LOAD_FREQUENCY}" "Hz" "frequency" "measurement"
    mqtt_publish "Today Load Usage" "today_load_usage" "${TODAY_LOAD_USAGE}" "kWh" "energy" "total_increasing"

    mqtt_publish "PV Voltage" "pv_voltage" "${PV_VOLTAGE}" "V" "voltage" "measurement"
    mqtt_publish "PV Current" "pv_current" "${PV_CURRENT}" "A" "current" "measurement"
    mqtt_publish "PV Power" "pv_power" "${PV_POWER}" "W" "power" "measurement"
    mqtt_publish "Today PV Generation" "today_pv_generation" "${TODAY_PV_GENERATION}" "kWh" "energy" "total_increasing"

    mqtt_publish_text "Program Time 1" "program_time1" "${PROGRAM_TIME1}"
    mqtt_publish_text "Program Time 2" "program_time2" "${PROGRAM_TIME2}"
    mqtt_publish_text "Program Time 3" "program_time3" "${PROGRAM_TIME3}"
    mqtt_publish_text "Program Time 4" "program_time4" "${PROGRAM_TIME4}"
    mqtt_publish_text "Program Time 5" "program_time5" "${PROGRAM_TIME5}"
    mqtt_publish_text "Program Time 6" "program_time6" "${PROGRAM_TIME6}"

    mqtt_publish_text "Program Charge 1" "program_charge1" "${PROGRAM_CHARGE1}"
    mqtt_publish_text "Program Charge 2" "program_charge2" "${PROGRAM_CHARGE2}"
    mqtt_publish_text "Program Charge 3" "program_charge3" "${PROGRAM_CHARGE3}"
    mqtt_publish_text "Program Charge 4" "program_charge4" "${PROGRAM_CHARGE4}"
    mqtt_publish_text "Program Charge 5" "program_charge5" "${PROGRAM_CHARGE5}"
    mqtt_publish_text "Program Charge 6" "program_charge6" "${PROGRAM_CHARGE6}"

    mqtt_publish "Program Capacity 1" "program_capacity1" "${PROGRAM_CAPACITY1}" "%" "battery" "measurement"
    mqtt_publish "Program Capacity 2" "program_capacity2" "${PROGRAM_CAPACITY2}" "%" "battery" "measurement"
    mqtt_publish "Program Capacity 3" "program_capacity3" "${PROGRAM_CAPACITY3}" "%" "battery" "measurement"
    mqtt_publish "Program Capacity 4" "program_capacity4" "${PROGRAM_CAPACITY4}" "%" "battery" "measurement"
    mqtt_publish "Program Capacity 5" "program_capacity5" "${PROGRAM_CAPACITY5}" "%" "battery" "measurement"
    mqtt_publish "Program Capacity 6" "program_capacity6" "${PROGRAM_CAPACITY6}" "%" "battery" "measurement"

    mqtt_publish_text "Energy Mode" "energy_mode" "${ENERGY_MODE}"
    mqtt_publish_text "Work Mode" "work_mode" "${WORK_MODE}"

    
    # Print the data for debugging
    echo "Battery Voltage: ${BATTERY_VOLTAGE} V"
    echo "Battery Current: ${BATTERY_CURRENT} A"
    echo "Battery SOC: ${BATTERY_SOC} %"
    echo "Battery Power: ${BATTERY_POWER} W"
    echo "Battery Temperature: ${BATTERY_TEMPERATURE} °C"
    echo "Today Battery Charge: ${TODAY_BATTERY_CHARGE} kWh"
    echo "Today Battery Discharge: ${TODAY_BATTERY_DISCHARGE} kWh"

    echo "Inverter Voltage: ${INVERTER_VOLTAGE} V"
    echo "Inverter Current: ${INVERTER_CURRENT} A"
    echo "Inverter Power: ${INVERTER_POWER} W"
    echo "Inverter Frequency: ${INVERTER_FREQUENCY} Hz"

    echo "Grid Voltage: ${GRID_VOLTAGE} V"
    echo "Grid Current: ${GRID_CURRENT} A"
    echo "Grid Power: ${GRID_POWER} W"
    echo "Grid Frequency: ${GRID_FREQUENCY} Hz"
    echo "Today Grid Import: ${TODAY_GRID_IMPORT} kWh"
    echo "Today Grid Export: ${TODAY_GRID_EXPORT} kWh"
    echo "Grid Status: ${GRID_STATUS}"

    echo "Load Voltage: ${LOAD_VOLTAGE} V"
    echo "Load Current: ${LOAD_CURRENT} A"
    echo "Load Power: ${LOAD_POWER} W"
    echo "Load Frequency: ${LOAD_FREQUENCY} Hz"
    echo "Today Load Usage: ${TODAY_LOAD_USAGE} kWh"

    echo "PV Voltage: ${PV_VOLTAGE} V"
    echo "PV Current: ${PV_CURRENT} A"
    echo "PV Power: ${PV_POWER} W"
    echo "Today PV Generation: ${TODAY_PV_GENERATION} kWh"

    echo "Program Time 1: ${PROGRAM_TIME1}"
    echo "Program Time 2: ${PROGRAM_TIME2}"
    echo "Program Time 3: ${PROGRAM_TIME3}"
    echo "Program Time 4: ${PROGRAM_TIME4}"
    echo "Program Time 5: ${PROGRAM_TIME5}"
    echo "Program Time 6: ${PROGRAM_TIME6}"

    echo "Program Charge 1: ${PROGRAM_CHARGE1}"
    echo "Program Charge 2: ${PROGRAM_CHARGE2}"
    echo "Program Charge 3: ${PROGRAM_CHARGE3}"
    echo "Program Charge 4: ${PROGRAM_CHARGE4}"
    echo "Program Charge 5: ${PROGRAM_CHARGE5}"
    echo "Program Charge 6: ${PROGRAM_CHARGE6}"

    echo "Program Capacity 1: ${PROGRAM_CAPACITY1} %"
    echo "Program Capacity 2: ${PROGRAM_CAPACITY2} %"
    echo "Program Capacity 3: ${PROGRAM_CAPACITY3} %"
    echo "Program Capacity 4: ${PROGRAM_CAPACITY4} %"
    echo "Program Capacity 5: ${PROGRAM_CAPACITY5} %"
    echo "Program Capacity 6: ${PROGRAM_CAPACITY6} %"

    echo "Energy Mode: ${ENERGY_MODE}"
    echo "Work Mode: ${WORK_MODE}"
    echo "----------------------------------------"
    
    # Wait for a while before checking again
    sleep $(bashio::config "refresh_time")
done

