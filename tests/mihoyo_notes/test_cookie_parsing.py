import unittest

from tools.mihoyo_notes.mihoyo_notes.cookies import cookie_header, parse_cookie_text, redacted_cookie_keys


class CookieParsingTests(unittest.TestCase):
    def test_parse_cookie_pairs(self):
        cookies = parse_cookie_text("ltuid=123; ltoken=abc; cookie_token=secret")

        self.assertEqual(cookies["ltuid"], "123")
        self.assertEqual(cookies["ltoken"], "abc")
        self.assertEqual(cookies["cookie_token"], "secret")

    def test_parse_cookie_json(self):
        cookies = parse_cookie_text('{"ltuid": 123, "ltoken": "abc"}')

        self.assertEqual(cookies, {"ltuid": "123", "ltoken": "abc"})

    def test_cookie_header(self):
        self.assertEqual(cookie_header({"a": "1", "b": "2"}), "a=1; b=2")

    def test_redacts_sensitive_values(self):
        redacted = redacted_cookie_keys({"ltoken": "secret", "ltuid": "123"})

        self.assertEqual(redacted["ltoken"], "<redacted>")
        self.assertEqual(redacted["ltuid"], "123")


if __name__ == "__main__":
    unittest.main()
