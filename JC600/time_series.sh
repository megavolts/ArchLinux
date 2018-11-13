IP=${curl ifconfig.co}

# InfluxDB
echo -e".. Setting up influxdb database"
yaourt -S --noconfirm influxdb
systemctl start influxdb
systemctl enable influxdb
echo -e "... influxdb is available at $IP:8086 (admin:admin)"
echo -e "... setting "


# Grafana
echo -e".. Setting up grafana server"
yaourt -S --noconfirm grafana
systemctl start grafana
systemctl enable grafana
echo -e "... grafana is available at $IP:3000 (admin:admin)"

# Mosquitto
echo -e".. Setting up MQTT"
yaourt -S --noconfirm mosquitto
yaourt -S --noconfirm python-pip
pip3 install influxdb
pip3 install paho-mqtt
