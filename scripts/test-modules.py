import json
from pathlib import Path
import re
import subprocess
import unittest


ROOT = Path(__file__).resolve().parents[1]


def body_rules(module):
    for line in (ROOT / "modules" / f"{module}.sgmodule").read_text().splitlines():
        if line.startswith("http-response-jq "):
            _, pattern, quoted_filter = line.split(" ", 2)
            yield pattern, quoted_filter[1:-1]


def rewrite(module, url, body):
    matched = False
    for pattern, jq_filter in body_rules(module):
        if re.search(pattern, url):
            matched = True
            result = subprocess.run(
                ["jq", "-c", jq_filter], input=json.dumps(body),
                text=True, capture_output=True, check=True,
            )
            body = json.loads(result.stdout)
    assert matched, url
    return body


class ModuleTests(unittest.TestCase):
    def test_removed_amap_script_is_not_referenced(self):
        self.assertNotIn(
            "https://kelee.one/Resource/JavaScript/Amap/Amap_remove_ads.js",
            (ROOT / "modules/amap.sgmodule").read_text(),
        )

    def test_weibo_timeline_keeps_regular_posts(self):
        for endpoint in ("friends/timeline", "unread_hot_timeline"):
            result = rewrite("weibo-intl", f"https://api.weibo.cn/2/statuses/{endpoint}", {
                "statuses": [{"id": 1, "text": "hello"}, {"id": 2, "ad_marked": True}],
                "ad": {}, "ad_version_2_weibo": [], "next_cursor": 42,
            })
            self.assertEqual(result, {"statuses": [{"id": 1, "text": "hello"}], "next_cursor": 42})

    def test_weibo_trends_keeps_search(self):
        result = rewrite("weibo-intl", "https://weibointl.api.weibo.cn/portal.php?a=trends", {
            "data": {"banner": [], "native_content": [], "discover": [
                {"schema": "搜索微博"}, {"schema": "尊享会员"},
            ], "search_topic": ["topic"]}, "retcode": 0,
        })
        self.assertEqual(result, {"data": {"discover": [{"schema": "搜索微博"}],
                                          "search_topic": ["topic"]}, "retcode": 0})

    def test_amap_keeps_navigation_tools(self):
        result = rewrite("amap", "https://sns.amap.com/ws/opc/tools/list?test=1", {
            "data": {"category": [{"tools": [{"id": "547", "name": "promo"},
                {"id": 1, "name": "navigation", "tips": "promotion"}]}]}, "code": 1,
        })
        self.assertEqual(result, {"data": {"category": [{"tools": [
            {"id": 1, "name": "navigation"}]}]}, "code": 1})

    def test_imported_jq_filters_compile(self):
        for module in ("amap", "weibo-intl"):
            for _, jq_filter in body_rules(module):
                subprocess.run(["jq", "-n", f"if false then ({jq_filter}) else null end"],
                               capture_output=True, text=True, check=True)


if __name__ == "__main__":
    unittest.main()
