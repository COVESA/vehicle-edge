#!/bin/sh

DEFAULT_VIN="ishouldbeavin"
DEFAULT_USERID="ishouldbetheuserid"

# checkout specific vss tag or master
VSS_TAG="release/2.1"

BASEDIR=`pwd`

### prequisites
[ -z "`which jq`" ] && sudo apt-get -y install jq

# force checkout/rebuild
FORCE=0
[ "$1" = "-f" ] && FORCE=1

# from https://github.com/GENIVI/iot-event-analytics/blob/develop/docker/vss2iotea/README.md (fixed links)

echo "### Getting kuksa.val certs/ ..."
[ -d $BASEDIR/certs ] || mkdir -p $BASEDIR/certs
if [ $FORCE -eq 1 ] || [ ! -f $BASEDIR/certs/jwt.key.pub ]; then
	wget -q https://raw.githubusercontent.com/eclipse/kuksa.val/master/kuksa_certificates/jwt/jwt.key.pub -O $BASEDIR/certs/jwt.key.pub
fi
if [ $FORCE -eq 1 ] || [ ! -f $BASEDIR/certs/Server.key ]; then
	wget -q https://raw.githubusercontent.com/eclipse/kuksa.val/master/kuksa_certificates/Server.key -O $BASEDIR/certs/Server.key
fi
if [ $FORCE -eq 1 ] || [ ! -f $BASEDIR/certs/Server.pem ]; then
	wget -q https://raw.githubusercontent.com/eclipse/kuksa.val/master/kuksa_certificates/Server.pem -O $BASEDIR/certs/Server.pem
fi

#VSS_DIR=$BASEDIR
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
[ $FORCE -eq 1 ] && rm -f $BASEDIR/vss.json &>/dev/null
python3 vss-tools/vspec2json.py -I spec -i:spec/VehicleSignalSpecification.id spec/VehicleSignalSpecification.vspec $BASEDIR/vss.json

echo
if [ -f $BASEDIR/vss.json ]; then
	echo "### Generated vss tree: $BASEDIR/vss.json"
else
	echo "VSS Tree generation failed!"
fi

echo

# sanity checks for json keys before update:
DRIVER_ID=`cat $BASEDIR/vss.json | jq '.Vehicle.children.Driver.children.Identifier.children.Subject'`
VIN=`cat $BASEDIR/vss.json | jq '.Vehicle.children.VehicleIdentification.children.VIN'`

if [ -z "$DRIVER_ID" ] || [ -z "$VIN" ] || [ "$DRIVER_ID" = "null" ] || [ "$VIN" = "null" ]; then
	echo "Unexpected Vehicle.Driver.Identifier.Subject | Vehicle.VehicleIdentification.VIN structure in $BASEDIR/vss.json"
	exit 1
fi

# append value keys in new file
cat $BASEDIR/vss.json | jq --arg uid $DEFAULT_USERID --arg vin $DEFAULT_VIN \
	'.Vehicle.children.VehicleIdentification.children.VIN += { "value": $vin} | .Vehicle.children.Driver.children.Identifier.children.Subject += { "value": $uid }' \
	> $BASEDIR/vss-mod.json

echo

echo "### (mod) Vehicle.Driver.Identifier.Subject:"
cat $BASEDIR/vss-mod.json | jq '.Vehicle.children.Driver.children.Identifier.children.Subject'

echo "### (mod) Vehicle.VehicleIdentification.VIN:"
cat $BASEDIR/vss-mod.json | jq '.Vehicle.children.VehicleIdentification.children.VIN'

echo
echo "### Modified file: $BASEDIR/vss-mod.json"
echo

echo "Execute the following command to install modified vss.json"
echo "  cp vss-mod.json ../../../docker-compose/config/kuksa.val/vss.json"
echo "  cp -r certs ../../../docker-compose/config/kuksa.val/"

