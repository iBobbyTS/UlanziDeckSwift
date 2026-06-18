import unittest

from tools.mihoyo_notes.mihoyo_notes.client import MiyousheClient
from tools.mihoyo_notes.mihoyo_notes.models import Game


class FakeHttp:
    def __init__(self, payload):
        self.payload = payload
        self.calls = []

    def request_json(self, method, url, *, headers=None, params=None, json_body=None):
        self.calls.append((method, url, headers, params, json_body))
        return self.payload


class BoundRolesTests(unittest.TestCase):
    def test_bound_roles_extracts_three_games(self):
        payload = {
            "retcode": 0,
            "message": "OK",
            "data": {
                "list": [
                    {"game_biz": "hk4e_cn", "game_uid": "100000001", "region": "cn_gf01", "nickname": "A", "level": 60},
                    {"game_biz": "hkrpg_cn", "game_uid": "100000002", "region": "prod_gf_cn", "nickname": "B", "level": "70"},
                    {"game_biz": "nap_cn", "game_uid": "10000003", "region": "prod_gf_cn", "nickname": "C", "level": 60},
                    {"game_biz": "unknown", "game_uid": "x", "region": "x"},
                ]
            },
        }
        client = MiyousheClient("cookie=placeholder", http=FakeHttp(payload))

        roles = client.bound_roles()

        self.assertEqual([role.game for role in roles], [Game.GENSHIN, Game.STARRAIL, Game.ZZZ])
        self.assertEqual(roles[1].level, 70)


if __name__ == "__main__":
    unittest.main()
