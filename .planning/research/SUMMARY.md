# Research Summary — v1.22 Webhooks

## Stack additions

- durable subscription, event, and delivery-attempt storage
- HMAC-SHA256 signing using built-in crypto
- explicit async dispatch path
- generated admin LiveView and host wiring

## Feature table stakes

- subscription registry
- signed HTTPS delivery
- event filtering
- retry with dead-letter
- delivery history

## Watch out for

- never block auth success on remote endpoint response
- do not expose raw internal audit shapes as the public webhook contract
- require stable delivery IDs and documented signature verification
- make failure states inspectable from the generated admin surface
