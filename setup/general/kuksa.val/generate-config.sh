#!/bin/sh

DEFAULT_VIN="ishouldbeavin"
DEFAULT_USERID="ishouldbetheuserid"

# checkout specific vss tag or master
VSS_TAG="release/2.1"

# configuration directory
CONFIG_DIR=`pwd`/config

### prequisites
[ -z "`which jq`" ] && sudo apt-get -y install jq

# force checkout/rebuild
FORCE=0
[ "$1" = "-f" ] && FORCE=1

# from https://github.com/GENIVI/iot-event-analytics/blob/develop/docker/vss2iotea/README.md (fixed links)

echo "### Getting kuksa.val certs/ ..."
[ -d $CONFIG_DIR/certs ] || mkdir -p $CONFIG_DIR/certs
if [ $FORCE -eq 1 ] || [ ! -f $CONFIG_DIR/certs/jwt.key.pub ]; then
	wget -q https://raw.githubusercontent.com/eclipse/kuksa.val/master/kuksa_certificates/jwt/jwt.key.pub -O $CONFIG_DIR/certs/jwt.key.pub
fi
if [ $FORCE -eq 1 ] || [ ! -f $CONFIG_DIR/certs/Server.key ]; then
	wget -q https://raw.githubusercontent.com/eclipse/kuksa.val/master/kuksa_certificates/Server.key -O $CONFIG_DIR/certs/Server.key
fi
if [ $FORCE -eq 1 ] || [ ! -f $CONFIG_DIR/certs/Server.pem ]; then
	wget -q https://raw.githubusercontent.com/eclipse/kuksa.val/master/kuksa_certificates/Server.pem -O $CONFIG_DIR/certs/Server.pem
fi

VSS_DIR=/tmp

# from https://github.com/GENIVI/vss-tools/blob/master/README.md
if [ $FORCE -eq 1 ] || [ ! -d $VSS_DIR/vehicle_signal_specification ]; then
	cd $VSS_DIR
	git clone https://github.com/GENIVI/vehicle_signal_specification.git --recurse-submodules
fi

cd $VSS_DIR/vehicle_signal_specification
if [ $FORCE -eq 1 ] || [ ! -f ./vss-tools/vspec2json.py ]; then
	git checkout $VSS_TAG
	git submodule update --init
fi

# from https://github.com/GENIVI/vss-tools/blob/master/README.md
cd $VSS_DIR/vehicle_signal_specification/vss-tools
[ $FORCE -eq 1 ] && pip3 uninstall vss-tools
pip3 install -e .
pip3 install -r requirements.txt
# pytest tests


# generate json from vspec
cd $VSS_DIR/vehicle_signal_specification/
[ $FORCE -eq 1 ] && rm -f $CONFIG_DIR/vss.json &>/dev/null
python3 vss-tools/vspec2json.py -I spec -i:spec/VehicleSignalSpecification.id spec/VehicleSignalSpecification.vspec $CONFIG_DIR/vss.json

echo
if [ -f $CONFIG_DIR/vss.json ]; then
	echo "### Generated vss tree: $CONFIG_DIR/vss.json"
else
	echo "VSS Tree generation failed!"
fi

echo

# sanity checks for json keys before update:
DRIVER_ID=`cat $CONFIG_DIR/vss.json | jq '.Vehicle.children.Driver.children.Identifier.children.Subject'`
VIN=`cat $CONFIG_DIR/vss.json | jq '.Vehicle.children.VehicleIdentification.children.VIN'`

if [ -z "$DRIVER_ID" ] || [ -z "$VIN" ] || [ "$DRIVER_ID" = "null" ] || [ "$VIN" = "null" ]; then
	echo "Unexpected Vehicle.Driver.Identifier.Subject | Vehicle.VehicleIdentification.VIN structure in $CONFIG_DIR/vss.json"
	exit 1
fi

# append value keys in new file
cat $CONFIG_DIR/vss.json | jq --arg uid $DEFAULT_USERID --arg vin $DEFAULT_VIN \
	'.Vehicle.children.VehicleIdentification.children.VIN += { "value": $vin} | .Vehicle.children.Driver.children.Identifier.children.Subject += { "value": $uid }' \
	> $CONFIG_DIR/vss-mod.json

echo

echo "### (mod) Vehicle.Driver.Identifier.Subject:"
cat $CONFIG_DIR/vss-mod.json | jq '.Vehicle.children.Driver.children.Identifier.children.Subject'

echo "### (mod) Vehicle.VehicleIdentification.VIN:"
cat $CONFIG_DIR/vss-mod.json | jq '.Vehicle.children.VehicleIdentification.children.VIN'

echo
echo "### Modified file: $CONFIG_DIR/vss-mod.json"
echo

echo "Execute the following command to install modified vss.json"
echo "  cp vss-mod.json ../../../docker-compose/config/kuksa.val/vss.json"
echo "  cp -r certs ../../../docker-compose/config/kuksa.val/"

