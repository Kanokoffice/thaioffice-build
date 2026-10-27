# Positive control for the network test: this program fetches a web page, so its connection must be logged.
import sys
import urllib.request

url = sys.argv[1] if len(sys.argv) > 1 else "https://example.com/"
try:
    print("control python bytes", len(urllib.request.urlopen(url, timeout=20).read()))
except Exception as e:  # report and go on: the connection attempt is what the log must show
    print("control python error", type(e).__name__, e)
