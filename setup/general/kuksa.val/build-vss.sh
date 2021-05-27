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

# from https://github.com/GENIVI/vss-tools/blob/master/README.md
if [ $FORCE -eq 1 ] || [ ! -d $BASEDIR/vehicle_signal_specification ]; then
	git clone --recurse-submodules https://github.com/GENIVI/vehicle_signal_specification.git
fi

cd $BASEDIR/vehicle_signal_specification/
if [ $FORCE -eq 1 ] || [ ! -f vss-tools/vspec2json.py ]; then
	git checkout $VSS_TAG
	git submodule update --init
fi

# from https://github.com/GENIVI/vss-tools/blob/master/README.md
cd $BASEDIR/vehicle_signal_specification/vss-tools
[ $FORCE -eq 1 ] && pip3 uninstall vss-tools
pip3 install -e .
pip3 install -r requirements.txt
pytest tests


# generate json from vspec
cd $BASEDIR/vehicle_signal_specification/
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
echo "cp vss-mod.json ../../../docker-compose/config/kuksa.val/vss.json"
