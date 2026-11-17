import os
import socket
import subprocess
import sys
import time
import unittest
import urllib.request

from helpers import PORTAL, fresh_home


def free_port():
    s = socket.socket()
    s.bind(("127.0.0.1", 0))
    p = s.getsockname()[1]
    s.close()
    return p


class ServerTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.home, cls.prof, cls.core = fresh_home()
        cls.port = free_port()
        cfg = cls.core.load_config()
        cfg["token"] = "testtoken1"
        cfg["port"] = cls.port
        cls.core.save_config(cfg)
        env = dict(os.environ, HOME=str(cls.home))
        cls.proc = subprocess.Popen([sys.executable, str(PORTAL / "spdw_stream_core.py"), "serve", "--port", str(cls.port)],
                                    env=env, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        for _ in range(50):
            try:
                socket.create_connection(("127.0.0.1", cls.port), timeout=0.2).close()
                break
            except OSError:
                time.sleep(0.1)

    @classmethod
    def tearDownClass(cls):
        cls.proc.terminate()
        cls.proc.wait(timeout=5)

    def get(self, path):
        try:
            with urllib.request.urlopen(f"http://127.0.0.1:{self.port}{path}", timeout=5) as r:
                return r.status, r.read().decode()
        except urllib.error.HTTPError as e:
            return e.code, ""

    def test_profiles_tsv_is_public(self):
        code, body = self.get("/profiles.tsv")
        self.assertEqual(code, 200)
        self.assertTrue(body.startswith("# profiles.tsv"))

    def test_private_files_are_not_served(self):
        for p in ("/config.json", "/../config.json", "/%2e%2e/config.json", "/serve.pid"):
            self.assertEqual(self.get(p)[0], 404, p)

    def test_ctl_rejects_bad_token(self):
        code, body = self.get("/ctl?token=nope&op=set&kind=GCPad&profile=muos&key=Buttons/Z&value=TL")
        self.assertTrue(body.startswith("ERR bad token"), body)

    def test_ctl_edits_with_token_and_validates(self):
        q = "/ctl?token=testtoken1&op=set&kind=GCPad&profile=muos&key=Buttons%2FZ&value="
        _, body = self.get(q + "TL")
        self.assertTrue(body.startswith("OK"), body)
        self.assertEqual(dict(self.prof.read(self.core.load_config(), "GCPad", "muos"))["Buttons/Z"], "TL")
        self.assertTrue(self.get(q + "A%0AEvil")[1].startswith("ERR"))
        self.assertTrue(self.get("/ctl?token=testtoken1&op=set&kind=GCPad&profile=evil&key=Buttons%2FZ&value=TL")[1].startswith("ERR"))

    def test_ctl_switches_active_profile(self):
        _, body = self.get("/ctl?token=TESTTOKEN1&op=active&kind=Wiimote&profile=muos-nunchuk")   # token is case-insensitive
        self.assertTrue(body.startswith("OK"), body)
        self.assertEqual(self.prof.active(self.core.load_config())["Wiimote"], "muos-nunchuk")


if __name__ == "__main__":
    unittest.main()
