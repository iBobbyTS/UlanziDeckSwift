import unittest

from tools.mihoyo_notes.mihoyo_notes.client import MiyousheClient
from tools.mihoyo_notes.mihoyo_notes.models import Game


class ClientMappingTests(unittest.TestCase):
    def test_genshin_status_mapping_prefers_reward_claimed(self):
        client = MiyousheClient("cookie=placeholder")
        status = client._daily_status(
            Game.GENSHIN,
            {
                "current_resin": 120,
                "max_resin": 200,
                "resin_recovery_time": "3600",
                "finished_task_num": 4,
                "total_task_num": 4,
                "is_extra_task_reward_received": False,
            },
        )

        self.assertEqual(status.stamina_name, "树脂")
        self.assertEqual(status.current_stamina, 120)
        self.assertEqual(status.daily_current, 4)
        self.assertFalse(status.daily_done)

    def test_starrail_status_mapping(self):
        client = MiyousheClient("cookie=placeholder")
        status = client._daily_status(
            Game.STARRAIL,
            {
                "current_stamina": 240,
                "max_stamina": 240,
                "stamina_recover_time": 0,
                "current_train_score": 500,
                "max_train_score": 500,
            },
        )

        self.assertEqual(status.stamina_name, "开拓力")
        self.assertEqual(status.current_stamina, 240)
        self.assertTrue(status.daily_done)

    def test_zzz_status_mapping(self):
        client = MiyousheClient("cookie=placeholder")
        status = client._daily_status(
            Game.ZZZ,
            {
                "energy": {"progress": {"current": 320, "max": 240}, "restore": 0},
                "vitality": {"current": 300, "max": 400},
                "card_sign": "Done",
                "bounty_commission": {"num": 2, "total": 4},
            },
        )

        self.assertEqual(status.stamina_name, "电量")
        self.assertEqual(status.current_stamina, 320)
        self.assertEqual(status.max_stamina, 240)
        self.assertEqual(status.daily_name, "活跃度")
        self.assertEqual(status.daily_current, 300)
        self.assertEqual(status.daily_max, 400)
        self.assertFalse(status.daily_done)
        self.assertEqual(status.extra["bounty_commission"], {"num": 2, "total": 4})
        self.assertTrue(status.extra["card_sign_done"])
        self.assertFalse(status.extra["stamina_may_be_capped_by_source"])

    def test_widget_source_marks_stamina_as_maybe_capped(self):
        client = MiyousheClient("cookie=placeholder")
        status = client._daily_status(
            Game.ZZZ,
            {
                "energy": {"progress": {"current": 240, "max": 240}, "restore": 0},
                "vitality": {"current": 400, "max": 400},
            },
            source="widget",
        )

        self.assertEqual(status.extra["source"], "widget")
        self.assertTrue(status.extra["stamina_may_be_capped_by_source"])


if __name__ == "__main__":
    unittest.main()
