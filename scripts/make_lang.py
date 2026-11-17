#!/usr/bin/env python3
"""Generate owncast.lang for the TOS App Center (26 locales, English fill)."""
NAME_EN = "Owncast Live Streaming"
AUTHOR = "ericbyz"
DESC_EN = (
    "Self-hosted live streaming server: push RTMP from OBS or any encoder to the "
    "NAS and viewers watch in the browser (low-latency HLS) with built-in chat. "
    "Watch at http://<NAS>:18239; push to rtmp://<NAS>:1935/<streamKey> (key "
    "generated at install). Packaged unmodified from upstream owncast/owncast "
    "(MIT); requires ffmpeg for transcoding."
)
NOTE_EN = "1. Repackaged upstream owncast/owncast (MIT) unmodified for TOS."
NOTE_ZH = "1. 将上游 owncast/owncast(MIT)原样封装为 TOS 应用。"

PRIMARY = [
    ("zh-cn", "Owncast 自托管直播",
     "自托管直播服务器:OBS 等推流软件把 RTMP 流推到 NAS(rtmp://<NAS>:1935/<推流密钥>),"
     "观众在浏览器里低延迟观看(HLS)+ 内置弹幕聊天。观看地址 http://<NAS>:18239,"
     "推流密钥安装时自动生成(存于 /var/lib/owncast/config.yaml)。"
     "上游二进制原样封装(MIT),转码依赖 ffmpeg(TOS 出厂自带)。"),
    ("zh-hk", "Owncast 自託管直播",
     "自託管直播伺服器:OBS 等推流軟體把 RTMP 流推到 NAS(rtmp://<NAS>:1935/<推流密鑰>),"
     "觀眾在瀏覽器裡低延遲觀看(HLS)+ 內置彈幕聊天。觀看地址 http://<NAS>:18239。"),
]

ORDER = ["zh-cn", "zh-hk", "en-us", "ko-kr", "ja-jp", "de-de", "fr-fr", "it-it",
         "es-es", "hu-hu", "pl-pl", "tr-tr", "ru-ru", "pt-pt", "cs-cz", "da-dk",
         "nl-nl", "nb-no", "sv-se", "el-gr", "ro-ro", "th-th", "vi-vn", "id-id",
         "ar-sa", "he-il"]

NATIVE = {
    "ja-jp": "セルフホスト配信サーバー:OBS などから RTMP で NAS に配信し、視聴者はブラウザで低遅延 HLS+チャットで視聴。視聴 URL は http://<NAS>:18239、ストリームキーはインストール時に生成。上流バイナリを無改修でパッケージ化(MIT)、トランスコードには ffmpeg が必要。",
    "ko-kr": "셀프 호스트 라이브 스트리밍 서버: OBS 등에서 RTMP로 NAS에 송신하고 시청자는 브라우저에서 저지연 HLS+채팅으로 시청합니다. 시청 URL http://<NAS>:18239, 스트림 키는 설치 시 생성. 업스트림 바이너리 무수정 패키징(MIT), 트랜스코딩에 ffmpeg 필요.",
    "de-de": "Self-Hosting-Livestreaming-Server: RTMP von OBS an die NAS pushen, Zuschauer sehen low-latency HLS mit integriertem Chat unter http://<NAS>:18239. Stream-Key wird bei der Installation generiert. Upstream unverändert paketiert (MIT), Transcodierung via ffmpeg.",
    "fr-fr": "Serveur de direct auto-hébergé : poussez du RTMP depuis OBS vers le NAS, les spectateurs regardent en HLS faible latence avec chat intégré sur http://<NAS>:18239. Clé de flux générée à l'installation. Amont intact (MIT), transcodage via ffmpeg.",
    "es-es": "Servidor de emisión autoalojado: envíe RTMP desde OBS al NAS, los espectadores ven HLS de baja latencia con chat integrado en http://<NAS>:18239. Clave de emisión generada al instalar. Upstream intacto (MIT), transcodificación vía ffmpeg.",
    "ru-ru": "Самостоятельный сервер прямых трансляций: отправляйте RTMP из OBS на NAS, зрители смотрят низколатентный HLS со встроенным чатом на http://<NAS>:18239. Ключ потока генерируется при установке. Оригинальные бинарники без изменений (MIT), транскодирование через ffmpeg.",
}

def main(out_path):
    lines = []
    for loc in ORDER:
        name, desc = NAME_EN, NATIVE.get(loc, DESC_EN)
        for l, n, d in PRIMARY:
            if l == loc:
                name, desc = n, d
                break
        note = NOTE_ZH if loc in ("zh-cn", "zh-hk") else NOTE_EN
        lines += [f"[{loc}]", f'name = "{name}"', f'auth = "{AUTHOR}"',
                  f'descript = "{desc}"', f'note = "{note}"', ""]
    open(out_path, "w", encoding="utf-8", newline="\n").write("\n".join(lines))
    print("wrote", out_path, len(ORDER), "locales")

if __name__ == "__main__":
    main("owncast.lang")
