"""
tw_stock.py — hermesagent 台股查價 Tool
支援：上市（TSE）、上櫃（OTC/TPEx）、ETF（含後綴字母如 00403A）
查價順序：即時報價 → 盤後歷史（當月）→ 跨月 fallback（最多 3 個月）
"""

import requests
import json
from datetime import datetime

# ════════════════════════════════════════════
# 常數
# ════════════════════════════════════════════

HEADERS = {"User-Agent": "Mozilla/5.0"}
TIMEOUT = 10


# ════════════════════════════════════════════
# 工具：判斷市場別
# ════════════════════════════════════════════

def _detect_market(stock_no: str) -> str:
    """
    回傳 'tse'（上市）或 'otc'（上櫃）。
    規則：
      - 6 開頭 → otc
      - 其餘 → tse（預設，caller 會 fallback）
    """
    if stock_no.startswith("6"):
        return "otc"
    return "tse"


# ════════════════════════════════════════════
# 即時報價（TSE + OTC 共用 TWSE MIS API）
# ════════════════════════════════════════════

def _is_numeric(v) -> bool:
    try:
        float(str(v).replace(",", ""))
        return True
    except (TypeError, ValueError):
        return False


def _fetch_realtime(stock_no: str) -> dict | None:
    """
    盤中即時報價。
    上市用 tse_{code}.tw，上櫃用 otc_{code}.tw。
    兩個都試，任一有資料就回傳。

    MIS API 欄位：
      z = 最新成交價（搓合前為 "-"）
      o = 開盤價
      y = 昨收價
      h = 最高, l = 最低
      pz = 漲跌, tv = 成交量, t = 時間
    """
    url = "https://mis.twse.com.tw/stock/api/getStockInfo.jsp"

    market = _detect_market(stock_no)
    prefixes = (
        [f"tse_{stock_no}.tw", f"otc_{stock_no}.tw"]
        if market == "tse"
        else [f"otc_{stock_no}.tw", f"tse_{stock_no}.tw"]
    )

    for ex_ch in prefixes:
        try:
            resp = requests.get(
                url,
                params={"ex_ch": ex_ch, "json": "1", "delay": "0"},
                headers=HEADERS,
                timeout=TIMEOUT,
            )
            resp.raise_for_status()
            items = resp.json().get("msgArray", [])
            if not items:
                continue

            item = items[0]
            z = item.get("z")   # 最新成交價
            o = item.get("o")   # 開盤價
            y = item.get("y")   # 昨收價
            market_tag = "tse" if ex_ch.startswith("tse") else "otc"

            no_trade_yet = z in ("-", None, "")

            if no_trade_yet:
                # 有昨收(y) 且有開盤(o) → 盤中真空期（開盤但尚未搓出第一筆）
                if _is_numeric(y) and _is_numeric(o):
                    return {
                        "realtime":   True,
                        "pending":    True,       # price 為昨收參考值
                        "market":     market_tag,
                        "stock_no":   stock_no,
                        "name":       item.get("n", ""),
                        "price":      y,          # 昨收，僅供參考
                        "open":       o,
                        "high":       item.get("h"),
                        "low":        item.get("l"),
                        "prev_close": y,
                        "change":     None,
                        "volume":     "0",
                        "time":       item.get("t"),
                        "source":     "TWSE MIS 即時（盤中尚未成交）",
                    }
                # 盤前 / 盤後 / 非交易日 → 試下一個 prefix
                continue

            return {
                "realtime":   True,
                "pending":    False,
                "market":     market_tag,
                "stock_no":   stock_no,
                "name":       item.get("n", ""),
                "price":      z,
                "open":       o,
                "high":       item.get("h"),
                "low":        item.get("l"),
                "prev_close": y,
                "change":     item.get("pz"),
                "volume":     item.get("tv"),
                "time":       item.get("t"),
                "source":     "TWSE MIS 即時",
            }

        except Exception:
            continue

    return None


# ════════════════════════════════════════════
# 盤後歷史：上市（TWSE）
# ════════════════════════════════════════════

def _fetch_tse_stock_day(stock_no: str, year: int, month: int) -> dict | None:
    """
    TWSE 盤後月資料，回傳最新一筆。
    欄位順序：
      0: 日期, 1: 成交股數, 2: 成交金額,
      3: 開盤, 4: 最高, 5: 最低, 6: 收盤, 7: 漲跌, 8: 成交筆數
    """
    url = "https://www.twse.com.tw/exchangeReport/STOCK_DAY"
    params = {
        "response": "json",
        "stockNo":  stock_no,
        "date":     f"{year}{month:02d}01",
    }

    resp = requests.get(url, params=params, headers=HEADERS, timeout=TIMEOUT)
    resp.raise_for_status()
    data = resp.json()

    if data.get("stat") != "OK":
        return None
    if stock_no not in data.get("title", ""):
        return None

    rows = data.get("data", [])
    if not rows:
        return None

    latest = rows[-1]   # 最後一筆 = 最新交易日
    return {
        "realtime": False,
        "pending":  False,
        "market":   "tse",
        "stock_no": stock_no,
        "name":     data["title"].split(" ")[-1],
        "date":     latest[0],
        "open":     latest[3],
        "high":     latest[4],
        "low":      latest[5],
        "close":    latest[6],   # 收盤價，正確欄位
        "change":   latest[7],
        "volume":   latest[1],
        "source":   f"TWSE 盤後 ({year}/{month:02d})",
    }


# ════════════════════════════════════════════
# 盤後歷史：上櫃（TPEx）
# ════════════════════════════════════════════

def _fetch_otc_stock_day(stock_no: str, year: int, month: int) -> dict | None:
    """
    TPEx 盤後月資料，回傳最新一筆。
    TPEx 用民國年，date 格式：{民國年}/{月}，例如 114/05
    欄位順序：
      0: 日期, 1: 收盤, 2: 漲跌, 3: 開盤, 4: 最高, 5: 最低,
      6: 成交量(張), 7: 成交金額(元), 8: 成交筆數
    """
    roc_year = year - 1911
    url = "https://www.tpex.org.tw/web/stock/aftertrading/daily_trading_info/stk_quote_result.php"
    params = {
        "l":     "zh-tw",
        "d":     f"{roc_year}/{month:02d}",
        "stkno": stock_no,
        "s":     "0,asc",
    }

    resp = requests.get(url, params=params, headers=HEADERS, timeout=TIMEOUT)
    resp.raise_for_status()
    data = resp.json()

    rows = data.get("aaData", [])
    if not rows:
        return None
    if data.get("iTotalRecords", 0) == 0:
        return None

    latest = rows[-1]

    def clean(v: str) -> str:
        return v.replace(",", "").strip()

    return {
        "realtime": False,
        "pending":  False,
        "market":   "otc",
        "stock_no": stock_no,
        "name":     data.get("stkName", stock_no),
        "date":     latest[0],
        "open":     clean(latest[3]),
        "high":     clean(latest[4]),
        "low":      clean(latest[5]),
        "close":    clean(latest[1]),   # TPEx 收盤在 index 1
        "change":   clean(latest[2]),
        "volume":   clean(latest[6]),
        "source":   f"TPEx 盤後 ({year}/{month:02d})",
    }


# ════════════════════════════════════════════
# 主函式（供 dispatcher 呼叫）
# ════════════════════════════════════════════

def get_tw_stock_price(stock_no: str) -> str:
    stock_no = stock_no.upper().strip()

    # Step 1：即時報價
    try:
        rt = _fetch_realtime(stock_no)
        if rt:
            return json.dumps(rt, ensure_ascii=False)
    except Exception:
        pass

    # Step 2：盤後歷史，跨月 fallback（最多往回 3 個月）
    now = datetime.now()
    year, month = now.year, now.month

    for i in range(3):
        m = month - i
        y = year
        if m <= 0:
            m += 12
            y -= 1

        # 先試上市
        try:
            result = _fetch_tse_stock_day(stock_no, y, m)
            if result:
                return json.dumps(result, ensure_ascii=False)
        except Exception:
            pass

        # 再試上櫃
        try:
            result = _fetch_otc_stock_day(stock_no, y, m)
            if result:
                return json.dumps(result, ensure_ascii=False)
        except Exception:
            pass

    return json.dumps(
        {"error": f"查無 {stock_no} 資料（已試上市+上櫃，往回查 3 個月）"},
        ensure_ascii=False,
    )


# ════════════════════════════════════════════
# Tool Schema
# ════════════════════════════════════════════

TW_STOCK_TOOL = {
    "type": "function",
    "function": {
        "name": "get_tw_stock_price",
        "description": (
            "查詢台灣上市（TSE）、上櫃（OTC）股票及 ETF 的最新價格。"
            "交易時間內回傳即時成交價，盤後回傳收盤價。"
            "當月無資料時自動往回查最多 3 個月。"
            "支援含後綴字母的 ETF 代碼，例如 00403A。"
        ),
        "parameters": {
            "type": "object",
            "properties": {
                "stock_no": {
                    "type": "string",
                    "description": (
                        "台灣股票或 ETF 代碼，純數字或數字+單一大寫字母。"
                        "例如：'2330'（台積電）、'6547'（高端疫苗）、'00403A'（統一升級50）"
                    ),
                    "pattern": "^[0-9]{4,6}[A-Z]?$",
                }
            },
            "required": ["stock_no"],
        },
    },
}


if __name__ == "__main__":
    import sys
    code = sys.argv[1] if len(sys.argv) > 1 else "2330"
    print(get_tw_stock_price(code))
