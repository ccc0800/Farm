"""
tw_stock.py — hermesagent 台股查價 Tool (V1.6)
支援：上市（TSE）、上櫃（OTC/TPEx）、ETF（含後綴字母如 00403A）
優化重點：Session 複用、精準市場分流、盤後欄位兼容、高效 Fallback 機制

V1.4 修正：
  - [Bug] 即時報價 change 欄位錯用 pz（前次成交價），改為 z - y 自算漲跌
  - [Bug] _detect_market 6 開頭誤判為 OTC；6 字頭多為 TSE 上市，移除此規則

V1.5 修正：
  - [Bug] 即時報價 volume 誤用 tv（單筆瞬間成交量），改用 v（當日累計成交量）
  - [Bug] change 欄位型態不一致：即時為 float、歷史為字串，統一為帶正負號字串
  - [優化] Step 2 歷史 fallback 迴圈順序改為「月份外層、市場內層」交替查詢，
           猜錯市場時每個月只多打 1 次請求，而非把整輪 3 個月浪費在錯誤市場
  - 註：未採用「前兩碼 prefix 對照表」判斷市場，因台股代碼前兩碼與上市/上櫃
       無官方對應規則，硬記一份來源不明的清單反而誤導維護者；交替查詢已能
       將猜錯市場的代價壓到最低，故維持原本單碼 3/5 判斷

V1.6 修正：
  - [Bug] TWSE MIS API 在部分 ETF（如 009816）會把 z（最新成交價）欄位
    誤回傳為股票代碼本身，導致 price 顯示為 "009816"、change 出現離譜數字
    （如 +9800.95）。新增 _is_valid_price() 防呆，偵測 z 數值等於代碼本身
    時視為異常並丟棄，改用昨收價為參考值、標註來源為「價格欄位異常」。
"""

import requests
import json
from datetime import datetime

# ════════════════════════════════════════════
# 常數與 Session 初始化
# ════════════════════════════════════════════

HEADERS = {"User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36"}
TIMEOUT = 5

_session = requests.Session()
_session.headers.update(HEADERS)


# ════════════════════════════════════════════
# 工具函式
# ════════════════════════════════════════════

def _detect_market(stock_no: str) -> str:
    """
    回傳 'tse'（上市）或 'otc'（上櫃）。僅作為查詢順序的「初猜」，
    猜錯時 Step 2 會以月份為外層、市場為內層交替查詢，代價壓到最低。
    規則：
      - 首碼 3 / 5 → otc（上櫃大宗）
      - 其餘（含 6 開頭） → tse（6 字頭上市公司眾多，不列入 OTC）
    """
    if stock_no and stock_no[0] in ("3", "5"):
        return "otc"
    return "tse"


def _is_numeric(v) -> bool:
    try:
        float(str(v).replace(",", ""))
        return True
    except (TypeError, ValueError):
        return False


def _safe_float(v) -> float | None:
    """字串轉 float，失敗回傳 None。"""
    try:
        return float(str(v).replace(",", "").strip())
    except (TypeError, ValueError):
        return None


def _is_valid_price(z, stock_no) -> bool:
    """
    防呆：TWSE MIS API 在特定 ETF／特殊狀況下，z（最新成交價）欄位
    會誤帶回股票代碼本身的數字（例如查 009816 時 z 回傳 "009816"）。
    將股票代碼的數字部分轉成 float 跟 z 比對，相同則判定為異常值。
    """
    if not _is_numeric(z):
        return False
    z_f = _safe_float(z)
    digits = "".join(ch for ch in stock_no if ch.isdigit())
    if digits:
        code_f = _safe_float(digits)
        if code_f is not None and z_f == code_f:
            return False
    return True


def _calc_change_str(z, y) -> str | None:
    """
    即時漲跌 = 最新成交價(z) - 昨收(y)，回傳帶正負號字串（如 "+2.50" / "-1.00"），
    與盤後歷史 API 的字串格式保持一致。
    MIS API 的 pz 為「前次成交價」，不是漲跌，不可使用。
    """
    z_f = _safe_float(z)
    y_f = _safe_float(y)
    if z_f is None or y_f is None:
        return None
    diff = round(z_f - y_f, 2)
    return f"+{diff:.2f}" if diff > 0 else f"{diff:.2f}"


# ════════════════════════════════════════════
# 即時報價
# ════════════════════════════════════════════

def _fetch_realtime(stock_no: str) -> dict | None:
    url = "https://mis.twse.com.tw/stock/api/getStockInfo.jsp"

    market = _detect_market(stock_no)
    prefixes = (
        [f"tse_{stock_no}.tw", f"otc_{stock_no}.tw"]
        if market == "tse"
        else [f"otc_{stock_no}.tw", f"tse_{stock_no}.tw"]
    )

    for ex_ch in prefixes:
        try:
            resp = _session.get(
                url,
                params={"ex_ch": ex_ch, "json": "1", "delay": "0"},
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
            c = item.get("c")   # 當日收盤價（盤後 z 可能變 "-"，以 c 補）
            market_tag = "tse" if ex_ch.startswith("tse") else "otc"

            # 盤後兼容：z 為 "-" 時嘗試以 c 補線
            if z in ("-", None, "") and _is_numeric(c):
                z = c

            # 防呆：z 若等於股票代碼本身（MIS API 異常值），視為無效
            z_was_invalid = z not in ("-", None, "") and not _is_valid_price(z, stock_no)
            if z_was_invalid:
                z = None

            no_trade_yet = z in ("-", None, "") or z is None

            if no_trade_yet:
                # 盤中真空期（開盤但尚未搓出第一筆），或 z 欄位異常被丟棄
                if _is_numeric(y) and _is_numeric(o):
                    return {
                        "realtime":   True,
                        "pending":    True,
                        "market":     market_tag,
                        "stock_no":   stock_no,
                        "name":       item.get("n", ""),
                        "price":      y,
                        "open":       o,
                        "high":       item.get("h"),
                        "low":        item.get("l"),
                        "prev_close": y,
                        "change":     None,
                        "volume":     item.get("v", "0"),   # v = 當日累計量，非 tv
                        "time":       item.get("t"),
                        "source": (
                            "TWSE MIS 即時（價格欄位異常，已改用昨收參考值）"
                            if z_was_invalid
                            else "TWSE MIS 即時（盤中尚未成交）"
                        ),
                    }
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
                "change":     _calc_change_str(z, y),   # 自算 z - y，字串格式
                "volume":     item.get("v"),             # v = 當日累計量，非 tv
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
    url = "https://www.twse.com.tw/exchangeReport/STOCK_DAY"
    params = {
        "response": "json",
        "stockNo":  stock_no,
        "date":     f"{year}{month:02d}01",
    }

    resp = _session.get(url, params=params, timeout=TIMEOUT)
    resp.raise_for_status()
    data = resp.json()

    if data.get("stat") != "OK" or not data.get("data"):
        return None
    if stock_no not in data.get("title", ""):
        return None

    latest = data["data"][-1]
    return {
        "realtime": False,
        "pending":  False,
        "market":   "tse",
        "stock_no": stock_no,
        "name":     data["title"].split(" ")[-1] or stock_no,
        "date":     latest[0],
        "open":     latest[3],
        "high":     latest[4],
        "low":      latest[5],
        "close":    latest[6],
        "change":   latest[7],
        "volume":   latest[1],
        "source":   f"TWSE 盤後 ({year}/{month:02d})",
    }


# ════════════════════════════════════════════
# 盤後歷史：上櫃（TPEx）
# ════════════════════════════════════════════

def _fetch_otc_stock_day(stock_no: str, year: int, month: int) -> dict | None:
    roc_year = year - 1911
    url = "https://www.tpex.org.tw/web/stock/aftertrading/daily_trading_info/stk_quote_result.php"
    params = {
        "l":     "zh-tw",
        "d":     f"{roc_year}/{month:02d}",
        "stkno": stock_no,
        "s":     "0,asc",
    }

    resp = _session.get(url, params=params, timeout=TIMEOUT)
    resp.raise_for_status()
    data = resp.json()

    rows = data.get("aaData", [])
    if not rows or data.get("iTotalRecords", 0) == 0:
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
        "close":    clean(latest[1]),
        "change":   clean(latest[2]),
        "volume":   clean(latest[6]),
        "source":   f"TPEx 盤後 ({year}/{month:02d})",
    }


# ════════════════════════════════════════════
# 主函式
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

    # Step 2：盤後歷史
    # 外層迴圈 = 月份，內層迴圈 = 市場（交替查）
    # 猜錯市場時，每個月只多打 1 次請求，不會把整輪 3 個月都浪費在錯誤市場
    now = datetime.now()
    year, month = now.year, now.month

    guessed = _detect_market(stock_no)
    markets_order = [guessed, "tse" if guessed == "otc" else "otc"]
    fetcher_map = {
        "tse": _fetch_tse_stock_day,
        "otc": _fetch_otc_stock_day,
    }

    for i in range(3):
        m = month - i
        y = year
        if m <= 0:
            m += 12
            y -= 1
        for mkt in markets_order:
            try:
                result = fetcher_map[mkt](stock_no, y, m)
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
