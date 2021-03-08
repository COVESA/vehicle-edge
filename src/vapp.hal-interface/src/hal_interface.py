##############################################################################
# Copyright (c) 2021 Robert Bosch GmbH
#
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at https://mozilla.org/MPL/2.0/.
#
# SPDX-License-Identifier: MPL-2.0
##############################################################################

import random
import asyncio
import threading
import re
import json
import os
import time
import logging
import can
import cantools

from iotea.core.logger import Logger
from iotea.core.mqtt_broker import NamedMqttBroker

logging.setLoggerClass(Logger)

class BusObserver:
    def __init__(self, bus_config, hal_broker):
        self.logger = logging.getLogger('HalInterface.BusObserver-{}'.format(bus_config['interface']))
        self.bus_config = bus_config
        self.bus = None
        self.hal_broker = hal_broker
        self.filter = {}
        self.db = None

    async def start(self):
        if len(self.bus_config['dbc']) == 0:
            raise Exception('At least one dbc file needs to be given')

        for dbc_file in self.bus_config['dbc']:
            self.__add_dbc_file(os.path.join(os.path.dirname(os.path.realpath(__file__)), dbc_file))

        self.bus = can.interface.Bus(self.bus_config['interface'], bustype=self.bus_config['bustype'])

        loop = asyncio.new_event_loop()
        t = threading.Thread(target=self.__start_loop, args=(loop,)) #, daemon=True
        t.start()

        self.logger.info('Bus observer started successfully on interface {}'.format(self.bus_config['interface']))

    def add_to_filter(self, frame_id, signal):
        if frame_id not in self.filter:
            self.filter[frame_id] = {}

        frame_filter = self.filter[frame_id]

        if signal not in frame_filter:
            frame_filter[signal] = {
                "sentAtMs": -1,
                "throttleMs": -1,
                "last": None
            }

        signal_filter = self.filter[frame_id][signal]

        filter_key = self.get_signal_id(frame_id, signal)

        if filter_key in self.bus_config['signalThrottleMs']:
            signal_filter['throttleMs'] = self.bus_config['signalThrottleMs'][filter_key]

        self.logger.info('Added: [{}] to filters'.format(filter_key))

    def remove_from_filter(self, frame_id, signal):
        if frame_id not in self.filter:
            return

        if signal not in self.filter[frame_id]:
            return

        del self.filter[frame_id][signal]

        self.logger.info('Removed: [{}] from filters'.format(self.get_signal_id(frame_id, signal)))

    def get_signal_id(self, frame_id, signal):
        return '{}.{}'.format(frame_id, signal)

    def get_signal_topic(self, frame_id, signal):
        return self.get_signal_id(frame_id, signal)

    def __start_loop(self, loop):
        asyncio.set_event_loop(loop)
        loop.run_until_complete(self.__listen_to_bus())

    async def __listen_to_bus(self):
        while True:
            message = self.bus.recv()

            frame_id = '{:X}'.format(message.arbitration_id) # message.arbitration_id is int
            self.logger.debug('RX: [{}] {{ ID:0x{:08X} Data:[{}] }}'.format(message.channel, message.arbitration_id, message.data.hex()))

            if frame_id not in self.filter:
                # filter out, if frame_id exists but signal list is empty
                continue

            now = int(round(time.time() * 1000))
            decoded_message = self.db.decode_message(message.arbitration_id, message.data) # Needs int input

            for signal in self.filter[frame_id]:
                signal_filter = self.filter[frame_id][signal]

                if signal_filter['throttleMs'] > -1:
                    if now - signal_filter['sentAtMs'] < signal_filter['throttleMs']:
                        continue

                if signal not in decoded_message:
                    self.logger.warning('Signal {} not found in frame {}. Decoded frame is {}'.format(signal, frame_id, decoded_message))
                    continue

                # Check last value
                value = decoded_message[signal]

                # Check, if this leads to deleted instance features in IoTEA, since the feature TTL expires
                if signal_filter['last'] == value:
                    # Nothing changed
                    continue

                signal_filter['last'] = value
                signal_filter['sentAtMs'] = now

                self.logger.info("Sending: '{}' to: {}".format(value, self.get_signal_id(frame_id, signal)))

                await self.hal_broker.publish_json(self.get_signal_topic(frame_id, signal), { "value": value })

    def __add_dbc_file(self, dbc_file):
        self.logger.info('Loading dbc file {}...'.format(dbc_file))

        if self.db is None:
            self.db = cantools.database.load_file(dbc_file)
        else:
            self.db.add_dbc_file(dbc_file)

        self.logger.info('Success')

class MockSignalGenerator:
    def __init__(self, config, frame_id, signal, on_signal):
        self.config = config
        self.logger = Logger('HalInterface.MockBusObserver.MockSignalGenerator.{}.{}'.format(frame_id.upper(), signal))
        self.frame_id = frame_id
        self.signal = signal
        self.should_stop = False
        self.is_running = False
        self.last_value = None
        self.value_cnt = 0
        self.__on_signal = on_signal
        self.loop = None
        self.t = None
        self.sleep_task = None

    def use_signal_request_trigger(self):
        return self.config['useSignalRequestTriggers'] is True if 'useSignalRequestTriggers' in self.config else True

    def start(self):
        if self.is_running:
            return

        self.should_stop = False
        self.loop = asyncio.new_event_loop()
        self.t = threading.Thread(target=self.__start_loop, args=(self.loop,))
        self.t.start()
        self.is_running = True

    def stop(self):
        if not self.is_running:
            return

        self.should_stop = True
        self.sleep_task.cancel()
        self.t.join()
        self.loop.stop()
        self.is_running = False

    def __start_loop(self, loop):
        asyncio.set_event_loop(loop)
        loop.run_until_complete(self.__run())

    async def __run(self):
        interval_ms = self.config['intervalMs'] if 'intervalMs' in self.config else 1000
        jitter_ms = self.config['jitterMs'] if 'jitterMs' in self.config else 500

        # Check if file property is given
        if 'file' in self.config:
            await self.run_simulation_from_file(self.config)
            # Clean up after simulation is finished
            self.is_running = False
            self.should_stop = False
            return

        while not self.should_stop:
            sleep_s = max(0, interval_ms - jitter_ms + 2 * random.randint(0, jitter_ms)) / 1000

            self.sleep_task = asyncio.ensure_future(asyncio.sleep(sleep_s))

            try:
                await self.sleep_task
            except asyncio.CancelledError:
                continue

            value = None

            if 'pattern' in self.config:
                value = self.config['pattern'][self.value_cnt % len(self.config['pattern'])]

            if 'values' in self.config:
                # Pick random value from all given values
                value = self.config['values'][random.randint(0, len(self.config['values']) - 1)]

            if 'min' in self.config and 'max' in self.config:
                range_ = self.config['max'] - self.config['min']
                multiple_of = self.config['multipleOf'] if 'multipleOf' in self.config else 1

                if multiple_of > range_:
                    continue

                min_value = self.config['min']
                max_value = self.config['max']

                if 'maxDelta' in self.config:
                    if self.config['maxDelta'] < multiple_of:
                        # If the maximum deviation is smaller than the stepping, there cannot be any value
                        continue

                    if self.last_value is not None:
                        min_value = max(self.config['min'], self.last_value - self.config['maxDelta'])
                        max_value = min(self.config['max'], self.last_value + self.config['maxDelta'])

                        range_ = max_value - min_value

                        if range_ <= 0:
                            continue

                range_max = round(range_ / multiple_of)

                value = round(min_value + multiple_of * random.randint(0, range_max), 8)

            if value is None:
                continue

            # Ignore equal values
            if value == self.last_value:
                continue

            await self.__on_signal(self.frame_id, self.signal, value)

            self.last_value = value
            self.value_cnt += 1

        self.should_stop = False

    async def run_simulation_from_file(self, config):
        base_time_ms = int(self.config['baseTimeMs'] if 'baseTimeMs' in self.config else 0)

        # Timestamp of the previous line
        previous_ts_ms = base_time_ms

        value_type = 'string'

        # Check the value type, defined by the filename e.g. A4D.Test-int.txt, A4D.Test2-float.txt, A4D.Test3.txt (defaults to string)
        # pylint: disable=anomalous-backslash-in-string
        value_type_result = re.search('-(int|float|string)?\.[^\.]+$', config['file'])

        if value_type_result is not None:
            value_type = value_type_result.group(1).lower()

        with open(config['file'], 'r') as simulation_file:
            while not self.should_stop:
                signal = simulation_file.readline()

                if not signal:
                    break

                # Lines are in CSV form "signal,timestamp"
                signal_parts = signal.split(',')

                if len(signal_parts) != 2:
                    self.logger.error('Error simulating signal {}. Line {} is invalid'.format(self.get_signal_id(), signal))
                    break

                try:
                    current_ts_ms = int(signal_parts[1])
                    rel_ts_ms = current_ts_ms - previous_ts_ms

                    if rel_ts_ms < 0:
                        self.logger.error('Subsequent lines must have increasing timestamp values')
                        break

                    if rel_ts_ms > 0:
                        self.sleep_task = asyncio.ensure_future(asyncio.sleep(rel_ts_ms / 1000))

                        try:
                            await self.sleep_task
                        except asyncio.CancelledError:
                            continue

                    previous_ts_ms = current_ts_ms
                    self.value_cnt += 1

                    signal_value = signal_parts[0]

                    try:
                        # Type case value types
                        if value_type == 'int':
                            signal_value = int(signal_value, base=10)

                        if value_type == 'float':
                            signal_value = float(signal_value)

                        # Emit signal value
                        await self.__on_signal(self.frame_id, self.signal, signal_value)
                    # pylint: disable=broad-except
                    except Exception as ex:
                        self.logger.warn('Given value {} of signal {} cannot be cast to type {}'.format(signal_parts[0], self.get_signal_id(), value_type), ex)
                # pylint: disable=broad-except
                except Exception as ex:
                    self.logger.error('Error simulating signal {}'.format(self.get_signal_id()), ex)
                    break

    def get_signal_id(self):
        return '{}.{}'.format(self.frame_id, self.signal)

class MockBusObserver(BusObserver):
    def __init__(self, bus_config, hal_broker):
        super(MockBusObserver, self).__init__(bus_config, hal_broker)

        # pylint: disable=anomalous-backslash-in-string
        self.topic_regex = re.compile('^{}([^\.]+)\.(.+)\/(?:start|stop)$'.format((self.hal_broker.topic_ns or '').replace('\\/', '\\\\/')))

        self.logger = logging.getLogger('HalInterface.MockBusObserver')
        self.generators = {}

        self.lock = threading.Lock()

    async def start(self):
        await self.hal_broker.subscribe_json('+/start', self.__on_signal_start)
        await self.hal_broker.subscribe_json('+/stop', self.__on_signal_stop)

    def add_to_filter(self, frame_id, signal):
        signal_id = self.get_signal_id(frame_id, signal)

        self.logger.debug('Adding {} {} signal to filter'.format(frame_id, signal_id))

        if signal_id not in self.bus_config['signals']:
            return

        if signal_id in self.generators and self.generators[signal_id].use_signal_request_trigger():
            self.generators[signal_id].start()
            return

        self.generators[signal_id] = MockSignalGenerator(self.bus_config['signals'][signal_id], frame_id, signal, self.__on_signal)

        self.logger.debug('MockBusObserver added MockSignalGenerator for {}'.format(signal_id))

        if self.generators[signal_id].use_signal_request_trigger():
            # This generator is triggered by signals
            self.generators[signal_id].start()
            self.logger.debug('MockBusObserver started MockSignalGenerator for {}'.format(signal_id))

    def remove_from_filter(self, frame_id, signal):
        signal_id = self.get_signal_id(frame_id, signal)

        if signal_id not in self.generators:
            return

        if self.generators[signal_id].use_signal_request_trigger():
            # This generator is triggered by signals
            self.generators[signal_id].stop()
            self.logger.debug('MockBusObserver stopped MockSignalGenerator for {}'.format(signal_id))

    # pylint: disable=unused-argument
    async def __on_signal_start(self, ev, topic):
        try:
            frame_id, signal = self.extract_can_info_from_topic(topic)

            signal_id = self.get_signal_id(frame_id, signal)

            if signal_id not in self.generators:
                # Generator for given signal_id does not exist yet. Create a temporary one and check whether it is triggered manually
                generator = MockSignalGenerator(self.bus_config['signals'][signal_id], frame_id, signal, self.__on_signal)

                if generator.use_signal_request_trigger() is False:
                    # This generator is triggered manually
                    # Add it to the list of generators
                    self.generators[signal_id] = generator
                    self.generators[signal_id].start()
                    self.logger.debug('MockBusObserver manually started MockSignalGenerator for {}'.format(signal_id))
            else:
                if self.generators[signal_id].use_signal_request_trigger() is False:
                    # This generator is triggered manually
                    self.generators[signal_id].start()
                    self.logger.debug('MockBusObserver manually started MockSignalGenerator for {}'.format(signal_id))
        # pylint: disable=broad-except
        except Exception as err:
            self.logger.warning(err)

    # pylint: disable=unused-argument
    async def __on_signal_stop(self, ev, topic):
        try:
            frame_id, signal = self.extract_can_info_from_topic(topic)

            signal_id = self.get_signal_id(frame_id, signal)

            if signal_id not in self.generators:
                return

            if self.generators[signal_id].use_signal_request_trigger() is False:
                # This generator is triggered manually
                self.generators[signal_id].stop()
                self.logger.debug('MockBusObserver stopped MockSignalGenerator for {}'.format(signal_id))
        # pylint: disable=broad-except
        except Exception as err:
            self.logger.warning(err)

    async def __on_signal(self, frame_id, signal, value):
        with self.lock:
            self.logger.info('Sending: "{}" to: {}'.format(value, self.get_signal_id(frame_id, signal)))
            await self.hal_broker.publish_json(self.get_signal_topic(frame_id, signal), { "value": value })

    def extract_can_info_from_topic(self, topic):
        # Returns frame_id, signal
        match = self.topic_regex.fullmatch(topic)

        if match is None:
            raise Exception('Invalid signal selector')

        return match[1].upper(), match[2]

class HalInterface:
    def __init__(self, abs_config_path):
        self.logger = logging.getLogger('HalInterface')
        self.bus_observer = []
        self.broker = None
        self.config = self.read_config(abs_config_path)
        self.topic_regex = None

        log_level = logging.WARNING

        try:
            log_level = Logger.resolve_log_level(self.config['loglevel'])
        finally:
            logging.getLogger().setLevel(log_level)

    async def start(self):
        await self.init_message_broker()

        # Starting all observers
        for bus_config in self.config['can']:
            if bus_config['interface'] == 'mock':
                bus_observer = MockBusObserver(bus_config, self.broker)
            else:
                bus_observer = BusObserver(bus_config, self.broker)

            self.bus_observer.append(bus_observer)
            await bus_observer.start()

        while True:
            # Make the application run forever
            await asyncio.sleep(1000)

    async def init_message_broker(self):
        self.broker = NamedMqttBroker('HalInterface-{}'.format(id(self)), self.config['mqtt']['connectionString'], self.config['mqtt']['ns'] or 'hal/')

        # pylint: disable=anomalous-backslash-in-string
        self.topic_regex = re.compile('^{}([^\.]+)\.(.+)\/(?:enable|disable)$'.format((self.broker.topic_ns or '').replace('\\/', '\\\\/')))
        self.logger.info("mqtt broker created")

        await self.broker.subscribe_json('+/enable', self.on_enable)
        await self.broker.subscribe_json('+/disable', self.on_disable)

        self.logger.info("mqtt subscribed for: enable/disable")

        return self.broker

    def read_config(self, abs_path):
        with open(abs_path, mode='r', encoding='utf-8') as config_file:
            return json.loads(config_file.read())

    # pylint: disable=unused-argument
    async def on_enable(self, ev, topic):
        # Add to filter 10.CruiseStatus2/enable
        self.logger.info("Enable for: '{}'".format(topic))

        try:
            frame_id, signal = self.extract_can_info_from_topic(topic)

            for bus_observer in self.bus_observer:
                bus_observer.add_to_filter(frame_id, signal)
        # pylint: disable=broad-except
        except Exception as err:
            self.logger.warning(err)

    # pylint: disable=unused-argument
    async def on_disable(self, ev, topic):
        # Remove from filter 10.CruiseStatus2/disable
        self.logger.info("Disable for: '{}'".format(topic))

        try:
            frame_id, signal = self.extract_can_info_from_topic(topic)

            for bus_observer in self.bus_observer:
                bus_observer.remove_from_filter(frame_id, signal)
        # pylint: disable=broad-except
        except Exception as err:
            self.logger.warning(err)

    def extract_can_info_from_topic(self, topic):
        # Returns frame_id, signal
        match = self.topic_regex.fullmatch(topic)

        if match is None:
            raise Exception('Invalid signal selector')

        return match[1].upper(), match[2]
