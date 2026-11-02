import json
import os
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch
import linux_telemetry
import path_probes
import service_config

class AdapterConfiguration(unittest.TestCase):
    def test_no_implicit_configuration(self):
        with patch.dict(os.environ, {}, clear=True):
            self.assertEqual(service_config.load_config(), {})

    def test_missing_gateway_has_no_process(self):
        with patch.object(linux_telemetry, 'GATEWAY_COMMAND', []), patch('linux_telemetry.subprocess.run') as run:
            with self.assertRaisesRegex(RuntimeError, 'not_configured'):
                linux_telemetry.read_gateway_snapshot()
            run.assert_not_called()

    def test_missing_probe_has_no_network_process(self):
        with patch.dict(path_probes.PEERS, {'winpc':'198.51.100.20'}, clear=True), patch.object(path_probes, 'PROBE_COMMAND', []), patch('path_probes.subprocess.run') as run:
            result = path_probes.probe_peer('winpc')
            self.assertFalse(result['ok'])
            run.assert_not_called()

    def test_gateway_reads_only_explicit_adapter(self):
        packet = {'metadata':{'services':[], 'privatePeers':{}, 'gatewaySelf':{}}, 'controller':{}}
        with patch.object(linux_telemetry, 'GATEWAY_COMMAND', ['example-status-adapter']), patch.object(linux_telemetry, 'GUEST_UNITS', []), patch('linux_telemetry.subprocess.run') as run:
            run.return_value.stdout = json.dumps(packet).encode()
            result = linux_telemetry.read_gateway_snapshot()
            self.assertEqual(result['privateLinks']['mac']['kind'], 'unknown')
            self.assertEqual(result['proxy']['error'], 'controller_not_configured')
            self.assertEqual(run.call_args.args[0], ['example-status-adapter'])
