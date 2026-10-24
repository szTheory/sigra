"""Offline repair candidate. Does not change or replace the frozen production transport."""
import json,re

def scrub_json_receipt(transport,headers,body,secrets,raw_headers):
    # Reuse unchanged header validation, duplicate handling and trusted-location checks.
    safe,_=transport.scrub_receipt(headers,b'',secrets,raw_headers)
    try:value=json.loads(body)
    except (ValueError,UnicodeDecodeError):
        return transport.scrub_receipt(headers,body,secrets,raw_headers)
    sensitive=re.compile(r'^(access_token|token|secret|password|client_secret|authorization|cookie|set-cookie)$',re.I)
    def walk(node):
        if isinstance(node,dict):
            return {key:('[REDACTED]' if sensitive.fullmatch(key) else walk(item)) for key,item in node.items()}
        if isinstance(node,list):return [walk(item) for item in node]
        if isinstance(node,str):return transport._scrub_text(node,secrets)
        return node
    return safe,json.dumps(walk(value),ensure_ascii=False,separators=(',',':')).encode()
