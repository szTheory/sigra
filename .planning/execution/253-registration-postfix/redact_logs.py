"""Retain server/query structure; remove authentication values before committing logs."""
import hashlib
import json
from pathlib import Path
import re

HERE=Path(__file__).resolve().parent


def main():
    target=HERE/'log-redaction.json'
    assert not target.exists(), 'logs already redacted; do not overwrite the original hashes'
    records=[]
    for path in sorted((HERE/'runtime-output').glob('*/*.log')):
        if path.name not in ['app.log','setup.log']:
            continue
        raw=path.read_bytes()
        text=re.sub(r'\x1b\[[0-9;]*m','',raw.decode())
        output=[];counts=dict(sql_arguments=0,parameters=0,sensitive_lines=0)
        for line in text.splitlines(keepends=True):
            query=re.match(r'^(\s*(?:SELECT|INSERT|UPDATE|DELETE|WITH|CREATE|ALTER|DROP|BEGIN|COMMIT|ROLLBACK)\b.*?) \[.*(?:\n)?$',line)
            if query:
                line=query.group(1)+' [SQL arguments redacted]\n';counts['sql_arguments']+=1
            elif re.match(r'^\s*(?:Parameters:|Session:|Last message:)',line):
                line=line.split(':',1)[0]+': [authentication values redacted]\n';counts['parameters']+=1
            elif re.search(r'password|secret|token|/users/(?:confirm|reset_password)/',line,re.I):
                line='[authentication values redacted]\n';counts['sensitive_lines']+=1
            output.append(line)
        redacted=''.join(output).encode()
        path.write_bytes(redacted)
        records.append(dict(path=str(path.relative_to(HERE)),original_sha256=hashlib.sha256(raw).hexdigest(),
                            original_bytes=len(raw),retained_sha256=hashlib.sha256(redacted).hexdigest(),
                            retained_bytes=len(redacted),counts=counts))
    target.write_text(json.dumps(dict(rule='strip ANSI; redact SQL arguments, request/session payloads and remaining authentication-value lines; retain native browser reports unchanged',files=records),indent=2)+'\n')
    print('Redacted',len(records),'logs; native browser reports and runtime result unchanged.')


if __name__=='__main__':main()
