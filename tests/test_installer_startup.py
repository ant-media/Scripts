"""Exercise installer startup checks without installing packages or services."""
import pathlib
import subprocess
import tempfile
import unittest

SCRIPT = (pathlib.Path(__file__).resolve().parents[1] / 'install_ant-media-server.sh').read_text()
HELPERS = SCRIPT[SCRIPT.index('check() {'):SCRIPT.index('# Start\n')]


class StartupTests(unittest.TestCase):
    def run_shell(self, body):
        with tempfile.TemporaryDirectory() as directory:
            conf = pathlib.Path(directory) / 'conf'
            conf.mkdir()
            (conf / 'red5.properties').write_text('http.port=5090\n')
            return subprocess.run(['bash', '-c', HELPERS + '\n' + '''
SUDO=""
AMS_BASE="$1"
LOG_DIRECTORY="$1"
sleep() { SECONDS=$((SECONDS + 10)); }
systemctl() {
  case "$1" in
    is-active) return "${ACTIVE_RC:-0}";;
    show) echo "${TEST_PID:-$$}";;
    status) echo diagnostic-status;;
  esac
}
journalctl() { echo diagnostic-journal; }
curl() { echo "${HTTP_CODE:-200}"; }
''' + body, 'test', directory], capture_output=True, text=True)

    def test_ready(self):
        result = self.run_shell('wait_for_server; echo ready')
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn('5090', result.stdout)
        self.assertIn('ready', result.stdout)

    def test_inactive_or_missing_pid_or_http_error(self):
        for setting in ['ACTIVE_RC=3', 'TEST_PID=0', 'TEST_PID=invalid', 'HTTP_CODE=503']:
            with self.subTest(setting=setting):
                result = self.run_shell(setting + '\nwait_for_server\necho FALSE_SUCCESS')
                self.assertEqual(result.returncode, 1)
                self.assertNotIn('FALSE_SUCCESS', result.stdout)
                self.assertIn('diagnostic-journal', result.stderr)

    def test_transient_readiness_does_not_pass(self):
        result = self.run_shell('''
calls=0
service_running() { calls=$((calls + 1)); (( calls % 3 != 0 )); }
wait_for_server
echo FALSE_SUCCESS
''')
        self.assertEqual(result.returncode, 1)
        self.assertNotIn('FALSE_SUCCESS', result.stdout)

    def test_delayed_start(self):
        result = self.run_shell('''
calls=0
service_running() { calls=$((calls + 1)); (( calls > 2 )); }
wait_for_server
[[ "$calls" == 5 ]]
''')
        self.assertEqual(result.returncode, 0, result.stderr)

    def test_critical_failure_keeps_exit_code(self):
        result = self.run_shell('(exit 42)\ncheck\necho FALSE_SUCCESS')
        self.assertEqual(result.returncode, 42)
        self.assertNotIn('FALSE_SUCCESS', result.stdout)

    def test_sysv_status_fallback(self):
        result = self.run_shell('''
command() { return 1; }
service() { [[ "$*" == 'antmedia status' ]]; }
service_running
''')
        self.assertEqual(result.returncode, 0, result.stderr)


if __name__ == '__main__':
    unittest.main()
