Expire pickup codes after 72 hours

Codes now stop opening the door 72 hours after the drop. The resident gets "code for locker N has expired; ask the front desk", and the parcel stays in the locker. A wrong code is still reported as wrong after expiry, so the message can't be used to confirm a guess. The decision is written up in `docs/decisions/002`.

`Locker` takes an optional `clock:` so the tests can move time.
